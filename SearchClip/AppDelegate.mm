//////////////////////////////////////////////////////////////////////

#import <AVFoundation/AVFoundation.h>
#import <ApplicationServices/ApplicationServices.h>

#import "AppDelegate.h"
#import "OptionsWindow.h"

#include "log.h"
#include "settings.h"
#include "image.h"

LOG_CONTEXT("AppDelegate");

CGEventRef __nullable on_hotkey(CGEventTapProxy proxy, CGEventType type, CGEventRef cgevent, void *__nullable userInfo);

//////////////////////////////////////////////////////////////////////

@implementation AppDelegate

OptionsWindow *options_window;

NSStatusItem *status_item;
NSMenuItem *enable_menu_item;

bool hotkey_installed = false;

CFMachPortRef hotkey_tap;
CFRunLoopSourceRef hotkey_runloop_source_ref;

NSTimeInterval last_hotkey_timestamp = 0;

NSImage *status_image;

//////////////////////////////////////////////////////////////////////

- (bool)on_double_tap
{
    LOG(@"Double TAP!");
    NSPasteboard*  myPasteboard  = [NSPasteboard generalPasteboard];
    NSString* clipString = [myPasteboard  stringForType:NSPasteboardTypeString];

    if([clipString length] > 1000) {
        return false;
    }
    
    NSCharacterSet *allowedCharacters = [NSCharacterSet URLQueryAllowedCharacterSet];
    NSString *searchString = [clipString stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacters];
    LOG(@"Clip: %@", searchString);
    NSString *urlString = [settings.search_format stringByReplacingOccurrencesOfString:@"{{CLIP}}" withString:searchString];
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:urlString]];

    return true;
}

//////////////////////////////////////////////////////////////////////

- (CGEventRef)hotkey_pressed:(CGEventTapProxy)proxy type:(CGEventType)type event:(CGEventRef)cgevent
{
    LOG(@"?");
    if (type != kCGEventKeyDown) {
        return cgevent;
    }

    NSEvent *event = [NSEvent eventWithCGEvent:cgevent];
    if([event isARepeat]) {
        return cgevent;
    }

    NSString *chars = [event charactersIgnoringModifiers];
    if([chars length] != 1) {
        return cgevent;
    }

    uint32 chr = [chars characterAtIndex:0];
    uint32 modifiers = [event modifierFlags] & NSEventModifierFlagDeviceIndependentFlagsMask;

    NSTimeInterval when = [event timestamp];

    LOG(@"0x%04x(%08x) AT %f", chr, modifiers, when);

    if (chr != 0x63 || modifiers != NSEventModifierFlagCommand) {
        return cgevent;
    }
    LOG(@"HOTKEY PRESSED");
    NSTimeInterval difference = when - last_hotkey_timestamp;
    last_hotkey_timestamp = when;

    if(difference >= [NSEvent doubleClickInterval]) {
        return cgevent;
    }
    
    if(![self on_double_tap]) {
        return cgevent;
    }
    
    return nil;
}

//////////////////////////////////////////////////////////////////////

- (void)options_closing
{
    save_settings();
}

//////////////////////////////////////////////////////////////////////

- (void)enable_searchclip
{
    if(settings.hotkey_enabled) {
        [self disable_hotkey];
    } else {
        [self enable_hotkey];
    }
    settings.hotkey_enabled = hotkey_installed;
    if(hotkey_installed) {
        [enable_menu_item setTitle:@"Disable SearchClip"];
    } else {
        [enable_menu_item setTitle:@"Enable SearchClip"];
    }
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

- (void)set_status_icon
{
    status_item.button.image = status_image;
    status_item.button.alternateImage = status_image;
}

//////////////////////////////////////////////////////////////////////

- (void)applicationWillResignActive:(NSNotification *)notification
{
    if (options_window != nil) {
        [options_window on_deactivate];
    }
}

//////////////////////////////////////////////////////////////////////

- (void)enable_hotkey
{
    LOG(@"enable hotkey");
    if (!hotkey_installed) {
        NSDictionary *options_prompt = @{(__bridge id)kAXTrustedCheckOptionPrompt : @YES};
        if (AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options_prompt)) {
            LOG(@"permissions OK");
            hotkey_tap = CGEventTapCreate(kCGSessionEventTap, kCGHeadInsertEventTap, kCGEventTapOptionDefault,
                                          CGEventMaskBit(kCGEventKeyDown), on_hotkey, (__bridge void *)self);
            hotkey_runloop_source_ref = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, hotkey_tap, 0);
            CFRunLoopAddSource(CFRunLoopGetMain(), hotkey_runloop_source_ref, kCFRunLoopCommonModes);
            hotkey_installed = true;
        }
    }
}

//////////////////////////////////////////////////////////////////////

-(void)disable_hotkey
{
    LOG(@"disable hotkey");
    if(hotkey_installed) {
        CFRunLoopRemoveSource(CFRunLoopGetMain(), hotkey_runloop_source_ref, kCFRunLoopCommonModes);
        hotkey_tap = nil;
        hotkey_runloop_source_ref = nil;
        hotkey_installed = false;
    }
}

//////////////////////////////////////////////////////////////////////

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [[maybe_unused]] NSProcessInfo *pInfo = [NSProcessInfo processInfo];
    [[maybe_unused]] NSString *version = [pInfo operatingSystemVersionString];
    [[maybe_unused]] NSOperatingSystemVersion ver = [NSProcessInfo.processInfo operatingSystemVersion];
    LOG(@"OS: %@ (%d.%d.%d)", version, ver.majorVersion, ver.minorVersion, ver.patchVersion);

    load_settings();

    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];

    NSMenu *status_menu = [[NSMenu alloc] initWithTitle:@"menu"];

    [status_menu addItemWithTitle:@"Options" action:@selector(show_options_window) keyEquivalent:@""];
    enable_menu_item = [status_menu addItemWithTitle:@"Enable SearchClip" action:@selector(enable_searchclip) keyEquivalent:@""];
    [status_menu addItem:[NSMenuItem separatorItem]];
    [status_menu addItemWithTitle:@"Quit SearchClip" action:@selector(terminate:) keyEquivalent:@""];
#if DEBUG
    [[status_menu addItemWithTitle:@"Debug Build" action:NULL keyEquivalent:@""] setEnabled:false];
#endif

    status_item = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
    status_item.menu = status_menu;

    NSRect frame = [[status_item valueForKey:@"window"] frame];
    int sz = static_cast<int>(frame.size.height * 0.75f);
    status_image = get_status_image(sz);
    [status_image setTemplate:NO];
    
    [self set_status_icon];
    [self enable_searchclip];
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
