//
//  FSAViewAssociationController.m
//  F-Script Anywhere
//
//  Created by Nicholas Riley on Wed Jul 17 2002.
//  Copyright (c) 2002 Nicholas Riley. All rights reserved.
//

/*

 F-Script Anywhere is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 2 of the License, or
 (at your option) any later version.

 F-Script Anywhere is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with F-Script Anywhere; if not, write to the Free Software
 Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

*/

#import "FSAViewAssociationController.h"
#import "FSAController.h"
#import "FSAWindowManager.h"
#import "FSAnywhere.h"
#import <FScript/FSInterpreter.h>
#import <FScript/System.h>

// XXX workaround for lack of identifier validation; should go away when F-Script adds (promised) direct support for this
@interface Compiler
+ (BOOL)isValidIdentifier:(NSString *)str;
@end

@implementation FSAViewAssociationController

- (id)initWithFSAController:(FSAController *)fsa;
{
    self = [super initWithWindowNibName: @"FSAViewAssociationPanel"];

    if (self != nil) {
        NSImage *bullseyeImage = [[NSImage alloc] initByReferencingFile: [[NSBundle bundleForClass: [self class]] pathForResource: @"Bullseye menu cursor" ofType: @"tiff"]];
        NSString *label = [fsa interpreterLabel];
        
        interpreter = [[[fsa interpreterView] interpreter] retain];
        system = [fsa system];
        [[self window] setResizeIncrements: NSMakeSize(1, 12)];
        if (label != nil) [[self window] setTitle: [NSString stringWithFormat: @"%@: %@", [[self window] title], label]];
        bullseyeCursor = [[NSCursor alloc] initWithImage: bullseyeImage hotSpot: NSMakePoint(6, 7)];
        [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(controlTextDidChange:) name: NSControlTextDidChangeNotification object: variableNameField];
        [[captureButton cell] setShowsStateBy: NSContentsCellMask | NSChangeGrayCellMask];
        [captureButton setState: NSOffState];
        [self update: nil];
    }
    return self;
}

- (void)dealloc;
{
    [viewHierarchyMenu release];
    [selectedElement release];
    [interpreter release];
    [bullseyeCursor release];
    [[NSNotificationCenter defaultCenter] removeObserver: self];
    [super dealloc];
}

- (IBAction)update:(id)sender;
{
    NSString *variableName = [variableNameField stringValue];
    BOOL canAssignToVariable = NO;
    [browseButton setEnabled: selectedElement != nil];
    [statusField setStringValue: @""];
    if ([variableName length] != 0) {
        if (![Compiler isValidIdentifier: variableName]) {
            [statusField setStringValue: @"Invalid name: contains spaces, punctuation or non-ASCII characters"];
        } else if (selectedElement != nil) {
            [statusField setStringValue: @"Click ÒAssociateÓ to assign to this variable"];
            canAssignToVariable = YES;
        }
    }
    [associateButton setEnabled: canAssignToVariable];
    [variableNameField setEnabled: [captureButton state] == NSOffState];
}

- (void)stopCapturingVoluntarily:(BOOL)voluntary;
{
    FSALog(@"stopping capture");
    [[NSNotificationCenter defaultCenter] removeObserver: self name: NSMenuWillSendActionNotification object: nil];
    [captureButton setState: NSOffState];
    [self update: nil];
    if (voluntary) {
        FSALog(@"voluntary!");
        [[self window] makeKeyAndOrderFront: self];
        [bullseyeCursor pop];
        [variableNameField becomeFirstResponder];        
    }
}

- (void)_addElement:(id)element withLabel:(NSString *)label toSubmenuForItem:(NSMenuItem *)item;
{
    NSMenu *submenu = [item submenu];
    NSMenuItem *subItem;
    if (submenu == nil) {
        id superElement = [item representedObject];
        submenu = [[NSMenu alloc] initWithTitle: @""];
        subItem = [submenu addItemWithTitle: NSStringFromClass([superElement class])
                                     action: @selector(elementSelected:)
                              keyEquivalent: @""];
        [subItem setTarget: self];
        [subItem setRepresentedObject: superElement];
        [item setSubmenu: submenu];
        [submenu release];
    }
    [submenu addItem: [NSMenuItem separatorItem]];
    [submenu addItemWithTitle: label action: nil keyEquivalent: @""];
    subItem = [submenu addItemWithTitle: [@"  "
                stringByAppendingString: NSStringFromClass([element class])]
                                           action: @selector(elementSelected:)
                                    keyEquivalent: @""];
    [subItem setTarget: self];
    [subItem setRepresentedObject: element];
}

- (void)_addValueForSelector:(SEL)sel withLabel:(NSString *)label toSubmenuForItem:(NSMenuItem *)item;
{
    id obj = [item representedObject];
    if ([obj respondsToSelector: sel]) {
        id value = [obj performSelector: sel];
        if (value == nil) return;
        [self _addElement: value withLabel: label toSubmenuForItem: item];
    }
}

- (void)_addElementToMenu:(id)element;
{
    NSMenuItem *item;
    if (element == nil) return;
    item = [viewHierarchyMenu addItemWithTitle: [@"  "
                stringByAppendingString: NSStringFromClass([element class])]
                                        action: @selector(elementSelected:)
                                 keyEquivalent: @""];
    [item setTarget: self];
    [item setRepresentedObject: element];
    [self _addValueForSelector: @selector(windowController) withLabel: @"Window Controller" toSubmenuForItem: item];
    [self _addValueForSelector: @selector(delegate) withLabel: @"Delegate" toSubmenuForItem: item];
    [self _addValueForSelector: @selector(dataSource) withLabel: @"Data Source" toSubmenuForItem: item];
    [self _addValueForSelector: @selector(target) withLabel: @"Target" toSubmenuForItem: item];
    [self _addValueForSelector: @selector(cell) withLabel: @"Cell" toSubmenuForItem: item];
}

- (void)captureOneView;
{
    NSEvent *event;
    NSView *view, *superView = nil, *contentView;
    NSWindow *eventWindow;
    static unsigned captureCount = 0;
    unsigned capture = captureCount++;
    
    FSALog(@"%4u>capturing one", capture);
    [captureButton setState: NSOnState];
    [bullseyeCursor push];

captureElement:
    [bullseyeCursor set];
    FSALog(@"%4u waiting for event...", capture);
    [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(menuWillSendAction:) name: NSMenuWillSendActionNotification object: nil];
    event = [NSApp nextEventMatchingMask: NSLeftMouseDownMask | NSRightMouseDownMask | NSOtherMouseDownMask | NSKeyUpMask | NSAppKitDefinedMask
                               untilDate: [NSDate distantFuture]
                                  inMode: NSEventTrackingRunLoopMode
                                 dequeue: YES];
    FSALog(@"%4u got %@", capture, event);
    [[NSNotificationCenter defaultCenter] removeObserver: self name: NSMenuWillSendActionNotification object: nil];
    if ([event type] == NSAppKitDefined) {
        if ([event subtype] == NSApplicationDeactivatedEventType) {
            [NSApp discardEventsMatchingMask: NSAnyEventMask beforeEvent: event];
            [self stopCapturingVoluntarily: NO];
            [NSApp sendEvent: event];
            return;
        }
        goto captureElement;
    }
    if ([event type] == NSKeyUp) {
        [NSApp discardEventsMatchingMask: NSAnyEventMask & ~NSKeyUpMask beforeEvent: event];
        FSALog(@"%4u<stop capture [key up]", capture);
        [self stopCapturingVoluntarily: YES];
        return;
    }
    [viewHierarchyMenu release]; viewHierarchyMenu = nil;
    viewHierarchyMenu = [[NSMenu alloc] initWithTitle: @""];
    NS_DURING
        eventWindow = [event window];
        contentView = [eventWindow contentView];
        view = [[contentView superview] hitTest: [event locationInWindow]];
        if (view == captureButton) {
            [NSApp discardEventsMatchingMask: NSAnyEventMask & ~NSKeyUpMask beforeEvent: event];
            FSALog(@"%4u<stop capture [capture button]", capture);
            [self stopCapturingVoluntarily: YES];
            NS_VOIDRETURN;
        }
        if (view == nil) {
            [self captureOneView];
            NS_VOIDRETURN;
        }
        [viewHierarchyMenu addItemWithTitle: @"View" action: nil keyEquivalent: @""];
        [self _addElementToMenu: view];
        superView = view;
        do {
            superView = [superView superview];
            if (superView == nil) break;
            [self _addElementToMenu: superView];
        } while (superView != contentView);
        [viewHierarchyMenu addItem: [NSMenuItem separatorItem]];
        [viewHierarchyMenu addItemWithTitle: @"Window" action: nil keyEquivalent: @""];
        [self _addElementToMenu: eventWindow];
    NS_HANDLER
        [descriptionField setStringValue:
            [NSString stringWithFormat: @"Çan exception occurred: %@È", localException]];
    NS_ENDHANDLER
    [NSMenu popUpContextMenu: viewHierarchyMenu withEvent: event forView: view];
    if ([captureButton state] == NSOnState) goto captureElement;
    FSALog(@"%4u<stop capture [fell through to end]", capture);
}

- (IBAction)captureView:(id)sender
{
    [statusField setStringValue: @"Click inside one of this applicationÕs windows to select."];
    [selectedElement release]; selectedElement = nil;
    [self update: nil];
    [self captureOneView];
}

- (void)setSelectedElement:(id)element;
{
    FSALog(@"element selected: %@", element);
    NS_DURING
        [descriptionField setStringValue: [element description]];
        [selectedElement release];
        selectedElement = [element retain];
        [[self window] orderFront: self];
    NS_HANDLER
        [descriptionField setStringValue:
            [NSString stringWithFormat: @"Çan exception occurred: %@È", localException]];
    NS_ENDHANDLER
    [viewHierarchyMenu release]; viewHierarchyMenu = nil;
}

- (void)elementSelected:(NSMenuItem *)sender;
{
    [self setSelectedElement: [sender representedObject]];
    [self captureOneView];
}

- (void)menuWillSendAction:(NSNotification *)notification;
{
    NSMenuItem *item = [[notification userInfo] objectForKey: @"MenuItem"];
    [self setSelectedElement: item];
    [NSApp discardEventsMatchingMask: NSAnyEventMask beforeEvent: [NSApp currentEvent]];
    // we're already capturing, don't do it again
}

- (void)controlTextDidChange:(NSNotification *)notification;
{
    [self update: nil];
}

- (IBAction)defineVariable:(id)sender;
{
#warning this should change when F-Script supports a public API for identifier validation
    NS_DURING
        NSString *variableName = [variableNameField stringValue];
        [statusField setStringValue: @"AssociatingÉ"];
        [interpreter setObject: selectedElement forIdentifier: variableName];
        [statusField setStringValue: [NSString stringWithFormat: @"Assigned variable Ò%@Ó", variableName]];
    NS_HANDLER
        [statusField setStringValue: [NSString stringWithFormat: @"Assocation failed: %@", localException]];
    NS_ENDHANDLER
}

- (IBAction)viewInObjectBrowser:(id)sender;
{
    FSALog(@"system: %@", system);
    [system browse: selectedElement];
    [statusField setStringValue: @"Opened object browser"];
}

@end