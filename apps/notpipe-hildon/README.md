# NotPipe (notpipe-hildon)

A YouTube client for the Nokia N900 with a touch interface. It does not talk to YouTube: it asks a public **Invidious** instance for the search
results and the list of streams, downloads the picture and the sound (YouTube keeps them in two files) and plays them with **nplay**.
The idea comes from notPipe, a client for old Android phones (WTFPL).

* Type what to look for, tap Search (or Return). The list shows the title, the channel, the length and the views; the last row loads more.
* Tap a video: **Watch** downloads it into the cache and plays it; **Download** does the same download but joins the two files into one MP4 straight in
  `MyDocs/Videos` (no re-encoding) and does not play it. A video that is already in the Videos folder (it has a check mark in the list) plays from there, without
  the network, and the file manager and other players can open it too.
* While a video downloads or plays, **Watch** and **Download** of other videos put them into a queue (the status line shows how many wait; one at a
  time, in order; a duplicate is refused; Cancel stops only the current one).
* In the list, **√** before a title means the video is downloaded in the Videos folder, **◊** that it is complete in the cache (both play without the network).
* Menu of the title bar: Settings (quality 144p to 480p, 240p is the default and plays smoothly; the sound normal or small; the size of the cache),
  Clear the queue, Cached videos (the list of everything that plays without the network: complete in the cache or in the Videos folder; a tap offers Watch),
  Update list of instances, Clear cache, About.
* In nplay: Up/Down change the volume, Left/Right go 10 seconds back/forward (PgUp/PgDn 60), space pauses, Esc ends.

What you watch is kept (with a small `<id>.json` that remembers the title, so a video in the cache plays at once, with no call to an instance) in `MyDocs/Videos/NotPipe cache` (the picture and the sound as two files, the thumbnails in `thumbs`; 400 MB by default, the oldest go first,
"Clear cache" empties it). The folder is visible in the file manager; the pieces in it are only useful to NotPipe. Downloaded videos are never deleted by the cache.

## How it works and what can go wrong

The public Invidious instances come and go and some of them ask for a browser check or limit their use. The list of instances is refreshed from
https://api.invidious.io/ once a day (menu: Update list of instances); a call tries up to five instances one after another and skips the ones that
answer with a page instead of JSON. Nothing is worked around: if no instance answers, the search fails and the message says what each one said.
You can run your own instance and put its URL into `NOTPIPE_INSTANCES` (comma separated) in the environment.

The video must have an H.264 stream (all YouTube videos have one up to 1080p). 360p is on the edge of what the processor of the N900 can decode
in real time; 240p is the sensible choice. See `apps/nplay/nplay.md` for what was measured.

Only the logic is in `notpipe_core.py` (tests: `tests/test_notpipe_core.py`, a fake instance on localhost); the windows are in `notpipe-hildon`
(Python 3 and [hildonlite](../hildonlite)).
