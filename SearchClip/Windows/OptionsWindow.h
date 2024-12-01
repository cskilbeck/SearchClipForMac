//////////////////////////////////////////////////////////////////////

#pragma once

#import <Cocoa/Cocoa.h>

//////////////////////////////////////////////////////////////////////

@interface LinkButton : NSButton

- (void)set_link_color;
- (void)resetCursorRects;

@property(strong) NSCursor *cursor;

@end

//////////////////////////////////////////////////////////////////////

@interface OptionsWindow : NSWindowController <NSTabViewDelegate, NSWindowDelegate>

@property(weak) IBOutlet NSButton *enable_hotkey_button;
@property(weak) IBOutlet NSButton *button_run_at_login;
@property(weak) IBOutlet NSTextField *hotkey_textfield;
@property(weak) IBOutlet LinkButton *github_button;
@property(weak) IBOutlet NSButtonCell *github_button_cell;
@property(weak) IBOutlet NSButton *show_overlay_button;
@property(weak) IBOutlet NSBox *outline_box;
@property(weak) IBOutlet NSBox *hotkey_container_box;

- (IBAction)enable_hotkey_changed:(NSButton *)sender;
- (IBAction)ok_pressed:(id)sender;
- (IBAction)run_after_login_changed:(NSButton *)sender;
- (IBAction)github_link_clicked:(LinkButton *)sender;
- (IBAction)show_overlay_button_changed:(NSButton *)sender;
- (IBAction)set_hotkey_button:(NSButton *)sender;

- (void)on_deactivate;

- (void)on_hotkey_scanned;
- (void)set_hotkey;

- (void)update_controls;

@end
