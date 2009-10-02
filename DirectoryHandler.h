//
//  DirectoryHandler.h
//  photocontrol_server
//
//  Created by Wolfgang König on 03.10.09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface DirectoryHandler : NSObject {

}

+ (NSURL *)searchFileInDirectories:(NSURL *)url andDocumentRoot:(NSURL *)documentRoot;

@end
