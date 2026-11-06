#!/usr/bin/env python3
# Stand-in for the top bar of hildon-desktop in the PC emulator (run INSIDE the Workshop by scripts/hildon-session.sh).
# A 800x56 dock window above the applications (which run under qemu-user on the same virtual X screen, 800x424 below it):
#   [Apps]  [running window] [running window] ...             [Menu] [Back]
#   Apps   ... like the application switcher of the phone: the running applications (thumbnail of the window, the current one is
#              highlighted, a button closes each) and below them all installed applications (scrollable grid with icons from the
#              packages; every apps/<app>/hildon-run.sh and every installed package is one, see hildon_apps.py)
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
#launcher button.close { min-width: 0; min-height: 28px; padding: 0 8px; }
button.icon { min-width: 48px; }
#launcher button.active { background: #2f6fa8; }
#launcher label.section { color: #aaa; font-size: 15px; font-weight: bold; margin: 6px 4px 0 4px; }
"""
THUMB = (176, 106)


ICON_DIRS = [PROJ + "/sysroot/usr/share/icons/hicolor/%s/hildon" % d for d in ("48x48", "64x64", "32x32", "128x128")]


def icon_button(name, label, size=32):
    """Button with the stock Fremantle icon (hildon-overlay.sh copies the icon theme of the phone); the text if the icon is missing."""
    for d in ICON_DIRS:
        f = "%s/%s.png" % (d, name)
        if os.path.exists(f):
            try:
                img = Gtk.Image.new_from_pixbuf(GdkPixbuf.Pixbuf.new_from_file_at_size(f, size, size))
            except GLib.Error:
                continue
            b = Gtk.Button()
            b.set_image(img)
            b.set_always_show_image(True)
            b.set_tooltip_text(label)
            b.get_style_context().add_class("icon")
            return b
    return Gtk.Button(label=label)


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
        apps = icon_button("general_applications", "Apps")
        apps.connect("clicked", self.show_launcher)
        box.pack_start(apps, False, False, 0)
        self.tasks = Gtk.Box(spacing=4)
        box.pack_start(self.tasks, True, True, 0)
        for label, icon, cb in (("Back", "general_back", self.on_back), ("Menu", "keyboard_menu", self.on_menu)):
            b = icon_button(icon, label)
            b.connect("clicked", cb)
            box.pack_end(b, False, False, 0)
        # pack_end: the first one is rightmost, so Back is the rightmost and Menu is left of it
        self.shown = None
        self.launcher = None
        self.thumbs = {}     # window id -> Pixbuf: the last picture of the window (an obscured window cannot be captured)
        GLib.timeout_add(700, self.refresh)
        GLib.timeout_add(4000, self.snap_active)
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
            if act != self.last and act not in self.thumbs:
                GLib.timeout_add(2500, lambda w=act: self.snap(w) and False)   # picture of a window once it has drawn itself
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

    # --- application switcher
    def snap(self, wid):
        """Remember a small picture of the (visible) window."""
        try:
            png = subprocess.run(["import", "-silent", "-window", wid, "-resize", "%dx%d" % THUMB, "png:-"],
                                 capture_output=True, timeout=5).stdout
            loader = GdkPixbuf.PixbufLoader.new_with_type("png")
            loader.write(png)
            loader.close()
            self.thumbs[wid] = loader.get_pixbuf()
        except (OSError, subprocess.SubprocessError, GLib.Error):
            pass

    def snap_active(self):
        if self.last and self.launcher is None:
            self.snap(self.last)
        return True

    def section(self, text):
        label = Gtk.Label(label=text, xalign=0)
        label.get_style_context().add_class("section")
        return label

    def flow(self):
        f = Gtk.FlowBox()
        f.set_selection_mode(Gtk.SelectionMode.NONE)
        f.set_min_children_per_line(4)
        f.set_max_children_per_line(4)
        f.set_homogeneous(True)
        f.set_column_spacing(8)
        f.set_row_spacing(8)
        f.set_border_width(8)
        return f

    def close_launcher(self):
        if self.launcher is not None:
            self.launcher.destroy()
            self.launcher = None

    def switch_to(self, wid):
        self.close_launcher()
        run("wmctrl", "-i", "-a", wid)

    def close_window(self, wid):
        run("wmctrl", "-i", "-c", wid)
        self.thumbs.pop(wid, None)
        GLib.timeout_add(600, self.reopen_launcher)

    def reopen_launcher(self):
        if self.launcher is not None:
            self.close_launcher()
            self.show_launcher(None)
        return False

    def show_launcher(self, _b):
        if self.launcher is not None:
            self.close_launcher()
            return
        wins = self.windows()
        act = self.active_window(wins)
        if act:
            self.snap(act)      # the active window is the only one that is on the screen
        w = Gtk.Window(title="Apps - launcher")
        w.set_type_hint(Gdk.WindowTypeHint.DIALOG)
        w.set_decorated(False)
        w.set_default_size(800, 424)
        w.move(0, 56)
        w.set_name("launcher")
        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        scroll.add(page)
        w.add(scroll)

        # running applications; the current one first and highlighted
        page.pack_start(self.section("Running applications" if wins else "Running applications: none"), False, False, 0)
        if wins:
            running = self.flow()
            order = sorted(wins, key=lambda wt: int(wt[0], 16) != int(act or "0", 16))
            for wid, title in order:
                card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
                b = Gtk.Button()
                b.set_size_request(180, 130)
                inner = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
                pix = self.thumbs.get(wid)
                inner.pack_start(Gtk.Image.new_from_pixbuf(pix) if pix else Gtk.Label(label="(no picture)"), True, True, 0)
                inner.pack_start(Gtk.Label(label=("\u25cf " if wid == act else "") + title[:22]), False, False, 0)
                b.add(inner)
                if wid == act:
                    b.get_style_context().add_class("active")
                b.connect("clicked", lambda _b, wid=wid: self.switch_to(wid))
                card.pack_start(b, False, False, 0)
                c = icon_button("general_close", "Close", 20)
                c.get_style_context().add_class("close")
                c.connect("clicked", lambda _b, wid=wid: self.close_window(wid))
                card.pack_start(c, False, False, 0)
                running.add(card)
            page.pack_start(running, False, False, 0)

        # installed applications
        page.pack_start(self.section("Installed applications"), False, False, 0)
        grid = self.flow()
        for entry in hildon_apps.catalogue():
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
            grid.add(b)
        page.pack_start(grid, False, False, 0)
        self.launcher = w
        w.connect("destroy", lambda _w: setattr(self, "launcher", None))
        w.show_all()

    def active_window(self, wins):
        act = self.active()
        ids = [int(w, 16) for w, _t in wins]
        if act and int(act, 16) in ids:
            return act
        return self.last if self.last and int(self.last, 16) in ids else None

    def launch(self, entry):
        self.close_launcher()
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
