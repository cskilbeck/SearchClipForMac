#pragma once

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate>

- (void)applicationWillResignActive:(NSNotification *)notification;

- (void)options_closing;

- (void)enable_hotkey;

- (void)disable_hotkey;

- (bool)on_double_tap;

- (void)enable_searchclip;

- (CGEventRef)hotkey_pressed:(CGEventTapProxy)proxy type:(CGEventType)type event:(CGEventRef)cgevent;

@end

