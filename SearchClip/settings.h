//////////////////////////////////////////////////////////////////////

#pragma once

//////////////////////////////////////////////////////////////////////

typedef struct settings {

    bool hotkey_enabled;
    NSString *search_format;

} settings_t;

//////////////////////////////////////////////////////////////////////

#ifdef __cplusplus
extern "C" {
#endif

extern settings_t settings;

void load_settings(void);
void save_settings(void);

#ifdef __cplusplus
}
#endif
