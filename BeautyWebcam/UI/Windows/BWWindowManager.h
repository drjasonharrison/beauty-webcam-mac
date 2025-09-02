//
//  BWWindowManager.h
//  BeautyWebcam
//
//  Created by BeautyWebcam on 2024.
//  Copyright © 2024 BeautyWebcam. All rights reserved.
//

#import <Foundation/Foundation.h>

@class BWApplicationCoordinator;

NS_ASSUME_NONNULL_BEGIN

/**
 * Centralized window management for all application windows
 */
@interface BWWindowManager : NSObject

@property (nonatomic, weak) BWApplicationCoordinator *applicationCoordinator;

/**
 * Shared window manager instance
 */
+ (instancetype)sharedManager;

/**
 * Show the main settings window
 */
- (void)showSettingsWindow;

/**
 * Show the live camera preview window
 */
- (void)showPreviewWindow;

/**
 * Hide the live camera preview window
 */
- (void)hidePreviewWindow;

/**
 * Show the performance monitor window
 */
- (void)showPerformanceMonitor;

/**
 * Show the help window
 */
- (void)showHelpWindow;

/**
 * Close all windows
 */
- (void)closeAllWindows;

@end

NS_ASSUME_NONNULL_END
