#pragma once

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate>

- (void)applicationWillResignActive:(NSNotification *)notification;

- (void)options_closing;

- (bool)on_double_tap;

- (void)enable_or_disable_searchclip;

- (void)toggle_enabled;

- (CGEventRef)hotkey_pressed:(CGEventTapProxy)proxy type:(CGEventType)type event:(CGEventRef)cgevent;

@end

