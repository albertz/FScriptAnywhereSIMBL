//
//  FSAWindowManager.h
//  F-Script Anywhere
//
//  Created by Nicholas Riley on Mon Sep 30 2002.
//  Copyright (c) 2002 Nicholas Riley. All rights reserved.
//

#import <AppKit/AppKit.h>

@interface FSAWindowManager : NSObject {
    NSMenu *menu;
    NSMutableDictionary *records;
    NSMenuItem *separator, *label;
}

+ (FSAWindowManager *)sharedManager;

- (void)setWindowMenu:(NSMenu *)windowMenu;

- (void)registerWindow:(NSWindow *)window;
- (void)registerSubordinateWindow:(NSWindow *)subWindow forWindow:(NSWindow *)window;
- (BOOL)windowIsRegistered:(NSWindow *)window;

@end
