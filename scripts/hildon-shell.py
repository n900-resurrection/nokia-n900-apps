#!/usr/bin/env python3
# Stand-in for the top bar of hildon-desktop in the PC emulator (run INSIDE the Workshop by scripts/hildon-session.sh).
# A 800x56 dock window above the applications (which run under qemu-user on the same virtual X screen, 800x424 below it):
#   [Apps]  [running window] [running window] ...             [Menu] [Back]
#   Apps   ... the launcher: every apps/<app>/hildon-run.sh is an application (first lines: "# Name: Mail")
#   running ... switch between the windows (the active one is highlighted)
#   Menu   ... the application menu of the active window (key F4; hildon-stubs/sitecustomize.py opens the HildonAppMenu)
#   Back   ... closes the active window (WM_DELETE_WINDOW, like the Back button of the title bar)
# Window management is done by matchbox-window-manager; this program only uses wmctrl and xdotool.
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gi
gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
from gi.repository import GLib, Gdk, GdkPixbuf, Gtk  # noqa: E402

import hildon_apps  # noqa: E402

PROJ = os.environ.get("PROJ", "/project")
BAR_TITLE = "hildon-shell"
CSS = b"""
window, #bar { background: #1c1c1c; }
button { background: #3a3a3a; color: #fff; border: 1px solid #555; border-radius: 6px; padding: 2px 10px;
         min-height: 40px; font-size: 16px; }
button:hover { background: #4d4d4d; }
button.active { background: #2f6fa8; border-color: #6aa5d8; }
#launcher { background: #1c1c1c; }
#launcher button { min-width: 150px; min-height: 90px; font-size: 18px; }
"""


def run(*cmd):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=5).stdout
    except (OSError, subprocess.SubprocessError):
        return ""


class Shell(Gtk.Window):
    def __init__(self):
        super().__init__(title=BAR_TITLE)
        self.set_type_hint(Gdk.WindowTypeHint.DOCK)
        self.set_decorated(False)
        self.set_accept_focus(False)
        self.last = None     # the last active window of an application (the bar itself never counts)
        self.set_default_size(800, 56)
        self.move(0, 0)
        self.set_name("bar")
        self.children = []   # launched programs
        css = Gtk.CssProvider()
        css.load_from_data(CSS)
        Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(), css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

        box = Gtk.Box(spacing=4)
        box.set_border_width(4)
        self.add(box)
        apps = Gtk.Button(label="Apps")
        apps.connect("clicked", self.show_launcher)
        box.pack_start(apps, False, False, 0)
        self.tasks = Gtk.Box(spacing=4)
        box.pack_start(self.tasks, True, True, 0)
        for label, cb in (("Back", self.on_back), ("Menu", self.on_menu)):
            b = Gtk.Button(label=label)
            b.connect("clicked", cb)
            box.pack_end(b, False, False, 0)
        # pack_end: the first one is rightmost, so Back is the rightmost and Menu is left of it
        self.shown = None
        self.launcher = None
        GLib.timeout_add(700, self.refresh)
        self.connect("destroy", Gtk.main_quit)
        self.show_all()

    # --- windows
    def windows(self):
        out = []
        for line in run("wmctrl", "-l").splitlines():
            parts = line.split(None, 3)
            if len(parts) == 4 and parts[1] != "-1" and parts[3] not in (BAR_TITLE, "<unknown>") and not parts[3].startswith("Apps -"):
                out.append((parts[0], parts[3]))
        return out

    def active(self):
        s = run("xdotool", "getactivewindow").strip()
        return "0x%08x" % int(s) if s.isdigit() else None

    def refresh(self):
        wins, act = self.windows(), self.active()
        ids = [int(w, 16) for w, _t in wins]
        if act and int(act, 16) in ids:
            self.last = act
        elif self.last and int(self.last, 16) not in ids:
            self.last = None
        act = self.last
        state = (tuple(wins), act)
        if state != self.shown:
            self.shown = state
            for c in self.tasks.get_children():
                self.tasks.remove(c)
            for wid, title in wins:
                b = Gtk.Button(label=title[:18])
                if int(wid, 16) == int(act or "0", 16):
                    b.get_style_context().add_class("active")
                b.connect("clicked", lambda _b, w=wid: run("wmctrl", "-i", "-a", w))
                self.tasks.pack_start(b, False, False, 0)
            self.tasks.show_all()
        self.children = [p for p in self.children if p.poll() is None]
        return True

    def on_menu(self, _b):
        if self.last:
            run("wmctrl", "-i", "-a", self.last)    # the key goes to the focused window
            run("xdotool", "key", "F4")

    def on_back(self, _b):
        if self.last:
            run("wmctrl", "-i", "-c", self.last)

    # --- launcher
    def show_launcher(self, _b):
        if self.launcher is not None:
            self.launcher.destroy()
            self.launcher = None
            return
        w = Gtk.Window(title="Apps - launcher")
        w.set_type_hint(Gdk.WindowTypeHint.DIALOG)
        w.set_decorated(False)
        w.set_default_size(800, 424)
        w.move(0, 56)
        w.set_name("launcher")
        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        grid = Gtk.Grid(column_spacing=8, row_spacing=8)
        grid.set_border_width(12)
        scroll.add(grid)
        w.add(scroll)
        for i, entry in enumerate(hildon_apps.catalogue()):
            b = Gtk.Button(label=entry.name)
            b.set_size_request(180, 112)
            b.set_image_position(Gtk.PositionType.TOP)
            b.set_always_show_image(True)
            if entry.icon:
                try:
                    b.set_image(Gtk.Image.new_from_pixbuf(GdkPixbuf.Pixbuf.new_from_file_at_size(entry.icon, 48, 48)))
                except GLib.Error:
                    pass
            b.connect("clicked", lambda _b, e=entry: self.launch(e))
            grid.attach(b, i % 4, i // 4, 1, 1)
        self.launcher = w
        w.connect("destroy", lambda _w: setattr(self, "launcher", None))
        w.show_all()

    def launch(self, entry):
        if self.launcher is not None:
            self.launcher.destroy()
        try:
            cmd, env = hildon_apps.launch_command(entry)
        except (OSError, subprocess.SubprocessError) as e:
            sys.stderr.write("cannot start %s: %s\n" % (entry.name, e))
            return
        log = open("/tmp/hildon-app-%s.log" % entry.name.replace("/", "_").replace(" ", "_"), "w")
        self.children.append(subprocess.Popen(cmd, env=env, stdout=log, stderr=subprocess.STDOUT, start_new_session=True))


if __name__ == "__main__":
    Shell()
    Gtk.main()
