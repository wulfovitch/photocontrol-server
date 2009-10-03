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

#import "Message.h"

@implementation Message

@synthesize message;
@synthesize con;

- (id)initWithMessage:(NSString *)msg andConnection:(SimpleCocoaConnection *)connection
{
	if(self = [super init])
	{
		[self setMessage:msg];
		[self setCon:connection];
	}
	return self;	
}

-(void) dealloc
{
	[message release];
	[con release];
	[super dealloc];
}

@end
