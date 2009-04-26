#import <Cocoa/Cocoa.h>
#import "SimpleCocoaServer.h"

// Message Object, which contains an message and the corresponding connection

@interface Message : NSObject {
	NSString *message;
	SimpleCocoaConnection *con;
}

@property (nonatomic, retain) NSString *message;
@property (nonatomic, retain) SimpleCocoaConnection *con;

- (id)initWithMessage:(NSString *)msg andConnection:(SimpleCocoaConnection *) connection;
@end
