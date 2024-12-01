//////////////////////////////////////////////////////////////////////
// App Icon
// Run after login
// Sandboxing
// Input Monitoring vs Accessibility permissions

#import <AVFoundation/AVFoundation.h>
#import <ApplicationServices/ApplicationServices.h>

#import "AppDelegate.h"
#import "OptionsWindow.h"
#import "OverlayWindow.h"

#include "log.h"
#include "audio.h"
#include "settings.h"
#include "image.h"
#include "mic_status.h"

LOG_CONTEXT("AppDelegate");

CGEventRef __nullable on_hotkey(CGEventTapProxy proxy, CGEventType type, CGEventRef cgevent, void *__nullable userInfo);

//////////////////////////////////////////////////////////////////////

@implementation AppDelegate

OverlayWindow *overlay_window;
OptionsWindow *options_window;

NSStatusItem *status_item;
NSMenuItem *mute_menu_item;

bool hotkey_installed = false;
bool hotkey_scanning = false;

CFMachPortRef hotkey_tap;
CFRunLoopSourceRef hotkey_runloop_source_ref;

NSTimer *audio_update_timer;

int previous_mute_status = -1;
bool muting = false;

NSImage *mic_small_images[mic_num_statuses];

//////////////////////////////////////////////////////////////////////

- (CGEventRef)hotkey_pressed:(CGEventTapProxy)proxy type:(CGEventType)type event:(CGEventRef)cgevent
{
    if (type == kCGEventKeyDown) {
        NSEvent *event = [NSEvent eventWithCGEvent:cgevent];
        NSString *chars = [event charactersIgnoringModifiers];
        if ([chars length] == 1) {
            uint32 chr = [chars characterAtIndex:0];
            uint32 modifiers = [event modifierFlags] & NSEventModifierFlagDeviceIndependentFlagsMask;
            LOG(@"0x%04x(%08x) (0x%04x(%08x))", chr, modifiers, settings.hotkey, settings.modifiers);
            if (hotkey_scanning) {
                hotkey_scanning = false;
                settings.hotkey = chr;
                settings.modifiers = modifiers;
                [options_window on_hotkey_scanned];
                return nil;
            } else {
                if (![event isARepeat] && chr == settings.hotkey && modifiers == settings.modifiers) {
                    LOG(@"HOTKEY PRESSED");
                    muting = true;
                    audio_toggle_mute();
                    return nil;
                }
            }
        }
    }
    return cgevent;
}

//////////////////////////////////////////////////////////////////////

- (void)options_closing
{
    save_settings();
}

//////////////////////////////////////////////////////////////////////

- (void)toggle_mute
{
    audio_toggle_mute();
}

//////////////////////////////////////////////////////////////////////

- (void)debug_dump
{
    audio_debug_dump();
}

//////////////////////////////////////////////////////////////////////

- (void)show_options_window
{
    if (options_window == nil) {
        options_window = [[OptionsWindow alloc] initWithWindowNibName:@"OptionsWindow"];
    }
    [options_window update_controls];
    [options_window showWindow:nil];
    [NSApp activateIgnoringOtherApps:TRUE];
    [options_window.window makeKeyAndOrderFront:nil];
}

//////////////////////////////////////////////////////////////////////

- (void)show_overlay
{
    if (settings.show_overlay) {
        int status = audio_get_mute_status();
        [overlay_window set_image:status];
        [overlay_window orderFront:nil];
        [overlay_window do_fadeout:status];
    }
}

//////////////////////////////////////////////////////////////////////

- (void)set_status_icon
{
    int status = audio_get_mute_status();
    if (status == mic_status_normal) {
        [mute_menu_item setTitle:@"Mute"];
    } else {
        [mute_menu_item setTitle:@"Unmute"];
    }
    status_item.button.image = mic_small_images[status];
    status_item.button.alternateImage = mic_small_images[status];
}

//////////////////////////////////////////////////////////////////////

- (void)on_audio_update_timer
{
    audio_scan_devices(!muting);
    int new_status = audio_get_mute_status();
    LOG(@"NEW MUTE STATUS IS %s", get_mute_status_name(new_status));
    if (new_status != previous_mute_status) {
        [self set_status_icon];
        [self show_overlay];
    }
    previous_mute_status = new_status;
    muting = false;
}

//////////////////////////////////////////////////////////////////////

- (void)audio_changed
{
    @synchronized(self) {

        if (audio_update_timer) {
            [audio_update_timer invalidate];
            audio_update_timer = nil;
        }
        audio_update_timer = [NSTimer timerWithTimeInterval:0.1f
                                                     target:self
                                                   selector:@selector(on_audio_update_timer)
                                                   userInfo:nil
                                                    repeats:NO];

        [[NSRunLoop mainRunLoop] addTimer:audio_update_timer forMode:NSRunLoopCommonModes];
    }
}

//////////////////////////////////////////////////////////////////////

- (void)applicationWillResignActive:(NSNotification *)notification
{
    hotkey_scanning = false;

    if (options_window != nil) {
        [options_window on_deactivate];
    }
}

//////////////////////////////////////////////////////////////////////

- (void)scan_for_hotkey
{
    hotkey_scanning = true;
}

//////////////////////////////////////////////////////////////////////

- (void)setup_hotkey
{
    LOG(@"setup_hotkey: enabled = %d", settings.hotkey_enabled);
    if (settings.hotkey_enabled) {
        if (!hotkey_installed) {
            NSDictionary *options_prompt = @{(__bridge id)kAXTrustedCheckOptionPrompt : @YES};
            if (AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options_prompt)) {
                LOG(@"permissions OK");
                hotkey_tap = CGEventTapCreate(kCGSessionEventTap, kCGHeadInsertEventTap, kCGEventTapOptionDefault,
                                              CGEventMaskBit(kCGEventKeyDown), on_hotkey, (__bridge void *)self);
                hotkey_runloop_source_ref = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, hotkey_tap, 0);
                CFRunLoopAddSource(CFRunLoopGetMain(), hotkey_runloop_source_ref, kCFRunLoopCommonModes);
                hotkey_installed = true;
            } else {
                LOG(@"still need permissions");
                settings.hotkey_enabled = false;
                [self show_options_window];
            }
        }
    } else if (hotkey_installed) {
        LOG(@"remove hotkey");
        CFRunLoopRemoveSource(CFRunLoopGetMain(), hotkey_runloop_source_ref, kCFRunLoopCommonModes);
        hotkey_tap = nil;
        hotkey_runloop_source_ref = nil;
        hotkey_installed = false;
    }
}

//////////////////////////////////////////////////////////////////////

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    LOG(@"----------------------------------------------------------");

    NSProcessInfo *pInfo = [NSProcessInfo processInfo];
    NSString *version = [pInfo operatingSystemVersionString];

    NSOperatingSystemVersion ver = [NSProcessInfo.processInfo operatingSystemVersion];

    LOG(@"OS: %@ (%d.%d.%d)", version, ver.majorVersion, ver.minorVersion, ver.patchVersion);

    load_settings();

    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];

    [self setup_hotkey];

    audio_init();

    NSMenu *status_menu = [[NSMenu alloc] initWithTitle:@"menu"];

    mute_menu_item = [status_menu addItemWithTitle:@"Toggle mute" action:@selector(toggle_mute) keyEquivalent:@""];
    [status_menu addItemWithTitle:@"Options" action:@selector(show_options_window) keyEquivalent:@""];
    [status_menu addItem:[NSMenuItem separatorItem]];
    [status_menu addItemWithTitle:@"Quit MicMuter" action:@selector(terminate:) keyEquivalent:@""];
#if DEBUG
    [status_menu addItem:[NSMenuItem separatorItem]];
    [status_menu addItemWithTitle:@"Debug Dump" action:@selector(debug_dump) keyEquivalent:@""];
#endif

    status_item = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
    status_item.menu = status_menu;

    NSRect frame = [[status_item valueForKey:@"window"] frame];
    int sz = (int)(frame.size.height * 1);
    for (int i = 0; i < mic_num_statuses; ++i) {
        mic_small_images[i] = get_small_image_for_mic_status(i, sz);
        [mic_small_images[i] setTemplate:YES];
    }

    [self set_status_icon];

    overlay_window = [[OverlayWindow alloc] init];
    [overlay_window set_image:audio_get_mute_status()];
}

//////////////////////////////////////////////////////////////////////

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
}

//////////////////////////////////////////////////////////////////////

- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app
{
    return YES;
}

//////////////////////////////////////////////////////////////////////

@end

//////////////////////////////////////////////////////////////////////

CGEventRef __nullable on_hotkey(CGEventTapProxy proxy, CGEventType type, CGEventRef cgevent, void *__nullable userInfo)
{
    AppDelegate *d = (__bridge AppDelegate *)userInfo;
    return [d hotkey_pressed:proxy type:type event:cgevent];
}
