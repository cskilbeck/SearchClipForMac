//////////////////////////////////////////////////////////////////////

#import "AppDelegate.h"
#import "OptionsWindow.h"
#include "log.h"
#include "settings.h"
#include "audio.h"
#include "image.h"

LOG_CONTEXT("OptionsWindow");

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
    [[self button_run_at_login] setState:settings.run_at_login ? NSControlStateValueOn : NSControlStateValueOff];
    [[self enable_hotkey_button] setState:settings.hotkey_enabled ? NSControlStateValueOn : NSControlStateValueOff];
    [[self show_overlay_button] setState:settings.show_overlay ? NSControlStateValueOn : NSControlStateValueOff];
    [self update_hotkey_textfield];
    [self hotkey_container_box].hidden = !settings.hotkey_enabled;
}

//////////////////////////////////////////////////////////////////////

- (void)windowDidLoad
{
    [super windowDidLoad];
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

- (IBAction)enable_hotkey_changed:(NSButton *)sender
{
    settings.hotkey_enabled = [[self enable_hotkey_button] state] == NSControlStateValueOn;
    LOG(@"HOTKEY ENABLED: %d", settings.hotkey_enabled);
    if (settings.hotkey_enabled) {

        AppDelegate *app = (AppDelegate *)[[NSApplication sharedApplication] delegate];
        [app setup_hotkey];
    }
    [[self enable_hotkey_button] setState:settings.hotkey_enabled ? NSControlStateValueOn : NSControlStateValueOff];
    [self hotkey_container_box].hidden = !settings.hotkey_enabled;
}

//////////////////////////////////////////////////////////////////////

- (IBAction)ok_pressed:(id)sender
{
    [self close];
}

//////////////////////////////////////////////////////////////////////
// 'run after login' check button changed state

- (IBAction)run_after_login_changed:(NSButton *)sender
{
    settings.run_at_login = [sender state] == NSControlStateValueOn;
}

//////////////////////////////////////////////////////////////////////

- (IBAction)github_link_clicked:(LinkButton *)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/cskilbeck/MacMicMuter"]];
}

//////////////////////////////////////////////////////////////////////

static NSString *get_key_name(uint32 key)
{
    if (key > ' ' && key < 127) {
        unichar uni = (unichar)key;
        return [NSString stringWithCharacters:&uni length:1];
    }
    if (key >= NSF1FunctionKey && key <= NSF24FunctionKey) {
        return [NSString stringWithFormat:@"F%d", key - NSF1FunctionKey + 1];
    }
    switch (key) {
    case 0x0020:
        return @"␣"; // Space
    case 0x0003:
        return @"⌅"; // Enter
    case 0x0009:
        return @"⇥"; // Tab
    case 0x000d:
        return @"↩"; // Return
    case 0x001b:
        return @"⎋"; // Escape
    case 0x007f:
        return @"⌫"; // Backspace
    case 0xf700:
        return @"↑"; // Up
    case 0xf701:
        return @"↓"; // Down
    case 0xf702:
        return @"←"; // Left
    case 0xf703:
        return @"→"; // Right
    case 0xf728:
        return @"⌦"; // Delete
    case 0xf729:
        return @"↖"; // Home
    case 0xf72b:
        return @"↘"; // End
    case 0xf72c:
        return @"⇞"; // Page Up
    case 0xf72d:
        return @"⇟"; // Page Down
    case 0xf739:
        return @"⌧"; // Clear
    }
    return [NSString stringWithFormat:@"%04x", key];
}

//////////////////////////////////////////////////////////////////////

#define NUM_MODIFIERS 5

typedef struct modifier_name {
    char const *name;
    uint32 mask;
} modifier_name_t;

static modifier_name_t modifier_names[NUM_MODIFIERS] = {
    {"⇧", NSEventModifierFlagShift},      // shift
    {"⌃", NSEventModifierFlagControl},    // control
    {"⌥", NSEventModifierFlagOption},     // option
    {"⌘", NSEventModifierFlagCommand},    // command
    {" 𐄡", NSEventModifierFlagNumericPad} // numpad
};

//////////////////////////////////////////////////////////////////////

- (void)update_hotkey_textfield
{
    LOG(@"update_hotkey_textfield");
    NSString *modifiers = @"";
    for (int i = 0; i < NUM_MODIFIERS; ++i) {
        if ((settings.modifiers & modifier_names[i].mask) != 0) {
            NSString *name = [NSString stringWithUTF8String:modifier_names[i].name];
            modifiers = [modifiers stringByAppendingString:name];
        }
    }
    NSString *hotkey_name = [NSString stringWithFormat:@"%@ %@", modifiers, get_key_name(settings.hotkey)];
    [[self outline_box] setHidden:YES];
    [[[self hotkey_textfield] cell] setTitle:hotkey_name];
}

//////////////////////////////////////////////////////////////////////

- (void)set_hotkey
{
    LOG(@"set_hotkey");
    if (hotkey_scanning) {
        hotkey_scanning = false;
        [self update_hotkey_textfield];
        return;
    }
    hotkey_scanning = true;

    [[self outline_box] setHidden:NO];
    [[[self hotkey_textfield] cell] setTitle:@"Choose hotkey..."];

    AppDelegate *app = (AppDelegate *)[[NSApplication sharedApplication] delegate];
    [app scan_for_hotkey];
}

//////////////////////////////////////////////////////////////////////

- (void)on_deactivate
{
    LOG(@"on_deactivate");
    hotkey_scanning = false;
    [self update_hotkey_textfield];
}

//////////////////////////////////////////////////////////////////////

- (IBAction)set_hotkey_button:(NSButton *)sender
{
    [self set_hotkey];
}

//////////////////////////////////////////////////////////////////////

- (IBAction)show_overlay_button_changed:(NSButton *)sender
{
    settings.show_overlay = [sender state] == NSControlStateValueOn;
}

//////////////////////////////////////////////////////////////////////

- (void)on_hotkey_scanned
{
    hotkey_scanning = false;
    [self update_hotkey_textfield];
}

@end
