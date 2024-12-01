#import "AppDelegate.h"

AppDelegate *delegate;

int main(int argc, const char *argv[])
{
    @autoreleasepool {
        delegate = [[AppDelegate alloc] init];
        [[NSApplication sharedApplication] setDelegate:delegate];
    }
    // NSApplicationMain() loads OptionsWindow.xib which isn't what we want
    // so just call the run selector directly. Seems to work...
    NSApplication *app = [NSApplication sharedApplication];
    [app setActivationPolicy: NSApplicationActivationPolicyAccessory];
    [app performSelectorOnMainThread:@selector(run) withObject:nil waitUntilDone:YES];
}
