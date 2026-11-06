# Developer shell for programs run by scripts/hildon-run.sh PY2=1 (loaded automatically by Python at start).
# On the phone hildon-desktop draws the title bar with the Back button and opens the application menu (HildonAppMenu).
# It does not run on the PC, so this module stands in for it, inside the process of the program:
#   - (without hildon-shell.py) two small buttons in the top right corner: "Menu" (the app menu of the topmost window) and "Back" (closes it,
#     like the Back button: a delete-event, so the program can refuse it),
#   - keys: F4 = menu, Escape = Back (like the hardware keyboard of the N900).
# Only active with HILDON_DEVSHELL=1 (set by hildon-run.sh). HILDON_DEVSHELL_SCRIPT="3:menu,6:back" runs actions after
# N seconds (for screenshots without a mouse).
import os
import sys

if os.environ.get("HILDON_DEVSHELL") and os.environ.get("DISPLAY"):
    try:
        import gobject
        import gtk
        import hildon
    except ImportError:
        gtk = None

    if gtk is not None:
        _stack = []
        _bar = []

        def _top():
            while _stack and not (_stack[-1].flags() & gtk.MAPPED):
                _stack.pop()
            return _stack and _stack[-1] or None

        def back(*args):
            if _popup:
                _close_popup()
                return True
            win = _top()
            if win is not None and not win.emit("delete-event", gtk.gdk.Event(gtk.gdk.DELETE)):
                win.destroy()
            return True

        _popup = []

        def _close_popup():
            while _popup:
                _popup.pop().destroy()

        def _buttons(widget, out):
            if isinstance(widget, gtk.Button):
                if widget.flags() & gtk.VISIBLE:
                    out.append(widget)
            elif isinstance(widget, gtk.Container):
                widget.foreach(_buttons, out)
            return out

        def menu(*args):
            """Application menu of the topmost window. HildonAppMenu.popup() shows nothing without hildon-desktop, so
            the items (the buttons of the menu) are shown in a window of our own; a tap calls the original button."""
            if _popup:
                _close_popup()
                return True
            win = _top()
            m = win is not None and win.get_app_menu() or None
            if os.environ.get("HILDON_DEVSHELL_DEBUG"):
                open("/tmp/hildon-devshell.log", "a").write("menu on %s app menu %s\n" % (win, m))
            if not isinstance(m, hildon.AppMenu):
                return True
            items = _buttons(m, [])
            pop = gtk.Window(gtk.WINDOW_POPUP)
            table = gtk.Table((len(items) + 1) // 2, 2, True)
            table.set_border_width(8)
            table.set_row_spacings(6)
            table.set_col_spacings(6)
            for n, orig in enumerate(items):
                b = gtk.Button(orig.get_label() or "")
                b.set_size_request(380, 56)
                b.connect("clicked", lambda _b, o=orig: (_close_popup(), o.clicked()))
                table.attach(b, n % 2, n % 2 + 1, n // 2, n // 2 + 1)
            pop.add(table)
            pop.set_default_size(800, 10)
            pop.move(0, 56)
            pop.show_all()
            _popup.append(pop)
            return True

        def _make_bar():
            w = gtk.Window(gtk.WINDOW_POPUP)
            box = gtk.HBox(True, 2)
            for label, cb in (("Menu", menu), ("Back", back)):
                b = gtk.Button(label)
                b.connect("clicked", cb)
                b.set_size_request(90, 48)
                box.pack_start(b, True, True, 0)
            w.add(box)
            w.set_default_size(180, 48)
            w.move(800 - 180, 0)
            w.show_all()
            _bar.append(w)

        def _raise():
            if _bar:
                _bar[0].window.raise_()
            return False

        def _on_map(widget, *args):
            if isinstance(widget, hildon.StackableWindow):
                if widget in _stack:
                    _stack.remove(widget)
                _stack.append(widget)
                if not _bar and not os.environ.get("HILDON_SHELL"):   # the top bar of hildon-shell.py replaces the buttons
                    _make_bar()
                gobject.idle_add(_raise)
            return True

        def _on_key(widget, event, *args):
            try:
                if os.environ.get("HILDON_DEVSHELL_DEBUG"):
                    open("/tmp/hildon-devshell.log", "a").write("key %s on %s\n" % (gtk.gdk.keyval_name(event.keyval), widget))
                if isinstance(widget, hildon.StackableWindow):
                    name = gtk.gdk.keyval_name(event.keyval)
                    if name == "F4":
                        menu()
                    elif name == "Escape":
                        if _popup:
                            _close_popup()
                        else:
                            back()
            except Exception, e:
                sys.stderr.write("devshell: %s\n" % e)
                if os.environ.get("HILDON_DEVSHELL_DEBUG"):
                    open("/tmp/hildon-devshell.log", "a").write("error %s\n" % e)
            return True

        try:
            gtk.Label("")    # the signals of GtkWidget exist only after the class was initialised by the first instance
            gobject.add_emission_hook(gtk.Widget, "map", _on_map)
            gobject.add_emission_hook(gtk.Widget, "key-press-event", _on_key)
        except Exception, e:     # a developer aid must never stop the program from starting
            import sys
            sys.stderr.write("hildon-stubs/sitecustomize: %s\n" % e)

        for item in os.environ.get("HILDON_DEVSHELL_SCRIPT", "").split(","):
            if ":" in item:
                secs, action = item.split(":", 1)
                gobject.timeout_add(int(float(secs) * 1000), {"menu": menu, "back": back}[action])
