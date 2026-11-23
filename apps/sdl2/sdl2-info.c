/* sdl2-info: what SDL 2 finds on this system (video and audio drivers, display, window surface) and, on request, a short drawing and sound test.
 *   sdl2-info                 list the drivers (needs no display)
 *   sdl2-info --window [ms]   open a window 800x480, draw moving bars for ms milliseconds (default 3000), print the frame rate
 *   sdl2-info --beep [ms]     play a 440 Hz tone (default 1000 ms) through the default audio driver
 * SDL_VIDEODRIVER and SDL_AUDIODRIVER choose the drivers (for example SDL_AUDIODRIVER=pulseaudio). */
#include <SDL.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void tone(void *ud, Uint8 *stream, int len) {
    static double ph = 0;
    Sint16 *s = (Sint16 *)stream;
    (void)ud;
    for (int i = 0; i < len / 2; i++) { s[i] = (Sint16)(sin(ph) * 6000); ph += 2 * M_PI * 440.0 / 22050.0; if (ph > 2 * M_PI) ph -= 2 * M_PI; }
}

int main(int argc, char **argv) {
    int window = 0, beep = 0, wms = 0, bms = 0, *ms = NULL;
    for (int i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "--window")) { window = 1; ms = &wms; }
        else if (!strcmp(argv[i], "--beep")) { beep = 1; ms = &bms; }
        else if (ms && atoi(argv[i]) > 0) *ms = atoi(argv[i]);
        else { fprintf(stderr, "usage: sdl2-info [--window [ms]] [--beep [ms]]\n"); return 2; }
    }
    SDL_version v; SDL_GetVersion(&v);
    printf("SDL %d.%d.%d\n", v.major, v.minor, v.patch);
    printf("video drivers:");
    for (int i = 0; i < SDL_GetNumVideoDrivers(); i++) printf(" %s", SDL_GetVideoDriver(i));
    printf("\naudio drivers:");
    for (int i = 0; i < SDL_GetNumAudioDrivers(); i++) printf(" %s", SDL_GetAudioDriver(i));
    printf("\n");
    if (!window && !beep) return 0;

    if (window) {
        if (SDL_InitSubSystem(SDL_INIT_VIDEO) != 0) { printf("video init failed: %s\n", SDL_GetError()); return 1; }
        SDL_DisplayMode dm;
        if (SDL_GetDesktopDisplayMode(0, &dm) == 0) printf("display: %dx%d %s\n", dm.w, dm.h, SDL_GetPixelFormatName(dm.format));
        SDL_Window *w = SDL_CreateWindow("sdl2-info", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, 800, 480, SDL_WINDOW_SHOWN);
        if (!w) { printf("window failed: %s\n", SDL_GetError()); return 1; }
        SDL_Surface *s = SDL_GetWindowSurface(w);
        printf("video=%s window surface %dx%d %s\n", SDL_GetCurrentVideoDriver(), s->w, s->h, SDL_GetPixelFormatName(s->format->format));
        Uint32 t0 = SDL_GetTicks(), limit = wms ? (Uint32)wms : 3000; int frames = 0, quit = 0;
        while (!quit && SDL_GetTicks() - t0 < limit) {
            SDL_Event e;
            while (SDL_PollEvent(&e)) {
                if (e.type == SDL_QUIT) quit = 1;
                else if (e.type == SDL_KEYDOWN) { printf("key %s\n", SDL_GetKeyName(e.key.keysym.sym)); if (e.key.keysym.sym == SDLK_ESCAPE) quit = 1; }
                else if (e.type == SDL_MOUSEBUTTONDOWN) printf("click %d,%d\n", e.button.x, e.button.y);
            }
            SDL_FillRect(s, NULL, SDL_MapRGB(s->format, 0, 40, 80));
            for (int b = 0; b < 8; b++) {
                SDL_Rect r = { (int)((SDL_GetTicks() / 4 + b * 100) % 800), b * 60, 80, 50 };
                SDL_FillRect(s, &r, SDL_MapRGB(s->format, 255 - b * 25, 180, b * 30));
            }
            SDL_UpdateWindowSurface(w);
            frames++;
        }
        Uint32 dt = SDL_GetTicks() - t0;
        printf("%d frames in %u ms: %.1f frames/s\n", frames, dt, dt ? frames * 1000.0 / dt : 0.0);
        SDL_DestroyWindow(w);
    }
    if (beep) {
        if (SDL_InitSubSystem(SDL_INIT_AUDIO) != 0) { printf("audio init failed: %s\n", SDL_GetError()); return 1; }
        SDL_AudioSpec want, have;
        SDL_zero(want); want.freq = 22050; want.format = AUDIO_S16SYS; want.channels = 1; want.samples = 1024; want.callback = tone;
        SDL_AudioDeviceID d = SDL_OpenAudioDevice(NULL, 0, &want, &have, 0);
        if (!d) { printf("audio open failed: %s\n", SDL_GetError()); return 1; }
        printf("audio=%s %d Hz, %d channel(s), buffer %d samples\n", SDL_GetCurrentAudioDriver(), have.freq, have.channels, have.samples);
        SDL_PauseAudioDevice(d, 0);
        SDL_Delay(bms ? bms : 1000);
        SDL_CloseAudioDevice(d);
    }
    SDL_Quit();
    return 0;
}
