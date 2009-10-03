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

#import "FullScreenController.h"

@implementation FullScreenController

enum {
	sendingNothing = 0,
	sendingSubDirs
};

@synthesize rootDirectory;
@synthesize imageDisplayedInFullScreen;

- (id)initWithWindowNibName:(NSString *)nibName andDirectory:(NSString *)dir
{
	// start fullscreen display
	[super initWithWindowNibName:nibName];

	self.rootDirectory = dir;
	NSLog(@"selected dir: %@", rootDirectory);
	
	// set system variables
	NSRect screenRect = [[NSScreen mainScreen] frame];
	screenWidth = screenRect.size.width;
	screenHeight = screenRect.size.height;

	sending = sendingNothing;
	
	// start HTTP Server
	httpServer = [[HTTPServer alloc] init];
	[httpServer setType:@"_http._tcp."];
	[httpServer setDocumentRoot:[NSURL fileURLWithPath:rootDirectory]];
	
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
	
	displayedImage = [NSImage imageNamed:@"photocontrol-start.png"];
	[imageDisplayedInFullScreen setImage:displayedImage];
	[imageDisplayedInFullScreen setNeedsDisplay:YES];
	
	[[NSApplication sharedApplication] setPresentationOptions: NSApplicationPresentationAutoHideDock | NSApplicationPresentationAutoHideMenuBar];
	
	// start stay awake timer which prevents the display from sleeping
	keepAwakeTimer = [NSTimer scheduledTimerWithTimeInterval:30 target:self selector:@selector(stayAwake:) userInfo:nil repeats: YES];  
}

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

- (void)sendContentsOfDirectory:(NSString *)path toConnection:(SimpleCocoaConnection *)con
{
	NSLog(@"sendContentsOfDirectory:toConnection: with rootDirectory: '%@' and path: '%@", rootDirectory, path);
	
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSError* error = nil;
	NSArray *directoryURLs = [fileManager contentsOfDirectoryAtURL:[NSURL URLWithString:rootDirectory]
										includingPropertiesForKeys:NULL
														   options:NSDirectoryEnumerationSkipsHiddenFiles | NSDirectoryEnumerationSkipsSubdirectoryDescendants
															 error:&error];
	
	
	
	NSArray *pathComponents = [[NSURL URLWithString:path] pathComponents];

	if(directoryURLs == nil)
	{
	  NSLog(@"empty dir or directory not existant");
	  return;
	} else {
	  
		for (int i=0; i < [pathComponents count]; i++)
		{
			NSString *component = [pathComponents objectAtIndex:i];
			if([component isEqual:@"/"])
			{
				NSLog(@"/ dir catched");
			} else {
				
				NSLog(@"%@", component);
				int intIndex;
				BOOL success = [[NSScanner scannerWithString:component] scanInteger:&intIndex];
				// check if that file even exists
				if(!success && intIndex >= [directoryURLs count])
				{
					NSLog(@"Not a number");
					return;
				} else {
					NSURL *file = [directoryURLs objectAtIndex:intIndex];
				  
					NSNumber *isDirectory = nil;
					[file getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:NULL];
				  
					if ([isDirectory boolValue])
					{
						directoryURLs = [fileManager contentsOfDirectoryAtURL:file
												   includingPropertiesForKeys:NULL
																	  options:NSDirectoryEnumerationSkipsHiddenFiles | NSDirectoryEnumerationSkipsSubdirectoryDescendants
																		error:&error];
					} 
				}
			}
		}
	}
							  
							  
	NSMutableArray *subDirectoryArray = [[NSMutableArray alloc] init];
	int imageCount = 0;
							  
	for(int i=0; i < [directoryURLs count]; i++)
	{
		NSNumber *isDirectory = nil;
		NSURL *file = [directoryURLs objectAtIndex:i];
		[file getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:NULL];
		if ([isDirectory boolValue]) {
			// format is: url_name of the object, where url is a numberic format url like /1/3/3
			NSString *urlString = [NSString stringWithFormat:@"%@%i_%@", path, i, [file lastPathComponent]];
			urlString = [urlString stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding];
			NSURL *urlToAdd = [NSURL URLWithString:urlString];
			NSLog(@"urlToAdd: %@ %@ %@", urlToAdd, [file lastPathComponent], urlString);
			[subDirectoryArray addObject:urlToAdd];
		} else {
			imageCount++;
		}

	}
							  
	
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
	
	

	//msg = [[Message alloc] initWithMessage:@"### START IMAGECOUNT ###\n" andConnection:con];
	//[messagesToSend addObject:msg];
	//[msg release];
	msg = [[Message alloc] initWithMessage:[NSString stringWithFormat:@"%i\n", imageCount] andConnection:con];
	[messagesToSend addObject:msg];
	[msg release];
	msg = [[Message alloc] initWithMessage:@"### END IMAGECOUNT ###\n" andConnection:con];
	[messagesToSend addObject:msg];
	[msg release];
							  
	[subDirectoryArray release];
}



# pragma mark -
# pragma mark delegate methods for SimpleCocoaServer

// this method processes the incoming messages from the client
- (void)processMessage:(NSString *)message orData:(NSData *)data fromConnection:(SimpleCocoaConnection *)con {
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
					} else {
						
						// setting the image in the fullscreen here
						// auto release pool has to be created here otherwise the app does not deallocate the used
						// memory for the images which were already being displayed in fullscreen
						NSAutoreleasePool *thePool = [[NSAutoreleasePool alloc] init];  
						
						NSURL *imageURL = [DirectoryHandler searchFileInDirectories:[NSURL URLWithString:messageLine] andDocumentRoot:[NSURL URLWithString:rootDirectory]];
						NSImage *imageToDisplayOrigSize = [[NSImage alloc] initWithContentsOfURL:imageURL];
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
						[self sendContentsOfDirectory:[NSString stringWithFormat:@"%@", messageLine] toConnection:con];
					}
					break;
			}
		}
	}
}

// this method processes any new connection to the SimpleCocoaServer
- (void)processNewConnection:(SimpleCocoaConnection *)con {
	//NSLog(@"processing new con: %@", selectedDirectory);
	[self sendContentsOfDirectory:self.rootDirectory toConnection:con];
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
