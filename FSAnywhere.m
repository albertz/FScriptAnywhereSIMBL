//
//  FSAnywhere.m
//  F-Script Anywhere
//
//  Created by Nicholas Riley on Sat Feb 02 2002.
//  Copyright (c) 2002 Nicholas Riley. All rights reserved.
//

#import "FSAnywhere.h"

// wish we could #define out completely, but it seems impossible to use varargs #defines on OS X's cpp

void FSALog(NSString *fmt, ...) {
#if FSA_DEBUG
    va_list ap;
    va_start(ap, fmt);
    NSLogv([NSString stringWithFormat: @"F-Script Anywhere: %@", fmt], ap);
#endif
}

// XXX put this in a .strings file instead
NSString * FSA_FScriptURL = @"http://www.fscript.org/";