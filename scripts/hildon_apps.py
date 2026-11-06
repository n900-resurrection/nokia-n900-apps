# Application catalogue of the PC emulator (used by scripts/hildon-shell.py, runs INSIDE the Workshop).
# Two sources, merged by name:
#   - development copies: apps/<app>/hildon-run.sh (GUI programs with demo data, see mutt-hildon),
#   - built packages: build/deb/*.deb (newest of each package) that carry a /usr/share/applications/hildon/*.desktop file;
#     name and icon come from the package, the package is unpacked into ./sysroot on the first start (like an installation)
#     and runs under qemu-user; "osso-xterm -e CMD" entries run in a host xterm.
import configparser
import glob
import os
import re
import shlex
import subprocess

PROJ = os.environ.get("PROJ", "/project")
SR = os.path.join(PROJ, "sysroot")
EMU = os.path.join(PROJ, "build", "emu")
ICON_DIRS = ("48x48", "64x64", "40x40", "scalable", "32x32", "26x26")


class Entry:
    def __init__(self, name, icon=None, app=None, deb=None, exec_line=None):
        self.name, self.icon, self.app, self.deb, self.exec_line = name, icon, app, deb, exec_line


def _newest_debs():
    best = {}
    for f in glob.glob(os.path.join(PROJ, "build", "deb", "*.deb")):
        pkg = os.path.basename(f).split("_", 1)[0]
        if pkg not in best or os.path.getmtime(f) > os.path.getmtime(best[pkg]):
            best[pkg] = f
    return best


def _unpack_metadata(deb):
    """Desktop files and icons of a package, cached in build/emu/pkgs/<deb>/."""
    d = os.path.join(EMU, "pkgs", os.path.basename(deb))
    if not os.path.isdir(d):
        os.makedirs(d)
        tar = subprocess.run("dpkg-deb --fsys-tarfile %s | tar -x -C %s --wildcards './usr/share/applications/hildon/*.desktop' './usr/share/icons/*'"
                             % (shlex.quote(deb), shlex.quote(d)), shell=True, capture_output=True)
        del tar     # a package without them is fine (tar reports "not found in archive")
    return d


def _find_icon(root, name):
    for size in ICON_DIRS:
        p = os.path.join(root, "usr/share/icons/hicolor", size, "apps", name + ".png")
        if os.path.exists(p):
            return p
    return None


def catalogue():
    dev = {}
    for path in sorted(glob.glob(os.path.join(PROJ, "apps", "*", "hildon-run.sh"))):
        d = os.path.basename(os.path.dirname(path))
        name = d
        with open(path, encoding="utf-8") as f:
            for line in f.readlines()[:10]:
                if line.startswith("# Name:"):
                    name = line.split(":", 1)[1].strip()
        icon = os.path.join(PROJ, "apps", d, "icons", "48.png")
        dev[d] = Entry(name, icon if os.path.exists(icon) else None, app=d)
    entries = []
    for pkg, deb in sorted(_newest_debs().items()):
        root = _unpack_metadata(deb)
        for desk in sorted(glob.glob(os.path.join(root, "usr/share/applications/hildon/*.desktop"))):
            cp = configparser.ConfigParser(strict=False, interpolation=None)
            try:
                cp.read(desk, encoding="utf-8")
                sec = cp["Desktop Entry"]
            except (configparser.Error, KeyError):
                continue
            name, exec_line = sec.get("Name", pkg), sec.get("Exec", "")
            icon = _find_icon(root, sec.get("Icon", pkg)) if sec.get("Icon") else None
            if pkg in dev:     # the development copy runs (demo data), the package supplies the icon
                dev[pkg].icon = icon or dev[pkg].icon
                dev[pkg].name = dev[pkg].name or name
            elif exec_line:
                entries.append(Entry(name, icon, deb=deb, exec_line=exec_line))
    entries = list(dev.values()) + entries
    return [Entry("Hildon demo")] + entries


def _install(deb):
    """Unpack the package into the sysroot once (a stand-in for installing it on the phone)."""
    stamp = os.path.join(EMU, "installed", os.path.basename(deb))
    if not os.path.exists(stamp):
        subprocess.run(["dpkg-deb", "-x", deb, SR], check=True)
        os.makedirs(os.path.dirname(stamp), exist_ok=True)
        open(stamp, "w").close()


PY2_PATH = ("%s/scripts/hildon-stubs:/usr/lib/pymodules/python2.5/gtk-2.0:/usr/lib/pymodules/python2.5:"
            "/usr/lib/python2.5/site-packages" % PROJ)


def _arm_command(argv, env):
    """Program of the sysroot to start: the host kernel runs ARM files through qemu-user (binfmt_misc, set up by hildon-session.sh);
    scripts run in the host shell, their `exec /opt/<app>/bin/...` finds the sysroot because it is bind-mounted on /opt.
    (qemu-user itself does not translate the path of execve, so `qemu-arm /bin/sh script` cannot start other ARM programs.)
    A script whose interpreter exists only in the sysroot (python2.5) is started through that interpreter, with the Python 2.5 paths
    and the Menu/Back helper of hildon-stubs (like make hildon-run PY2=1)."""
    exe = argv[0] if os.path.isabs(argv[0]) else os.path.join("/usr/bin", argv[0])
    with open(SR + exe, "rb") as f:
        head = f.read(128)
    if head.startswith(b"#!"):
        interp = shlex.split(head.split(b"\n")[0][2:].decode("latin-1"))
        if not os.path.exists(interp[0]):
            if "python2" in interp[0]:
                env.update(PYTHONPATH=PY2_PATH, HILDON_DEVSHELL="1")
            return [SR + interp[0]] + interp[1:] + [exe] + argv[1:]
    return [SR + exe] + argv[1:]


def launch_command(entry):
    """(command, environment) that starts the entry; run it with DISPLAY set (and hildon-session.sh done: binfmt, /opt)."""
    env = dict(os.environ, DESKTOP="0", HILDON_SHELL="1")
    for k in ("PY2", "APP", "RUN_SCRIPT"):
        env.pop(k, None)
    if entry.app is not None or entry.exec_line is None and entry.deb is None:
        cmd = [os.path.join(PROJ, "scripts", "hildon-run.sh")]
        if entry.app:
            env["APP"] = entry.app
        else:
            cmd.append(os.path.join(PROJ, "src/python3/hildon/proof.py"))
        return cmd, env
    _install(entry.deb)
    line = re.sub(r"\s%[a-zA-Z]", "", entry.exec_line)
    argv = shlex.split(line)
    terminal = len(argv) >= 3 and os.path.basename(argv[0]) == "osso-xterm" and argv[1] == "-e"
    if terminal:
        argv = argv[2:]
    env.update(QEMU_LD_PREFIX=SR, LC_ALL="C", LANG="C", TERM="xterm", HOME=os.path.join(EMU, "home"))
    os.makedirs(env["HOME"], exist_ok=True)
    cmd = _arm_command(argv, env)
    if terminal:
        cmd = ["xterm", "-T", entry.name, "-fa", "DejaVu Sans Mono", "-fs", "12", "-e"] + cmd
    return cmd, env
