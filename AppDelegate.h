#import <Cocoa/Cocoa.h>
#import "FullScreenController.h"

@interface AppDelegate : NSObject {
	
	// Outlets
	IBOutlet NSButton *startFullScreenButton;
	IBOutlet NSButton *selectDirectoryButton;
	IBOutlet NSTextField *selectedDirectoryTextField;
	IBOutlet NSBox *selectedDirectoryTextFieldBox;
	IBOutlet NSWindow *window;
	
	// variables
	NSString *selectedDirectory;
}

@property (nonatomic, retain) NSString *selectedDirectory;

- (IBAction)showOpenPanel:(id)sender;
- (IBAction)startPresentation:(id)sender;

@end
