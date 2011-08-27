//
//  FSAWindowManager.m
//  F-Script Anywhere
//
//  Created by Nicholas Riley on Mon Sep 30 2002.
//  Copyright (c) 2002 Nicholas Riley. All rights reserved.
//

#import "FSAWindowManager.h"
#import "FSAnywhere.h"

@interface FSAWindowRecord:NSObject
{
    unsigned level;
    NSWindow *window;
    BOOL windowClosed;
    FSAWindowRecord *parent;
    NSMutableArray *subordinates;
    NSMenuItem *menuItem;
}
- (id)initWithWindow:(NSWindow *)aWindow parent:(FSAWindowRecord *)aRecord;
- (void)addSubordinate:(FSAWindowRecord *)aRecord;
- (void)removeSubordinate:(FSAWindowRecord *)aRecord;
- (BOOL)hasSubordinates;
- (unsigned)level;
- (NSString *)levelPaddedTitle;
- (NSMenuItem *)menuItem;
- (NSWindow *)window;
@end

@implementation FSAWindowRecord

- (id)initWithWindow:(NSWindow *)aWindow parent:(FSAWindowRecord *)aRecord;
{
    if ( (self = [super init]) != nil) {
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        window = [aWindow retain];
        [nc addObserver: self selector: @selector(windowWillClose:)
                   name: NSWindowWillCloseNotification object: window];
        [nc addObserver: self selector: @selector(windowDidBecomeKey:)
                   name: NSWindowDidBecomeKeyNotification object: window];
        [nc addObserver: self selector: @selector(windowDidResignKey:)
                   name: NSWindowDidResignKeyNotification object: window];
        if (aRecord == nil) {
            level = 1;
        } else {
            parent = aRecord; // note: not retaining parent
            [parent addSubordinate: self];
            level = [parent level] + 1;
        }
        [self retain]; // manage own object lifetime, tie to window lifetime
    }
    return self;
}

- (void)dealloc;
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];
    [[menuItem menu] removeItem: menuItem];
    [menuItem release]; menuItem = nil;
    [window release]; window = nil;
    parent = nil;
    NSAssert1(![self hasSubordinates], @"Window still has subordinates at dealloc: %@", self);
    [subordinates release]; subordinates = nil;
    // XXX still get this from time to time, canÕt reproduce reliably... please let me know if you can!
    NSAssert1(windowClosed, @"Window hasn't closed at dealloc: %@", self);
    [super dealloc];
}

- (unsigned)level;
{
    return level;
}

- (NSWindow *)window;
{
    return window;
}

- (void)addSubordinate:(FSAWindowRecord *)aRecord;
{
    if (subordinates == nil)
        subordinates = [[NSMutableArray alloc] init];
    NSAssert(![subordinates containsObject: aRecord], @"subordinate already exists");
    [subordinates addObject: aRecord];
}

- (BOOL)hasSubordinates;
{
    return (subordinates != nil && [subordinates count] > 0);
}

- (void)removeSubordinate:(FSAWindowRecord *)aRecord;
{
    NSAssert(subordinates != nil && [subordinates containsObject: aRecord], @"subordinate does not exist");
    [subordinates removeObject: aRecord];
    if ([subordinates count] == 0 && windowClosed)
        [self release];
}

- (NSString *)levelPaddedTitle;
{
    NSString *windowTitle = [window title];
    NSMutableString *paddedTitle = [[NSMutableString alloc] initWithCapacity: [windowTitle length] + 3 * level + 2 * windowClosed];
    unsigned i;
    for (i = 0 ; i < level ; i++) {
        [paddedTitle appendString: @"   "];
    }
    if (windowClosed) [paddedTitle appendString: @"("];
    [paddedTitle appendString: windowTitle];
    if (windowClosed) [paddedTitle appendString: @")"];
    return [paddedTitle autorelease];
}

- (NSMenuItem *)menuItem;
{
    if (menuItem == nil) {
        menuItem = [[NSMenuItem alloc] initWithTitle: [self levelPaddedTitle]
                                              action: @selector(makeKeyAndOrderFront:)
                                       keyEquivalent: @""];
        [menuItem setTarget: window];
        [menuItem setRepresentedObject: window];
        [menuItem setState: NSOnState];
    }
    return menuItem;
}

- (NSString *)description;
{
    return [NSString stringWithFormat: @"%@ [L%u] for %@%@ subs %u%@%@", [super description], level, window, windowClosed ? @" (closed)" : @"", [subordinates count], menuItem == nil ? @"" : [NSString stringWithFormat: @" item %@", menuItem], parent == nil ? @"" : [NSString stringWithFormat: @"\n  parent: %@", parent]];
}

@end

@implementation FSAWindowRecord (NSWindowNotifications)

- (void)windowWillClose:(NSNotification *)notification;
{
    windowClosed = YES;

    [parent removeSubordinate: self];

    FSALog(@"windowWillClose (rc %u): %@", [self retainCount], notification);
    if ([self hasSubordinates]) {
        [menuItem setTitle: [self levelPaddedTitle]];
    } else {
        [self release];
    }
}

- (void)windowDidBecomeKey:(NSNotification *)notification;
{
    if (windowClosed) {
        windowClosed = NO;
        [menuItem setTitle: [self levelPaddedTitle]];
        [parent addSubordinate: self];
    }
    [menuItem setState: NSOnState];
}

- (void)windowDidResignKey:(NSNotification *)notification;
{
    [menuItem setState: NSOffState];
}

@end

static FSAWindowManager *FSASharedWindowManager;

@implementation FSAWindowManager

+ (FSAWindowManager *)sharedManager;
{
    if (FSASharedWindowManager == nil) {
        FSASharedWindowManager = [[self alloc] init];
    }
    return FSASharedWindowManager;
}

- (id)init;
{
    if ( (self = [super init]) != nil) {
        if (FSASharedWindowManager != nil) {
            [self release];
            self = nil;
        } else {
            records = [[NSMutableDictionary alloc] init];
        }
    }
    return self;
}

- (void)setWindowMenu:(NSMenu *)windowMenu;
{
    menu = [windowMenu retain];
}

- (FSAWindowRecord *)recordForWindow:(NSWindow *)window;
{
    FSAWindowRecord *record = [records objectForKey: [NSValue valueWithNonretainedObject: window]];
    NSAssert1(record != nil, @"no record for window %@", window);
    return record;
}

- (void)addRecord:(FSAWindowRecord *)aRecord;
{
    NSWindow *window = [aRecord window];
    NSValue *wValue = [NSValue valueWithNonretainedObject: window];
    [[NSNotificationCenter defaultCenter]
        addObserver: self selector: @selector(windowWillClose:)
               name: NSWindowWillCloseNotification object: window];
    NSAssert1(![self windowIsRegistered: window], @"Window already registered: %@", window);
    [records setObject: aRecord forKey: wValue];
    if ([records count] == 1) {
        separator = [NSMenuItem separatorItem];
        [menu addItem: separator];
        label = [menu addItemWithTitle: @"Windows" action: NULL keyEquivalent: @""];
    }
    FSALog(@"Registered:\n%@", aRecord);
}

- (void)registerWindow:(NSWindow *)window;
{
    FSAWindowRecord *record = [[FSAWindowRecord alloc] initWithWindow: window parent: nil];
    [self addRecord: record];
    [menu addItem: [record menuItem]];
    [record release];
}

- (void)registerSubordinateWindow:(NSWindow *)subWindow forWindow:(NSWindow *)window;
{
    FSAWindowRecord *record = [[FSAWindowRecord alloc] initWithWindow: subWindow parent:
        [self recordForWindow: window]];
    int itemIndex = [menu indexOfItemWithRepresentedObject: window];

    NSAssert1(itemIndex != -1, @"CanÕt get menu item for window %@", window);
    [self addRecord: record];
    [menu insertItem: [record menuItem] atIndex: itemIndex + 1];
    [record release];
}

- (BOOL)windowIsRegistered:(NSWindow *)window;
{
    return [records objectForKey: [NSValue valueWithNonretainedObject: window]] != nil;
}

@end

@interface FSAWindowManager (Private)
- (FSAWindowRecord *)recordForWindow:(NSWindow *)window;
@end

@implementation FSAWindowManager (NSWindowNotifications)

- (void)windowWillClose:(NSNotification *)notification;
{
    NSWindow *window = [notification object];
    FSAWindowRecord *record = [self recordForWindow: window];

    if ([record hasSubordinates]) return;
    [records removeObjectForKey: [NSValue valueWithNonretainedObject: window]];
    if ([records count] == 0) {
        [menu removeItem: separator];
        [menu removeItem: label];
        separator = nil;
    }
    [[NSNotificationCenter defaultCenter]
        removeObserver: self name: NSWindowWillCloseNotification object: window];
}

@end