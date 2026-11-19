# nplay: video player with ffmpeg

Our own video player for the N900 (`apps/nplay/nplay.c`, about 450 lines of C). It exists because the stock Media Player and the GStreamer
of the phone cannot play what video sites deliver today (H.264 profile Main, fragmented MP4, the picture and the sound in separate files) at
a usable speed. nplay decodes with the libraries of ffmpeg 9 (`apps/ffmpeg`, NEON) and shows the picture through SDL 1.2.

    nplay [-n] [-N] [-s SECONDS] [-f] [-W] [-b] [-v] VIDEO [AUDIO]

| Option | Meaning |
|--------|---------|
| `VIDEO [AUDIO]` | media files; the sound comes from AUDIO (default: the same file). Fragmented MP4 is read as it is, no conversion |
| `-n` / `-N` | no sound / no picture |
| `-s SECONDS` | start there |
| `-f` | always skip the loop filter of H.264 (faster, a little less sharp) |
| `-W` | window instead of full screen (the emulator) |
| `-b` | benchmark: decode everything as fast as possible, show and play nothing |
| `-v`, `-vv` | statistics at the end; `-vv` also one line per second and the keys that were pressed |

Keys: Esc, q or Backspace quits, space pauses, Up/Down change the volume of the phone, Left/Right go 10 seconds back/forward, PgUp/PgDn 60 seconds.

Touch, like the player of the phone: the picture fills the screen; **a tap shows the controls** (the first tap only does that) and they hide by themselves after a few
seconds (never while paused or while you drag). The arrow at the top right ends the player; the three big buttons in the middle go 10 seconds back, play or pause, and
10 seconds forward; at the bottom are the time, a slider with an orange fill and a grip (**drag it to seek**, the seek happens when you let go; a tap goes there), the
length and a speaker. **The speaker opens a vertical volume slider** (the volume of the phone, changes as you drag). A tap anywhere else hides the controls.

The controls are drawn into the picture itself: the picture is an Xv hardware overlay that covers whatever is drawn on the window, so there is no other way. While
the controls are shown the overlay has the size of the screen and the frame is scaled with swscale (a little more work for the processor, for a few seconds); while they
are hidden the overlay has the size of the video and the hardware scales it.

**Volume.** It is the volume of the phone, not a volume of the program: the PulseAudio of the phone keeps a volume for the role of the stream (`x-maemo`, the
module stream-restore) and the volume item of the status menu writes it. nplay reads and writes the same entry with the extension API of libpulse (loaded at run
time, the headers are not in the sysroot; "apply immediately" changes the stream that is playing). So the slider, Up/Down and the status menu all change and
show one level, and it is kept for the next video. The steps of Up/Down are 3 dB, the slider is perceptual (its position is the square root of the volume).
`NPLAY_OWN_STREAM=1` gives the stream an identity of its own (100 %, not muted), for a phone whose volume was left muted (the status area shows a crossed-out note).

## What was learned on the phone (2026-11-19, test video 640x360 25 fps, Main profile)

* **Hardware decoders cannot be used**: `omx_h264dec` and `dspvdec` fail on these streams (the DSP of the OMAP3 does Baseline).
* **The decoder of GStreamer on the phone** (`ffdec_h264`) managed 5 to 10 frames per second even at 144p. The ffmpeg 9 with NEON: 144p at 159,
  240p at about 90 and 360p at 39 frames per second without any output (`nplay -b`).
* **The picture**: SDL asks the X server for an Xv overlay. Only the **YV12** format is in hardware on the phone; IYUV is software and stutters.
* **The sound**: SDL's default ALSA driver goes through the ALSA to PulseAudio plug-in and used a third of the CPU; `SDL_AUDIODRIVER=pulse` does not.
  The PulseAudio of the phone also remembers volume and mute per stream role (`x-maemo`), so a stream inherits whatever another program left there
  (muted, or -28 dB). nplay sets its own `module-stream-restore.id` through `PULSE_PROP`: the stream starts at 100 % and the volume is applied by nplay.
  The volume keys of the phone do not reach programs: the status menu handles them (signals `mm_key_press` of the touch screen lock) and sets the
  remembered volume of the role.
* **The clock**: the sound is the master clock. SDL takes the sound in blocks of 4096 samples (85 ms), so the clock is interpolated between the
  calls; without it every frame looked late and was dropped.
* **Volume of the phone, not of the program.** The first version had its own gain, the second changed only the running stream with `pactl` (which did not reach the
  level of the phone and was capped by it). The system volume is the PulseAudio volume of the role `x-maemo` (and the crossed-out note in the status area means it was
  muted, which also explains the silent streams of the first tests); writing that entry changes everything at once.
* **SDL and SIGTERM.** SDL turns SIGTERM into a quit event that a busy loop may never read, so a player that its parent wanted to stop kept playing: nplay ends at once
  on SIGTERM (and SDL_INIT_NOPARACHUTE is set).
* **When the CPU is not enough** (360p is on the edge): the picture lags behind the sound; the main loop makes the decoder cheaper (level 1: no loop
  filter, level 2: also skip the frames that no other frame needs) and goes back when the picture has caught up.
