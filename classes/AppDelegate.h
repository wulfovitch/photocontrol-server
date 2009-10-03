//	photocontrol server
//	see http://photocontrol.net for more information
//
//	Copyright (C) 2009  Wolfgang König
//
//	This program is free software: you can redistribute it and/or modify
//	it under the terms of the GNU General Public License as published by
//	the Free Software Foundation, either version 3 of the License, or
//	(at your option) any later version.
//
//	This program is distributed in the hope that it will be useful,
//	but WITHOUT ANY WARRANTY; without even the implied warranty of
//	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//	GNU General Public License for more details.
//
//	You should have received a copy of the GNU General Public License
//	along with this program.  If not, see <http://www.gnu.org/licenses/>.


#import <Cocoa/Cocoa.h>
#import "FullScreenController.h"

@interface AppDelegate : NSObject {
	
	// Outlets
	IBOutlet NSButton *startFullScreenButton;
	IBOutlet NSButton *selectDirectoryButton;
	IBOutlet NSTextField *selectedDirectoryTextField;
	IBOutlet NSBox *selectedDirectoryTextFieldBox;
	IBOutlet NSWindow *window;
	
	// variables
	NSString *selectedDirectory;
}

@property (nonatomic, retain) NSString *selectedDirectory;

- (IBAction)showOpenPanel:(id)sender;
- (IBAction)startPresentation:(id)sender;

@end