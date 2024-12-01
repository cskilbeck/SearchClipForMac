//////////////////////////////////////////////////////////////////////

#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <ApplicationServices/ApplicationServices.h>
#import "image.h"

#include "log.h"
#include "lunasvg/include/lunasvg.h"
#include "mic_status.h"

LOG_CONTEXT("image");

#include "Image/microphone_disconnected_svg.h"
#include "Image/microphone_mute_svg.h"
#include "Image/microphone_normal_svg.h"

#include "Image/microphone_disconnected_small_svg.h"
#include "Image/microphone_mute_small_svg.h"
#include "Image/microphone_normal_small_svg.h"

#include "Image/search_svg.h"

//////////////////////////////////////////////////////////////////////

// clang-format off

char const **microphone_svgs[mic_num_statuses] =
{
    &microphone_mute_svg,
    &microphone_normal_svg,
    &microphone_disconnected_svg
};

char const **microphone_small_svgs[mic_num_statuses] =
{
    &microphone_mute_small_svg,
    &microphone_normal_small_svg,
    &microphone_disconnected_small_svg
};

// clang-format on

//////////////////////////////////////////////////////////////////////

void done_callback(void *info, const void *data, size_t size)
{
    free((void *)data);
    LOG(@"Done!");
}

//////////////////////////////////////////////////////////////////////

static NSImage *svg_to_image(char const *svg, int size)
{
    auto doc = lunasvg::Document::loadFromData(svg);
    if (doc.get() == nullptr) {
        return nullptr;
    }

    auto bmp = doc->renderToBitmap(size, size);
    if (!bmp.valid()) {
        return nullptr;
    }

    UInt32 bmp_size = size * size * 4;
    UInt32 *f = (UInt32 *)malloc(bmp_size);
    memcpy(f, bmp.data(), bmp_size);
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, f, bmp_size, done_callback);
    CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = kCGImageAlphaPremultipliedFirst | kCGImageByteOrder32Little;
    CGImageRef cg_img = CGImageCreate(size, size, 8, 32, 4 * size, colorSpaceRef, bitmapInfo, provider, NULL, NO,
                                      kCGRenderingIntentDefault);
    CGDataProviderRelease(provider);
    NSImage *ns_img = [[NSImage alloc] initWithCGImage:cg_img size:NSMakeSize(size, size)];
    CGImageRelease(cg_img);
    return ns_img;
}

//////////////////////////////////////////////////////////////////////

extern "C" NSImage *get_image_for_mic_status(int status, int size)
{
    if (status < 0 || status >= mic_num_statuses) {
        return nullptr;
    }
    return svg_to_image(*microphone_svgs[status], size);
}

//////////////////////////////////////////////////////////////////////

extern "C" NSImage *get_small_image_for_mic_status(int status, int size)
{
    if (status < 0 || status >= mic_num_statuses) {
        return nullptr;
    }
    return svg_to_image(*microphone_small_svgs[status], size);
}
