# Music streaming on the N900 - research notes

Status (2026-11-13): **research only**; the only thing tried on the phone: the stock Internet radio of the Media player works (as long as the stations still broadcast). Items marked *[unverified]* come from search results (mostly Maemo forums and mailing lists from 2009 to 2016), not from our own test.

## What we want

- Services such as Spotify or YouTube Music, or better: **cache a playlist on the phone** and use the online service only for a **background synchronisation** (listening offline, on Wi-Fi only for the sync).
- Internet radio.

## Internet radio (the easy part)

- The stock **Media player has an "Internet radio" view**: menu > *Add radio bookmark* and the address of the stream; a Shoutcast stream can also be sent to the Audio Player and added with Track > *Add to favorites* *[unverified]*. [Nokia N900 user manual](https://www.manualsdir.com/manuals/490067/nokia-n900.html?page=91).
- Existing community work *[unverified]*: **cuteRadio** (a Qt player with about 30 000 stations), a Shoutcast browser by a forum user (muf.mobi, uses the XML API of Shoutcast), **Streamtuner** (2006, Nokia 770, needs mplayer), the **Grilo** plugins for MAFW (YouTube, Jamendo, Shoutcast in the Fremantle media player, [mafw-grilo-source](https://lists.maemo.org/pipermail/maemo-users/2010-June/016263.html)). Their servers and station lists may be dead by now.
- Plan: a small own station list (an `.m3u`/JSON file, no catalogue server needed) with a Hildon GUI that starts the stream in the system player. HTTPS streams go through a local `curl` proxy, as gPodder does. Directories with a free API to browse: radio-browser.info (open, community) *[to check]*.

## Spotify

- Old N900 clients existed (**Footify** on Despotify, **QSpot** on libspotify, **Qtify**, **yaspot**) *[unverified]*; [Footify article](https://www.tu.no/artikler/vi-kjorer-spotify-pa-nokia-n900/226007). Both libraries are dead (Despotify protocol, libspotify shut down), so none of them works today.
- **librespot** (Rust, open source; Premium account only) speaks the current protocol. It could run on the phone as a **Spotify Connect speaker** (another phone or a PC controls it), no offline playback. Rust works on the phone (static musl binaries, see the Rust and Go notes), the audio decoding of Ogg Vorbis on the Cortex-A8 should be fine *[to test]*; the control is by another device, which is awkward.
- **Offline playlists are not an option:** librespot only caches what it plays, and the terms of Spotify forbid downloading the audio *[unverified: second-hand quotes, check the current terms]*. So "cache a playlist" does not work with Spotify.

## YouTube Music

- On the phone `yt-dlp` is far too slow (about 257 s for one video, see the podcast post notes in `TODO.md`), but on a **server or the PC** it works. Tools that sync a playlist into a directory exist: `yt-playlist-sync`, `sync-dl`, `yt-music-manager-cli` (all on PyPI) *[unverified]*; `ytmusicapi` for the playlists of an account (OAuth instead of cookies, because cookies used outside a browser expire in about two weeks and carry a risk of an IP ban) *[unverified]*.
- The terms of YouTube about downloading are a grey area; this would be for personal use of one's own playlists, at the user's own risk.

## The architecture that fits ("cache + background sync")

A **home server** (the Jellyfin machine that already downloads YouTube channels) keeps the playlists as audio files (`yt-dlp` for YouTube Music; own files, Bandcamp, Jamendo, podcasts), and the phone only **synchronises a folder** in the background and plays the files with the stock Media player, which has no need for the network:

- `rsync` over ssh (we have rsync and openssh on the phone) from cron when online, the same pattern as `ical-sync` (`--if-online`, an interval per source, a GUI with a list of sources and a log switch);
- or **Jellyfin / Subsonic (Navidrome)** with a small client on the phone that downloads the playlists marked "offline" (the Jellyfin item is already in the TODO; MaAmp was an Ampache client for Maemo 5 *[unverified]*);
- the files are put where the Media player scans (`/home/user/MyDocs/.sounds` or the memory card) so that the library of the system sees them, with tags and cover art.

Battery cost: only the network radio during the sync, as with the calendar.

## Open points

- Does the stock player play Opus/OGG/FLAC from the library (formats of the MAFW codecs on the phone)? *[to check; otherwise convert to MP3/AAC on the server]*
- Where does the Media player look for files, and how to trigger a rescan after a sync?
- The ToS question is the user's decision for each service.
