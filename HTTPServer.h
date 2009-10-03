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


#import <Foundation/Foundation.h>
#import "DirectoryHandler.h"

@class AsyncSocket;

@interface HTTPServer : NSObject <NSNetServiceDelegate>
{
	// Underlying asynchronous TCP/IP socket
	AsyncSocket *asyncSocket;
	
	// Standard delegate
	id delegate;
	
	// HTTP server configuration
	NSURL *documentRoot;
	Class connectionClass;
	
	// NSNetService and related variables
	NSNetService *netService;
    NSString *domain;
	NSString *type;
    NSString *name;
	UInt16 port;
	NSDictionary *txtRecordDictionary;
	
	NSMutableArray *runLoops;
	NSMutableArray *runLoopsLoad;
	NSMutableArray *connections;
}

- (id)delegate;
- (void)setDelegate:(id)newDelegate;

- (NSURL *)documentRoot;
- (void)setDocumentRoot:(NSURL *)value;

- (Class)connectionClass;
- (void)setConnectionClass:(Class)value;

- (NSString *)domain;
- (void)setDomain:(NSString *)value;

- (NSString *)type;
- (void)setType:(NSString *)value;

- (NSString *)name;
- (void)setName:(NSString *)value;

- (UInt16)port;
- (void)setPort:(UInt16)value;

- (NSDictionary *)TXTRecordDictionary;
- (void)setTXTRecordDictionary:(NSDictionary *)dict;

- (BOOL)start:(NSError **)error;
- (BOOL)stop;

- (int)numberOfHTTPConnections;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface HTTPConnection : NSObject
{
	AsyncSocket *asyncSocket;
	HTTPServer *server;
	
	CFHTTPMessageRef request;
	
	NSString *nonce;
	int lastNC;
	
	NSFileHandle *fileResponse;
}

- (id)initWithAsyncSocket:(AsyncSocket *)newSocket forServer:(HTTPServer *)myServer;

- (BOOL)isSecureServer;

- (NSArray *)sslIdentityAndCertificates;

- (BOOL)isPasswordProtected:(NSString *)path;

- (NSString *)realm;
- (NSString *)passwordForUser:(NSString *)username;

- (NSString *)filePathForURI:(NSURL *)url;

- (UInt64)contentLengthForURI:(NSURL *)url;
- (NSFileHandle *)fileForURI:(NSURL *)url;
- (NSData *)dataForURI:(NSURL *)url;

- (void)handleInvalidRequest:(NSData *)data;

- (void)handleUnknownMethod:(NSString *)method;

- (NSData *)preprocessResponse:(CFHTTPMessageRef)response;
- (NSData *)preprocessErrorResponse:(CFHTTPMessageRef)response;

- (void)die;

@end
