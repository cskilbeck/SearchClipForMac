#pragma once

#import <Cocoa/Cocoa.h>

//////////////////////////////////////////////////////////////////////

@interface OverlayWindow : NSWindow

- (OverlayWindow *)init;

- (void)set_image:(int)index;

- (void)do_fadeout:(int)index;

@end
