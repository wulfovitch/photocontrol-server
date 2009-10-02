//
//  DirectoryHandler.m
//  photocontrol_server
//
//  Created by Wolfgang König on 03.10.09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "DirectoryHandler.h"


@implementation DirectoryHandler


+ (NSURL *)searchFileInDirectories:(NSURL *)url andDocumentRoot:(NSURL *)documentRoot {
	NSLog(@"searchFileInDirectories called with url: %@", url);
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSError *error = nil;
	NSArray *directoryURLs = [fileManager contentsOfDirectoryAtURL:documentRoot
										includingPropertiesForKeys:NULL
														   options:NSDirectoryEnumerationSkipsHiddenFiles | NSDirectoryEnumerationSkipsSubdirectoryDescendants
															 error:&error];
	
	NSArray *pathComponents = [url pathComponents];
	
	if(directoryURLs == nil)
	{
		NSLog(@"empty dir or directory not existant");
		return NULL;
	} else {
		
		for (NSString *component in pathComponents)
		{
			if(![component isEqual:@"/"])
			{
				NSLog(@"%@", component);
				int intIndex;
				BOOL success = [[NSScanner scannerWithString:component] scanInteger:&intIndex];
				if(!success)
				{
					NSLog(@"Not a number");
					return NULL;
				}
				
				// check if that file even exists
				if(intIndex >= [directoryURLs count])
				{
					return NULL;
				}
				NSURL *file = [directoryURLs objectAtIndex:intIndex];
				
				NSNumber *isDirectory = nil;
				[file getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:NULL];
				
				if ([isDirectory boolValue])
				{
					directoryURLs = [fileManager contentsOfDirectoryAtURL:file
											   includingPropertiesForKeys:NULL
																  options:NSDirectoryEnumerationSkipsHiddenFiles | NSDirectoryEnumerationSkipsSubdirectoryDescendants
																	error:&error];
				} else {
					return file;
				}
			}
			
		}
		
	}	
	return NULL;
}

@end
