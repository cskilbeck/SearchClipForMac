//////////////////////////////////////////////////////////////////////

#import "AppDelegate.h"
#import "OptionsWindow.h"
#include "log.h"
#include "settings.h"
#include "image.h"

LOG_CONTEXT("OptionsWindow");

//////////////////////////////////////////////////////////////////////

int const num_default_searches = 5;

NSString *default_searches[num_default_searches] = {
    @"https://google.com/search?q={{CLIP}}",
    @"https://bing.com/search?q={{CLIP}}",
    @"https://duckduckgo.com/?q={{CLIP}}",
    @"https://search.yahoo.com/?q={{CLIP}}",
    @"https://www.ask.com/web?q={{CLIP}}",
};

NSString *default_search_names[num_default_searches] = {
    @"Google",
    @"Bing",
    @"DuckDuckGo",
    @"Yahoo",
    @"Ask",
};

@implementation LinkButton

- (void)set_link_color
{
    NSColor *color = [NSColor linkColor];
    NSMutableAttributedString *t = [[NSMutableAttributedString alloc] initWithAttributedString:[self attributedTitle]];
    NSRange titleRange = NSMakeRange(0, [t length]);
    [t addAttribute:NSForegroundColorAttributeName value:color range:titleRange];
    [self setAttributedTitle:t];
}

- (void)resetCursorRects
{
    if (self.cursor) {
        [self addCursorRect:[self bounds] cursor:self.cursor];
    } else {
        [super resetCursorRects];
    }
}

//////////////////////////////////////////////////////////////////////

@end

//////////////////////////////////////////////////////////////////////

@interface OptionsWindow () {
}
@end

//////////////////////////////////////////////////////////////////////

@implementation OptionsWindow

- (void)update_controls
{
    [[self search_format] setStringValue:settings.search_format];
}

//////////////////////////////////////////////////////////////////////

- (void)windowDidLoad
{
    [super windowDidLoad];
    for(int i=0; i<num_default_searches; ++i) {
        [[self default_searches_combobox] addItemWithObjectValue:default_search_names[i]];
    }
    [[self github_button] setCursor:[NSCursor pointingHandCursor]];
    [[self github_button] set_link_color];
    [self update_controls];
}

//////////////////////////////////////////////////////////////////////

- (void)windowWillClose:(NSNotification *)notification
{
    AppDelegate *d = (AppDelegate *)[[NSApplication sharedApplication] delegate];
    [d options_closing];
}

//////////////////////////////////////////////////////////////////////

- (void)controlTextDidChange:(NSNotification *)notification {
    NSTextField *textField = [notification object];
    NSLog(@"controlTextDidChange: stringValue == %@", [textField stringValue]);
    settings.search_format = [textField stringValue];
    save_settings();
}

//////////////////////////////////////////////////////////////////////

- (IBAction)default_search_chosen:(NSComboBox *)sender
{
    long index = [[self default_searches_combobox] indexOfSelectedItem];
    LOG(@"%ld", index);
    NSString *search = default_searches[index];
    [[self search_format] setStringValue:search];
    settings.search_format = search;
    save_settings();
}

//////////////////////////////////////////////////////////////////////

- (IBAction)ok_pressed:(id)sender
{
    [self close];
}

//////////////////////////////////////////////////////////////////////

- (IBAction)github_link_clicked:(LinkButton *)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/cskilbeck/SearchClipForMac"]];
}

//////////////////////////////////////////////////////////////////////

- (void)on_deactivate
{
    LOG(@"on_deactivate");
}

@end
