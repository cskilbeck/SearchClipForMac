#pragma once

enum { mic_status_muted = 0, mic_status_normal = 1, mic_status_disconnected = 2, mic_num_statuses = 3 };

//////////////////////////////////////////////////////////////////////

static char const *mute_status_names[3] = {"Muted", "Unmuted", "Disconnected"};

static inline char const *get_mute_status_name(int status)
{
    if (status < 0) {
        status = 0;
    }
    if (status >= 3) {
        status = 2;
    }
    return mute_status_names[status];
}
