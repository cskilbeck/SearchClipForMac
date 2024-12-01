#pragma once

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate>

- (void)applicationWillResignActive:(NSNotification *)notification;

- (void)options_closing;

- (void)audio_changed;

- (void)setup_hotkey;

- (void)scan_for_hotkey;

- (CGEventRef)hotkey_pressed:(CGEventTapProxy)proxy type:(CGEventType)type event:(CGEventRef)cgevent;

@end

extern bool hotkey_scanning;
