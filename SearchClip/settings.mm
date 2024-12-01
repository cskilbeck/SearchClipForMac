//////////////////////////////////////////////////////////////////////

#import <AVFoundation/AVFoundation.h>

#include <AppKit/NSEvent.h>

#include "log.h"
#include "mic_status.h"
#include "settings.h"

LOG_CONTEXT("settings");

//////////////////////////////////////////////////////////////////////

settings_t settings;

//////////////////////////////////////////////////////////////////////

void save_settings(void)
{
    LOG(@"SAVE SETTINGS");
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

#define SAVE(type, val)                              \
    [defaults set##type:settings.val forKey:@ #val]; \
    LOG(@"Saved " #val);

    SAVE(Bool, hotkey_enabled);
    SAVE(Bool, show_overlay);
    SAVE(Bool, run_at_login);
    SAVE(Integer, hotkey);
    SAVE(Integer, modifiers);
}

//////////////////////////////////////////////////////////////////////

void load_settings(void)
{
    LOG(@"LOAD SETTINGS");
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSArray<NSString *> *keys = [[defaults dictionaryRepresentation] allKeys];

    settings.run_at_login = false;
    settings.show_overlay = true;
    settings.hotkey_enabled = true;
    settings.hotkey = 'C';
    settings.modifiers = NSEventModifierFlagFunction;

#define LOAD(type, val)                                                        \
    if ([keys containsObject:@ #val]) {                                        \
        settings.val = (decltype(settings.val))[defaults type##ForKey:@ #val]; \
        LOG(@"Loaded " #val);                                             \
    }

    LOAD(bool, hotkey_enabled);
    LOAD(bool, show_overlay);
    LOAD(bool, run_at_login);
    LOAD(integer, hotkey);
    LOAD(integer, modifiers);
}
