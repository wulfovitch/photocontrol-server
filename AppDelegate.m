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

#import "AppDelegate.h"

@implementation AppDelegate

@synthesize selectedDirectory;

- (void)awakeFromNib
{
	// Start from the Pictures directory
	self.selectedDirectory = [NSString stringWithFormat:@"%@/Pictures", NSHomeDirectory()];
	[selectedDirectoryTextField setStringValue:[NSString stringWithFormat:@"\'%@\'", self.selectedDirectory]];
	[selectedDirectoryTextFieldBox setTitle:NSLocalizedString(@"photocontrol server Home Directory", @"photocontrol server Home Directory")];
	[startFullScreenButton setTitle:NSLocalizedString(@"Start Presentation", @"Start Presentation")];
	[selectDirectoryButton setTitle:NSLocalizedString(@"Change", @"Change")];
}

- (IBAction)showOpenPanel:(id)sender
{
	NSOpenPanel* oPanel = [NSOpenPanel openPanel];
	[oPanel setCanChooseDirectories:YES];
	[oPanel setCanChooseFiles:NO];
	[oPanel setCanCreateDirectories:NO];
	[oPanel setAllowsMultipleSelection:NO];
	[oPanel beginSheetForDirectory:nil file:nil modalForWindow:window modalDelegate:self didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (void)openPanelDidEnd:(NSOpenPanel *)openPanel returnCode:(int)returnCode contextInfo:(void *) x
{
	if(returnCode == NSOKButton)
	{
		NSString *path = [openPanel directory];
		self.selectedDirectory = path;
		[selectedDirectoryTextField setStringValue:[NSString stringWithFormat:@"\'%@\'", self.selectedDirectory]];
	}
}

- (IBAction)startPresentation:(id)sender
{
	FullScreenController *fullScreenController = [[FullScreenController alloc] initWithWindowNibName:@"FullScreenWindow" andDirectory:self.selectedDirectory];
	[fullScreenController showWindow:sender];
	[window close];
}

- (void)dealloc
{
	[super dealloc];
}

@end
