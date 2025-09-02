//
//  BWApplicationCoordinator.h
//  BeautyWebcam
//
//  Created by BeautyWebcam on 2024.
//  Copyright © 2024 BeautyWebcam. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class BWCaptureManager;
@class BWVirtualCameraPlugin;
@class BWVideoProcessor;

/**
 * Main application coordinator that manages the overall application lifecycle
 * and coordinates between different subsystems.
 */
@interface BWApplicationCoordinator : NSObject

@property (nonatomic, strong, readonly) BWCaptureManager *captureManager;
@property (nonatomic, strong, readonly) BWVirtualCameraPlugin *virtualCameraPlugin;
@property (nonatomic, strong, readonly) BWVideoProcessor *videoProcessor;
@property (nonatomic, assign, readonly) BOOL enhancementEnabled;

/**
 * Initializes all application subsystems and prepares for operation.
 */
- (void)startup;

/**
 * Gracefully shuts down all subsystems and cleans up resources.
 */
- (void)shutdown;

/**
 * Enables or disables video enhancement processing
 */
- (void)setEnhancementEnabled:(BOOL)enabled;

/**
 * Starts video capture and processing pipeline
 */
- (BOOL)startVideoProcessingWithError:(NSError **)error;

/**
 * Stops video capture and processing pipeline
 */
- (void)stopVideoProcessing;

/**
 * Load a processing preset (Natural, Studio, Creative)
 */
- (void)loadPreset:(NSString *)presetName;

/**
 * Get current processing performance metrics
 */
- (NSDictionary *)getProcessingPerformanceMetrics;

@end

NS_ASSUME_NONNULL_END
