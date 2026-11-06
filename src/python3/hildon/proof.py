# Proof of concept: Hildon window from Python 3 through ctypes (no PyGTK for Python 3 and GTK 2 exists).
import ctypes, sys
gtk = ctypes.CDLL("libgtk-x11-2.0.so.0")
hil = ctypes.CDLL("libhildon-1.so.0")
gobj = ctypes.CDLL("libgobject-2.0.so.0")
for f in (gtk.gtk_label_new, hil.hildon_stackable_window_new, hil.hildon_button_new_with_text,
          hil.hildon_program_get_instance):
    f.restype = ctypes.c_void_p
ok = gtk.gtk_init_check(None, None)
print("gtk_init_check:", ok, "gtk", ctypes.c_uint.in_dll(gtk, "gtk_major_version").value, ctypes.c_uint.in_dll(gtk, "gtk_minor_version").value)
if not ok:
    sys.exit(1)
win = hil.hildon_stackable_window_new()
gtk.gtk_window_set_title(ctypes.c_void_p(win), b"Hello from Python 3")
box = gtk.gtk_vbox_new(0, 8); gtk.gtk_vbox_new.restype = ctypes.c_void_p
box = ctypes.c_void_p(gtk.gtk_vbox_new(0, 8))
lab = ctypes.c_void_p(gtk.gtk_label_new(b"Python 3.11 + Hildon (ctypes)"))
gtk.gtk_box_pack_start(box, lab, 1, 1, 0)
btn = ctypes.c_void_p(hil.hildon_button_new_with_text(4, 1, b"Quit", b"closes the window"))   # THUMB height, horizontal
CB = ctypes.CFUNCTYPE(None, ctypes.c_void_p, ctypes.c_void_p)
quit_cb = CB(lambda w, d: gtk.gtk_main_quit())
gobj.g_signal_connect_data(btn, b"clicked", quit_cb, None, None, 0)
gtk.gtk_box_pack_start(box, btn, 0, 0, 0)
gtk.gtk_container_add(ctypes.c_void_p(win), box)
gtk.gtk_widget_show_all(ctypes.c_void_p(win))
# leave after 4 s so that the test ends by itself
TO = ctypes.CFUNCTYPE(ctypes.c_int, ctypes.c_void_p)
to_cb = TO(lambda d: (gtk.gtk_main_quit(), 0)[1])
gtk.g_timeout_add(30000, to_cb, None)
print("running main loop")
gtk.gtk_main()
print("done")
