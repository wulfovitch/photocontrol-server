#import "FullScreenController.h"

@implementation FullScreenController

enum {
	sendingNothing = 0,
	sendingSubDirs,
	sendingPictures,
};

@synthesize selectedDirectory;
@synthesize imageDisplayedInFullScreen;

- (id)initWithWindowNibName:(NSString *)nibName andDirectory:(NSString *)dir
{
	// start fullscreen display
	[super initWithWindowNibName:nibName];

	self.selectedDirectory = dir;
	NSLog(@"selected dir: %@", selectedDirectory);
	
	// set system variables
	NSRect screenRect = [[NSScreen mainScreen] frame];
	screenWidth = screenRect.size.width;
	screenHeight = screenRect.size.height;

	sending = sendingNothing;
	
	// start HTTP Server
	httpServer = [[HTTPServer alloc] init];
	[httpServer setType:@"_http._tcp."];
	[httpServer setDocumentRoot:[NSURL fileURLWithPath:selectedDirectory]];
	
	NSError *error;
	BOOL success = [httpServer start:&error];
	
	if(!success)
	{
		NSLog(@"Error starting HTTP Server: %@", error);
	}
	
	// start Simple Cocoa Server
	simpleCocoaServer = [[SimpleCocoaServer alloc] initWithPort:55567 delegate:self];
	[simpleCocoaServer startListening];
	
	// advertise server on the network (via bonjour)
	netService = [[NSNetService alloc] initWithDomain:@"" type:@"_photocontrol._tcp." name:@"" port:55567];
	[netService setDelegate:self];
	[netService publish];
	
	// setting up the timer for sending messages
	// this is necessary, because too many messages at a time are too much for the client
	messagesToSend = [[NSMutableArray alloc] init];
	
	return self;
}

- (void)dealloc
{	
	[keepAwakeTimer invalidate];
	[netService stop];
	[netService release];
	[simpleCocoaServer stopListening];
	[simpleCocoaServer release];
	[httpServer stop];
	[httpServer release];
	[super dealloc];
}

- (void)awakeFromNib
{
	[sendingMessagesTimer invalidate];
	if(sendingMessagesTimer == nil)
	{
		NSLog(@"setting up timer");
		sendingMessagesTimer = [NSTimer scheduledTimerWithTimeInterval: 0.1
																target: self
															  selector: @selector(handleTimer:)
															  userInfo: nil
															   repeats: YES];
	}
	//[fullScreenWindow makeKeyAndOrderFront:nil];
	
	displayedImage = [NSImage imageNamed:@"photocontrol-start.png"];
	[imageDisplayedInFullScreen setImage:displayedImage];
	[imageDisplayedInFullScreen setNeedsDisplay:YES];
	
	// hide the menubar and setup an tracking area, which is responsible for showing the menubar if the mousecursor is moved to the top (and for hiding the menubar if the mousecursor is moved somewhere else)
	[NSMenu setMenuBarVisible:NO];
	NSTrackingArea *menuBarTrackingArea = [[NSTrackingArea alloc] initWithRect:NSMakeRect(0, 0, screenWidth, screenHeight-22) options:(NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways) owner:self userInfo:nil];
	[imageDisplayedInFullScreen addTrackingArea:menuBarTrackingArea];
	[menuBarTrackingArea release];
	
	// start stay awake timer which prevents the display from sleeping
	keepAwakeTimer = [NSTimer scheduledTimerWithTimeInterval:30 target:self selector:@selector(stayAwake:) userInfo:nil repeats: YES];  
}

- (void)mouseEntered:(NSEvent *)theEvent {
	//NSLog(@"mouse exits menu bar");
	[NSMenu setMenuBarVisible:NO];
}

- (void)mouseExited:(NSEvent *)theEvent {
	//NSLog(@"mouse enters menu bar");
	[NSMenu setMenuBarVisible:YES];
}

//- (void)mouseMoved:(NSEvent *)theEvent {
//}

//- (void)cursorUpdate:(NSEvent *)theEvent {
//}

- (void)stayAwake:(NSTimer *)sleepTimer
{
	UpdateSystemActivity(OverallAct);// This is from Apple Tech Note QA1160:Preventing Sleep
}

// this timer is responsible for sending the messages to the client - only 3 messages are send per function call
- (void)handleTimer:(NSTimer *)timer
{
	int i;
	for(i=0; i < 3; i++)
	{
		if ([messagesToSend count] > 0)
		{
			[simpleCocoaServer sendString: [[messagesToSend objectAtIndex:0] message] toConnection:[[messagesToSend objectAtIndex:0] con]];
			[messagesToSend removeObjectAtIndex:0];
		}
	}
}

# pragma mark -
# pragma mark methods for sending contents of a directory to the client

- (void)sendContentsOfDirectory:(NSString *)path directories:(BOOL)dirs toConnection:(SimpleCocoaConnection *)con
{
	path = [NSString stringWithFormat:@"%@", path];
	
	// create arrays for the list of subdirectories/images
	NSMutableArray *subDirectoryArray = [[NSMutableArray alloc] init];
	NSMutableArray *imagesArray = [[NSMutableArray alloc] init];	
	
	// iterate through the directories
	NSDirectoryEnumerator *direnum = [[NSFileManager defaultManager] enumeratorAtPath:path];
	NSString *pname;
	while (pname = [direnum nextObject])
	{
		// add images to images array
		if ([[[pname pathExtension] lowercaseString] isEqualToString:@"jpg"] ||
			[[[pname pathExtension] lowercaseString] isEqualToString:@"jpeg"] ||
			[[[pname pathExtension] lowercaseString] isEqualToString:@"png"] ||
			[[[pname pathExtension] lowercaseString] isEqualToString:@"gif"] ||
			[[[pname pathExtension] lowercaseString] isEqualToString:@"bmp"] ||
			[[[pname pathExtension] lowercaseString] isEqualToString:@"tif"] ||
			[[[pname pathExtension] lowercaseString] isEqualToString:@"tiff"])
		{
			if(![pname isCaseInsensitiveLike:@".DS_Store"])
			{
				NSString *addedImage = [[NSString alloc] initWithString:pname];
				[imagesArray addObject:addedImage];
				[addedImage release];
			}
		}
		else
		{
			// add subdirectories to subdirectory array
			BOOL isDir;
			NSString *pathToDir = [path stringByAppendingString:[NSString stringWithFormat:@"/%@", pname]];
			if ([[NSFileManager defaultManager] fileExistsAtPath:pathToDir isDirectory:&isDir] && isDir) {
				[subDirectoryArray addObject:[NSString stringWithString:pname]];
			}
			[direnum skipDescendents]; // we are not interested in the contents of subdirectories
		}
	}
	
	if(dirs)
	{
		msg = [[Message alloc] initWithMessage:@"### START DIRECTORIES ###\n" andConnection:con];
		[messagesToSend addObject:msg];
		[msg release];
		int i;
		for ( i = 0; i < [subDirectoryArray count]; ++i )
		{  
			msg = [[Message alloc] initWithMessage:[NSString stringWithFormat:@"%@\n", [subDirectoryArray objectAtIndex:i]] andConnection:con];
			[messagesToSend addObject:msg];
			[msg release];
		}
		msg = [[Message alloc] initWithMessage:@"### END DIRECTORIES ###\n" andConnection:con];
		[messagesToSend addObject:msg];
		[msg release];
	}
	
	int imageCount = 0;
	int i;
	if(!dirs)
	{ 
		msg = [[Message alloc] initWithMessage:@"### START PICTURELIST ###\n" andConnection:con];
		[messagesToSend addObject:msg];
		[msg release];
	}
	for ( i = 0; i < [imagesArray count]; ++i ) {  
		imageCount++;
		if (!dirs)
		{
			msg = [[Message alloc] initWithMessage:[NSString stringWithFormat:@"%@\n", [imagesArray objectAtIndex:i]] andConnection:con];
			[messagesToSend addObject:msg];
			[msg release];
		}
	}
	if(!dirs)
	{ 
		msg = [[Message alloc] initWithMessage:@"### END PICTURELIST ###\n" andConnection:con];
		[messagesToSend addObject:msg];
		[msg release];
	}
	
	if(dirs)
	{
		//msg = [[Message alloc] initWithMessage:@"### START IMAGECOUNT ###\n" andConnection:con];
		//[messagesToSend addObject:msg];
		//[msg release];
		msg = [[Message alloc] initWithMessage:[NSString stringWithFormat:@"%i\n", imageCount] andConnection:con];
		[messagesToSend addObject:msg];
		[msg release];
		msg = [[Message alloc] initWithMessage:@"### END IMAGECOUNT ###\n" andConnection:con];
		[messagesToSend addObject:msg];
		[msg release];
	}
	[subDirectoryArray release];
	[imagesArray release];
}



# pragma mark -
# pragma mark delegate methods for SimpleCocoaServer

// this method processes the incoming messages from the client
- (void)processMessage:(NSString *)message fromConnection:(SimpleCocoaConnection *)con {
    NSLog(@"'%@' received from client: %@\n", message, con);
	
	NSArray *messageArray = [message componentsSeparatedByString:@"\n"];
	NSUInteger i, count = [messageArray	count];
	for (i = 0; i < count; i++) {
		NSString *messageLine = [messageArray objectAtIndex:i];
		if(![messageLine isEqualToString:@""])
		{
			
			switch (sending) {
				case sendingNothing:
					if([messageLine isEqualToString:@"### SEND DIRECTORY ###"])
					{
						//NSLog(@"start: send dir");
						sending = sendingSubDirs;		
					} else if([messageLine isEqualToString:@"### START PICTURELIST ###"])
					{
						//NSLog(@"start: send pictures");
						sending = sendingPictures;		
					}  else {
						
						// setting the image in the fullscreen here
						// auto release pool has to be created here otherwise the app does not deallocate the used
						// memory for the images which were already being displayed in fullscreen
						NSAutoreleasePool *thePool = [[NSAutoreleasePool alloc] init];  
						
						NSString *imagePathString = [NSString stringWithFormat:@"%@%@", selectedDirectory, messageLine];
					    NSLog(@"setting image: %@", imagePathString);
						NSImage *imageToDisplayOrigSize = [[NSImage alloc] initWithContentsOfFile:imagePathString];
						displayedImage = [FullScreenController imageByScalingProportionallyToSize:NSMakeSize(screenWidth, screenHeight) withImage:imageToDisplayOrigSize];
						[imageToDisplayOrigSize release];
						
						[imageDisplayedInFullScreen setImage:displayedImage];
						[imageDisplayedInFullScreen setNeedsDisplay:YES];
						
						[thePool release]; 
					}
					break;
					
				case sendingSubDirs:
					if([messageLine isEqualToString:@"### END SEND DIRECTORY ###"])
					{
						//NSLog(@"stop: send dir");
						sending = sendingNothing;
					} else {
						// send contents of the received path
						[self sendContentsOfDirectory:[NSString stringWithFormat:@"%@%@", self.selectedDirectory, messageLine] directories:YES toConnection:con];
					}
					break;
					
				case sendingPictures:
					if([messageLine isEqualToString:@"### END PICTURELIST ###"])
					{
						//NSLog(@"stop: send pictures");
						sending = sendingNothing;
					} else {
						// send contents of the received path
						[self sendContentsOfDirectory:[NSString stringWithFormat:@"%@/%@/", self.selectedDirectory, messageLine] directories:NO toConnection:con];
					}
					break;
			}
		}
	}
}

// this method processes any new connection to the SimpleCocoaServer
- (void)processNewConnection:(SimpleCocoaConnection *)con {
	//NSLog(@"processing new con: %@", selectedDirectory);
	[self sendContentsOfDirectory:self.selectedDirectory directories:YES toConnection:con];
}


// this method resizes an given image to an target size without touching the aspect ratio of the image
+ (NSImage *)imageByScalingProportionallyToSize:(NSSize)targetSize withImage:(NSImage *)image
{
	NSImage* sourceImage = image;
	NSImage* newImage = nil;
	
	if ([sourceImage isValid])
	{
		NSSize imageSize = [sourceImage size];
		float width  = imageSize.width;
		float height = imageSize.height;
		
		float targetWidth  = targetSize.width;
		float targetHeight = targetSize.height;
		
		float scaleFactor  = 0.0;
		float scaledWidth  = targetWidth;
		float scaledHeight = targetHeight;
		
		NSPoint thumbnailPoint = NSZeroPoint;
		
		if ( NSEqualSizes( imageSize, targetSize ) == NO )
		{
			
			float widthFactor  = targetWidth / width;
			float heightFactor = targetHeight / height;
			
			if ( widthFactor < heightFactor )
				scaleFactor = widthFactor;
			else
				scaleFactor = heightFactor;
			
			scaledWidth  = width  * scaleFactor;
			scaledHeight = height * scaleFactor;
			
			if ( widthFactor < heightFactor )
				thumbnailPoint.y = (targetHeight - scaledHeight) * 0.5;
			
			else if ( widthFactor > heightFactor )
				thumbnailPoint.x = (targetWidth - scaledWidth) * 0.5;
		}
		
		newImage = [[NSImage alloc] initWithSize:targetSize];
		
		[newImage lockFocus];
		
		NSRect thumbnailRect;
		thumbnailRect.origin = thumbnailPoint;
		thumbnailRect.size.width = scaledWidth;
		thumbnailRect.size.height = scaledHeight;
		
		[sourceImage drawInRect: thumbnailRect
					   fromRect: NSZeroRect
					  operation: NSCompositeSourceOver
					   fraction: 1.0];
		
		[newImage unlockFocus];
		
	}
	
	return [newImage autorelease];
}

// this method returns the name of the maching running this program
/*+ (NSString *)computerName
{
	CFStringRef name;
	NSString *computerName;
	name=SCDynamicStoreCopyComputerName(NULL,NULL);
	computerName=[NSString stringWithString:(NSString *)name];
	CFRelease(name);
	return computerName;
}*/

# pragma mark -
# pragma mark delegate methods for NetService (bonjour advertising on the network)

- (void)netServiceWillPublish:(NSNetService *)sender {
	NSLog(@"Starting Bonjour");
}

- (void)netService:(NSNetService *)sender didNotPublish:(NSDictionary *)errorDict {
	NSLog(@"Stopping Bonjour - an error occured");
}

- (void)netServiceDidStop:(NSNetService *)sender {
	NSLog(@"Bonjour stopped!");
}

@end
