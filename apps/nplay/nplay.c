/* nplay: a small video player for the N900. ffmpeg (libav*) decodes, SDL 1.2 shows the picture (the Xv overlay of the phone does the
 * colour conversion and the scaling) and plays the sound. The sound is the master clock; late frames are dropped.
 *
 *   nplay [options] VIDEO [AUDIO]
 *
 * VIDEO and AUDIO may be the same file (the default) or two files: the video sites give the picture and the sound separately (DASH),
 * so nplay plays them together without joining them. Each file is opened twice (once per stream thread), so nothing is shared.
 */
#define _GNU_SOURCE
#include <SDL.h>
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libswscale/swscale.h>
#include <libswresample/swresample.h>
#include <libavutil/channel_layout.h>
#include <libavutil/imgutils.h>
#include <libavutil/opt.h>
#include <dlfcn.h>
#include <pthread.h>
#include <signal.h>
#include <stdint.h>
#include <sys/resource.h>
#include <sys/syscall.h>
#include <stdio.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define VQ 4                         /* decoded frames waiting for their time */
#define ARING (48000 * 4 * 2)        /* the audio ring: two seconds of 48 kHz stereo S16 */

static const char *vpath, *apath;
static int opt_noaudio, opt_novideo, opt_verbose, opt_window, opt_fast, opt_bench;
static double opt_start;
static volatile int quitting;

/* ---------- the video side ---------- */
static AVFormatContext *vfc;
static AVCodecContext *vcc;
static int vsi = -1;
static struct SwsContext *sws;
static AVFrame *vq[VQ];
static double vq_pts[VQ];
static int vq_n, vq_head, vdone;
static pthread_mutex_t vm = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t vc = PTHREAD_COND_INITIALIZER;

/* ---------- the audio side ---------- */
static AVFormatContext *afc;
static AVCodecContext *acc;
static int asi = -1;
static SwrContext *swr;
static SDL_AudioSpec aspec;
static unsigned char aring[ARING];
static size_t ar_r, ar_count;
static volatile int adone, apaused = 1;
static double a_base = -1.0;         /* the pts of the first sample played */
static unsigned long long a_consumed; /* bytes handed to the sound card */
static Uint32 a_cb_ticks;             /* when the callback last ran (SDL_GetTicks) */
static pthread_mutex_t am = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t ac = PTHREAD_COND_INITIALIZER;

/* ---------- the volume of the phone ----------
 * The volume of the phone is what the PulseAudio of the phone remembers for the role of our stream (x-maemo): the module stream-restore keeps it
 * and the volume item of the status menu writes it. nplay reads and writes the same entry with the extension API of libpulse (loaded at run time:
 * the headers are not in the sysroot), "apply immediately" changes the stream that is playing, and the status menu shows the same level. */
#define ROLE_ENTRY "sink-input-by-media-role:x-maemo"
typedef struct { uint8_t channels; uint32_t values[32]; } pa_cvol_t;
typedef struct { uint8_t channels; int map[32]; } pa_cmap_t;
typedef struct { const char *name; pa_cmap_t channel_map; pa_cvol_t volume; const char *device; int mute; } pa_entry_t;
typedef void (*pa_read_cb)(void *, const pa_entry_t *, int, void *);
static struct {
    int tried, ok;
    void *ml, *ctx;
    void *(*mainloop_new)(void);
    void *(*mainloop_get_api)(void *);
    int (*mainloop_iterate)(void *, int, int *);
    void *(*context_new)(void *, const char *);
    int (*context_connect)(void *, const char *, int, void *);
    int (*context_get_state)(void *);
    void *(*restore_read)(void *, pa_read_cb, void *);
    void *(*restore_write)(void *, int, const pa_entry_t *, unsigned, int, void *, void *);
    int (*operation_get_state)(void *);
    void (*operation_unref)(void *);
} pa;
static double vol_lin = -1.0;                   /* the volume of the phone, 0..1 (-1 not known) */
static Uint32 vol_applied_at;

static int pa_pump(int (*done)(void *), void *arg, int ms)
{
    for (Uint32 t0 = SDL_GetTicks(); SDL_GetTicks() - t0 < (Uint32)ms; ) {
        int rv;
        pa.mainloop_iterate(pa.ml, 0, &rv);
        if (done(arg)) return 1;
        SDL_Delay(2);
    }
    return 0;
}
static int pa_is_ready(void *u) { (void)u; int st = pa.context_get_state(pa.ctx); return st == 4 || st == 5 || st == 6; }
static int pa_op_done(void *op) { return pa.operation_get_state(op) != 0; }

static int pa_start(void)
{
    if (pa.tried) return pa.ok;
    pa.tried = 1;
    void *h = dlopen("libpulse.so.0", RTLD_NOW);
    if (!h) return 0;
#define SYM(field, name) do { *(void **)&pa.field = dlsym(h, name); if (!pa.field) return 0; } while (0)
    SYM(mainloop_new, "pa_mainloop_new"); SYM(mainloop_get_api, "pa_mainloop_get_api"); SYM(mainloop_iterate, "pa_mainloop_iterate");
    SYM(context_new, "pa_context_new"); SYM(context_connect, "pa_context_connect"); SYM(context_get_state, "pa_context_get_state");
    SYM(restore_read, "pa_ext_stream_restore_read"); SYM(restore_write, "pa_ext_stream_restore_write");
    SYM(operation_get_state, "pa_operation_get_state"); SYM(operation_unref, "pa_operation_unref");
    pa.ml = pa.mainloop_new();
    pa.ctx = pa.context_new(pa.mainloop_get_api(pa.ml), "nplay");
    if (!pa.ml || !pa.ctx || pa.context_connect(pa.ctx, NULL, 0, NULL) < 0) return 0;
    if (!pa_pump(pa_is_ready, NULL, 3000) || pa.context_get_state(pa.ctx) != 4) return 0;
    pa.ok = 1;
    return 1;
}

struct rd { pa_entry_t info; char name[160], dev[160]; int found; };
static void rd_cb(void *c, const pa_entry_t *i, int eol, void *u)
{
    struct rd *r = u;
    (void)c;
    if (eol || !i || !i->name || strcmp(i->name, ROLE_ENTRY)) return;
    r->info = *i;
    snprintf(r->name, sizeof r->name, "%s", i->name);
    snprintf(r->dev, sizeof r->dev, "%s", i->device ? i->device : "");
    r->info.name = r->name;
    r->info.device = i->device ? r->dev : NULL;
    r->found = 1;
}

static int pa_read_entry(struct rd *r)
{
    memset(r, 0, sizeof *r);
    if (!pa_start()) return 0;
    void *op = pa.restore_read(pa.ctx, rd_cb, r);
    if (!op) return 0;
    pa_pump(pa_op_done, op, 2000);
    pa.operation_unref(op);
    return r->found;
}

/* the volume of the phone now (linear 0..1), -1 when it cannot be read */
static double sysvol_read(void)
{
    struct rd r;
    if (!pa_read_entry(&r) || !r.info.volume.channels) return -1.0;
    double sum = 0;
    for (int k = 0; k < r.info.volume.channels; k++) sum += r.info.volume.values[k];
    return sum / r.info.volume.channels / 65536.0;
}

/* set it (linear 0..1): the entry is written back with the new level, unmuted, and applied to the stream that plays */
static int sysvol_write(double v)
{
    struct rd r;
    if (v < 0) v = 0;
    if (v > 1) v = 1;
    if (!pa_read_entry(&r)) {                       /* no entry yet: make one for a stereo stream */
        memset(&r, 0, sizeof r);
        r.info.name = ROLE_ENTRY;
        r.info.channel_map.channels = 2; r.info.channel_map.map[0] = 1; r.info.channel_map.map[1] = 2;
        r.info.volume.channels = 2;
    }
    for (int k = 0; k < r.info.volume.channels; k++) r.info.volume.values[k] = (uint32_t)(v * 65536.0 + 0.5);
    r.info.mute = 0;
    void *op = pa.restore_write(pa.ctx, 2 /* PA_UPDATE_REPLACE */, &r.info, 1, 1 /* apply to the streams that play */, NULL, NULL);
    if (!op) return 0;
    pa_pump(pa_op_done, op, 2000);
    pa.operation_unref(op);
    vol_lin = v;
    vol_applied_at = SDL_GetTicks();
    return 1;
}

/* a step of 3 dB up or down */
static void sysvol_step(int dir)
{
    double v = vol_lin >= 0 ? vol_lin : sysvol_read();
    if (v < 0) return;
    v = dir > 0 ? (v < 0.02 ? 0.03 : v * 1.41) : v / 1.41;
    if (v > 1) v = 1;
    if (v < 0.01) v = 0.01;
    if (opt_verbose > 1) fprintf(stderr, "nplay: volume of the phone %.0f %% -> %.0f %%\n", vol_lin * 100, v * 100);
    sysvol_write(v);
}

static volatile int quality_level;              /* 0 full quality, 1 no loop filter, 2 also skips frames that no other frame needs (set by the main loop when the picture lags) */
static unsigned long t_copy;                    /* ms spent showing frames (copy or scale, controls, display) */
static int ov_swapuv;                           /* YV12: the planes are Y, V, U */
static volatile int seek_gen;                   /* counts the seeks; the decoding threads notice a change and seek their file */
static volatile double seek_to;                 /* the target of the last seek, in seconds */
static volatile double start_pts;               /* frames and samples before this time are thrown away: the start, or the target of the last seek */
static unsigned long n_corrupt;               /* frames the decoder marked as damaged: not shown (they look green or grey) */
static unsigned long n_shown, n_dropped, n_underrun;
static double max_late;

static void die(const char *what, int err)
{
    char b[128] = "";
    if (err < 0) av_strerror(err, b, sizeof b);
    fprintf(stderr, "nplay: %s%s%s\n", what, *b ? ": " : "", b);
    exit(1);
}

static int open_stream(const char *path, enum AVMediaType type, AVFormatContext **fc, AVCodecContext **cc, int *si)
{
    int r = avformat_open_input(fc, path, NULL, NULL);
    if (r < 0) die(path, r);
    if (avformat_find_stream_info(*fc, NULL) < 0) die("no stream info", 0);
    int i = av_find_best_stream(*fc, type, -1, -1, NULL, 0);
    if (i < 0) return -1;
    AVStream *st = (*fc)->streams[i];
    const AVCodec *c = avcodec_find_decoder(st->codecpar->codec_id);
    if (!c) die("no decoder for the stream", 0);
    *cc = avcodec_alloc_context3(c);
    avcodec_parameters_to_context(*cc, st->codecpar);
    (*cc)->thread_count = 1;                       /* one CPU */
    if (type == AVMEDIA_TYPE_VIDEO) {
        (*cc)->flags2 |= AV_CODEC_FLAG2_FAST;
        if (opt_fast) (*cc)->skip_loop_filter = AVDISCARD_ALL;   /* less work, a little less sharp */
    }
    if ((r = avcodec_open2(*cc, c, NULL)) < 0) die("decoder", r);
    for (unsigned k = 0; k < (*fc)->nb_streams; k++)
        if ((int)k != i) (*fc)->streams[k]->discard = AVDISCARD_ALL;
    *si = i;
    if (opt_start > 0) av_seek_frame(*fc, -1, (int64_t)(opt_start * AV_TIME_BASE), AVSEEK_FLAG_BACKWARD);
    return 0;
}

/* ---------- decoding threads ---------- */
/* returns 1 when the frame is at or after the start/seek target (so the decoder has caught up) */
static int video_push(AVFrame *fr, int gen)
{
    if ((fr->flags & AV_FRAME_FLAG_CORRUPT) || fr->decode_error_flags) { n_corrupt++; return 0; }
    double pts = fr->best_effort_timestamp == AV_NOPTS_VALUE ? 0.0 : fr->best_effort_timestamp * av_q2d(vfc->streams[vsi]->time_base);
    if (pts < start_pts) return 0;                 /* before the requested start or seek target (the keyframe is earlier) */
    AVFrame *c;
    if (fr->format == AV_PIX_FMT_YUV420P || fr->format == AV_PIX_FMT_YUVJ420P) {
        c = av_frame_clone(fr);
    } else {                                       /* 4:2:2, 4:4:4 ...: convert; the overlay wants 4:2:0 */
        c = av_frame_alloc();
        c->format = AV_PIX_FMT_YUV420P; c->width = fr->width; c->height = fr->height;
        av_frame_get_buffer(c, 32);
        sws = sws_getCachedContext(sws, fr->width, fr->height, fr->format, fr->width, fr->height, AV_PIX_FMT_YUV420P, SWS_BILINEAR, NULL, NULL, NULL);
        sws_scale(sws, (const uint8_t * const *)fr->data, fr->linesize, 0, fr->height, c->data, c->linesize);
    }
    pthread_mutex_lock(&vm);
    while (vq_n == VQ && !quitting && seek_gen == gen) pthread_cond_wait(&vc, &vm);
    if (!quitting && seek_gen == gen) {
        int i = (vq_head + vq_n) % VQ;
        vq[i] = c; vq_pts[i] = pts; vq_n++;
        pthread_cond_broadcast(&vc);
    } else av_frame_free(&c);
    pthread_mutex_unlock(&vm);
    return 1;
}

static void *video_thread(void *arg)
{
    /* The sound must never wait for the picture: the decoder runs at a lower priority than the sound thread and the sound server. */
    setpriority(PRIO_PROCESS, (id_t)syscall(SYS_gettid), getenv("NPLAY_NICE") ? atoi(getenv("NPLAY_NICE")) : 10);
    AVPacket *pkt = av_packet_alloc();
    AVFrame *fr = av_frame_alloc();
    int gen = 0, catching_up = opt_start > 0;      /* after a start or a seek the decoder runs from the keyframe: cheaply, until the target */
    (void)arg;
    while (!quitting) {
        if (seek_gen != gen) {                     /* a seek was asked for */
            gen = seek_gen;
            av_seek_frame(vfc, -1, (int64_t)(seek_to * AV_TIME_BASE), AVSEEK_FLAG_BACKWARD);
            avcodec_flush_buffers(vcc);
            catching_up = 1;
        }
        if (av_read_frame(vfc, pkt) < 0) break;
        if (pkt->stream_index == vsi) {
            int q = catching_up ? 2 : quality_level;
            vcc->skip_loop_filter = (q >= 1 || opt_fast) ? AVDISCARD_ALL : AVDISCARD_DEFAULT;
            vcc->skip_frame = q >= 2 ? AVDISCARD_NONREF : AVDISCARD_DEFAULT;
            if (avcodec_send_packet(vcc, pkt) >= 0)
                while (!quitting && seek_gen == gen && avcodec_receive_frame(vcc, fr) == 0) {
                    if (video_push(fr, gen)) catching_up = 0;
                    av_frame_unref(fr);
                }
        }
        av_packet_unref(pkt);
    }
    avcodec_send_packet(vcc, NULL);
    while (!quitting && avcodec_receive_frame(vcc, fr) == 0) { video_push(fr, gen); av_frame_unref(fr); }
    pthread_mutex_lock(&vm);
    vdone = 1;
    pthread_cond_broadcast(&vc);
    pthread_mutex_unlock(&vm);
    return NULL;
}

static int a_gen;                              /* the generation (seek count) that the audio thread is working on */

/* base: the pts of the first sample, taken when the ring is empty after a start or a seek */
static void audio_write(const unsigned char *p, size_t n, int gen, double base)
{
    pthread_mutex_lock(&am);
    if (seek_gen != gen) { pthread_mutex_unlock(&am); return; }
    if (a_base < 0) a_base = base;
    while (n && !quitting) {
        size_t room = ARING - ar_count;
        if (!room) { pthread_cond_wait(&ac, &am); if (seek_gen != gen) break; continue; }
        size_t w = (ar_r + ar_count) % ARING, k = n < room ? n : room;
        if (k > ARING - w) k = ARING - w;
        memcpy(aring + w, p, k);
        ar_count += k; p += k; n -= k;
    }
    pthread_mutex_unlock(&am);
}

static void audio_frame(AVFrame *fr)
{
    double pts = fr->pts == AV_NOPTS_VALUE ? 0.0 : fr->pts * av_q2d(afc->streams[asi]->time_base);
    double from = start_pts;
    int skip = 0;
    if (seek_gen != a_gen) return;
    if (pts + (double)fr->nb_samples / fr->sample_rate < from) return;
    if (pts < from) skip = (int)((from - pts) * aspec.freq);
    int max = (int)av_rescale_rnd(swr_get_delay(swr, fr->sample_rate) + fr->nb_samples, aspec.freq, fr->sample_rate, AV_ROUND_UP) + 64;
    uint8_t *out = av_malloc((size_t)max * 4);
    int n = swr_convert(swr, &out, max, (const uint8_t **)fr->extended_data, fr->nb_samples);
    if (n > skip) audio_write(out + (size_t)skip * 4, (size_t)(n - skip) * 4, a_gen, pts > from ? pts : from);
    av_free(out);
}

static void *audio_thread(void *arg)
{
    AVPacket *pkt = av_packet_alloc();
    AVFrame *fr = av_frame_alloc();
    (void)arg;
    while (!quitting) {
        if (seek_gen != a_gen) {
            a_gen = seek_gen;
            av_seek_frame(afc, -1, (int64_t)(seek_to * AV_TIME_BASE), AVSEEK_FLAG_BACKWARD);
            avcodec_flush_buffers(acc);
            swr_convert(swr, NULL, 0, NULL, 0);        /* drop what the resampler still holds */
        }
        if (av_read_frame(afc, pkt) < 0) break;
        if (pkt->stream_index == asi && avcodec_send_packet(acc, pkt) >= 0)
            while (!quitting && seek_gen == a_gen && avcodec_receive_frame(acc, fr) == 0) { audio_frame(fr); av_frame_unref(fr); }
        av_packet_unref(pkt);
    }
    avcodec_send_packet(acc, NULL);
    while (!quitting && avcodec_receive_frame(acc, fr) == 0) { audio_frame(fr); av_frame_unref(fr); }
    adone = 1;
    return NULL;
}

/* called by SDL in its own thread: fill the buffer of the sound card */
static void audio_cb(void *u, Uint8 *stream, int len)
{
    (void)u;
    memset(stream, 0, len);
    pthread_mutex_lock(&am);
    if (!apaused) {
        size_t k = (size_t)len < ar_count ? (size_t)len : ar_count, first = k < ARING - ar_r ? k : ARING - ar_r;
        memcpy(stream, aring + ar_r, first);
        memcpy(stream + first, aring, k - first);
        ar_r = (ar_r + k) % ARING; ar_count -= k; a_consumed += k; a_cb_ticks = SDL_GetTicks();
        if (k < (size_t)len && !adone) n_underrun++;
        pthread_cond_broadcast(&ac);
    }
    pthread_mutex_unlock(&am);
}

/* ---------- the clock ---------- */
static Uint32 wall0, wall_pause_at, wall_paused_total;
static int have_audio;

static double audio_clock(void)
{
    pthread_mutex_lock(&am);
    double c = a_base + (double)a_consumed / ((double)aspec.freq * 4.0);
    /* The sound card takes the data in blocks (4096 samples = 85 ms), so a_consumed jumps; between two calls the clock goes on by the system time. */
    double step = (double)aspec.samples / aspec.freq, since = (SDL_GetTicks() - a_cb_ticks) / 1000.0;
    int running = !apaused && a_cb_ticks;
    pthread_mutex_unlock(&am);
    if (running) c += since < step ? since : step;
    return c - step;                                /* what is heard now is about one block behind what was handed over */
}

static double now(double first_pts)
{
    if (have_audio && a_base >= 0 && !(adone && ar_count == 0)) return audio_clock();
    return first_pts + (SDL_GetTicks() - wall0 - wall_paused_total) / 1000.0;
}

static void set_paused(int p)
{
    pthread_mutex_lock(&am); apaused = p; pthread_mutex_unlock(&am);
    if (p) wall_pause_at = SDL_GetTicks(); else wall_paused_total += SDL_GetTicks() - wall_pause_at;
}

/* ---------- the controls: drawn into the picture, like the player of the phone ----------
 * The picture is a hardware (Xv) overlay that covers whatever the program draws on the window, so the controls cannot be drawn on the screen: they are
 * drawn into a canvas (colour and transparency per pixel, 800x480) and blended into the frame itself. While they are shown the overlay has the size of
 * the screen and the frame is scaled (swscale) into it; while they are hidden the overlay has the size of the video and the hardware scales it. */
#define UI_W 800
#define UI_H 480
typedef struct { uint8_t y, u, v; } yuv_t;
static uint8_t ui_a[UI_H][UI_W];                 /* transparency: 0 nothing, 255 solid */
static yuv_t ui_c[UI_H][UI_W];
static int vol_panel;                            /* the vertical volume slider is shown */

static yuv_t rgb(int r, int g, int b)
{
    yuv_t c = { (uint8_t)(((66 * r + 129 * g + 25 * b + 128) >> 8) + 16), (uint8_t)(((-38 * r - 74 * g + 112 * b + 128) >> 8) + 128),
                (uint8_t)(((112 * r - 94 * g - 18 * b + 128) >> 8) + 128) };
    return c;
}

static void ui_px(int x, int y, yuv_t c, int a) { if ((unsigned)x < UI_W && (unsigned)y < UI_H) { ui_c[y][x] = c; ui_a[y][x] = (uint8_t)a; } }
static void ui_rect(int x, int y, int w, int h, yuv_t c, int a) { for (int j = 0; j < h; j++) for (int i = 0; i < w; i++) ui_px(x + i, y + j, c, a); }
static void ui_round(int x, int y, int w, int h, int r, yuv_t c, int a)
{
    for (int j = 0; j < h; j++)
        for (int i = 0; i < w; i++) {
            int dx = i < r ? r - i : i >= w - r ? i - (w - r - 1) : 0, dy = j < r ? r - j : j >= h - r ? j - (h - r - 1) : 0;
            if (dx * dx + dy * dy <= r * r) ui_px(x + i, y + j, c, a);
        }
}
static int edge(int ax, int ay, int bx, int by, int px, int py) { return (bx - ax) * (py - ay) - (by - ay) * (px - ax); }
static void ui_tri(int x1, int y1, int x2, int y2, int x3, int y3, yuv_t c, int a)
{
    int minx = x1 < x2 ? (x1 < x3 ? x1 : x3) : (x2 < x3 ? x2 : x3), maxx = x1 > x2 ? (x1 > x3 ? x1 : x3) : (x2 > x3 ? x2 : x3);
    int miny = y1 < y2 ? (y1 < y3 ? y1 : y3) : (y2 < y3 ? y2 : y3), maxy = y1 > y2 ? (y1 > y3 ? y1 : y3) : (y2 > y3 ? y2 : y3);
    for (int y = miny; y <= maxy; y++)
        for (int x = minx; x <= maxx; x++) {
            int e1 = edge(x1, y1, x2, y2, x, y), e2 = edge(x2, y2, x3, y3, x, y), e3 = edge(x3, y3, x1, y1, x, y);
            if ((e1 >= 0 && e2 >= 0 && e3 >= 0) || (e1 <= 0 && e2 <= 0 && e3 <= 0)) ui_px(x, y, c, a);
        }
}
static void ui_arc(int cx, int cy, int r0, int r1, yuv_t c)            /* a ring segment on the right side of a point (the waves of the speaker) */
{
    for (int y = -r1; y <= r1; y++)
        for (int x = 1; x <= r1; x++) {
            int d = x * x + y * y;
            if (d >= r0 * r0 && d <= r1 * r1 && abs(y) <= x * 13 / 10) ui_px(cx + x, cy + y, c, 255);
        }
}

/* a tiny font for the times: 5x7 digits and the colon, drawn at a scale */
static const unsigned char glyphs[11][7] = {
    {0x0e, 0x11, 0x13, 0x15, 0x19, 0x11, 0x0e}, {0x04, 0x0c, 0x04, 0x04, 0x04, 0x04, 0x0e}, {0x0e, 0x11, 0x01, 0x02, 0x04, 0x08, 0x1f},
    {0x1e, 0x01, 0x01, 0x0e, 0x01, 0x01, 0x1e}, {0x02, 0x06, 0x0a, 0x12, 0x1f, 0x02, 0x02}, {0x1f, 0x10, 0x1e, 0x01, 0x01, 0x11, 0x0e},
    {0x06, 0x08, 0x10, 0x1e, 0x11, 0x11, 0x0e}, {0x1f, 0x01, 0x02, 0x04, 0x08, 0x08, 0x08}, {0x0e, 0x11, 0x11, 0x0e, 0x11, 0x11, 0x0e},
    {0x0e, 0x11, 0x11, 0x0f, 0x01, 0x02, 0x0c}, {0x00, 0x04, 0x00, 0x00, 0x00, 0x04, 0x00}};

static int text_width(const char *t, int scale) { return (int)strlen(t) * 6 * scale - scale; }

static void ui_text(int x, int y, const char *t, int scale, yuv_t col)
{
    for (; *t; t++, x += 6 * scale) {
        int g = *t == ':' ? 10 : (*t >= '0' && *t <= '9') ? *t - '0' : -1;
        if (g < 0) continue;
        for (int row = 0; row < 7; row++)
            for (int cx = 0; cx < 5; cx++)
                if (glyphs[g][row] & (0x10 >> cx)) ui_rect(x + cx * scale, y + row * scale, scale, scale, col, 255);
    }
}

static void fmt_time(char *buf, double sec)
{
    int t = sec < 0 ? 0 : (int)sec;
    if (t >= 3600) sprintf(buf, "%d:%02d:%02d", t / 3600, t / 60 % 60, t % 60);
    else sprintf(buf, "%02d:%02d", t / 60, t % 60);
}

/* the layout (the same as the player of the phone has): hit areas used by the touch handling */
typedef struct { int x, y, w, h; } area_t;
static const area_t A_BACK = { 700, 0, 100, 76 }, A_PREV = { 232, 192, 96, 96 }, A_PLAY = { 352, 192, 96, 96 }, A_NEXT = { 472, 192, 96, 96 };
static const area_t A_BAR = { 0, 408, 730, 72 }, A_SPEAKER = { 730, 408, 70, 72 }, A_PANEL = { 696, 70, 104, 338 };
#define SL_X0 140                                /* the position slider */
#define SL_X1 612
#define VP_Y0 132                                /* the volume slider (a vertical one, in the panel) */
#define VP_Y1 372
static int in_area(const area_t *a, int x, int y) { return x >= a->x && x < a->x + a->w && y >= a->y && y < a->y + a->h; }

/* the volume slider is perceptual: the position is the square root of the linear volume */
static double slider_of(double lin) { return lin <= 0 ? 0 : sqrt(lin); }
static double vol_from_y(int y)
{
    double f = (double)(VP_Y1 - y) / (VP_Y1 - VP_Y0);
    f = f < 0 ? 0 : f > 1 ? 1 : f;
    return f * f;
}
static double pos_from_x(int x, double duration)
{
    double f = (double)(x - SL_X0) / (SL_X1 - SL_X0);
    f = f < 0 ? 0 : f > 1 ? 1 : f;
    return f * duration;
}

static void ui_draw(double pos, double duration, int paused, int drag_pos, int drag_vol)
{
    memset(ui_a, 0, sizeof ui_a);
    yuv_t white = rgb(245, 245, 245), mid = rgb(165, 165, 170), black = rgb(0, 0, 0), track = rgb(64, 66, 70), frame = rgb(28, 28, 30);
    yuv_t or1 = rgb(255, 150, 25), or2 = rgb(214, 104, 0), knob = rgb(46, 46, 50), rim = rgb(120, 120, 126), blue = rgb(120, 190, 255);
    /* the bar at the bottom: the time, the slider with its grip, the length, the speaker */
    ui_rect(0, UI_H - 72, UI_W, 72, black, 205);
    int scale = duration >= 3600 ? 2 : 3, ty = UI_H - 36 - 7 * scale / 2, cy = UI_H - 36;
    char tl[16], tr[16];
    fmt_time(tl, pos); fmt_time(tr, duration);
    ui_text(22, ty, tl, scale, white);
    ui_round(SL_X0 - 4, cy - 12, SL_X1 - SL_X0 + 8, 24, 6, frame, 255);
    ui_rect(SL_X0, cy - 8, SL_X1 - SL_X0, 16, track, 255);
    int fw = duration > 0 ? (int)((SL_X1 - SL_X0) * (pos < 0 ? 0 : pos > duration ? 1 : pos / duration)) : 0;
    ui_rect(SL_X0, cy - 8, fw, 8, or1, 255);
    ui_rect(SL_X0, cy, fw, 8, or2, 255);
    int kx = SL_X0 + fw;
    ui_round(kx - 20, cy - 33, 40, 66, 8, drag_pos ? blue : rim, 255);
    ui_round(kx - 18, cy - 31, 36, 62, 7, knob, 255);
    for (int i = -1; i <= 1; i++) ui_rect(kx + i * 7 - 1, cy - 18, 3, 36, rim, 255);
    if (duration > 0) ui_text(SL_X1 + 14, ty, tr, scale, mid);
    int sx = 764, sy = cy;                                    /* the speaker */
    ui_rect(sx - 26, sy - 10, 14, 20, white, 255);
    ui_tri(sx - 12, sy - 10, sx + 4, sy - 24, sx + 4, sy + 24, white, 255);
    ui_tri(sx - 12, sy - 10, sx + 4, sy + 24, sx - 12, sy + 10, white, 255);
    ui_arc(sx + 6, sy, 12, 16, white);
    if (vol_lin > 0.15) ui_arc(sx + 6, sy, 22, 26, white);
    /* the arrow to go back (it ends the player) */
    ui_tri(726, 28, 746, 12, 746, 44, white, 255);
    ui_rect(746, 22, 24, 12, white, 255);
    /* the three big buttons in the middle: back 10 s, play or pause, forward 10 s */
    for (int i = 0; i < 3; i++) ui_round(232 + 120 * i, 192, 96, 96, 10, black, 215);
    int cx = 280;                                             /* previous */
    ui_rect(cx - 22, 218, 6, 44, white, 255);
    ui_tri(cx + 22, 218, cx + 22, 262, cx - 14, 240, white, 255);
    cx = 400;                                                 /* play / pause */
    if (paused) ui_tri(cx - 12, 216, cx - 12, 264, cx + 22, 240, white, 255);
    else { ui_rect(cx - 18, 218, 12, 44, white, 255); ui_rect(cx + 6, 218, 12, 44, white, 255); }
    cx = 520;                                                 /* next */
    ui_tri(cx - 22, 218, cx - 22, 262, cx + 14, 240, white, 255);
    ui_rect(cx + 16, 218, 6, 44, white, 255);
    /* the vertical volume slider above the speaker */
    if (vol_panel) {
        ui_round(A_PANEL.x, A_PANEL.y, A_PANEL.w, A_PANEL.h, 10, black, 215);
        int px = A_PANEL.x + A_PANEL.w / 2;
        double sl = slider_of(vol_lin < 0 ? 0 : vol_lin);
        sl = sl > 1 ? 1 : sl;
        int ky = VP_Y1 - (int)((VP_Y1 - VP_Y0) * sl);
        ui_round(px - 10, VP_Y0 - 4, 20, VP_Y1 - VP_Y0 + 8, 6, frame, 255);
        ui_rect(px - 6, VP_Y0, 12, VP_Y1 - VP_Y0, track, 255);
        ui_rect(px - 6, ky, 6, VP_Y1 - ky, or1, 255);
        ui_rect(px, ky, 6, VP_Y1 - ky, or2, 255);
        ui_round(px - 26, ky - 16, 52, 32, 7, drag_vol ? blue : rim, 255);
        ui_round(px - 24, ky - 14, 48, 28, 6, knob, 255);
        for (int i = -1; i <= 1; i++) ui_rect(px - 14 + (i + 1) * 14, ky - 8, 3, 16, rim, 255);
        char pct[8];
        sprintf(pct, "%d", vol_lin < 0 ? 0 : (int)(vol_lin * 100 + 0.5));
        ui_text(px - text_width(pct, 3) / 2, A_PANEL.y + 22, pct, 3, white);
    }
}

/* the canvas over a frame of the screen's size (an overlay in YV12 or IYUV) */
static void ui_blend(SDL_Overlay *o, int swapuv)
{
    uint8_t *yp = o->pixels[0], *up = o->pixels[swapuv ? 2 : 1], *vp = o->pixels[swapuv ? 1 : 2];
    int ys = o->pitches[0], us = o->pitches[swapuv ? 2 : 1], vs = o->pitches[swapuv ? 1 : 2];
    for (int y = 0; y < UI_H; y++)
        for (int x = 0; x < UI_W; x++) {
            int a = ui_a[y][x];
            if (!a) continue;
            uint8_t *d = yp + (size_t)y * ys + x;
            *d = (uint8_t)((*d * (255 - a) + ui_c[y][x].y * a) / 255);
        }
    for (int y = 0; y < UI_H / 2; y++)
        for (int x = 0; x < UI_W / 2; x++) {
            int a = ui_a[2 * y][2 * x];
            if (!a) continue;
            uint8_t *du = up + (size_t)y * us + x, *dv = vp + (size_t)y * vs + x;
            *du = (uint8_t)((*du * (255 - a) + ui_c[2 * y][2 * x].u * a) / 255);
            *dv = (uint8_t)((*dv * (255 - a) + ui_c[2 * y][2 * x].v * a) / 255);
        }
}

/* ---------- showing a frame ---------- */
static SDL_Surface *screen;
static SDL_Overlay *ov;
static Uint32 ov_format;
static int ov_ui;                                /* 1: the overlay has the size of the screen and carries the controls */
static SDL_Rect dst;                             /* where the overlay goes on the screen */
static struct SwsContext *sws_ui;
static AVFrame *cur_frame;                       /* the frame on the screen (to draw again when the controls change while paused) */
static int ui_visible, ui_dirty;

static void fit_rect(int sw, int sh, int w, int h, int *x, int *y, int *rw, int *rh)
{
    double sc = (double)sw / w, sv = (double)sh / h;
    if (sv < sc) sc = sv;
    *rw = ((int)(w * sc)) & ~1; *rh = ((int)(h * sc)) & ~1;
    *x = ((sw - *rw) / 2) & ~1; *y = ((sh - *rh) / 2) & ~1;
}

static void set_ui_mode(int on)
{
    if (!screen || (ov && on == ov_ui)) return;
    if (ov) SDL_FreeYUVOverlay(ov);
    ov = SDL_CreateYUVOverlay(on ? screen->w : vcc->width, on ? screen->h : vcc->height, ov_format, screen);
    if (!ov) die("no YUV overlay", 0);
    ov_ui = on;
    SDL_FillRect(screen, NULL, 0);                     /* what the old overlay left outside the new picture */
    SDL_UpdateRect(screen, 0, 0, 0, 0);
    if (on) {
        dst.x = 0; dst.y = 0; dst.w = (Uint16)screen->w; dst.h = (Uint16)screen->h;
        SDL_LockYUVOverlay(ov);                        /* black borders: the frame is scaled into the middle of it */
        for (int y = 0; y < ov->h; y++) memset(ov->pixels[0] + (size_t)y * ov->pitches[0], 16, ov->w);
        for (int k = 1; k <= 2; k++) for (int y = 0; y < ov->h / 2; y++) memset(ov->pixels[k] + (size_t)y * ov->pitches[k], 128, ov->w / 2);
        SDL_UnlockYUVOverlay(ov);
    } else {
        int x, y, w, h;
        fit_rect(screen->w, screen->h, vcc->width, vcc->height, &x, &y, &w, &h);
        dst.x = x; dst.y = y; dst.w = (Uint16)w; dst.h = (Uint16)h;
    }
}

static void present(AVFrame *f)
{
    if (!ov || !f) return;
    SDL_LockYUVOverlay(ov);
    if (!ov_ui) {                                     /* hidden controls: copy the frame, the hardware scales it */
        int w = vcc->width, h = vcc->height;
        for (int y = 0; y < h; y++) memcpy(ov->pixels[0] + (size_t)y * ov->pitches[0], f->data[0] + (size_t)y * f->linesize[0], w);
        for (int y = 0; y < (h + 1) / 2; y++) {
            memcpy(ov->pixels[1] + (size_t)y * ov->pitches[1], f->data[ov_swapuv ? 2 : 1] + (size_t)y * f->linesize[ov_swapuv ? 2 : 1], (w + 1) / 2);
            memcpy(ov->pixels[2] + (size_t)y * ov->pitches[2], f->data[ov_swapuv ? 1 : 2] + (size_t)y * f->linesize[ov_swapuv ? 1 : 2], (w + 1) / 2);
        }
    } else {                                          /* shown controls: scale the frame into the screen-sized overlay and blend them in */
        int x, y, w, h;
        fit_rect(ov->w, ov->h, f->width, f->height, &x, &y, &w, &h);
        uint8_t *dp[3] = { ov->pixels[0] + (size_t)y * ov->pitches[0] + x, ov->pixels[ov_swapuv ? 2 : 1] + (size_t)(y / 2) * ov->pitches[ov_swapuv ? 2 : 1] + x / 2,
                           ov->pixels[ov_swapuv ? 1 : 2] + (size_t)(y / 2) * ov->pitches[ov_swapuv ? 1 : 2] + x / 2 };
        int ds[3] = { ov->pitches[0], ov->pitches[ov_swapuv ? 2 : 1], ov->pitches[ov_swapuv ? 1 : 2] };
        sws_ui = sws_getCachedContext(sws_ui, f->width, f->height, f->format, w, h, AV_PIX_FMT_YUV420P, SWS_FAST_BILINEAR, NULL, NULL, NULL);
        sws_scale(sws_ui, (const uint8_t * const *)f->data, f->linesize, 0, f->height, dp, ds);
        ui_blend(ov, ov_swapuv);
    }
    SDL_UnlockYUVOverlay(ov);
    SDL_DisplayYUVOverlay(ov, &dst);
    if (cur_frame != f) { av_frame_free(&cur_frame); cur_frame = av_frame_clone(f); }
}

static void on_term(int sig)
{
    (void)sig;
    _exit(0);
}

/* ask both decoding threads to seek: drop what is decoded and queued, the sound starts again when a quarter of a second of the new position is ready */
static void do_seek(double target)
{
    pthread_mutex_lock(&am);
    seek_to = target; start_pts = target;
    seek_gen++;
    ar_r = 0; ar_count = 0; a_consumed = 0; a_base = -1.0; a_cb_ticks = 0; apaused = 1;
    pthread_cond_broadcast(&ac);
    pthread_mutex_unlock(&am);
    pthread_mutex_lock(&vm);
    while (vq_n) { av_frame_free(&vq[vq_head]); vq_head = (vq_head + 1) % VQ; vq_n--; }
    pthread_cond_broadcast(&vc);
    pthread_mutex_unlock(&vm);
}

static void usage(void)
{
    fputs("Usage: nplay [options] VIDEO [AUDIO]\n"
          "  VIDEO, AUDIO   media files (the same file by default; a video site gives the picture and the sound apart)\n"
          "  -n             no sound              -N   no picture (sound only)\n"
          "  -s SECONDS     start at this time    -W   window instead of full screen\n"
          "  -f             faster, less sharp decoding (skips the loop filter)\n"
          "  -b             benchmark: decode everything as fast as possible, show nothing\n"
          "  -v             statistics at the end\n"
          "Keys: Esc, q or Backspace quits, space pauses, Up/Down change the volume of the phone, Left/Right go 10 s back/forward, PgUp/PgDn 60 s.\n"
          "Touch: a tap shows the controls (like the player of the phone), they hide again after a few seconds: the arrow at the top right quits,\n"
          "       the buttons in the middle go 10 s back, play/pause, 10 s forward, the bar at the bottom seeks (drag it), the speaker opens the volume slider.\n", stderr);
    exit(2);
}

int main(int argc, char **argv)
{
    int c;
    while ((c = getopt(argc, argv, "nNs:Wfbvh")) != -1) {
        switch (c) {
        case 'n': opt_noaudio = 1; break;
        case 'N': opt_novideo = 1; break;
        case 's': opt_start = atof(optarg); break;
        case 'W': opt_window = 1; break;
        case 'f': opt_fast = 1; break;
        case 'b': opt_bench = 1; opt_noaudio = 1; break;
        case 'v': opt_verbose++; break;
        default: usage();
        }
    }
    if (optind >= argc) usage();
    vpath = argv[optind];
    apath = optind + 1 < argc ? argv[optind + 1] : vpath;
    av_log_set_level(opt_verbose ? AV_LOG_WARNING : AV_LOG_ERROR);

    if (!opt_novideo && open_stream(vpath, AVMEDIA_TYPE_VIDEO, &vfc, &vcc, &vsi) < 0) {
        if (opt_verbose) fputs("nplay: no video stream\n", stderr);
        opt_novideo = 1;
    }
    if (!opt_noaudio && open_stream(apath, AVMEDIA_TYPE_AUDIO, &afc, &acc, &asi) < 0) opt_noaudio = 1;
    if (opt_novideo && opt_noaudio && !opt_bench) die("nothing to play", 0);

    setenv("SDL_AUDIODRIVER", "pulse", 0);     /* the ALSA plug-in of SDL uses a third of the CPU on the phone */
    /* The volume of the phone (the volume keys, the volume item of the status menu) is the volume that the PulseAudio of the phone remembers for the
     * role of the stream (x-maemo), and nplay's stream has that role: so the system volume works. The Up/Down keys only fine-tune on top of it.
     * NPLAY_OWN_STREAM=1 gives the stream an identity of its own (100 %, not muted): for a phone whose system volume was left muted or very low. */
    if (getenv("NPLAY_OWN_STREAM")) setenv("PULSE_PROP", "module-stream-restore.id=nplay-stream", 0);
    signal(SIGTERM, on_term);                   /* SDL would turn SIGTERM into a quit event that a busy loop may never see; end at once */
    signal(SIGINT, on_term);
    Uint32 flags = SDL_INIT_NOPARACHUTE | SDL_INIT_TIMER | (opt_bench ? 0 : (opt_novideo ? 0 : SDL_INIT_VIDEO) | (opt_noaudio ? 0 : SDL_INIT_AUDIO));
    if (SDL_Init(flags) < 0) die(SDL_GetError(), 0);

    if (!opt_novideo && !opt_bench) {
        screen = SDL_SetVideoMode(800, 480, 0, SDL_SWSURFACE | (opt_window ? 0 : SDL_FULLSCREEN));
        if (!screen) die(SDL_GetError(), 0);
        SDL_ShowCursor(SDL_DISABLE);
        SDL_WM_SetCaption("nplay", "nplay");
        /* prefer a format that the video hardware takes (hw_overlay); NPLAY_FORMAT=yv12|iyuv forces one */
        static const Uint32 fmts[2] = { SDL_YV12_OVERLAY, SDL_IYUV_OVERLAY };
        static const char *names[2] = { "yv12", "iyuv" };
        const char *force = getenv("NPLAY_FORMAT");
        for (int k = 0; k < 2 && !ov; k++) {
            if (force && strcmp(force, names[k])) continue;
            SDL_Overlay *o = SDL_CreateYUVOverlay(vcc->width, vcc->height, fmts[k], screen);
            if (!o) continue;
            if (opt_verbose) fprintf(stderr, "nplay: overlay %s: %s\n", names[k], o->hw_overlay ? "hardware (Xv)" : "software");
            if (o->hw_overlay || k == 1 || force) { ov = o; ov_swapuv = (fmts[k] == SDL_YV12_OVERLAY); ov_format = fmts[k]; }
            else SDL_FreeYUVOverlay(o);
        }
        if (!ov) die("no YUV overlay", 0);
        if (opt_verbose) fprintf(stderr, "nplay: %dx%d, overlay %s\n", vcc->width, vcc->height, ov->hw_overlay ? "in hardware (Xv)" : "in software");
        SDL_FreeYUVOverlay(ov);                       /* set_ui_mode makes the real one (the size depends on the controls) */
        ov = NULL;
        set_ui_mode(0);
    }
    if (!opt_noaudio) {
        SDL_AudioSpec want;
        memset(&want, 0, sizeof want);
        want.freq = 48000; want.format = AUDIO_S16SYS; want.channels = 2; want.samples = 4096; want.callback = audio_cb;
        if (SDL_OpenAudio(&want, &aspec) < 0 || aspec.channels != 2 || aspec.format != AUDIO_S16SYS) {
            fprintf(stderr, "nplay: no sound (%s)\n", SDL_GetError());
            opt_noaudio = 1;
        } else {
            AVChannelLayout out = AV_CHANNEL_LAYOUT_STEREO;
            if (swr_alloc_set_opts2(&swr, &out, AV_SAMPLE_FMT_S16, aspec.freq, &acc->ch_layout, acc->sample_fmt, acc->sample_rate, 0, NULL) < 0 || swr_init(swr) < 0)
                die("resampler", 0);
        }
    }
    have_audio = !opt_noaudio;

    start_pts = opt_start; seek_to = opt_start;
    pthread_t vt, at;
    if (!opt_novideo) pthread_create(&vt, NULL, video_thread, NULL);
    if (have_audio) pthread_create(&at, NULL, audio_thread, NULL);

    /* the sound starts when a quarter of a second is ready (or all of it, if the sound is shorter) */
    if (have_audio) {
        for (;;) {
            pthread_mutex_lock(&am);
            int ready = ar_count >= (size_t)aspec.freq || adone;
            pthread_mutex_unlock(&am);
            if (ready || quitting) break;
            SDL_Delay(10);
        }
        set_paused(0);
        SDL_PauseAudio(0);
    } else set_paused(0);
    wall0 = SDL_GetTicks(); wall_paused_total = 0;

    double first_pts = opt_start, duration = 0.0;
    int paused = 0, have_first = 0, restarting = 0;
    if (vfc && vfc->duration > 0) duration = vfc->duration / (double)AV_TIME_BASE;
    else if (afc && afc->duration > 0) duration = afc->duration / (double)AV_TIME_BASE;
    /* a seek to a time: not while paused, not at the end */
#define SEEK_TO(abs_time) do { \
        if (!paused && !restarting && !(vfc && vdone) && !(have_audio && adone)) { \
            double tgt = (abs_time); \
            if (duration > 2 && tgt > duration - 2) tgt = duration - 2; \
            if (tgt < 0) tgt = 0; \
            do_seek(tgt); restarting = 1; have_first = 0; first_pts = tgt; wall0 = SDL_GetTicks(); wall_paused_total = 0; ui_dirty = 1; \
        } } while (0)
#define SEEK(delta) SEEK_TO(now(first_pts) + (delta))
    /* the controls: a tap shows them (the first tap only does that), they hide by themselves after a few seconds, never while paused or dragging */
    Uint32 ui_hide_at = 0;
#define SHOW_UI() do { ui_visible = 1; ui_hide_at = SDL_GetTicks() + 4500; set_ui_mode(1); ui_dirty = 1; if (cur_frame) { AVFrame *k = av_frame_clone(cur_frame); present(k); av_frame_free(&k); } } while (0)
#define HIDE_UI() do { if (!paused) { ui_visible = 0; vol_panel = 0; set_ui_mode(0); if (cur_frame) { AVFrame *k = av_frame_clone(cur_frame); present(k); av_frame_free(&k); } } } while (0)
#define TOGGLE_PAUSE() do { paused = !paused; if (have_audio) SDL_PauseAudio(paused); set_paused(paused); if (paused) SHOW_UI(); else ui_hide_at = SDL_GetTicks() + 3000; ui_dirty = 1; } while (0)
    Uint32 t_bench = SDL_GetTicks(), dbg_t = 0;
    double test_seek_at = -1, test_seek_by = 0, test_vol_at = -1;
    int test_vol_dir = 0, test_show_panel = 0;
    double test_show_at = -1;
    if (getenv("NPLAY_TEST_SHOW")) sscanf(getenv("NPLAY_TEST_SHOW"), "%lf:%d", &test_show_at, &test_show_panel);
    if (getenv("NPLAY_TEST_VOL")) sscanf(getenv("NPLAY_TEST_VOL"), "%lf:%d", &test_vol_at, &test_vol_dir);
    if (getenv("NPLAY_TEST_SEEK")) sscanf(getenv("NPLAY_TEST_SEEK"), "%lf:%lf", &test_seek_at, &test_seek_by);
    int drag = 0, last_sec = -1;                      /* drag: 1 the position slider, 2 the volume slider */
    double drag_t = 0;
    if (screen && !opt_bench) {
        SDL_FillRect(screen, NULL, 0);
        SDL_UpdateRect(screen, 0, 0, 0, 0);
        vol_lin = sysvol_read();
    }
    while (!quitting) {
        SDL_Event e;
        while (SDL_PollEvent(&e)) {
            if (e.type == SDL_QUIT) quitting = 1;
            else if (e.type == SDL_KEYDOWN) {
                SDLKey k = e.key.keysym.sym;
                if (opt_verbose > 1) fprintf(stderr, "nplay: key sym=%d scancode=%d name=%s\n", k, e.key.keysym.scancode, SDL_GetKeyName(k));
                if (k == SDLK_ESCAPE || k == SDLK_q || k == SDLK_BACKSPACE) quitting = 1;
                else if (k == SDLK_F7 || k == SDLK_UP || k == SDLK_PLUS || k == SDLK_KP_PLUS) { sysvol_step(1); vol_panel = 1; SHOW_UI(); }
                else if (k == SDLK_F8 || k == SDLK_DOWN || k == SDLK_MINUS || k == SDLK_KP_MINUS) { sysvol_step(-1); vol_panel = 1; SHOW_UI(); }
                else if (k == SDLK_RIGHT) { SEEK(10); SHOW_UI(); }
                else if (k == SDLK_LEFT) { SEEK(-10); SHOW_UI(); }
                else if (k == SDLK_PAGEUP) { SEEK(60); SHOW_UI(); }
                else if (k == SDLK_PAGEDOWN) { SEEK(-60); SHOW_UI(); }
                else if (k == SDLK_SPACE) TOGGLE_PAUSE();
            } else if (e.type == SDL_MOUSEBUTTONDOWN && screen) {
                int x = e.button.x, y = e.button.y;
                if (!ui_visible) SHOW_UI();                           /* the first tap only shows the controls */
                else {
                    ui_hide_at = SDL_GetTicks() + 4500;
                    if (vol_panel && in_area(&A_PANEL, x, y)) { drag = 2; sysvol_write(vol_from_y(y)); ui_dirty = 1; }
                    else if (in_area(&A_BACK, x, y)) quitting = 1;
                    else if (in_area(&A_SPEAKER, x, y)) { vol_panel = !vol_panel; ui_dirty = 1; }
                    else if (in_area(&A_BAR, x, y)) { if (duration > 0 && x >= SL_X0 - 26 && x <= SL_X1 + 26) { drag = 1; drag_t = pos_from_x(x, duration); ui_dirty = 1; } }
                    else if (in_area(&A_PREV, x, y)) SEEK(-10);
                    else if (in_area(&A_PLAY, x, y)) TOGGLE_PAUSE();
                    else if (in_area(&A_NEXT, x, y)) SEEK(10);
                    else HIDE_UI();                                  /* a tap elsewhere hides them */
                }
            } else if (e.type == SDL_MOUSEMOTION && screen && drag) {
                ui_hide_at = SDL_GetTicks() + 4500;
                if (drag == 1) { drag_t = pos_from_x(e.motion.x, duration); ui_dirty = 1; }
                else if (SDL_GetTicks() - vol_applied_at > 100) { sysvol_write(vol_from_y(e.motion.y)); ui_dirty = 1; }
            } else if (e.type == SDL_MOUSEBUTTONUP && screen && drag) {
                if (drag == 1) SEEK_TO(drag_t);
                else sysvol_write(vol_from_y(e.button.y));
                drag = 0; ui_dirty = 1;
            }
        }
        if (screen && !opt_bench && ui_visible) {
            if (!paused && !drag && (int)(SDL_GetTicks() - ui_hide_at) > 0) HIDE_UI();           /* the controls go away by themselves */
            else {
                double pos = drag == 1 ? drag_t : (restarting || !have_first) ? first_pts : now(first_pts);
                if (ui_dirty || (int)pos != last_sec) {
                    ui_draw(pos, duration, paused, drag == 1, drag == 2);
                    last_sec = (int)pos; ui_dirty = 0;
                    if (paused && cur_frame) { AVFrame *k = av_frame_clone(cur_frame); present(k); av_frame_free(&k); }   /* no new frames while paused */
                }
            }
        }
        if (test_seek_at >= 0 && (SDL_GetTicks() - t_bench) / 1000.0 >= test_seek_at) { double d = test_seek_by; test_seek_at = -1; SEEK(d); }   /* NPLAY_TEST_SEEK=SECONDS:DELTA, for the tests */
        if (test_show_at >= 0 && (SDL_GetTicks() - t_bench) / 1000.0 >= test_show_at) { test_show_at = -1; vol_panel = test_show_panel; SHOW_UI(); }   /* NPLAY_TEST_SHOW=SECONDS[:1 with the volume panel] */
        if (test_vol_at >= 0 && (SDL_GetTicks() - t_bench) / 1000.0 >= test_vol_at) { test_vol_at = -1; sysvol_step(test_vol_dir); ui_dirty = 1; }   /* NPLAY_TEST_VOL=SECONDS:DIR, for the tests */
        if (paused) { SDL_Delay(50); continue; }
        if (restarting) {                            /* after a seek the sound starts again when a quarter of a second is ready */
            pthread_mutex_lock(&am);
            int ready = !have_audio || ar_count >= (size_t)aspec.freq || adone;
            if (ready && have_audio) apaused = 0;
            pthread_mutex_unlock(&am);
            if (!ready) { SDL_Delay(5); continue; }
            restarting = 0;
        }

        if (opt_novideo) {                           /* sound only: wait for the end */
            pthread_mutex_lock(&am); int end = adone && ar_count == 0; pthread_mutex_unlock(&am);
            if (end) break;
            SDL_Delay(50);
            continue;
        }

        pthread_mutex_lock(&vm);
        if (vq_n == 0) {
            int end = vdone;
            pthread_mutex_unlock(&vm);
            if (end) break;
            SDL_Delay(2);
            continue;
        }
        AVFrame *f = vq[vq_head];
        double pts = vq_pts[vq_head];
        int more = vq_n > 1;
        pthread_mutex_unlock(&vm);

        if (!have_first) { first_pts = pts; have_first = 1; wall0 = SDL_GetTicks(); wall_paused_total = 0; }
        double diff = opt_bench ? 0.0 : pts - now(first_pts);
        if (opt_verbose > 1 && SDL_GetTicks() - dbg_t >= 1000) {
            dbg_t = SDL_GetTicks();
            fprintf(stderr, "nplay: t=%.1f clock=%.2f frame pts=%.2f queue=%d ring=%zuk shown=%lu dropped=%lu underruns=%lu\n", (dbg_t - t_bench) / 1000.0, now(first_pts), pts, vq_n, ar_count / 1024, n_shown, n_dropped, n_underrun);
        }
        if (diff > 0.004) { SDL_Delay(diff > 0.02 ? 10 : 2); continue; }
        if (!opt_bench) {                            /* the picture lags: make the decoder cheaper; it caught up: go back */
            static Uint32 calm_since;
            double lag = -diff;
            if (lag > 0.50 && quality_level < 2) quality_level = 2;
            else if (lag > 0.20 && quality_level < 1) quality_level = 1;
            if (lag > 0.09) calm_since = SDL_GetTicks();           /* one frame (0.04 s) late is normal */
            else if (quality_level > 0 && SDL_GetTicks() - calm_since > 1500) { quality_level--; calm_since = SDL_GetTicks(); }
        }
        int late_drop = !opt_bench && diff < -0.10 && more;      /* late and there is a newer one: skip it */
        if (!late_drop && ov) {
            Uint32 tt0 = SDL_GetTicks();
            present(f);
            t_copy += SDL_GetTicks() - tt0;
        }
        if (late_drop) n_dropped++; else { n_shown++; if (-diff > max_late) max_late = -diff; }
        pthread_mutex_lock(&vm);
        av_frame_free(&vq[vq_head]);
        vq_head = (vq_head + 1) % VQ; vq_n--;
        pthread_cond_broadcast(&vc);
        pthread_mutex_unlock(&vm);
    }

    quitting = 1;
    pthread_mutex_lock(&vm); pthread_cond_broadcast(&vc); pthread_mutex_unlock(&vm);
    pthread_mutex_lock(&am); pthread_cond_broadcast(&ac); pthread_mutex_unlock(&am);
    if (opt_verbose || opt_bench) {
        double secs = (SDL_GetTicks() - t_bench) / 1000.0;
        fprintf(stderr, "nplay: %lu frames shown, %lu dropped, %lu audio underruns, worst lateness %.3f s, quality level %d, %lu damaged frames skipped, showing %.1f ms%s per frame", n_shown, n_dropped, n_underrun, max_late, quality_level, n_corrupt, n_shown ? (double)t_copy / n_shown : 0.0, "");
        if (opt_bench) fprintf(stderr, ", %.1f frames/s", secs > 0 ? n_shown / secs : 0.0);
        fputc('\n', stderr);
    }
    _exit(0);                                        /* the decoding threads may sit in read(); do not wait for them */
}
