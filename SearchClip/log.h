#pragma once

//////////////////////////////////////////////////////////////////////

#if defined(__cplusplus)
extern "C" {
#endif

//////////////////////////////////////////////////////////////////////

#ifdef DEBUG

void emit_log_message(char const *tag, NSString *format, ...);

#define LOG_CONTEXT(x) static char const *__LOG_TAG=x
#define LOG(...) emit_log_message(__LOG_TAG, __VA_ARGS__)

#else

#define LOG_CONTEXT(...)
#define LOG(...)

#endif

//////////////////////////////////////////////////////////////////////

#if defined(__cplusplus)
}
#endif
