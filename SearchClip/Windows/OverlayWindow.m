//////////////////////////////////////////////////////////////////////

#import <Foundation/Foundation.h>
#import "OverlayWindow.h"
#include "log.h"
#include "image.h"
#include "settings.h"

LOG_CONTEXT("OverlayWindow");

//////////////////////////////////////////////////////////////////////

float const show_alpha = 0.95f;

//////////////////////////////////////////////////////////////////////

@interface OverlayWindow () {
    NSImage *mic_image[3];
    int image_index;
    float overlay_size;
    NSTimer *wait_timer;
    NSTimer *fade_timer;
    uint64_t fade_started_at_ns;
}

//////////////////////////////////////////////////////////////////////

- (void)refresh_image:(int)index;

@end

//////////////////////////////////////////////////////////////////////

@implementation OverlayWindow

//////////////////////////////////////////////////////////////////////

- (void)refresh_image:(int)index
{
    if (mic_image[index] == nil || [mic_image[index] size].width != overlay_size) {
        mic_image[index] = get_image_for_mic_status(index, overlay_size);
    }
}

//////////////////////////////////////////////////////////////////////

- (void)release_images
{
    mic_image[0] = nil;
    mic_image[1] = nil;
    mic_image[2] = nil;
}

//////////////////////////////////////////////////////////////////////

- (OverlayWindow *)init
{
    LOG(@"OverlayWindow init");
    self = [super init];

    [self setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces];
    [self setLevel:kCGDockWindowLevel];

    CGRect frame = [NSScreen mainScreen].frame;
    float width = frame.size.width;
    float height = frame.size.height;
    float max_dim = MAX(width, height);
    float const normal_size = 200.0f;
    float const ratio = 1920 / normal_size;
    overlay_size = roundf(max_dim / ratio);
    LOG(@"overlay size is %f", overlay_size);
    float x = (width - overlay_size) / 2;
    float y = overlay_size * .7f;
    [self setFrame:NSMakeRect(x, y, overlay_size, overlay_size) display:NO];
    [self setContentSize:NSMakeSize(overlay_size, overlay_size)];
    overlay_size = [self frame].size.width;
    [self setStyleMask:NSWindowStyleMaskBorderless];
    [self setOpaque:NO];
    [self setHasShadow:NO];
    [self setIgnoresMouseEvents:YES];
    [self setBackgroundColor:NSColor.clearColor];
    [self setCanHide:YES];
    [self setIsVisible:NO];
    return self;
}

//////////////////////////////////////////////////////////////////////

- (void)set_image:(int)index
{
    image_index = index;
    [self refresh_image:index];
    NSImageView *v = [NSImageView imageViewWithImage:mic_image[index]];
    [v setImageScaling:NSImageScaleProportionallyUpOrDown];
    [self setContentView:v];
}

//////////////////////////////////////////////////////////////////////

- (void)on_fade_timer
{
    uint64_t elapsed_ns = clock_gettime_nsec_np(CLOCK_MONOTONIC) - fade_started_at_ns;
    double elapsed_seconds = elapsed_ns / 1000000000.0;
    float new_alpha = show_alpha - (elapsed_seconds / 0.5f); // fadeout over 0.5 seconds
    if (new_alpha > 0) {
        [self setAlphaValue:new_alpha];
    } else {
        [fade_timer invalidate];
        fade_timer = nil;
        [self setCanHide:YES];
        [self setIsVisible:NO];
    }
}

//////////////////////////////////////////////////////////////////////

- (void)setup_fade_timer
{
    float const timer_interval = 1 / 60.0f;

    [self clear_timers];

    fade_timer = [NSTimer timerWithTimeInterval:timer_interval
                                         target:self
                                       selector:@selector(on_fade_timer)
                                       userInfo:nil
                                        repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:fade_timer forMode:NSRunLoopCommonModes];
    fade_started_at_ns = clock_gettime_nsec_np(CLOCK_MONOTONIC);
}

//////////////////////////////////////////////////////////////////////

- (void)clear_timers
{
    if (wait_timer) {
        [wait_timer invalidate];
        wait_timer = nil;
    }
    if (fade_timer) {
        [fade_timer invalidate];
        fade_timer = nil;
    }
}

//////////////////////////////////////////////////////////////////////

- (void)do_fadeout:(int)index
{
    [self clear_timers];

    wait_timer = [NSTimer timerWithTimeInterval:1.5f
                                         target:self
                                       selector:@selector(setup_fade_timer)
                                       userInfo:nil
                                        repeats:NO];
    [[NSRunLoop currentRunLoop] addTimer:wait_timer forMode:NSRunLoopCommonModes];
    [self setCanHide:NO];
    [self setIsVisible:YES];
    [self setAlphaValue:show_alpha];
}

@end
