#pragma once

//////////////////////////////////////////////////////////////////////

#if defined(__cplusplus)
extern "C" {
#endif

//////////////////////////////////////////////////////////////////////

// call this once at startup
OSStatus audio_init(void);

OSStatus audio_scan_devices(bool scan_volumes);

// call this at shutdown
void audio_cleanup(void);

// get mic_status_[muted|unmuted|disconnected] (0,1,2)
int audio_get_mute_status(void);

// do the thing
void audio_toggle_mute(void);

void audio_debug_dump(void);

//////////////////////////////////////////////////////////////////////

#if defined(__cplusplus)
}
#endif
