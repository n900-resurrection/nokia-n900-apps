# Palm OS applications on the N900 - research notes

Status (2026-11-13): **research only**, nothing tried on the phone. Items marked *[unverified]* come from search results (Maemo mailing lists, forums, news from 2007 to 2010), not from our own test, or from memory.

## What existed for Maemo

- **Garnet VM** (Access, November 2007): a virtual machine that emulates an **ARM** device and runs the Palm OS 5.5 (Garnet) userland on a Linux kernel; released for the tablets N770, N800 and N810. [OSNews](https://www.osnews.com/story/18925/access-palm-os-now-available-for-nokia/), [Palm Info Center](https://www.palminfocenter.com/news/6938/new-garnet-vm-beta-for-nokia-tablets/), [TechCrunch](https://techcrunch.com/2007/11/13/palm-garnet-on-your-nokia-tablet/).
- **N900:** there was never an official version. In January 2010 someone tried the package of the N800 and the installation failed with `maemo-select-menu-location: not found`, because the N900 has no divided menu area as the older tablets had. No confirmed successful run on the N900 found. [maemo-users, Garnet VM beta 5 on the N900](https://lists.maemo.org/pipermail/maemo-users/2010-January/015266.html).
- **Availability:** Access no longer offers it; copies are around the web with a doubtful legal status. [palmdb.net](https://palmdb.net/app/garnet-vm).
- **Limits reported:** applications for Palm OS 3.5 ran, more advanced ones for OS 5 and newer crashed *[unverified]*; most old Palm applications are **68k** programs, not ARM, so a VM that emulates an ARM device covers fewer of them.
- The Maemo wiki lists Garnet VM as the best known Palm OS emulator of the platform. [Emulators](https://wiki.maemo.org/Emulators).
- Nothing found about **Cobalt** (Palm OS 6), StyleTap or POSE on the N900.

## Idea for today (not checked) *[unverified]*

- A **68k Palm OS emulator** should be fast enough on the N900 (600 MHz Cortex-A8; the original Palm devices had about 33 MHz): the open projects **POSE** (Palm OS Emulator) or **Cloudpilot** (C++, cross-platform) could be cross-built in the Workshop for armel and run under X on the phone (an SDL or GTK window, the stylus as the pen).
- It needs a **ROM** image from a real Palm device (the legal side is the user's decision), and applications as `.prc`/`.pdb` files.
- A step before any porting: check which of those emulators still build, their licences, and what they need (SDL, threads, no recent glibc symbols; the phone has glibc 2.5).
- Data exchange (the phone's contacts, calendar) would need a conduit-like import of the `.pdb` databases; not planned.

## Questions to answer first

1. Which Palm applications does the user want? (68k, or Palm OS 5 ARM `.prc`, or only data files). This decides between a 68k emulator and Garnet-like ARM emulation.
2. Is a ROM available (from an own device)?
3. Do the emulators compile for armel with glibc 2.5 without big changes?
