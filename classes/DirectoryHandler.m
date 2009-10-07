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
				NSInteger intIndex;
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
