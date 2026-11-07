#!/usr/bin/env python3
# Stand-in for the top bar of hildon-desktop in the PC emulator (run INSIDE the Workshop by scripts/hildon-session.sh).
# A 800x56 dock window above the applications (which run under qemu-user on the same virtual X screen, 800x424 below it), modelled on
# the screenshots of the phone (make screenshots):
#   [windows] | 11:41 [battery] | title of the application  v | [back]
#   windows ... the orange button on the left cycles: current application -> switcher (the symbol turns into the grid) ->
#               all applications (the symbol is "windows" again) -> back to the current application
#   switcher .. over the wallpaper: a card per running application (title, orange X closes it, picture of the window), three per row,
#               scrollable; a tap on the free wallpaper goes back to the desktop
#   launcher .. all installed applications: five icons with a label per row, no frames, scrollable (every apps/<app>/hildon-run.sh and
#               every installed package is one, see hildon_apps.py)
#   clock   ... (clock and battery) opens the status panel: battery, date, network (a simplified copy of the status menu)
#   title   ... the whole title area is the Menu button: it opens the application menu of the active window (key F4;
#               hildon-stubs/sitecustomize.py opens the HildonAppMenu)
#   back    ... closes the active window (WM_DELETE_WINDOW, like the Back button of the title bar)
# Window management is done by matchbox-window-manager; this program only uses wmctrl and xdotool. Needs python3-gi-cairo (toolchain).
import os
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gi
gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
from gi.repository import GLib, Gdk, GdkPixbuf, Gtk  # noqa: E402

import hildon_apps  # noqa: E402

PROJ = os.environ.get("PROJ", "/project")
BAR_TITLE = "hildon-shell"
WALLPAPER = os.environ.get("HILDON_BG", PROJ + "/sysroot/usr/share/hildon-emu/background-1.png")
ORANGE = (0.97, 0.58, 0.13)
CSS = ("""
window, #bar { background: #1c1c1c; }
#bar { background-image: linear-gradient(#3a3a3a, #1b1b1b 55%%, #0f0f0f); }
button { background: #3a3a3a; color: #fff; border: 1px solid #555; border-radius: 6px; padding: 2px 10px;
         min-height: 40px; font-size: 16px; }
/* the cells of the bar: flat, separated by thin lines like the title bar of the phone */
#bar button.cell { background: transparent; background-image: none; border: none; border-radius: 0; box-shadow: none;
                   min-height: 0; padding: 0 12px; border-right: 1px solid #090909; }
#bar button.cell:hover { background-color: rgba(255,255,255,0.08); }
#clock { color: #fff; font-size: 24px; margin-right: 8px; }
#title { color: #fff; font-size: 24px; }
/* the application switcher, the launcher and the status panel: the wallpaper (darkened) of the desktop, continued below the bar */
#overlay, #overlay viewport, #overlay scrolledwindow, #overlay flowbox, #overlay flowboxchild, #overlay eventbox, #overlay box {
    background: transparent; box-shadow: none; }
#overlay flowboxchild { border: none; outline: none; padding: 0; }
#overlay { background-color: #000; %s }
#overlay button.app, #overlay button.preview, #overlay button.cardclose, #overlay button.row { background-image: none; box-shadow: none; text-shadow: none; }
#overlay button.app { background: transparent; border: none; border-radius: 8px; color: #fff; font-size: 15px; min-height: 0; padding: 6px 2px; }
#overlay button.app:hover { background: rgba(255,255,255,0.12); }
#overlay button.preview { background: transparent; border: none; padding: 0; min-height: 0; }
#overlay button.cardclose { background: transparent; border: none; color: #f7931e; font-size: 22px; font-weight: bold;
                            min-height: 0; padding: 0 6px; }
#overlay button.row { background: #1d1d1d; border: 1px solid #3b3b3b; border-radius: 6px; min-height: 52px; }
.panel { background: rgba(14,14,14,0.96); border: 1px solid #444; border-radius: 10px; }
.rowtitle { color: #fff; font-size: 20px; }
.rowsub { color: #bbb; font-size: 14px; }
.card { background: #171717; border: 1px solid #6b4a22; border-radius: 6px; }
.card.current { border-color: #f7931e; }
.cardtitle { color: #fff; font-size: 16px; font-weight: bold; margin: 2px 6px; }
.hint { color: #aaa; font-size: 18px; }
""" % ("background-image: linear-gradient(rgba(0,0,0,0.55), rgba(0,0,0,0.55)), url('file://%s'); background-size: 800px 480px; "
       "background-position: 0 -56px;" % WALLPAPER if os.path.exists(WALLPAPER) else "")).encode()
THUMB = (232, 123)
COLUMNS_SWITCHER, COLUMNS_LAUNCHER = 3, 5


def run(*cmd):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=5).stdout
    except (OSError, subprocess.SubprocessError):
        return ""


def symbol(kind, w=40, h=30):
    """The symbols of the phone drawn with cairo: 'windows' (application switcher), 'grid' (all applications), 'back' (orange arrow),
    'battery' (green, full). The kind can be changed later (area.kind = ...; area.queue_draw())."""
    area = Gtk.DrawingArea()
    area.kind = kind
    area.set_size_request(w, h)
    area.set_valign(Gtk.Align.CENTER)

    def draw(a, cr):
        cr.set_source_rgb(*ORANGE)
        cr.set_line_join(1)
        if a.kind == "grid":
            for r in range(3):
                for c in range(3):
                    cr.rectangle(w / 2 - 15 + c * 10.5, h / 2 - 13 + r * 9, 9, 7.5)
            cr.fill()
        elif a.kind == "windows":
            cr.set_line_width(3)
            cr.rectangle(7, 5, 18, 13)
            cr.stroke()
            cr.rectangle(15, 11, 18, 13)
            cr.set_source_rgb(0.14, 0.14, 0.14)
            cr.fill_preserve()
            cr.set_source_rgb(*ORANGE)
            cr.stroke()
        elif a.kind == "back":
            # the arrow of the Back button: a thick line that turns left and ends in a head
            cr.set_line_width(5)
            cr.move_to(w - 8, h - 4)
            cr.line_to(w - 8, h / 2 + 1)
            cr.curve_to(w - 8, h / 2 - 5, w - 11, h / 2 - 6, w - 17, h / 2 - 6)
            cr.line_to(16, h / 2 - 6)
            cr.stroke()
            cr.move_to(6, h / 2 - 6)
            cr.line_to(19, h / 2 - 16)
            cr.line_to(19, h / 2 + 4)
            cr.close_path()
            cr.fill()
        elif a.kind == "battery":
            cr.set_source_rgb(0.85, 0.85, 0.85)
            cr.set_line_width(2)
            cr.rectangle(w / 2 - 7, 5, 14, 22)
            cr.stroke()
            cr.rectangle(w / 2 - 3, 2, 6, 3)
            cr.fill()
            cr.set_source_rgb(0.35, 0.8, 0.2)
            cr.rectangle(w / 2 - 5, 7, 10, 18)
            cr.fill()
        return False
    area.connect("draw", draw)
    return area


def cell(widget, cb, tip=None):
    b = Gtk.Button()
    b.add(widget)
    b.get_style_context().add_class("cell")
    b.connect("clicked", cb)
    if tip:
        b.set_tooltip_text(tip)
    return b


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

        box = Gtk.Box()
        self.add(box)
        self.switch_symbol = symbol("windows", 44)
        box.pack_start(cell(self.switch_symbol, self.on_switch_button, "Application switcher"), False, True, 0)
        status = Gtk.Box(spacing=4)
        self.clock = Gtk.Label(label="")
        self.clock.set_name("clock")
        self.clock.set_valign(Gtk.Align.CENTER)
        status.pack_start(self.clock, False, False, 0)
        status.pack_start(symbol("battery", 24), False, False, 0)
        box.pack_start(cell(status, self.toggle_status, "Status"), False, True, 0)
        # the whole title area is the Menu button (title, then the orange triangle of the phone)
        title = Gtk.Box(spacing=8)
        self.title = Gtk.Label(label="", xalign=0)
        self.title.set_name("title")
        self.title.set_ellipsize(3)      # Pango.EllipsizeMode.END
        title.pack_start(self.title, False, False, 0)
        self.arrow = Gtk.Label()
        self.arrow.set_markup('<span foreground="#f7931e" size="small">\u25bc</span>')
        title.pack_start(self.arrow, False, False, 0)
        box.pack_start(cell(title, self.on_menu, "Menu"), True, True, 0)
        box.pack_end(cell(symbol("back", 52), self.on_back, "Back"), False, True, 0)
        self.shown = None
        self.overlay = None   # the open switcher/launcher/status window
        self.mode = None      # "switcher", "launcher", "status" or None
        self.thumbs = {}     # window id -> Pixbuf: the last picture of the window (an obscured window cannot be captured)
        self.tick()
        GLib.timeout_add(20000, self.tick)
        GLib.timeout_add(700, self.refresh)
        GLib.timeout_add(2500, self.snap_active)
        self.connect("destroy", Gtk.main_quit)
        self.show_all()

    def tick(self):
        self.clock.set_text(time.strftime("%H:%M"))
        return True

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
                # pictures of a new window once it has drawn itself (a program under qemu-user can need seconds), twice
                for delay in (1500, 4000):
                    GLib.timeout_add(delay, lambda w=act: self.snap(w) and False if w == self.last else False)
            self.last = act
        elif self.last and int(self.last, 16) not in ids:
            self.last = None
        act = self.last
        state = (tuple(wins), act)
        if state != self.shown:
            self.shown = state
            self.title.set_text(next((t for w, t in wins if int(w, 16) == int(act or "0", 16)), ""))
        self.children = [p for p in self.children if p.poll() is None]
        return True

    def on_menu(self, _b):
        self.close_overlay()
        if self.last:
            run("wmctrl", "-i", "-a", self.last)    # the key goes to the focused window
            run("xdotool", "key", "F4")

    def on_back(self, _b):
        if self.mode:
            self.close_overlay()          # Back leaves the switcher, like on the phone
        elif self.last:
            run("wmctrl", "-i", "-c", self.last)

    # --- picture of a window
    def snap(self, wid):
        """Remember a small picture of the window; only while nothing covers it (an obscured window cannot be captured)."""
        if self.overlay is not None:
            return
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
        if self.last:
            self.snap(self.last)
        return True

    # --- the switcher, the launcher and the status panel (one window below the bar, with the wallpaper)
    def close_overlay(self):
        if self.overlay is not None:
            self.overlay.destroy()
        self.overlay = None
        self.set_mode(None)

    def set_mode(self, mode):
        self.mode = mode
        self.switch_symbol.kind = "grid" if mode == "switcher" else "windows"
        self.switch_symbol.queue_draw()

    def on_switch_button(self, _b):
        # application -> switcher -> all applications -> application
        if self.mode is None or self.mode == "status":
            self.show_overlay("switcher")
        elif self.mode == "switcher":
            self.show_overlay("launcher")
        else:
            self.close_overlay()

    def toggle_status(self, _b):
        if self.mode == "status":
            self.close_overlay()
        else:
            self.show_overlay("status")

    def show_overlay(self, kind):
        wins = self.windows()
        act = self.active_window(wins)
        if act:
            self.snap(act)      # a fresh picture of the current window (nothing covers it yet)
        if self.overlay is not None:
            self.overlay.destroy()
            self.overlay = None
        w = Gtk.Window(title="Apps - " + kind)
        w.set_type_hint(Gdk.WindowTypeHint.DIALOG)
        w.set_decorated(False)
        w.set_default_size(800, 424)
        w.move(0, 56)
        w.set_name("overlay")
        page = {"switcher": lambda: self.switcher_page(wins, act), "launcher": self.launcher_page, "status": self.status_page}[kind]()
        if kind == "launcher":
            scroll = Gtk.ScrolledWindow()
            scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
            scroll.add(page)
            page = scroll
        elif kind == "switcher":
            scroll = Gtk.ScrolledWindow()
            scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
            scroll.add(page)
            page = scroll
        w.add(page)
        self.overlay = w
        self.set_mode(kind)
        w.connect("destroy", lambda ww: self.overlay_destroyed(ww))
        w.show_all()

    def overlay_destroyed(self, w):
        if self.overlay is w:
            self.overlay = None
            self.set_mode(None)

    def flow(self, columns, spacing):
        f = Gtk.FlowBox()
        f.set_selection_mode(Gtk.SelectionMode.NONE)
        f.set_min_children_per_line(columns)
        f.set_max_children_per_line(columns)
        f.set_homogeneous(True)
        f.set_column_spacing(spacing)
        f.set_row_spacing(spacing)
        f.set_valign(Gtk.Align.START)
        return f

    def free_area(self, child):
        """EventBox: a tap on the free wallpaper goes back to the desktop."""
        ev = Gtk.EventBox()
        ev.connect("button-press-event", lambda _w, _e: self.close_overlay())
        ev.add(child)
        return ev

    def switcher_page(self, wins, act):
        """Cards of the running applications: title and the orange X on top, the picture of the window below."""
        page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        page.set_border_width(10)
        if not wins:
            hint = Gtk.Label(label="No applications are running.\nPress the orange button to see all applications.")
            hint.get_style_context().add_class("hint")
            hint.set_margin_top(150)
            page.pack_start(hint, True, True, 0)
            return self.free_area(page)
        flow = self.flow(COLUMNS_SWITCHER, 10)
        order = sorted(wins, key=lambda wt: int(wt[0], 16) != int(act or "0", 16))
        for wid, title in order:
            card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
            card.get_style_context().add_class("card")
            if wid == act:
                card.get_style_context().add_class("current")
            head = Gtk.Box()
            name = Gtk.Label(label=title, xalign=0)
            name.set_ellipsize(3)
            name.get_style_context().add_class("cardtitle")
            head.pack_start(name, True, True, 0)
            x = Gtk.Button(label="\u2715")
            x.get_style_context().add_class("cardclose")
            x.connect("clicked", lambda _b, wid=wid: self.close_window(wid))
            head.pack_end(x, False, False, 0)
            card.pack_start(head, False, False, 0)
            pic = Gtk.Button()
            pic.get_style_context().add_class("preview")
            pix = self.thumbs.get(wid)
            pic.add(Gtk.Image.new_from_pixbuf(pix) if pix else Gtk.Label(label="(no picture)"))
            pic.set_size_request(THUMB[0], THUMB[1])
            pic.connect("clicked", lambda _b, wid=wid: self.switch_to(wid))
            card.pack_start(pic, False, False, 0)
            flow.add(card)
        page.pack_start(flow, False, False, 0)
        return self.free_area(page)

    def launcher_page(self):
        """All installed applications: icons with labels over the wallpaper, five per row."""
        page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        page.set_border_width(10)
        grid = self.flow(COLUMNS_LAUNCHER, 4)
        for entry in hildon_apps.catalogue():
            b = Gtk.Button()
            b.get_style_context().add_class("app")
            col = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
            img = Gtk.Image()
            if entry.icon:
                try:
                    img = Gtk.Image.new_from_pixbuf(GdkPixbuf.Pixbuf.new_from_file_at_size(entry.icon, 64, 64))
                except GLib.Error:
                    pass
            img.set_size_request(64, 64)
            col.pack_start(img, False, False, 0)
            label = Gtk.Label(label=entry.name)
            label.set_ellipsize(3)
            label.set_max_width_chars(14)
            col.pack_start(label, False, False, 0)
            b.add(col)
            b.connect("clicked", lambda _b, e=entry: self.launch(e))
            grid.add(b)
        page.pack_start(grid, False, False, 0)
        return page

    def status_page(self):
        """The overlay of the clock: battery, date and the network (a simplified copy of the status menu of the phone)."""
        def row(widget, title, sub):
            b = Gtk.Button()
            b.get_style_context().add_class("row")
            line = Gtk.Box(spacing=10)
            if widget is not None:
                line.pack_start(widget, False, False, 0)
            text = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
            t = Gtk.Label(label=title, xalign=0)
            t.get_style_context().add_class("rowtitle")
            text.pack_start(t, False, False, 0)
            st = Gtk.Label(label=sub, xalign=0)
            st.get_style_context().add_class("rowsub")
            text.pack_start(st, False, False, 0)
            line.pack_start(text, True, True, 0)
            b.add(line)
            return b
        panel = Gtk.Grid(column_spacing=8, row_spacing=8)
        panel.get_style_context().add_class("panel")
        panel.set_border_width(10)
        panel.set_halign(Gtk.Align.CENTER)
        panel.set_valign(Gtk.Align.START)
        panel.set_margin_top(10)
        panel.set_size_request(740, -1)
        panel.attach(row(symbol("battery", 36, 36), "Battery: 100 %", "Battery is full"), 0, 0, 2, 1)
        panel.attach(row(None, "Clock and alarms", time.strftime("%A, %-d %B %Y")), 0, 1, 1, 1)
        panel.attach(row(None, "Internet connection", "emulator (host network)"), 1, 1, 1, 1)
        panel.attach(row(None, "Wireless LAN", "On"), 0, 2, 1, 1)
        panel.attach(row(None, "Profile", "General"), 1, 2, 1, 1)
        for b in panel.get_children():
            b.set_hexpand(True)
        page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        page.pack_start(panel, False, False, 0)
        return self.free_area(page)

    def switch_to(self, wid):
        self.close_overlay()
        run("wmctrl", "-i", "-a", wid)

    def close_window(self, wid):
        run("wmctrl", "-i", "-c", wid)
        self.thumbs.pop(wid, None)
        GLib.timeout_add(600, self.reopen_switcher)

    def reopen_switcher(self):
        if self.mode == "switcher":
            self.show_overlay("switcher")
        return False

    def active_window(self, wins):
        act = self.active()
        ids = [int(w, 16) for w, _t in wins]
        if act and int(act, 16) in ids:
            return act
        return self.last if self.last and int(self.last, 16) in ids else None

    def launch(self, entry):
        self.close_overlay()
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
