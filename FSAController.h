//
//  FSAController.h
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

#import <AppKit/AppKit.h>
#import <FScript/FSInterpreterView.h>
#import <FScript/FSSystem.h>

@class FSAViewAssociationController;

@interface FSAController : NSWindowController {
    IBOutlet FSInterpreterView *interpreterView;
    FSSystem *system;
    FSAViewAssociationController *viewAssociationController;
    unsigned interpreterNum;
}

- (IBAction)setFloating:(id)sender;
- (IBAction)FSA_associateWithInterface:(id)sender;

- (FSInterpreterView *)interpreterView;
- (NSString *)interpreterLabel;
- (FSSystem *)system;

@end
