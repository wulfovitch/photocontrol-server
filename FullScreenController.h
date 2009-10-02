#import <Cocoa/Cocoa.h>
#import "HTTPServer.h"
#import "FullScreenWindow.h"
#import "SimpleCocoaServer.h"
#import "Message.h"
#import <IOKit/pwr_mgt/IOPMLib.h>


@interface FullScreenController : NSWindowController {
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
- (void)mouseEntered:(NSEvent *)theEvent;
@end
