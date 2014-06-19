//
//  UIDeviceHardware.m
//
//  Used to determine EXACT version of device software is running on.

#import "UIDeviceHardware.h"
#include <sys/types.h>
#include <sys/sysctl.h>

@implementation UIDeviceHardware

+ (NSString *) platform{
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char *machine = malloc(size);
    sysctlbyname("hw.machine", machine, &size, NULL, 0);
    NSString *platform = [NSString stringWithUTF8String:machine];
    free(machine);
    return platform;
}

@end