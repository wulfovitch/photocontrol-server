//	http server for the photocontrol server
//	see http://photocontrol.net for more information
//
//	this code is derived from:
//	http://code.google.com/p/cocoahttpserver/
//	which is licensed under the new-BSD-license.
//	The modificiations to that code are licensed under the gpl.
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


#import "AsyncSocket.h"
#import "HTTPServer.h"
#import "HTTPAuthenticationRequest.h"

#import <stdlib.h>

#if TARGET_OS_IPHONE
#import <CommonCrypto/CommonDigest.h>
#else
#import <SSCrypto/SSCrypto.h>
#endif


// Define number of connection threads to run
#define NUM_THREADS  3

// Define chunk size used to read files from disk
#define READ_CHUNKSIZE     (1024 * 512)

// Define the various timeouts (in seconds) for various parts of the HTTP process
#define READ_TIMEOUT        -1
#define WRITE_HEAD_TIMEOUT  30
#define WRITE_BODY_TIMEOUT  -1
#define WRITE_ERROR_TIMEOUT 30

// Define the various tags we'll use to differentiate what it is we're currently doing
#define HTTP_REQUEST                  15
#define HTTP_PARTIAL_RESPONSE_HEADER  28
#define HTTP_PARTIAL_RESPONSE_BODY    29
#define HTTP_RESPONSE                 30
#define HTTP_FINAL_RESPONSE           45

#define HTTPConnectionDidDieNotification  @"HTTPConnectionDidDie"

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation HTTPServer

/**
 * Standard Constructor.
 * Instantiates an HTTP server, but does not start it.
**/
- (id)init
{
	if(self = [super init])
	{
		// Initialize underlying asynchronous tcp/ip socket
		asyncSocket = [[AsyncSocket alloc] initWithDelegate:self];
		
		// Use default connection class of HTTPConnection
		connectionClass = [HTTPConnection self];
		
		// Configure default values for bonjour service
		
		// Use a default port of 0
		// This will allow the kernel to automatically pick an open port for us
		port = 55598;
		
		// Use the local domain by default
		domain = @"local.";
		
		// If using an empty string ("") for the service name when registering,
		// the system will automatically use the "Computer Name".
		// Passing in an empty string will also handle name conflicts
		// by automatically appending a digit to the end of the name.
		name = @"";
		
		// Initialize an array to reference all the threads
		runLoops = [[NSMutableArray alloc] initWithCapacity:NUM_THREADS];
		
		// Initialize an array to hold the number of connections being processed for each thread
		runLoopsLoad = [[NSMutableArray alloc] initWithCapacity:NUM_THREADS];
		
		// Initialize an array to hold all the HTTP connections
		connections = [[NSMutableArray alloc] init];
		
		// Start threads
		int i;
		for(i = 0; i < NUM_THREADS; i++)
		{
			[NSThread detachNewThreadSelector:@selector(connectionThread:)
									 toTarget:self
								   withObject:[NSNumber numberWithInt:i]];
		}
		
		// And register for notifications of closed connections
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(connectionDidDie:)
													 name:HTTPConnectionDidDieNotification
												   object:nil];
	}
	return self;
}

/**
 * Standard Deconstructor.
 * Stops the server, and clients, and releases any resources connected with this instance.
**/
- (void)dealloc
{
	// Remove notification observer
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	// Stop the server if it's running
	[self stop];
	
	// Release all instance variables
	[documentRoot release];
	[netService release];
    [domain release];
    [name release];
    [type release];
	[txtRecordDictionary release];
	[asyncSocket release];
	[runLoops release];
	[runLoopsLoad release];
	[connections release];
	
	[super dealloc];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Server Configuration:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Returns the delegate connected with this instance.
**/
- (id)delegate
{
	return delegate;
}

/**
 * Sets the delegate connected with this instance.
**/
- (void)setDelegate:(id)newDelegate
{
	delegate = newDelegate;
}

/**
 * The document root is filesystem root for the webserver.
 * Thus requests for /index.html will be referencing the index.html file within the document root directory.
 * All file requests are relative to this document root.
**/
- (NSURL *)documentRoot {
    return documentRoot;
}
- (void)setDocumentRoot:(NSURL *)value
{
    if(![documentRoot isEqual:value])
	{
        [documentRoot release];
        documentRoot = [value copy];
    }
}

/**
 * The connection class is the class that will be used to handle connections.
 * That is, when a new connection is created, an instance of this class will be intialized.
 * The default connection class is HTTPConnection.
 * If you use a different connection class, it is assumed that the class extends HTTPConnection
**/
- (Class)connectionClass {
    return connectionClass;
}
- (void)setConnectionClass:(Class)value
{
    connectionClass = value;
}

/**
 * Domain on which to broadcast this service via Bonjour.
 * The default domain is @"local".
**/
- (NSString *)domain {
    return domain;
}
- (void)setDomain:(NSString *)value
{
	if(![domain isEqualToString:value])
	{
		[domain release];
        domain = [value copy];
    }
}

/**
 * The type of service to publish via Bonjour.
 * No type is set by default, and one must be set in order for the service to be published.
**/
- (NSString *)type {
    return type;
}
- (void)setType:(NSString *)value
{
	if(![type isEqualToString:value])
	{
		[type release];
		type = [value copy];
    }
}

/**
 * The name to use for this service via Bonjour.
 * The default name is the host name of the computer.
**/
- (NSString *)name {
    return name;
}
- (void)setName:(NSString *)value
{
	if(![name isEqualToString:value])
	{
        [name release];
        name = [value copy];
    }
}

/**
 * The port to listen for connections on.
 * By default this port is initially set to zero, which allows the kernel to pick an available port for us.
 * After the HTTP server has started, the port being used may be obtained by this method.
**/
- (UInt16)port {
    return port;
}
- (void)setPort:(UInt16)value {
    port = value;
}

/**
 * The extra data to use for this service via Bonjour.
**/
- (NSDictionary *)TXTRecordDictionary {
	return txtRecordDictionary;
}
- (void)setTXTRecordDictionary:(NSDictionary *)value
{
	if(![txtRecordDictionary isEqualToDictionary:value])
	{
		[txtRecordDictionary release];
		txtRecordDictionary = [value copy];
		
		// And update the txtRecord of the netService if it has already been published
		if(netService)
		{
			[netService setTXTRecordData:[NSNetService dataFromTXTRecordDictionary:txtRecordDictionary]];
		}
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Server Control:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)start:(NSError **)error
{
	BOOL success = [asyncSocket acceptOnPort:port error:error];
	
	if(success)
	{
		// Update our port number
		[self setPort:[asyncSocket localPort]];
		
		// Output console message for debugging purposes
		NSLog(@"Started HTTP server on port %hu", port);
		
		// We can only publish our bonjour service if a type has been set
		if(type != nil)
		{
			// Create the NSNetService with our basic parameters
			netService = [[NSNetService alloc] initWithDomain:domain type:type name:name port:port];
			
			[netService setDelegate:self];
			[netService publish];
			
			// Do not set the txtRecordDictionary prior to publishing!!!
			// This will cause the OS to crash!!!
			
			// Set the txtRecordDictionary if we have one
			if(txtRecordDictionary != nil)
			{
				[netService setTXTRecordData:[NSNetService dataFromTXTRecordDictionary:txtRecordDictionary]];
			}
		}
	}
	else
	{
		NSLog(@"Failed to start HTTP Server: %@", error);
	}
	
	return success;
}

- (BOOL)stop
{
	// First stop publishing the service via bonjour
	if(netService)
	{
		[netService stop];
		[netService release];
		netService = nil;
	}
	
	// Now stop the asynchronouse tcp server
	// This will prevent it from accepting any more connections
	[asyncSocket disconnect];
	
	// Now stop all HTTP connections the server owns
	[connections removeAllObjects];
	
	return YES;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Server Status:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Returns the number of clients that are currently connected to the server.
**/
- (int)numberOfHTTPConnections
{
	return [connections count];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark AsyncSocket Delegate Methods:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

-(void)onSocket:(AsyncSocket *)sock didAcceptNewSocket:(AsyncSocket *)newSocket
{
	id newConnection = [[connectionClass alloc] initWithAsyncSocket:newSocket forServer:self];
	
	@synchronized(connections)
	{
		[connections addObject:newConnection];
	}
	
	[newConnection release];
}

/**
 * Called when a new socket is spawned to handle a connection.  This method should return the run-loop of the
 * thread on which the new socket and its delegate should operate. If omitted, [NSRunLoop currentRunLoop] is used.
**/
- (NSRunLoop *)onSocket:(AsyncSocket *)sock wantsRunLoopForNewSocket:(AsyncSocket *)newSocket
{
	// Figure out what thread/runloop to run the new connection on.
	// We choose the thread/runloop with the lowest number of connections.
	
	unsigned int m = 0;
	unsigned int mLoad = [[runLoopsLoad objectAtIndex:m] unsignedIntValue];
	
	@synchronized(runLoops)
	{
		unsigned int i;
		for(i = 1; i < NUM_THREADS; i++)
		{
			unsigned int iLoad = [[runLoopsLoad objectAtIndex:i] unsignedIntValue];
			
			if(iLoad < mLoad)
			{
				m = i;
				mLoad = iLoad;
			}
		}
		
		[runLoopsLoad replaceObjectAtIndex:m withObject:[NSNumber numberWithUnsignedInt:(mLoad + 1)]];
	}
	
	//NSLog(@"Choosing run loop %u with load %u", m, mLoad);
	
	// And finally, return the proper run loop
	return [runLoops objectAtIndex:m];
}

/**
 * This method is automatically called when a notification of type HTTPConnectionDidDieNotification is posted.
 * It allows us to remove the connection from our array.
**/
- (void)connectionDidDie:(NSNotification *)notification
{
	// Note: This method is called on the thread/runloop that posted the notification
	
	@synchronized(runLoops)
	{
		unsigned int runLoopIndex = [runLoops indexOfObject:[NSRunLoop currentRunLoop]];
		
		if(runLoopIndex < [runLoops count])
		{
			unsigned int runLoopLoad = [[runLoopsLoad objectAtIndex:runLoopIndex] unsignedIntValue];
			
			NSNumber *newLoad = [NSNumber numberWithUnsignedInt:(runLoopLoad - 1)];
			
			[runLoopsLoad replaceObjectAtIndex:runLoopIndex withObject:newLoad];
		}
	}
	
	HTTPConnection *deadConnection = [notification object];
	
	@synchronized(connections)
	{
		[connections removeObject:deadConnection];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Bonjour Delegate Methods:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Called when our bonjour service has been successfully published.
 * This method does nothing but output a log message telling us about the published service.
**/
- (void)netServiceDidPublish:(NSNetService *)ns
{
	// Override me to do something here...
	
	NSLog(@"Bonjour Service Published: domain(%@) type(%@) name(%@)", [ns domain], [ns type], [ns name]);
}

/**
 * Called if our bonjour service failed to publish itself.
 * This method does nothing but output a log message telling us about the published service.
**/
- (void)netService:(NSNetService *)ns didNotPublish:(NSDictionary *)errorDict
{
	// Override me to do something here...
	
	NSLog(@"Failed to Publish Service: domain(%@) type(%@) name(%@)", [ns domain], [ns type], [ns name]);
	NSLog(@"Error Dict: %@", errorDict);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Connection Threading:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)connectionThread:(NSNumber *)threadNum
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	@synchronized(runLoops)
	{
		[runLoops addObject:[NSRunLoop currentRunLoop]];
		[runLoopsLoad addObject:[NSNumber numberWithUnsignedInt:0]];
	}
	
	// We can't run the run loop unless it has an associated input source or a timer.
	// So we'll just create a timer that will never fire - unless the server runs for 10,000 years.
	[NSTimer scheduledTimerWithTimeInterval:DBL_MAX target:self selector:@selector(ignore:) userInfo:nil repeats:NO];
	
	// Start the run loop
	[[NSRunLoop currentRunLoop] run];
	
	[pool release];
}

@end


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


@implementation HTTPConnection

static NSMutableArray *recentNonces;

/**
 * This method is automatically called (courtesy of Cocoa) before the first instantiation of this class.
 * We use it to initialize any static variables.
**/
+ (void)initialize
{
	static BOOL initialized = NO;
	if(!initialized)
	{
		// Initialize class variables
		recentNonces = [[NSMutableArray alloc] initWithCapacity:5];
		
		initialized = YES;
	}
}

/**
 * This method is designed to be called by a scheduled timer, and will remove a nonce from the recent nonce list.
 * The nonce to remove should be set as the timer's userInfo.
**/
+ (void)removeRecentNonce:(NSTimer *)aTimer
{
	[recentNonces removeObject:[aTimer userInfo]];
}

+ (NSString *)md5Hash:(NSString *)clearText
{
#if TARGET_OS_IPHONE
	
	const char *cStr = [clearText UTF8String];
	unsigned char result[CC_MD5_DIGEST_LENGTH];
	CC_MD5( cStr, strlen(cStr), result );
	return [NSString stringWithFormat:@"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
			result[0], result[1], result[2], result[3], result[4], result[5], result[6], result[7],
			result[8], result[9], result[10], result[11], result[12], result[13], result[14], result[15]
	];
	
#else
	
	NSData *clearData = [clearText dataUsingEncoding:NSUTF8StringEncoding];
	return [[SSCrypto getMD5ForData:clearData] hexval];
	
#endif
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Init, Dealloc:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Sole Constructor.
 * Associates this new HTTP connection with the given AsyncSocket.
 * This HTTP connection object will become the socket's delegate and take over responsibility for the socket.
**/
- (id)initWithAsyncSocket:(AsyncSocket *)newSocket forServer:(HTTPServer *)myServer
{
	if(self = [super init])
	{
		// Take over ownership of the socket
		asyncSocket = [newSocket retain];
		[asyncSocket setDelegate:self];
		
		// Store reference to server
		// Note that we do not retain the server. Parents retain their children, children do not retain their parents.
		server = myServer;
		
		// Initialize lastNC (last nonce count)
		// These must increment for each request from the client
		lastNC = 0;
		
		// Create a new HTTP message
		// Note the second parameter is YES, because it will be used for HTTP requests from the client
		request = CFHTTPMessageCreateEmpty(kCFAllocatorDefault, YES);
		
		// Register for NSFileNotifications
		//[[NSNotificationCenter defaultCenter] addObserver:self
		//										 selector:@selector(responseDataReady:)
		//											 name:NSFileHandleReadCompletionNotification
		//										   object:nil];
		
		// And now that we own the socket, and we have our CFHTTPMessage object (for requests) ready,
		// we can start reading the HTTP requests...
		[asyncSocket readDataToData:[AsyncSocket CRLFData] withTimeout:READ_TIMEOUT tag:HTTP_REQUEST];
	}
	return self;
}

/**
 * Standard Deconstructor.
**/
- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[asyncSocket setDelegate:nil];
	[asyncSocket disconnect];
	[asyncSocket release];
	
	if(request) CFRelease(request);
	
	[nonce release];
	
	[fileResponse closeFile];
	[fileResponse release];
	
	[super dealloc];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Connection Control:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Returns whether or not the server is configured to be a secure server.
 * In other words, all connections to this server are immediately secured, thus only secure connections are allowed.
 * This is the equivalent of having an https server, where it is assumed that all connections must be secure.
 * If this is the case, then unsecure connections will not be allowed on this server, and a separate unsecure server
 * would need to be run on a separate port in order to support unsecure connections.
 * 
 * Note: In order to support secure connections, the sslIdentityAndCertificates method must be implemented.
**/
- (BOOL)isSecureServer
{
	// Override me to create an https server...
	
	return NO;
}

/**
 * This method is expected to returns an array appropriate for use in kCFStreamSSLCertificates SSL Settings.
 * It should be an array of SecCertificateRefs except for the first element in the array, which is a SecIdentityRef.
**/
- (NSArray *)sslIdentityAndCertificates
{
	// Override me to provide the proper required SSL identity.
	// You can configure the identity for the entire server, or based on the current request
	
	return nil;
}

/**
 * Returns whether or not the requested resource is password protected.
 * In this generic implementation, nothing is password protected.
**/
- (BOOL)isPasswordProtected:(NSString *)path
{
	// Override me to provide password protection...
	// You can configure it for the entire server, or based on the current request
	
	return NO;
}

/**
 * Returns the authentication realm.
 * In this generic implmentation, a default realm is used for the entire server.
**/
- (NSString *)realm
{
	// Override me to provide a custom realm...
	// You can configure it for the entire server, or based on the current request
	
	return @"defaultRealm@host.com";
}

/**
 * Returns the password for the given username.
 * This password will be used to generate the response hash to validate against the given response hash.
**/
- (NSString *)passwordForUser:(NSString *)username
{
	// Override me to provide proper password authentication
	// You can configure a password for the entire server, or custom passwords for users and/or resources
	
	// Note: A password of nil, or a zero-length password is considered the equivalent of no password
	
	return nil;
}

/**
 * Generates and returns an authentication nonce.
 * A nonce is a  server-specified string uniquely generated for each 401 response.
 * The default implementation uses a single nonce for each session.
**/
- (NSString *)generateNonce
{
	// We use the Core Foundation UUID class to generate a nonce value for us
	// UUIDs (Universally Unique Identifiers) are 128-bit values guaranteed to be unique.
	CFUUIDRef theUUID = CFUUIDCreate(NULL);
    NSString *newNonce = [(NSString *)CFUUIDCreateString(NULL, theUUID) autorelease];
    CFRelease(theUUID);
	
	// We have to remember that the HTTP protocol is stateless
	// Even though with version 1.1 persistent connections are the norm, they are not guaranteed
	// Thus if we generate a nonce for this connection,
	// it should be honored for other connections in the near future
	// 
	// In fact, this is absolutely necessary in order to support QuickTime
	// When QuickTime makes it's initial connection, it will be unauthorized, and will receive a nonce
	// It then disconnects, and creates a new connection with the nonce, and proper authentication
	// If we don't honor the nonce for the second connection, QuickTime will repeat the process and never connect
	
	[recentNonces addObject:newNonce];
	
	[NSTimer scheduledTimerWithTimeInterval:300
									 target:[HTTPConnection class]
								   selector:@selector(removeRecentNonce:)
								   userInfo:newNonce
									repeats:NO];
	return newNonce;
}

/**
 * Returns whether or not the user is properly authenticated.
 * Authentication is done using Digest Access Authentication accoring to RFC 2617.
**/
- (BOOL)isAuthenticated
{
	// Extract the authentication information from the Authorization header
	HTTPAuthenticationRequest *auth = [[[HTTPAuthenticationRequest alloc] initWithRequest:request] autorelease];
	
	if([auth username] == nil)
	{
		// The client didn't provide a username
		// Most likely they didn't provide any authentication at all
		return NO;
	}
	
	NSString *password = [self passwordForUser:[auth username]];
	if((password == nil) || ([password length] == 0))
	{
		// There is no password set, or the password is an empty string
		// We can consider this the equivalent of not using password protection
		return YES;
	}
	
	NSString *method = [(NSString *)CFHTTPMessageCopyRequestMethod(request) autorelease];
	
	NSURL *absoluteUrl = [(NSURL *)CFHTTPMessageCopyRequestURL(request) autorelease];
	NSString *url = [(NSURL *)absoluteUrl relativeString];
	
	if(![url isEqualToString:[auth uri]])
	{
		// Requested URL and Authorization URI do not match
		// This could be a replay attack
		// IE - attacker provides same authentication information, but requests a different resource
		return NO;
	}
	
	// The nonce the client provided will most commonly be stored in our local (cached) nonce variable
	if(![nonce isEqualToString:[auth nonce]])
	{
		// The given nonce may be from another connection
		// We need to search our list of recent nonce strings that have been recently distributed
		if([recentNonces containsObject:[auth nonce]])
		{
			// Store nonce in local (cached) nonce variable to prevent array searches in the future
			[nonce release];
			nonce = [[auth nonce] copy];
			
			// The client has switched to using a different nonce value
			// This may happen if the client tries to get a different file in a directory with different credentials.
			// The previous credentials wouldn't work, and the client would receive a 401 error
			// along with a new nonce value. The client then uses this new nonce value and requests the file again.
			// Whatever the case may be, we need to reset lastNC, since that variable is on a per nonce basis.
			lastNC = 0;
		}
		else
		{
			// We have no knowledge of ever distributing such a nonce
			// This could be a replay attack from a previous connection in the past
			return NO;
		}
	}
	
	if([[auth nc] intValue] <= lastNC)
	{
		// The nc value (nonce count) hasn't been incremented since the last request
		// This could be a replay attack
		return NO;
	}
	lastNC = [[auth nc] intValue];
	
	NSString *HA1str = [NSString stringWithFormat:@"%@:%@:%@", [auth username], [auth realm], password];
	NSString *HA2str = [NSString stringWithFormat:@"%@:%@", method, [auth uri]];
	
	NSString *HA1 = [[self class] md5Hash:HA1str];
	
	NSString *HA2 = [[self class] md5Hash:HA2str];
	
	NSString *responseStr = [NSString stringWithFormat:@"%@:%@:%@:%@:%@:%@",
		HA1, [auth nonce], [auth nc], [auth cnonce], [auth qop], HA2];
	
	NSString *response = [[self class] md5Hash:responseStr];
	
	return [response isEqualToString:[auth response]];
}

/**
 * This method is called after a full HTTP request has been received.
 * The current request is in the CFHTTPMessage request variable.
**/
- (void)replyToHTTPRequest
{
	NSLog(@"##########################");
	NSLog(@"replyToHTTPRequest called!");
	// Check the HTTP version
	// If it's anything but HTTP version 1.1, we don't support it
	NSString *version = [(NSString *)CFHTTPMessageCopyVersion(request) autorelease];
    if(!version || ![version isEqualToString:(NSString *)kCFHTTPVersion1_1])
	{
		NSLog(@"HTTP Server: Error 505 - Version Not Supported");
		
		// Status Code 505 - Version Not Supported
        CFHTTPMessageRef response = CFHTTPMessageCreateResponse(kCFAllocatorDefault, 505, NULL, (CFStringRef)version);
		CFHTTPMessageSetHeaderFieldValue(response, CFSTR("Content-Length"), CFSTR("0"));
        NSData *responseData = [self preprocessErrorResponse:response];
		[asyncSocket writeData:responseData withTimeout:WRITE_ERROR_TIMEOUT tag:HTTP_RESPONSE];
		CFRelease(response);
        return;
    }
	
	// Check HTTP method
	NSString *method = [(NSString *)CFHTTPMessageCopyRequestMethod(request) autorelease];
    if(![method isEqualToString:@"GET"] && ![method isEqualToString:@"HEAD"])
	{
		[self handleUnknownMethod:method];
        return;
    }
	
	// Extract requested URI
	NSURL *uri = [(NSURL *)CFHTTPMessageCopyRequestURL(request) autorelease];
	
	// Check Authentication (if needed)
	// If not properly authenticated for resource, issue Unauthorized response
	if([self isPasswordProtected:[uri relativeString]] && ![self isAuthenticated])
	{
		NSLog(@"HTTP Server: Error 401 - Unauthorized");
		
		// Status Code 401 - Unauthorized
		CFHTTPMessageRef response = CFHTTPMessageCreateResponse(kCFAllocatorDefault, 401, NULL, kCFHTTPVersion1_1);
		CFHTTPMessageSetHeaderFieldValue(response, CFSTR("Content-Length"), CFSTR("0"));
		
		NSString *authFormat = @"Digest realm=\"%@\", qop=\"auth\", nonce=\"%@\"";
		NSString *authInfo = [NSString stringWithFormat:authFormat, [self realm], [self generateNonce]];
		
		CFHTTPMessageSetHeaderFieldValue(response, CFSTR("WWW-Authenticate"), (CFStringRef)authInfo);
		
		NSData *responseData = [self preprocessErrorResponse:response];
		[asyncSocket writeData:responseData withTimeout:WRITE_ERROR_TIMEOUT tag:HTTP_RESPONSE];
		CFRelease(response);
		return;
	}
	
	
	// ########### CUSTOM CODE
	//NSString *imagesPath = [NSString stringWithFormat:@"%@%@/", [[server documentRoot] relativePath], [relativeURL stringByDeletingLastPathComponent]];
	
	//NSMutableArray *imagesArray = [[NSMutableArray alloc] init];	
	
	// iterate through the directories
	/*NSDirectoryEnumerator *direnum = [[NSFileManager defaultManager] enumeratorAtPath:imagesPath];
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
	}
	NSLog(@"replyToHTTPRequest [imagesArray count]: %d", [imagesArray count]);
	NSLog(@"replyToHTTPRequest [relativePath lastPathComponent]: %@", [relativeURL lastPathComponent]);
	
	int imageIndex = [[relativeURL lastPathComponent] intValue];
	if ([imagesArray count] < 1) {
		return;
	}
	NSLog(@"imageIndex: %d", imageIndex);
	
	NSLog(@"replyToHTTPRequest0 %@", uri);
	//NSString *standardizedString = [(NSString *) CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef) [NSString stringWithFormat:@"%@/%@", [relativeURL stringByDeletingLastPathComponent], [imagesArray objectAtIndex:imageIndex]], CFSTR(""), NULL, kCFStringEncodingUTF8) autorelease];
	//NSString *standardizedString = [[NSString stringWithFormat:@"%@/%@", [relativeURL stringByDeletingLastPathComponent], [imagesArray objectAtIndex:imageIndex]] stringByStandardizingPath];
	//NSLog(@"standardizedString: %@", standardizedString);
	NSString *standardizedString = [[NSString stringWithFormat:@"%@/%@", [relativeURL stringByDeletingLastPathComponent], [imagesArray objectAtIndex:imageIndex]] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	
	uri = [NSURL URLWithString:standardizedString];
	*/
	NSLog(@"replyToHTTPRequest1 %@", uri);
	
	uri = [DirectoryHandler searchFileInDirectories:uri andDocumentRoot:[server documentRoot]];
	
	// Respond properly to HTTP 'GET' and 'HEAD' commands
	NSData *customData = [self dataForURI:uri];
	UInt64 contentLength;
	if(customData != NULL)
	{
		contentLength = (UInt64)[customData length];
		if(contentLength == 0)
		{
			contentLength = [self contentLengthForURI:uri];
		}
	} else {
		contentLength = 0;
	}
	
	if(contentLength == 0)
	{
		NSLog(@"HTTP Server: Error 404 - Not Found");
		
		// Status Code 404 - Not Found
		CFHTTPMessageRef response = CFHTTPMessageCreateResponse(kCFAllocatorDefault, 404, NULL, kCFHTTPVersion1_1);
		CFHTTPMessageSetHeaderFieldValue(response, CFSTR("Content-Length"), CFSTR("0"));
		NSData *responseData = [self preprocessErrorResponse:response];
		[asyncSocket writeData:responseData withTimeout:WRITE_ERROR_TIMEOUT tag:HTTP_RESPONSE];
		CFRelease(response);
		return;
    }
	
	
	/* ################################## */
	
	NSLog(@"replyToHTTPRequest2 %@", [uri relativeString]);
	NSString *realName = [uri relativeString];
	unsigned int ch;
	char ext_temp;
	NSString *ext;
	NSBitmapImageFileType ty;
	
	// detect file extension and choose its image file representation
	for (ch = [realName length]; (ext_temp = [realName characterAtIndex:(ch - 1)]) != '.'; ch--);
	ext = [[realName lowercaseString] substringFromIndex:ch];
	if ([ext isEqualToString:@"tif"] || [ext isEqualToString:@"tiff"])
		ty = NSTIFFFileType;
	else if ([ext isEqualToString:@"bmp"])
		ty = NSBMPFileType;
	else if ([ext isEqualToString:@"gif"])
		ty = NSGIFFileType;
	else if ([ext isEqualToString:@"jpg"] || [ext isEqualToString:@"jpeg"])
		ty = NSJPEGFileType;
	else if ([ext isEqualToString:@"png"])
		ty = NSPNGFileType;
	else {
		ty = NSJPEGFileType;
		// none of the above
	}
	
	// resize the image
	NSData *repFileType;
	float resizeWidth = 160.0;
	float resizeHeight = 208.0;
	//float resizeWidth = 320.0;
	//float resizeHeight = 416.0;
	
	NSImage *sourceImage = [[NSImage alloc] initWithData: customData];
	NSImage *resizedImage = [[NSImage alloc] initWithSize: NSMakeSize(resizeWidth, resizeHeight)];
	
	NSSize originalSize = [sourceImage size];
	
	[resizedImage lockFocus];
	[sourceImage drawInRect: NSMakeRect(0, 0, resizeWidth, resizeHeight) fromRect: NSMakeRect(0, 0, originalSize.width, originalSize.height) operation: NSCompositeSourceOver fraction: 1.0];
	[resizedImage unlockFocus];
	
	NSData *resizedData = [resizedImage TIFFRepresentation];
	NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithData:resizedData];
	NSDictionary *imageProps = [NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:0.7] forKey:NSImageCompressionFactor];
	repFileType = [rep representationUsingType:ty properties:imageProps];
	
	[rep release];
	[sourceImage release];
	[resizedImage release];
	//} else {
	// file ist not an image file (png, jpg etc.)
	//	repFileType = data;
	//}
	
	contentLength = (UInt64)[repFileType length];
	
	/* ################################################ */
	
	// Status Code 200 - OK
	CFHTTPMessageRef response = CFHTTPMessageCreateResponse(kCFAllocatorDefault, 200, NULL, kCFHTTPVersion1_1);
	
	// set the correct mime type
	if(ty == NSJPEGFileType)
		CFHTTPMessageSetHeaderFieldValue(response, (CFStringRef)@"Content-Type", (CFStringRef)@"image/jpeg");
	if(ty == NSPNGFileType)
		CFHTTPMessageSetHeaderFieldValue(response, (CFStringRef)@"Content-Type", (CFStringRef)@"image/png");
	if(ty == NSGIFFileType)
		CFHTTPMessageSetHeaderFieldValue(response, (CFStringRef)@"Content-Type", (CFStringRef)@"image/gif");
	if(ty == NSTIFFFileType)
		CFHTTPMessageSetHeaderFieldValue(response, (CFStringRef)@"Content-Type", (CFStringRef)@"image/tiff");
	if(ty == NSBMPFileType)
		CFHTTPMessageSetHeaderFieldValue(response, (CFStringRef)@"Content-Type", (CFStringRef)@"image/bmp");
	
	NSString *contentLengthStr = [NSString stringWithFormat:@"%qu", contentLength];
	CFHTTPMessageSetHeaderFieldValue(response, CFSTR("Content-Length"), (CFStringRef)contentLengthStr);
    
	// If they issue a 'HEAD' command, we don't have to include the file
	// If they issue a 'GET' command, we need to include the file
	if([method isEqual:@"HEAD"])
	{
		NSData *responseData = [self preprocessResponse:response];
		[asyncSocket writeData:responseData withTimeout:WRITE_HEAD_TIMEOUT tag:HTTP_RESPONSE];
	}
	else
	{
		// Write the header response
		
		NSData *responseData = [self preprocessResponse:response];
		[asyncSocket writeData:responseData withTimeout:WRITE_HEAD_TIMEOUT tag:HTTP_PARTIAL_RESPONSE_HEADER];
		
		// Now we need to send the file
		if(repFileType)
		{
			[asyncSocket writeData:repFileType withTimeout:WRITE_BODY_TIMEOUT tag:HTTP_RESPONSE];
		}
		else
		{
			fileResponse = [[self fileForURI:uri] retain];
			NSData *fileData = [fileResponse readDataOfLength:READ_CHUNKSIZE];
			[asyncSocket writeData:fileData withTimeout:WRITE_BODY_TIMEOUT tag:HTTP_PARTIAL_RESPONSE_BODY];
		}
	}
	
	NSLog(@"replyToHTTPRequest call ended!");
	NSLog(@"##############################");
	CFRelease(response);
}

/**
 * Converts relative URI path into full file-system path.
**/
- (NSString *)filePathForURI:(NSURL *)url
{
	// Override me to perform custom path mapping.
	// For example you may want to use a default file other than index.html, or perhaps support multiple types.
	
	// If there is no configured documentRoot, then it makes no sense to try to return anything
	if(![server documentRoot]) return nil;
	
	// Convert path to a relative path.
	// This essentially means trimming beginning '/' characters.
	// Beware of a bug in the Cocoa framework:
	// 
	// [NSURL URLWithString:@"/foo" relativeToURL:baseURL]       == @"/baseURL/foo"
	// [NSURL URLWithString:@"/foo%20bar" relativeToURL:baseURL] == @"/foo bar"
	// [NSURL URLWithString:@"/foo" relativeToURL:baseURL]       == @"/foo"
	
	NSString *relativePath = [url path];
	
	while([relativePath hasPrefix:@"/"] && [relativePath length] > 1)
	{
		relativePath = [relativePath substringFromIndex:1];
	}
	
	//if ([relativePath hasPrefix:@"/"]) relativePath = [@"." stringByAppendingString:relativePath];
	
	if([relativePath hasSuffix:@"/"])
	{
		url = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@%@", [server documentRoot], relativePath]];
	}
	else
	{
		url = [NSURL URLWithString:relativePath relativeToURL:[server documentRoot]];
	}
	
	// Watch out for sneaky requests with ".." in the path
	// For example, the following request: "../Documents/TopSecret.doc"
	if(![[url path] hasPrefix:[[server documentRoot] path]]) return nil;
	return [url path];
}

/**
 * If the dataForURI method returns nil, then this method is consulted to obtain a file size.
 * If this method returns 0, then a 404 error is returned.
**/
- (UInt64)contentLengthForURI:(NSURL *)url
{
	NSString *filePath = [self filePathForURI:url];
	
	
	NSError *error;
	NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:&error];
	//NSDictionary *attributes = [[NSFileManager defaultManager] fileAttributesAtPath:filePath traverseLink:NO];
	
	NSNumber *fileSize = [attributes objectForKey:NSFileSize];
	
	return (UInt64)[fileSize unsignedLongLongValue];
}

/**
 * This method is called to get a file handle for a request.
 * This is the preferred way to serve files straight from disk, especially large files.
**/
- (NSFileHandle *)fileForURI:(NSURL *)url
{	
	return [NSFileHandle fileHandleForReadingAtPath:[url path]];
}

/**
 * This method is called first during requests.
 * Use this method to return custom non-file data.
 * The fileForURI method is better equipped to serve files straight from disk.
**/
- (NSData *)dataForURI:(NSURL *)url
{
	// If there is no configured documentRoot, then it makes no sense to try to return anything
	if(![server documentRoot]) return nil;
	
	//if ([path hasPrefix:@"/"]) path = [@"." stringByAppendingString:path];
	
	//if([url pathExtension:@"/"])
	//{
	//	NSString *newPath = [url stringByAppendingString:@"index.html"];
	//	url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", [server documentRoot], newPath]];
	//}
	//else
	//{
	NSLog(@"dataForURI %@", url);
	
	if(url == NULL)
	{
		return NULL;
	}
	
	//url = [[server documentRoot] URLByAppendingPathComponent:[url path]];
	
	// Watch out for sneaky requests with ".." in the path
	// For example, the following request: "../Documents/TopSecret.doc"
	//if(![[url path] hasPrefix:[[server documentRoot] path]]) return nil;
	
	// We don't want to map the file data into ram
	// We just want to map it from the disk, and we also don't need to bother caching it
	int options = NSMappedRead | NSUncachedRead;
	return [NSData dataWithContentsOfURL:url options:options error:nil];
}



/**
 * Called if we receive some sort of malformed HTTP request.
 * The data parameter is the invalid HTTP header line, including CRLF, as read from AsyncSocket.
**/
- (void)handleInvalidRequest:(NSData *)data
{
	// Override me for custom error handling of invalid HTTP requests
	
	NSLog(@"HTTP Server: Error 400 - Bad Request");
	
	// Status Code 400 - Bad Request
	CFHTTPMessageRef response = CFHTTPMessageCreateResponse(kCFAllocatorDefault, 400, NULL, kCFHTTPVersion1_1);
	CFHTTPMessageSetHeaderFieldValue(response, CFSTR("Content-Length"), CFSTR("0"));
	NSData *responseData = [self preprocessErrorResponse:response];
	[asyncSocket writeData:responseData withTimeout:WRITE_ERROR_TIMEOUT tag:HTTP_FINAL_RESPONSE];
	CFRelease(response);
	
	// Close connection as soon as the error message is sent
	[asyncSocket disconnectAfterWriting];
}

/**
 * Called if we receive a HTTP request with a method other than GET or HEAD.
**/
- (void)handleUnknownMethod:(NSString *)method
{
	// Override me to add support for methods other than GET and HEAD
	
	NSLog(@"HTTP Server: Error 405 - Method Not Allowed: %@", method);
	
	// Status code 405 - Method Not Allowed
    CFHTTPMessageRef response = CFHTTPMessageCreateResponse(kCFAllocatorDefault, 405, NULL, kCFHTTPVersion1_1);
	CFHTTPMessageSetHeaderFieldValue(response, CFSTR("Content-Length"), CFSTR("0"));
	NSData *responseData = [self preprocessErrorResponse:response];
	[asyncSocket writeData:responseData withTimeout:WRITE_ERROR_TIMEOUT tag:HTTP_RESPONSE];
    CFRelease(response);
}

- (NSData *)preprocessResponse:(CFHTTPMessageRef)response
{
	// Override me to customize the response
	// You may want to add mime types, etc
	
	NSData *result = (NSData *)CFHTTPMessageCopySerializedMessage(response);
	return [result autorelease];
}

- (NSData *)preprocessErrorResponse:(CFHTTPMessageRef)response;
{
	// Override me to customize the error response
	
	NSData *result = (NSData *)CFHTTPMessageCopySerializedMessage(response);
	return [result autorelease];
}

- (void)die
{
	// Post notification of dead connection
	// This will allow our server to release us from its array of connections
	[[NSNotificationCenter defaultCenter] postNotificationName:HTTPConnectionDidDieNotification object:self];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark AsyncSocket Delegate Methods:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * This method is called immediately prior to opening up the stream.
 * This is the time to manually configure the stream if necessary.
**/
- (BOOL)onSocketWillConnect:(AsyncSocket *)sock
{
	if([self isSecureServer])
	{
		NSArray *certificates = [self sslIdentityAndCertificates];
		
		if([certificates count] > 0)
		{
			NSLog(@"Securing connection...");
			
			// All connections are assumed to be secure. Only secure connections are allowed on this server.
			NSMutableDictionary *settings = [NSMutableDictionary dictionaryWithCapacity:3];
			
			// Configure this connection as the server
			CFDictionaryAddValue((CFMutableDictionaryRef)settings,
								 kCFStreamSSLIsServer, kCFBooleanTrue);
			
			CFDictionaryAddValue((CFMutableDictionaryRef)settings,
								 kCFStreamSSLCertificates, (CFArrayRef)certificates);
			
			// Configure this connection to use the highest possible SSL level
			CFDictionaryAddValue((CFMutableDictionaryRef)settings,
								 kCFStreamSSLLevel, kCFStreamSocketSecurityLevelNegotiatedSSL);
			
			CFReadStreamSetProperty([asyncSocket getCFReadStream],
									kCFStreamPropertySSLSettings, (CFDictionaryRef)settings);
			CFWriteStreamSetProperty([asyncSocket getCFWriteStream],
									 kCFStreamPropertySSLSettings, (CFDictionaryRef)settings);
		}
	}
	return YES;
}

/**
 * This method is called after the socket has successfully read data from the stream.
 * Remember that this method will only be called after the socket reaches a CRLF, or after it's read the proper length.
**/
- (void)onSocket:(AsyncSocket *)sock didReadData:(NSData*)data withTag:(long)tag
{
	// Append the header line to the http message
	BOOL result = CFHTTPMessageAppendBytes(request, [data bytes], [data length]);
	if(!result)
	{
		// We have a received a malformed request
		[self handleInvalidRequest:data];
	}
	else if(!CFHTTPMessageIsHeaderComplete(request))
	{
		// We don't have a complete header yet
		// That is, we haven't yet received a CRLF on a line by itself, indicating the end of the header
		[asyncSocket readDataToData:[AsyncSocket CRLFData] withTimeout:READ_TIMEOUT tag:HTTP_REQUEST];
	}
	else
	{
		// We have an entire HTTP request from the client
		// Now we need to reply to it
		[self replyToHTTPRequest];
	}
}

/**
 * This method is called after the socket has successfully written data to the stream.
 * Remember that this method will be called after a complete response to a request has been written.
**/
- (void)onSocket:(AsyncSocket *)sock didWriteDataWithTag:(long)tag
{
	BOOL doneSendingResponse = NO;
	
	if(tag == HTTP_PARTIAL_RESPONSE_BODY)
	{
		// We only wrote a part of the file - there may be more.
		NSData *data = [fileResponse readDataOfLength:READ_CHUNKSIZE];
		
		if([data length] > 0)
		{
			[asyncSocket writeData:data withTimeout:WRITE_BODY_TIMEOUT tag:HTTP_PARTIAL_RESPONSE_BODY];
		}
		else
		{
			[fileResponse closeFile];
			[fileResponse release];
			fileResponse = nil;
			
			doneSendingResponse = YES;
		}
	}
	else if(tag == HTTP_RESPONSE)
	{
		doneSendingResponse = YES;
	}
	
	if(doneSendingResponse)
	{
		// Release the old request, and create a new one
		if(request) CFRelease(request);
		request = CFHTTPMessageCreateEmpty(kCFAllocatorDefault, YES);
		
		// And start listening for more requests
		[asyncSocket readDataToData:[AsyncSocket CRLFData] withTimeout:READ_TIMEOUT tag:HTTP_REQUEST];
	}
}

/**
 * This message is sent:
 *  - if there is an connection, time out, or other i/o error.
 *  - if the remote socket cleanly disconnects.
 *  - before the local socket is disconnected.
**/
- (void)onSocket:(AsyncSocket *)sock willDisconnectWithError:(NSError *)err
{
	if(err)
	{
		//NSLog(@"HTTPConnection:willDisconnectWithError: %@", err);
	}
}

/**
 * Sent after the socket has been disconnected.
**/
- (void)onSocketDidDisconnect:(AsyncSocket *)sock
{
	[self die];
}

@end
