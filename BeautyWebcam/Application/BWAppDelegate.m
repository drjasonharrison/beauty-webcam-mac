//
//  BWAppDelegate.m
//  BeautyWebcam
//
//  Created by BeautyWebcam on 2024.
//  Copyright © 2024 BeautyWebcam. All rights reserved.
//

#import "BWAppDelegate.h"
#import "BWMenuBarManager.h"
#import "BWApplicationCoordinator.h"
#import "../UI/Windows/BWWindowManager.h"

@implementation BWAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Initialize application coordinator
    self.applicationCoordinator = [[BWApplicationCoordinator alloc] init];
    
    // Set up menu bar interface
    self.menuBarManager = [[BWMenuBarManager alloc] init];
    self.menuBarManager.delegate = self;
    [self.menuBarManager setupMenuBar];
    
    // Hide dock icon - we're a menu bar only app
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    
    NSLog(@"BeautyWebcam started successfully");
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Clean up resources
    [[BWWindowManager sharedManager] closeAllWindows];
    [self.applicationCoordinator shutdown];
    NSLog(@"BeautyWebcam terminated");
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    // Don't terminate when windows close - we're a menu bar app
    return NO;
}

#pragma mark - BWMenuBarDelegate

- (void)menuBarDidToggleEnhancement:(BOOL)enabled {
    NSLog(@"App Delegate: Enhancement toggled to %@", enabled ? @"ON" : @"OFF");
    
    // DEBUG: Check if applicationCoordinator exists
    NSLog(@"🔍 DEBUG: applicationCoordinator = %@", self.applicationCoordinator);
    if (!self.applicationCoordinator) {
        NSLog(@"❌ CRITICAL ERROR: applicationCoordinator is NIL!");
        return;
    }
    
    [self.applicationCoordinator setEnhancementEnabled:enabled];
    
    if (enabled) {
        // Start video processing when enhancement is enabled
        NSLog(@"🚀 App Delegate: About to start video processing...");
        NSLog(@"🔍 DEBUG: Calling [applicationCoordinator startVideoProcessingWithError:]...");
        NSError *error;
        BOOL success = [self.applicationCoordinator startVideoProcessingWithError:&error];
        NSLog(@"🎬 App Delegate: startVideoProcessingWithError returned: %@", success ? @"SUCCESS" : @"FAILED");
        if (!success) {
            NSLog(@"❌ Failed to start video processing: %@", error);
            // TODO: Show error alert to user
        } else {
            NSLog(@"✅ Video processing started successfully from App Delegate");
        }
    } else {
        // Stop video processing when enhancement is disabled
        NSLog(@"🛑 App Delegate: Stopping video processing...");
        [self.applicationCoordinator stopVideoProcessing];
    }
}

- (void)menuBarDidSelectPreset:(NSString *)presetName {
    NSLog(@"App Delegate: Preset selected: %@", presetName);
    [self.applicationCoordinator loadPreset:presetName];
}

- (void)menuBarDidRequestSettings {
    NSLog(@"App Delegate: Settings requested");
    [[BWWindowManager sharedManager] showSettingsWindow];
}

- (void)menuBarDidRequestPreview {
    NSLog(@"App Delegate: Preview requested");
    // Set up coordinator reference for window manager
    [BWWindowManager sharedManager].applicationCoordinator = self.applicationCoordinator;
    [[BWWindowManager sharedManager] showPreviewWindow];
}

- (void)menuBarDidRequestPerformanceMonitor {
    NSLog(@"App Delegate: Performance monitor requested");
    [[BWWindowManager sharedManager] showPerformanceMonitor];
}

- (void)menuBarDidRequestHelp {
    NSLog(@"App Delegate: Help requested");
    [[BWWindowManager sharedManager] showHelpWindow];
}

- (void)menuBarDidRequestQuit {
    NSLog(@"App Delegate: Quit requested");
    [NSApp terminate:nil];
}

@end
