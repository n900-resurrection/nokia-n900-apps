# USB host (OTG) on the N900 - notes for later

Status (2026-11-13): **not tried**, notes only. Items marked *[unverified]* come from the Maemo wiki and mailing lists (2009 to 2015), not from our own test.

## Why

- A USB flash disk (probably the most useful), a mouse, a small keyboard (low current).
- Maybe later a Wi-Fi adapter with a better range, for passive scanning (war-driving) on our own.

## What is known

- The OMAP3 USB controller (`musb_hdrc`) can do host mode in hardware; Nokia never finished the OTG drivers, so it is not an official feature. [USB host mode](https://wiki.maemo.org/USB_host_mode), [N900 Hardware USB Host](https://wiki.maemo.org/N900_Hardware_USB_Host).
- Switching: `echo host > /sys/devices/platform/musb_hdrc/mode` (values `host`, `peripheral`, `otg`) *[unverified]*. The host patches belong to kernel-power 2.6.28; the helper `usbmode` exists *[unverified]*. [Mailing list thread](https://lists.maemo.org/pipermail/maemo-developers/2009-December/022850.html).
- **Power:** the phone supplies VBUS up to about 200 mA only *[unverified]*; some devices are rejected ("insufficient available bus power"). A hub with its own power supply solves it (flash disks, Wi-Fi adapters, a keyboard with a hub).
- A user reported that every attached device ended in a kernel driver segfault with the A-A adapter and the stock stack *[unverified]*. [maemo-users](https://lists.maemo.org/pipermail/maemo-users/2012-November/017337.html).

## What we have seen on our phone

- Kernel `2.6.28-omap1`, package `kernel 2.6.28-20103103+0m5` (the original one, no kernel-power).
- `/sys/devices/platform/musb_hdrc/mode` exists; it reads `b_idle` (peripheral side idle). `g_file_storage` is loaded (mass-storage gadget for the PC).
- No `/proc/config.gz`, so it is not known whether the stock kernel has the host code and `usb-storage`, `usbhid`, `vfat` as modules.

## The cable

The phone is charged and connected through a **magnetic connector** (to spare the micro-USB port, which was weak on the N900). For OTG that connector has to come off and an adapter goes in the port itself: a micro-A (ID pin to ground) OTG cable, for example the one from the Raspberry Pi; or an A-A adapter with the Nokia cable *[unverified]*. A powered hub on the other end.

## Plan (every step needs consent: it changes the device)

1. Without a change to the system: with the OTG cable in, `echo host > .../mode`, plug a keyboard, then a flash disk, watch `dmesg`; `lsusb` / `/proc/bus/usb/devices`. The mode goes back after a reboot.
2. If the stock kernel has no host support or no `usb-storage`: kernel-power 2.6.28 (a flash of the kernel; check first that it exists for this firmware), or out-of-tree modules built against the kernel source.
3. Flash disk: mount with `vfat` (and maybe `exfat`/`ntfs-3g`, FUSE is not on the phone); the file manager of Maemo mounts only MMC cards.
4. Wi-Fi adapter: a driver in the kernel 2.6.28 is needed (old chips such as RTL8187, rt73usb, ath9k_htc need a backport; firmware files separately) and for scanning a mode that allows monitoring. The built-in WL1251 cannot monitor with the stock driver. Power: most adapters take 200 to 500 mA, so a powered hub is a must. Tools to try: `iw`, `aircrack-ng`/`kismet` (build in the Workshop). Scan only your own or public information; passive listening is legal in many places, but check the local rules.
