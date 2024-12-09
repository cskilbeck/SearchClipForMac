//////////////////////////////////////////////////////////////////////

#pragma once

#import <Cocoa/Cocoa.h>

//////////////////////////////////////////////////////////////////////

@interface LinkButton : NSButton

- (void)set_link_color;
- (void)resetCursorRects;

@property(weak) IBInspectable NSString *url;

@property(strong) NSCursor *cursor;

@end

