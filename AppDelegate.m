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
