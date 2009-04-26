#import "FullScreenWindow.h"

@implementation FullScreenWindow

// Code derived from here: http://www.cocoadev.com/index.pl?CoregraphicsFullscreen

//In Interface Builder we set CustomWindow to be the class for our window, so our own initializer is called here.
- (id)initWithContentRect:(NSRect)contentRect styleMask:(unsigned int)aStyle backing:(NSBackingStoreType)bufferingType defer:(BOOL)flag {
	
    NSWindow* result = [super initWithContentRect:contentRect styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO];
    //Set the background color to clear so that (along with the setOpaque call below) we can see through the parts
    //of the window that we're not drawing into
    [result setBackgroundColor: [NSColor blackColor]];
    //This next line pulls the window up to the front on top of other system windows.  This is how the Clock app behaves;
    //generally you wouldn't do this for windows unless you really wanted them to float above everything.
    [result setLevel: NSScreenSaverWindowLevel];
    //Let's start with no transparency for all drawing into the window
    [result setAlphaValue:1.0];
    //but let's turn off opaqueness so that we can see through the parts of the window that we're not drawing into
    [result setOpaque:NO];
    //and while we're at it, make sure the window has no shadow
    [result setHasShadow:NO];
      
    NSRect  screenFrame = [[NSScreen mainScreen] frame];
    [self setFrame:screenFrame display:YES];
    
    return result;
}

// Custom windows that use the NSBorderlessWindowMask can't become key by default.  Therefore, controls in such windows
// won't ever be enabled by default.  Thus, we override this method to change that.
- (BOOL) canBecomeKeyWindow
{
    return YES;
}

@end
