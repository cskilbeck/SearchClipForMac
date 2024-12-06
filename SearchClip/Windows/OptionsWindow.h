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

@interface OptionsWindow : NSWindowController <NSTabViewDelegate, NSWindowDelegate, NSControlTextEditingDelegate>

@property(weak) IBOutlet NSButton *button_run_at_login;
@property(weak) IBOutlet LinkButton *github_button;
@property(weak) IBOutlet NSButtonCell *github_button_cell;
@property(weak) IBOutlet NSTextField *search_format;
@property(weak) IBOutlet NSComboBox *default_searches_combobox;

- (IBAction)ok_pressed:(id)sender;
- (IBAction)run_after_login_changed:(NSButton *)sender;
- (IBAction)github_link_clicked:(LinkButton *)sender;
- (IBAction)default_search_chosen:(NSComboBox *)sender;

- (void)on_deactivate;

- (void)update_controls;

- (void) controlTextDidChange:(NSNotification *)obj;

@end
