#import <AVFoundation/AVFoundation.h>
#import <ApplicationServices/ApplicationServices.h>
#import <Foundation/Foundation.h>

#import "AppDelegate.h"

#include <mutex>
#include <vector>
#include <map>

#include "log.h"
#include "audio.h"
#include "mic_status.h"

LOG_CONTEXT("audio");

//////////////////////////////////////////////////////////////////////

#define CHK(x)                                             \
    {                                                      \
        OSStatus result = (x);                             \
        if (result != noErr) {                             \
            LOG(@ #x " failed: %@", four_cc(result)); \
            return result;                                 \
        }                                                  \
    }

//////////////////////////////////////////////////////////////////////

namespace
{

#if DEBUG

NSString *four_cc(OSStatus x)
{
    char v[5];
    for (int i = 0; i < 4; ++i) {
        int c = (x >> (i * 8)) & 0xff;
        if (c < ' ' || c > 127) {
            c = '.';
        }
        v[3 - i] = c;
    }
    v[4] = 0;
    return [NSString stringWithUTF8String:v];
}

#endif

//////////////////////////////////////////////////////////////////////

OSStatus get_device_name(uint32 device_id, NSString **name)
{
    constexpr AudioObjectPropertyAddress propName = {
        .mSelector = kAudioDevicePropertyDeviceNameCFString, //
        .mScope = kAudioDevicePropertyScopeInput,            //
        .mElement = kAudioObjectPropertyElementWildcard      //
    };
    CFStringRef device_name;
    uint32 ptr_size = 8;

    CHK(AudioObjectGetPropertyData(device_id, &propName, 0, NULL, &ptr_size, &device_name));
    *name = (__bridge NSString *)device_name;
    return noErr;
}

//////////////////////////////////////////////////////////////////////

OSStatus get_mute(uint32 device_id, bool *current_mute_status)
{
    constexpr AudioObjectPropertyAddress mute_addr = {
        .mSelector = kAudioDevicePropertyMute,    //
        .mScope = kAudioDevicePropertyScopeInput, //
        .mElement = 0                             //
    };

    uint32 mute;
    uint32 mute_size = sizeof(mute);

    CHK(AudioObjectGetPropertyData(device_id, &mute_addr, 0, NULL, &mute_size, &mute));
    *current_mute_status = mute != 0;
    return noErr;
}

//////////////////////////////////////////////////////////////////////

OSStatus set_mute(uint32 device_id, bool mute)
{
    constexpr AudioObjectPropertyAddress mute_addr = {
        .mSelector = kAudioDevicePropertyMute,    //
        .mScope = kAudioDevicePropertyScopeInput, //
        .mElement = 0                             //
    };

    uint32 mute_set = mute ? 1 : 0;
    CHK(AudioObjectSetPropertyData(device_id, &mute_addr, 0, NULL, sizeof(mute_set), &mute_set));
    return noErr;
}

//////////////////////////////////////////////////////////////////////

OSStatus get_volume(uint32 device_id, uint32 const channel, float *cur_vol)
{
    AudioObjectPropertyAddress const volume_addr = {
        .mSelector = kAudioDevicePropertyVolumeScalar, //
        .mScope = kAudioDevicePropertyScopeInput,      //
        .mElement = channel                            //
    };

    float volume = 0;
    uint32 size_volume = sizeof(volume);
    CHK(AudioObjectGetPropertyData(device_id, &volume_addr, 0, NULL, &size_volume, &volume));
    *cur_vol = volume;
    return noErr;
}

//////////////////////////////////////////////////////////////////////

OSStatus set_volume(uint32 device_id, uint32 element, float volume)
{
    AudioObjectPropertyAddress volume_addr = {
        .mSelector = kAudioDevicePropertyVolumeScalar, //
        .mScope = kAudioDevicePropertyScopeInput,      //
        .mElement = element                            //
    };

    CHK(AudioObjectSetPropertyData(device_id, &volume_addr, 0, NULL, sizeof(volume), &volume));
    return noErr;
}

//////////////////////////////////////////////////////////////////////

OSStatus get_uid(uint32 device_id, CFStringRef *uid)
{
    AudioObjectPropertyAddress uid_addr = {
        .mSelector = kAudioDevicePropertyDeviceUID,   //
        .mScope = kAudioObjectPropertyScopeGlobal,    //
        .mElement = kAudioObjectPropertyElementMaster //
    };
    CFStringRef local_uid;
    uint32 uid_size = sizeof(local_uid);

    CHK(AudioObjectGetPropertyData(device_id, &uid_addr, 0, NULL, &uid_size, &local_uid));
    *uid = local_uid;
    return noErr;
}

//////////////////////////////////////////////////////////////////////

OSStatus is_input_device(AudioObjectID deviceID, bool &is_input)
{
    AudioObjectPropertyAddress propertyAddress = {
        .mSelector = kAudioDevicePropertyStreamConfiguration, //
        .mScope = kAudioObjectPropertyScopeInput,             //
        .mElement = kAudioObjectPropertyElementWildcard       //
    };

    uint32 size = 0;
    CHK(AudioObjectGetPropertyDataSize(deviceID, &propertyAddress, 0, NULL, &size));

    std::vector<Byte> buffer(size);
    auto buffer_list = reinterpret_cast<AudioBufferList *>(buffer.data());

    CHK(AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, NULL, &size, buffer_list));

    is_input = buffer_list->mNumberBuffers > 0;

    return noErr;
}

//////////////////////////////////////////////////////////////////////

std::mutex device_list_mutex;

//////////////////////////////////////////////////////////////////////

struct audio_device {

    uint32 device_id{0};
    CFStringRef device_uid;
    NSString *name;

    bool device_is_present{false};

    // does it have a master mute switch? If so, just use that
    bool can_mute{false};

    // if has_master_volume, current_volumes[0] and original_volumes[0] are valid
    bool has_master_volume{false};

    float original_master_volume{0};

    int num_channel_volumes{0};

    // channel volumes
    std::vector<float> original_channel_volumes;

    //////////////////////////////////////////////////////////////////////
    // is this device muted?
    // if it can be muted and is muted AND
    // if it has a master volume which is not zero AND
    // if all the channel volumes (if any) are not zero
    // then it's muted

    bool is_muted()
    {
        bool really_muted = true;
        if (can_mute) {
            bool muted;
            get_mute(device_id, &muted);
            really_muted &= muted;
        }
        if (has_master_volume) {
            float vol;
            get_volume(device_id, 0, &vol);
            really_muted &= vol == 0;
        }
        for (size_t i = 0; i < num_channel_volumes; ++i) {
            float vol;
            get_volume(device_id, (int)i + 1, &vol);
            really_muted &= vol == 0;
        }
        return really_muted;
    }

    //////////////////////////////////////////////////////////////////////

    OSStatus on_change(AudioObjectID inObjectID, uint32 inNumberAddresses,
                       const AudioObjectPropertyAddress *inAddresses)
    {
        //        LOG(@"%@:%@", name, four_cc(inAddresses[0].mSelector));
        //        float vol;
        //        bool mute;
        //        switch (inAddresses[0].mSelector) {
        //        case 'volm':
        //            get_volume(device_id, inAddresses[0].mElement, &vol);
        //            LOG(@"New vol: %f", vol);
        //            break;
        //        case 'mute':
        //            get_mute(device_id, &mute);
        //            LOG(@"New mute: %d", mute);
        //            break;
        //        }
        dispatch_async(dispatch_get_main_queue(), ^{
          AppDelegate *d = (AppDelegate *)[[NSApplication sharedApplication] delegate];
          [d audio_changed];
        });
        return 0;
    }

    //////////////////////////////////////////////////////////////////////

    static OSStatus on_property_changed(AudioObjectID inObjectID, uint32 inNumberAddresses,
                                        const AudioObjectPropertyAddress *inAddresses, void *__nullable inClientData)
    {
        audio_device *d = reinterpret_cast<audio_device *>(inClientData);
        // assert(d != nullptr);
        return d->on_change(inObjectID, inNumberAddresses, inAddresses);
    }

    //////////////////////////////////////////////////////////////////////

    OSStatus mute()
    {
        LOG(@"Muting %@", name);
        if (can_mute) {
            LOG(@"  mute");
            CHK(set_mute(device_id, true));
        }
        if (has_master_volume) {
            LOG(@"  master volume -> 0");
            CHK(set_volume(device_id, 0, 0.0f));
        }
        for (int i = 0; i < num_channel_volumes; ++i) {
            LOG(@"  volume channel %d -> 0", i + 1);
            CHK(set_volume(device_id, i + 1, 0.0f));
        }
        return noErr;
    }

    //////////////////////////////////////////////////////////////////////

    OSStatus unmute()
    {
        LOG(@"Unmuting %@", name);
        if (can_mute) {
            LOG(@"  unmute");
            CHK(set_mute(device_id, false));
        }
        if (has_master_volume) {
            LOG(@"  master volume -> %f", original_master_volume);
            CHK(set_volume(device_id, 0, original_master_volume));
        }
        for (int i = 0; i < num_channel_volumes; ++i) {
            LOG(@"  channel %d volume -> %f", i + 1, original_channel_volumes[i]);
            CHK(set_volume(device_id, i + 1, original_channel_volumes[i]));
        }
        return noErr;
    }

    //////////////////////////////////////////////////////////////////////

    OSStatus init(uint32 audio_id)
    {
        device_id = audio_id;

        // temp for ARC gymnastics
        NSString *device_name;

        CHK(get_device_name(device_id, &device_name));

        name = device_name;

        CFStringRef uid;

        CHK(get_uid(device_id, &uid));

        device_uid = uid;

        LOG(@"INIT %@ (%@)", name, device_uid);

        // ***** is there a mute control? *****

        constexpr AudioObjectPropertyAddress mute_addr = {
            .mSelector = kAudioDevicePropertyMute, .mScope = kAudioDevicePropertyScopeInput, .mElement = 0};

        can_mute = false;

        if (AudioObjectHasProperty(device_id, &mute_addr)) {

            Boolean can_mute_be_set;

            CHK(AudioObjectIsPropertySettable(device_id, &mute_addr, &can_mute_be_set));

            can_mute = can_mute_be_set;

            if (can_mute) {
                LOG(@"  Has mute control");
            }
        }

        // ***** ok, is there a master volume control? *****

        AudioObjectPropertyAddress volume_addr = {
            .mSelector = kAudioDevicePropertyVolumeScalar, .mScope = kAudioDevicePropertyScopeInput, .mElement = 0};

        float volume = 0;

        uint32 size_volume = sizeof(volume);

        if (AudioObjectHasProperty(device_id, &volume_addr)) {

            Boolean can_vol_be_set;

            CHK(AudioObjectIsPropertySettable(device_id, &volume_addr, &can_vol_be_set));

            if (can_vol_be_set) {

                has_master_volume = true;
                LOG(@"  Has master volume");
            }
        }

        // ***** well are there individual channel volume controls at least? *****

        constexpr AudioObjectPropertyAddress chan_addr = {.mSelector = kAudioDevicePropertyPreferredChannelLayout,
                                                          .mScope = kAudioDevicePropertyScopeInput,
                                                          .mElement = kAudioObjectPropertyElementWildcard};

        uint32 channels_size;

        OSStatus result = AudioObjectGetPropertyDataSize(device_id, &chan_addr, 0, NULL, &channels_size);

        if (result != kAudioHardwareNoError) {
            LOG(@"Error getting preferred channel layout: %@", four_cc(result));
        } else {

            std::vector<Byte> buffer(channels_size);
            auto layout = reinterpret_cast<AudioChannelLayout *>(buffer.data());

            CHK(AudioObjectGetPropertyData(device_id, &chan_addr, 0, NULL, &channels_size, layout));

            LOG(@"  Has %d channel(s)", layout->mNumberChannelDescriptions);

            num_channel_volumes = 0;
            original_channel_volumes.resize(layout->mNumberChannelDescriptions);

            for (int i = 0; i < layout->mNumberChannelDescriptions; ++i) {

                AudioChannelDescription *d = layout->mChannelDescriptions + i;

                volume_addr.mElement = i + 1;

                if (AudioObjectHasProperty(device_id, &volume_addr)) {

                    Boolean channel_can_be_set;

                    CHK(AudioObjectIsPropertySettable(device_id, &volume_addr, &channel_can_be_set));

                    if (channel_can_be_set) {

                        num_channel_volumes = i + 1;

                        LOG(@"    Channel %d has volume control", i + 1);
                    }
                }
            }
        }

        if (can_mute) {
            CHK(AudioObjectAddPropertyListener(device_id, &mute_addr, on_property_changed, this));
        }
        if (has_master_volume) {
            volume_addr.mElement = 0;
            CHK(AudioObjectAddPropertyListener(device_id, &volume_addr, on_property_changed, this));
        }
        for (int i = 0; i < num_channel_volumes; ++i) {
            volume_addr.mElement = i + 1;
            CHK(AudioObjectAddPropertyListener(device_id, &volume_addr, on_property_changed, this));
        }
        device_is_present = true;
        return noErr;
    }

    //////////////////////////////////////////////////////////////////////

    OSStatus snapshot_volume()
    {
        if (has_master_volume) {
            CHK(get_volume(device_id, 0, &original_master_volume));
            if (original_master_volume == 0) {
                original_master_volume = 0.25f;
            }
        }
        for (int i = 0; i < num_channel_volumes; ++i) {
            CHK(get_volume(device_id, i + 1, &original_channel_volumes[i]));
            if (original_channel_volumes[i] == 0) {
                original_channel_volumes[i] = 0.25f;
            }
        }
        return noErr;
    }

    //////////////////////////////////////////////////////////////////////

    OSStatus cleanup()
    {
        if (can_mute) {

            constexpr AudioObjectPropertyAddress mute_addr = {
                .mSelector = kAudioDevicePropertyMute, .mScope = kAudioDevicePropertyScopeInput, .mElement = 0};

            CHK(AudioObjectRemovePropertyListener(device_id, &mute_addr, on_property_changed, this));
        }

        AudioObjectPropertyAddress volume_addr = {
            .mSelector = kAudioDevicePropertyVolumeScalar, .mScope = kAudioDevicePropertyScopeInput, .mElement = 0};

        if (has_master_volume) {

            CHK(AudioObjectRemovePropertyListener(device_id, &volume_addr, on_property_changed, this));
        }
        for (int i = 0; i < num_channel_volumes; ++i) {
            volume_addr.mElement = i + 1;
            CHK(AudioObjectRemovePropertyListener(device_id, &volume_addr, on_property_changed, this));
        }
        return noErr;
    }

    //////////////////////////////////////////////////////////////////////

    void debug_dump()
    {
        LOG(@"----------------------------------------");
        LOG(@"DEVICE %@ (%@)", name, device_uid);
        LOG(@"Can mute: %d", can_mute);
        LOG(@"Has master volume: %d", has_master_volume);
        LOG(@"# channels: %d", num_channel_volumes);
        if (can_mute) {
            bool muted;
            get_mute(device_id, &muted);
            LOG(@"Current mute status: %d", muted);
        }
        if (has_master_volume) {
            float master_vol;
            get_volume(device_id, 0, &master_vol);
            LOG(@"Current master volume: %f", master_vol);
        }
        for (int i = 0; i < num_channel_volumes; ++i) {
            float vol;
            get_volume(device_id, i + 1, &vol);
            LOG(@"Channel %d volume: %f", i, vol);
        }
    }
};

//////////////////////////////////////////////////////////////////////

std::map<uint32, audio_device *> audio_devices;

//////////////////////////////////////////////////////////////////////

static OSStatus device_listener(AudioObjectID inObjectID, uint32 inNumberAddresses,
                                const AudioObjectPropertyAddress *inAddresses, void *__nullable inClientData)
{
    LOG(@"DEVICE LIST CHANGED! (%d notifications)", inNumberAddresses);
    dispatch_async(dispatch_get_main_queue(), ^{
      AppDelegate *d = (AppDelegate *)[[NSApplication sharedApplication] delegate];
      [d audio_changed];
    });
    return noErr;
}

//////////////////////////////////////////////////////////////////////

bool audio_is_muted()
{
    for (auto &kv : audio_devices) {
        if (!kv.second->is_muted()) {
            return false;
        }
    }
    return true;
}

//////////////////////////////////////////////////////////////////////

} // namespace

//////////////////////////////////////////////////////////////////////

OSStatus audio_init()
{
    LOG(@"audio_init");

    audio_cleanup();

    AudioObjectPropertyAddress listener_addr = {.mSelector = kAudioHardwarePropertyDevices,
                                                .mScope = kAudioObjectPropertyScopeGlobal,
                                                .mElement = kAudioObjectPropertyElementMaster};

    CHK(AudioObjectAddPropertyListener(kAudioObjectSystemObject, &listener_addr, device_listener, nullptr));

    CHK(audio_scan_devices(true));

    return noErr;
}

//////////////////////////////////////////////////////////////////////

OSStatus audio_scan_devices(bool scan_volumes)
{
    std::lock_guard<std::mutex> lock(device_list_mutex);

    // get list of devices

    AudioObjectPropertyAddress addr = {.mSelector = kAudioHardwarePropertyDevices,
                                       .mScope = kAudioObjectPropertyScopeGlobal,
                                       .mElement = kAudioObjectPropertyElementWildcard};

    uint32 size = 0;
    CHK(AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &addr, 0, NULL, &size));

    int num_devices = size / sizeof(AudioObjectID);

    std::vector<AudioObjectID> audio_device_list(num_devices);

    CHK(AudioObjectGetPropertyData(kAudioObjectSystemObject, &addr, 0, NULL, &size, audio_device_list.data()));

    // all devices on probation

    for (auto &kv : audio_devices) {
        kv.second->device_is_present = false;
    }

    // scan for input devices, add new ones to the map

    for (int i = 0; i < num_devices; i++) {

        AudioObjectID &device_id = audio_device_list[i];

        bool is_input;

        CHK(is_input_device(device_id, is_input));

        if (is_input) {

            audio_device *device = nullptr;

            if (audio_devices.find(device_id) == audio_devices.end()) {

                device = new audio_device();

                if (device->init(device_id) == noErr) {
                    audio_devices[device_id] = device;
                    device->snapshot_volume();
                    LOG(@"  Is new device");
                } else {
                    LOG(@"  ERROR SCANNING DEVICE %d", device_id);
                    delete device;
                    device = nullptr;
                }
            } else {

                device = audio_devices[device_id];
                LOG(@"%@ is still plugged in", device->name);
                device->device_is_present = true;
                if (scan_volumes) {
                    device->snapshot_volume();
                }
            }
        }
    }

    // prune disconnected devices

    for (auto it = begin(audio_devices); it != end(audio_devices);) {
        if (!it->second->device_is_present) {
            LOG(@"DEVICE %@ removed (ID was %d)", it->second->name, it->first);
            it = audio_devices.erase(it);
        } else {
            ++it;
        }
    }
    return noErr;
}

//////////////////////////////////////////////////////////////////////

void audio_cleanup()
{
    std::lock_guard<std::mutex> lock(device_list_mutex);

    for (auto &kv : audio_devices) {
        kv.second->cleanup();
        delete kv.second;
    }
    audio_devices.clear();
}

//////////////////////////////////////////////////////////////////////

int audio_get_mute_status(void)
{
    if (audio_devices.empty()) {
        return mic_status_disconnected;
    }
    if (audio_is_muted()) {
        return mic_status_muted;
    }
    return mic_status_normal;
}

//////////////////////////////////////////////////////////////////////
// if any devices are not muted, mute them all else unmute them all

void audio_toggle_mute()
{
    bool all_muted = audio_is_muted();

    LOG(@"Before toggle, all muted = %d", all_muted);

    for (auto &kv : audio_devices) {
        audio_device *d = kv.second;
        if (all_muted) {
            d->unmute();
        } else {
            d->mute();
        }
    }
}

//////////////////////////////////////////////////////////////////////

void audio_debug_dump()
{
    LOG(@"AUDIO DEBUG DUMP");

    for (auto &kv : audio_devices) {
        kv.second->debug_dump();
    }
}
