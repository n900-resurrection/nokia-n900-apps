/* What cmus 2.13 uses from libpulse 0.9.19 and newer, for the 0.9.15 headers and library of the N900 (Maemo 5):
   the two "no flags" names and the two per-position volume helpers (pure arithmetic on the structures, no new library call). */
#ifndef CMUS_PULSE_COMPAT_H
#define CMUS_PULSE_COMPAT_H
#include <pulse/pulseaudio.h>

#ifndef PA_CONTEXT_NOFLAGS
#define PA_CONTEXT_NOFLAGS 0
#endif
#ifndef PA_STREAM_NOFLAGS
#define PA_STREAM_NOFLAGS 0
#endif

static inline pa_cvolume *pa_cvolume_set_position(pa_cvolume *cv, const pa_channel_map *map, pa_channel_position_t pos, pa_volume_t v)
{
	unsigned i;
	for (i = 0; i < map->channels; i++)
		if (map->map[i] == pos)
			cv->values[i] = v;
	return cv;
}

static inline pa_volume_t pa_cvolume_get_position(const pa_cvolume *cv, const pa_channel_map *map, pa_channel_position_t pos)
{
	unsigned i;
	pa_volume_t r = 0;
	for (i = 0; i < map->channels; i++)
		if (map->map[i] == pos && cv->values[i] > r)
			r = cv->values[i];
	return r;
}
#endif
