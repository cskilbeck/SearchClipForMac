//////////////////////////////////////////////////////////////////////

#include "LinkButton.h"

//////////////////////////////////////////////////////////////////////

@implementation LinkButton

- (void)set_link_color
{
    NSColor *color = [NSColor linkColor];
    NSMutableAttributedString *t = [[NSMutableAttributedString alloc] initWithAttributedString:[self attributedTitle]];
    NSRange titleRange = NSMakeRange(0, [t length]);
    [t addAttribute:NSForegroundColorAttributeName value:color range:titleRange];
    [self setAttributedTitle:t];
}

//////////////////////////////////////////////////////////////////////

- (void)resetCursorRects
{
    if (self.cursor) {
        [self addCursorRect:[self bounds] cursor:self.cursor];
    } else {
        [super resetCursorRects];
    }
}

@end

