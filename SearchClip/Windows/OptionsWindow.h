//////////////////////////////////////////////////////////////////////

#pragma once

#import <Cocoa/Cocoa.h>
#include "LinkButton.h"

//////////////////////////////////////////////////////////////////////

@interface OptionsWindow : NSWindowController <NSTabViewDelegate, NSWindowDelegate, NSControlTextEditingDelegate>

@property(weak) IBOutlet LinkButton *github_button;
@property(weak) IBOutlet NSButtonCell *github_button_cell;
@property(weak) IBOutlet NSTextField *search_format;
@property(weak) IBOutlet NSComboBox *default_searches_combobox;

- (IBAction)ok_pressed:(id)sender;
- (IBAction)github_link_clicked:(LinkButton *)sender;
- (IBAction)default_search_chosen:(NSComboBox *)sender;

- (void)on_deactivate;

- (void)update_controls;

- (void)controlTextDidChange:(NSNotification *)obj;

@end
