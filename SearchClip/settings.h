//////////////////////////////////////////////////////////////////////

#pragma once

//////////////////////////////////////////////////////////////////////

typedef struct settings {

    bool run_at_login;
    bool show_overlay;
    bool hotkey_enabled;
    uint32 hotkey;
    uint32 modifiers;

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
