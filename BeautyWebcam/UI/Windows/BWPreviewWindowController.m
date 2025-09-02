//
//  BWPreviewWindowController.m
//  BeautyWebcam
//
//  Copyright © 2024 BeautyWebcam. All rights reserved.
//

#import "BWPreviewWindowController.h"
#import "BWCameraPreviewView.h"
#import <os/log.h>

static os_log_t bw_preview_window_log(void) {
    static dispatch_once_t once;
    static os_log_t log;
    dispatch_once(&once, ^{
        log = os_log_create("com.beautywebcam.preview", "window");
    });
    return log;
}

@interface BWPreviewWindowController ()

@property (nonatomic, strong) BWCameraPreviewView *previewView;

@end

@implementation BWPreviewWindowController

+ (instancetype)sharedController {
    static BWPreviewWindowController *sharedController = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedController = [[BWPreviewWindowController alloc] init];
    });
    return sharedController;
}

- (instancetype)init {
    // Create window
    NSRect windowFrame = NSMakeRect(100, 100, 480, 360);
    NSWindow *window = [[NSWindow alloc] initWithContentRect:windowFrame
                                                   styleMask:(NSWindowStyleMaskTitled | 
                                                             NSWindowStyleMaskClosable | 
                                                             NSWindowStyleMaskMiniaturizable)
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    
    self = [super initWithWindow:window];
    if (self) {
        [self setupWindow];
        [self setupPreviewView];
    }
    return self;
}

- (void)setupWindow {
    self.window.title = @"BeautyWebcam Live Preview";
    self.window.minSize = NSMakeSize(320, 240);
    self.window.maxSize = NSMakeSize(1280, 720);
    
    // Center window on screen
    [self.window center];
    
    // Configure window appearance
    self.window.titlebarAppearsTransparent = NO;
    self.window.backgroundColor = [NSColor blackColor];
    
    os_log_info(bw_preview_window_log(), "🪟 Preview window setup completed");
}

- (void)setupPreviewView {
    // Create preview view that fills the entire content area
    NSRect contentFrame = self.window.contentView.bounds;
    self.previewView = [[BWCameraPreviewView alloc] initWithFrame:contentFrame];
    
    // Configure autoresizing
    self.previewView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    
    // Add to window
    [self.window.contentView addSubview:self.previewView];
    
    os_log_info(bw_preview_window_log(), "📹 Preview view added to window");
}

#pragma mark - Public Methods

- (void)showPreviewWindow {
    // Set up application coordinator connection
    if (!self.previewView.applicationCoordinator && self.applicationCoordinator) {
        self.previewView.applicationCoordinator = self.applicationCoordinator;
    }
    
    // Show window
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    
    // Start preview
    [self.previewView startPreview];
    
    os_log_info(bw_preview_window_log(), "🎬 Preview window shown and preview started");
}

- (void)hidePreviewWindow {
    // Stop preview
    [self.previewView stopPreview];
    
    // Hide window
    [self.window orderOut:nil];
    
    os_log_info(bw_preview_window_log(), "🛑 Preview window hidden and preview stopped");
}

- (void)setApplicationCoordinator:(BWApplicationCoordinator *)applicationCoordinator {
    _applicationCoordinator = applicationCoordinator;
    
    // Update preview view coordinator if it exists
    if (self.previewView) {
        self.previewView.applicationCoordinator = applicationCoordinator;
        os_log_info(bw_preview_window_log(), "🔗 Preview window coordinator updated");
        
        // If window is visible and preview was active, restart it
        if (self.window.isVisible && self.previewView.isPreviewActive) {
            os_log_info(bw_preview_window_log(), "🔄 Refreshing active preview after coordinator update");
            [self.previewView refreshPreview];
        }
    }
}

#pragma mark - Window Delegate

- (void)windowWillClose:(NSNotification *)notification {
    // Stop preview when window is closed
    [self.previewView stopPreview];
    
    os_log_info(bw_preview_window_log(), "🪟 Preview window will close, stopping preview");
}

- (BOOL)windowShouldClose:(NSWindow *)sender {
    // Hide instead of closing completely so we can reuse the window
    [self hidePreviewWindow];
    return NO;
}

@end
