//
//  BWSettingsWindowController.h
//  BeautyWebcam
//
//  Created by BeautyWebcam on 2024.
//  Copyright © 2024 BeautyWebcam. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class BWApplicationCoordinator;
@class BWVideoProcessor;
@class BWCaptureManager;

/**
 * Main settings window controller with tabbed interface for comprehensive app configuration
 */
@interface BWSettingsWindowController : NSWindowController

@property (nonatomic, weak) BWApplicationCoordinator *applicationCoordinator;

/**
 * Show the settings window (creates if needed)
 */
+ (void)showSettingsWindow;

/**
 * Hide the settings window
 */
+ (void)hideSettingsWindow;

@end

NS_ASSUME_NONNULL_END
