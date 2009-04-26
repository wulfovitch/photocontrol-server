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
