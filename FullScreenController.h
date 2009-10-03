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
#import "HTTPServer.h"
#import "FullScreenWindow.h"
#import "SimpleCocoaServer.h"
#import "Message.h"
#import <IOKit/pwr_mgt/IOPMLib.h>


@interface FullScreenController : NSWindowController <NSNetServiceDelegate> {
	// FullScreenView variables
	IBOutlet FullScreenWindow *fullScreenWindow;
	IBOutlet NSImageView *imageDisplayedInFullScreen;
	NSString *displayedImageName;
	NSImage *displayedImage;	
	NSString *rootDirectory;
	NSTimer *keepAwakeTimer;
	
	// HTTP Server variables
	HTTPServer *httpServer;
	
	// Simple Cocoa Server variables
	SimpleCocoaServer *simpleCocoaServer;
	
	// system dependent variables
	float screenWidth;
	float screenHeight;

	NSNetService *netService; // bonjour service
	
	// receiving messages from client
	NSInteger sending;
	NSString *currentDirectory;
	Message *msg;
	
	// Timer for sending messages
	NSTimer *sendingMessagesTimer;
	NSMutableArray *messagesToSend;
}

@property (nonatomic, retain) NSString *rootDirectory;
@property (nonatomic, retain) NSImageView *imageDisplayedInFullScreen;

- (id)initWithWindowNibName:(NSString *)nibName andDirectory:(NSString *)dir;
- (void)handleTimer:(NSTimer *)timer;
- (void)sendContentsOfDirectory:(NSString *)path toConnection:(SimpleCocoaConnection *)con;
- (void)stayAwake:(NSTimer *)sleepTimer;
+ (NSImage *)imageByScalingProportionallyToSize:(NSSize)targetSize withImage:(NSImage *)image;
@end
