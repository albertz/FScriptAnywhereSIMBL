//
//  FSAController.m
//  F-Script Anywhere
//
//  Created by Nicholas Riley on Fri Feb 01 2002.
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

#import "FSAController.h"
#import "FSAViewAssociationController.h"
#import "FSAnywhere.h"
#import "FSAWindowManager.h"
#import <FScript/FSInterpreter.h>

@class ShellView;

// XXX workaround for lack of focus on FSInterpreterView
@interface CLIView : NSView
- (ShellView *)shellView;
@end

@interface FSInterpreterView (FSAWorkaround)
- (CLIView *)cliView;
@end

@implementation FSAController

// derived from TETextWatcher.m in Mike Ferris's TextExtras
+ (void)installMenu;
{
    static BOOL alreadyInstalled = NO;
    NSMenu *mainMenu = nil;
    
    if (!alreadyInstalled && ((mainMenu = [NSApp mainMenu]) != nil)) {
        NSMenu *insertIntoMenu = nil;
        NSMenuItem *item;
        unsigned insertLoc = NSNotFound;
        NSBundle *bundle = [NSBundle bundleForClass:self];
        NSMenu * beforeSubmenu = [NSApp windowsMenu];
        // Succeed or fail, we do not try again.
        alreadyInstalled = YES;

        // Add it to the main menu.  We try to put it right before the Windows menu if there is one, or right before the Services menu if there is one, and if there's neither we put it right before the the last submenu item (ie above Quit and Hide on Mach, at the end on Windows.)

        if (!beforeSubmenu) {
            beforeSubmenu = [NSApp servicesMenu];
        }

        insertIntoMenu = mainMenu;

        if (beforeSubmenu) {
            NSArray *itemArray = [insertIntoMenu itemArray];
            unsigned i, c = [itemArray count];

            // Default to end of menu
            insertLoc = c;

            for (i=0; i<c; i++) {
                if ([[itemArray objectAtIndex:i] target] == beforeSubmenu) {
                    insertLoc = i;
                    break;
                }
            }
        } else {
            NSArray *itemArray = [insertIntoMenu itemArray];
            unsigned i = [itemArray count];

            // Default to end of menu
            insertLoc = i;

            while (i-- > 0) {
                if ([[itemArray objectAtIndex:i] hasSubmenu]) {
                    insertLoc = i+1;
                    break;
                }
            }
        }
        if (insertIntoMenu) {
            NSMenu *fsaMenu = [[NSMenu allocWithZone: [NSMenu menuZone]] initWithTitle:NSLocalizedStringFromTableInBundle(@"FSA", @"FSA", bundle, @"Title of F-Script Anywhere menu")];

            item = [insertIntoMenu insertItemWithTitle: NSLocalizedStringFromTableInBundle(@"FSA", @"FSA", bundle, @"Title of F-Script Anywhere menu") action:NULL keyEquivalent:@"" atIndex:insertLoc];
            [insertIntoMenu setSubmenu:fsaMenu forItem:item];
            [fsaMenu release];

            // Add the items for the commands.
            item = [fsaMenu addItemWithTitle: NSLocalizedStringFromTableInBundle(@"New F-Script Workspace", @"FSA", bundle, @"Title of F-Script Workspace menu item") action:@selector(createInterpreterWindow:) keyEquivalent: @""];
            [item setTarget: self];
            [fsaMenu addItemWithTitle: NSLocalizedStringFromTableInBundle(@"Associate With Interface", @"FSA", bundle, @"Title of Associate with Interface menu item") action: @selector(FSA_associateWithInterface:) keyEquivalent: @""];
            [fsaMenu addItem: [NSMenuItem separatorItem]];
            item = [fsaMenu addItemWithTitle: NSLocalizedStringFromTableInBundle(@"About F-Script Anywhere…", @"FSA", bundle, @"Title of Info Panel menu item") action:@selector(showInfo:) keyEquivalent: @""];
            [item setTarget: self];
            [[FSAWindowManager sharedManager] setWindowMenu: fsaMenu];
        }
    }

}

+ (BOOL)validateMenuItem:(id <NSMenuItem>)menuItem
{
    SEL sel;
    NSAssert([menuItem target] == self, @"menu item does not target FSAController!");
    sel = [menuItem action];
    if (sel == @selector(showInfo:) || sel == @selector(createInterpreterWindow:)) return YES;
    FSALog(@"+[FSAController validateMenuItem:] unknown menu item for validation: %@", menuItem);
    return NO;
}

+ (void)createInterpreterWindow:(id)sender;
{
    [[self alloc] init];
}

+ (void)showInfo:(id)sender;
{
    int result = NSRunInformationalAlertPanel([NSString stringWithFormat: @"About F-Script Anywhere (version %s)", FSA_VERSION], @"F-Script Anywhere lets you embed a F-Script interpreter in a Cocoa application while it is running.\n\nF-Script Anywhere is currently installed in this application.  To remove it, quit this application.\n\nFor more information about F-Script, please visit its Web site %@.", @"OK", @"Visit Web Site", nil, FSA_FScriptURL);
    if (result == NSAlertAlternateReturn) {
        [[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString: FSA_FScriptURL]];
    }
}

+ (void)load;
{
    [self installMenu];
}

- (id)init {
    self = [super initWithWindowNibName: @"FSAInterpreterPanel"];

    if (self != nil) {
        NSWindow *window = [self window];
        NSString *label;
        static unsigned numInterpWindows = 0;

        NSAssert(window != nil, @"Can’t get interpreter window!");
        if (interpreterNum == 0) interpreterNum = ++numInterpWindows;
        if ( (label = [self interpreterLabel]) != nil) {
            [window setTitle: [NSString stringWithFormat: @"%@: %@", [window title], label]];
        }

        [window setLevel: NSNormalWindowLevel]; // XXX if set floating, it is globally floating!
        [self showWindow: self];
        [window makeKeyAndOrderFront: self];
#warning this should go away when F-Script properly accepts firstResponder on the InterpreterView
        [window makeFirstResponder: (NSView *)[[[self interpreterView] cliView] shellView]];
        [[FSAWindowManager sharedManager] registerWindow: window];
        system = [[[self interpreterView] interpreter] objectForIdentifier: @"sys" found: NULL];
        [system retain];
        NSAssert1([system isKindOfClass: [System class]], @"Initial value bound to identifier 'sys' is not a System object, but %@", system);
    }
    
    return self;
}

- (void)dealloc;
{
    [system release];
    [super dealloc];
}

- (NSString *)interpreterLabel;
{
    static NSString *appName = nil;
    static BOOL retrievedAppName = NO;
    
    if (appName == nil) {
        if (retrievedAppName) return nil;
        NS_DURING
            appName = [[[NSBundle mainBundle] infoDictionary] objectForKey: @"CFBundleName"];
        NS_HANDLER
            FSALog(@"Exception occurred while trying to obtain application name: %@", localException);
        NS_ENDHANDLER
        retrievedAppName = YES;
    }
    if (interpreterNum == 1) return appName;
    return [NSString stringWithFormat: @"%@ [%u]", appName, interpreterNum];
}

- (FSInterpreterView *)interpreterView;
{
    return interpreterView;
}

- (System *)system;
{
    return system;
}

- (IBAction)setFloating:(id)sender;
{
    [[self window] setLevel: [sender state] == NSOnState ? NSFloatingWindowLevel : NSNormalWindowLevel];
}

- (IBAction)FSA_associateWithInterface:(id)sender;
{
    NS_DURING
        FSAWindowManager *wm = [FSAWindowManager sharedManager];
        if (viewAssociationController == nil) {
            viewAssociationController = [[FSAViewAssociationController alloc] initWithFSAController: self];
        }
        [viewAssociationController showWindow: self];
        if (![wm windowIsRegistered: [viewAssociationController window]]) {
            [wm registerSubordinateWindow: [viewAssociationController window]
                                forWindow: [self window]];
        }
    NS_HANDLER
        FSALog(@"%@", localException);
    NS_ENDHANDLER
}

@end
