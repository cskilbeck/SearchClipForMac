#import <AVFoundation/AVFoundation.h>

#include "log.h"

//////////////////////////////////////////////////////////////////////

namespace
{
NSString *log_format = [[NSString alloc] initWithUTF8String:"%-16s %@\n"];
}

//////////////////////////////////////////////////////////////////////

extern "C" void emit_log_message(char const *tag, NSString *format, ...)
{
    va_list args;
    va_start(args, format);
    NSString *formattedString = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    NSString *log_string = [[NSString alloc] initWithFormat:log_format, tag, formattedString];
    [[NSFileHandle fileHandleWithStandardOutput] writeData:[log_string dataUsingEncoding:NSNEXTSTEPStringEncoding]];
}
