//
//  BWWindowManager.m
//  BeautyWebcam
//
//  Created by BeautyWebcam on 2024.
//  Copyright © 2024 BeautyWebcam. All rights reserved.
//

#import "BWWindowManager.h"
#import "BWSettingsWindowController.h"
#import "BWPreviewWindowController.h"
#import "BWApplicationCoordinator.h"
#import <os/log.h>

static os_log_t bw_window_log(void) {
    static os_log_t log;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        log = os_log_create("com.beautywebcam.windows", "WindowManager");
    });
    return log;
}

@interface BWWindowManager ()

@property (nonatomic, strong) NSWindowController *performanceWindowController;
@property (nonatomic, strong) NSWindowController *helpWindowController;

@end

@implementation BWWindowManager

+ (instancetype)sharedManager {
    static BWWindowManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[BWWindowManager alloc] init];
    });
    return sharedManager;
}

- (instancetype)init {
    if (self = [super init]) {
        os_log_info(bw_window_log(), "🪟 Window manager initialized");
    }
    return self;
}

#pragma mark - Window Management

- (void)showSettingsWindow {
    os_log_info(bw_window_log(), "📋 Showing settings window");
    [BWSettingsWindowController showSettingsWindow];
}

- (void)showPreviewWindow {
    os_log_info(bw_window_log(), "🎬 Showing preview window");
    
    BWPreviewWindowController *previewController = [BWPreviewWindowController sharedController];
    previewController.applicationCoordinator = self.applicationCoordinator;
    [previewController showPreviewWindow];
}

- (void)hidePreviewWindow {
    os_log_info(bw_window_log(), "🛑 Hiding preview window");
    
    BWPreviewWindowController *previewController = [BWPreviewWindowController sharedController];
    [previewController hidePreviewWindow];
}

- (void)showPerformanceMonitor {
    os_log_info(bw_window_log(), "📊 Showing performance monitor");
    
    if (!self.performanceWindowController) {
        [self createPerformanceWindow];
    }
    
    [self.performanceWindowController showWindow:nil];
    [self.performanceWindowController.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)showHelpWindow {
    os_log_info(bw_window_log(), "❓ Showing help window");
    
    if (!self.helpWindowController) {
        [self createHelpWindow];
    }
    
    [self.helpWindowController showWindow:nil];
    [self.helpWindowController.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)closeAllWindows {
    os_log_info(bw_window_log(), "🚪 Closing all windows");
    
    // Close preview window
    [self hidePreviewWindow];
    
    [BWSettingsWindowController hideSettingsWindow];
    
    if (self.performanceWindowController) {
        [self.performanceWindowController.window close];
    }
    
    if (self.helpWindowController) {
        [self.helpWindowController.window close];
    }
}

#pragma mark - Window Creation

- (void)createPerformanceWindow {
    NSRect windowFrame = NSMakeRect(0, 0, 400, 300);
    NSWindow *window = [[NSWindow alloc] initWithContentRect:windowFrame
                                                   styleMask:NSWindowStyleMaskTitled | 
                                                            NSWindowStyleMaskClosable |
                                                            NSWindowStyleMaskMiniaturizable
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    
    window.title = @"Performance Monitor";
    window.titlebarAppearsTransparent = YES;
    [window center];
    
    // Create performance monitor content
    NSView *contentView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 400, 300)];
    
    // Title
    NSTextField *titleLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 250, 360, 30)];
    titleLabel.stringValue = @"Real-time Performance Monitor";
    titleLabel.editable = NO;
    titleLabel.bordered = NO;
    titleLabel.backgroundColor = [NSColor clearColor];
    titleLabel.font = [NSFont boldSystemFontOfSize:16];
    titleLabel.alignment = NSTextAlignmentCenter;
    [contentView addSubview:titleLabel];
    
    // Performance info
    NSTextField *infoLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 50, 360, 180)];
    infoLabel.stringValue = @"🎨 BeautyWebcam Performance Monitor\n\n• Real-time video processing metrics\n• Frame rate monitoring\n• CPU and GPU usage tracking\n• Memory usage optimization\n\nFor detailed metrics, open the Settings window\nand navigate to the Performance tab.\n\nThe system automatically optimizes performance\nbased on your hardware capabilities.";
    infoLabel.editable = NO;
    infoLabel.bordered = NO;
    infoLabel.backgroundColor = [NSColor clearColor];
    infoLabel.font = [NSFont systemFontOfSize:13];
    infoLabel.alignment = NSTextAlignmentLeft;
    [contentView addSubview:infoLabel];
    
    window.contentView = contentView;
    
    self.performanceWindowController = [[NSWindowController alloc] initWithWindow:window];
}

- (void)createHelpWindow {
    NSRect windowFrame = NSMakeRect(0, 0, 500, 400);
    NSWindow *window = [[NSWindow alloc] initWithContentRect:windowFrame
                                                   styleMask:NSWindowStyleMaskTitled | 
                                                            NSWindowStyleMaskClosable |
                                                            NSWindowStyleMaskMiniaturizable
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    
    window.title = @"BeautyWebcam Help";
    window.titlebarAppearsTransparent = YES;
    [window center];
    
    // Create help content
    NSView *contentView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 500, 400)];
    
    // Title
    NSTextField *titleLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 350, 460, 30)];
    titleLabel.stringValue = @"BeautyWebcam Help & Support";
    titleLabel.editable = NO;
    titleLabel.bordered = NO;
    titleLabel.backgroundColor = [NSColor clearColor];
    titleLabel.font = [NSFont boldSystemFontOfSize:18];
    titleLabel.alignment = NSTextAlignmentCenter;
    [contentView addSubview:titleLabel];
    
    // Help content
    NSTextField *helpLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 50, 460, 280)];
    helpLabel.stringValue = @"🎥 Getting Started\n\n1. Toggle Enhancement ON from the menu bar\n2. Select a preset: Natural, Studio, or Creative\n3. Open video apps like Zoom, Teams, or Discord\n4. Select \"BeautyWebcam Virtual Camera\" as your camera\n\n🎛️ Customization\n\n• Open Settings to fine-tune enhancement parameters\n• Adjust skin smoothing, brightness, and color\n• Monitor performance in real-time\n• Switch between different camera devices\n\n📋 Menu Bar Controls\n\n• Click the camera icon to access the menu\n• Toggle enhancement on/off instantly\n• Quick preset switching for different scenarios\n• Access settings and performance monitoring\n\n🔧 Troubleshooting\n\n• If camera appears dark: Grant camera permissions in System Preferences\n• If virtual camera not visible: Restart video applications\n• For performance issues: Lower quality settings or disable enhancement\n\n💡 Tips\n\n• Use \"Natural\" preset for everyday video calls\n• \"Studio\" preset works great for professional meetings\n• \"Creative\" preset adds dramatic enhancement for content creation\n• Monitor performance to ensure smooth video";
    helpLabel.editable = NO;
    helpLabel.bordered = NO;
    helpLabel.backgroundColor = [NSColor clearColor];
    helpLabel.font = [NSFont systemFontOfSize:12];
    helpLabel.alignment = NSTextAlignmentLeft;
    [contentView addSubview:helpLabel];
    
    window.contentView = contentView;
    
    self.helpWindowController = [[NSWindowController alloc] initWithWindow:window];
}

@end
