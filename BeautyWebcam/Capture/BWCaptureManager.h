//
//  BWCaptureManager.h
//  BeautyWebcam
//
//  Created by BeautyWebcam on 2024.
//  Copyright © 2024 BeautyWebcam. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, BWCaptureState) {
    BWCaptureStateIdle,
    BWCaptureStateConfiguring,
    BWCaptureStateRunning,
    BWCaptureStateStopped,
    BWCaptureStateError
};

typedef NS_ENUM(NSInteger, BWVideoQuality) {
    BWVideoQualityLow,      // 640x480
    BWVideoQualityMedium,   // 1280x720
    BWVideoQualityHigh,     // 1920x1080
    BWVideoQualityUltra     // 2560x1440 (if supported)
};

@protocol BWCaptureManagerDelegate <NSObject>
@optional
/**
 * Called when a new video frame is captured and ready for processing
 */
- (void)captureManager:(id)manager didCaptureVideoFrame:(CVPixelBufferRef)pixelBuffer timestamp:(CMTime)timestamp;

/**
 * Called when capture state changes
 */
- (void)captureManager:(id)manager didChangeState:(BWCaptureState)state;

/**
 * Called when an error occurs during capture
 */
- (void)captureManager:(id)manager didEncounterError:(NSError *)error;

/**
 * Called when available cameras change (plug/unplug)
 */
- (void)captureManagerDidUpdateAvailableCameras:(id)manager;
@end

@interface BWCaptureManager : NSObject

@property (nonatomic, weak) id<BWCaptureManagerDelegate> delegate;
@property (nonatomic, assign, readonly) BWCaptureState currentState;
@property (nonatomic, strong, readonly) AVCaptureDevice *currentDevice;
@property (nonatomic, strong, readonly) NSArray<AVCaptureDevice *> *availableDevices;
@property (nonatomic, assign) BWVideoQuality videoQuality;
@property (nonatomic, assign) NSInteger targetFrameRate; // 30 or 60 fps

/**
 * Shared instance for application-wide capture management
 */
+ (instancetype)sharedManager;

/**
 * Initializes capture session and discovers available cameras
 */
- (BOOL)initializeCaptureSessionWithError:(NSError **)error;

/**
 * Starts video capture with the specified device
 */
- (BOOL)startCaptureWithDevice:(AVCaptureDevice *)device error:(NSError **)error;

/**
 * Starts capture with default/preferred device
 */
- (BOOL)startCaptureWithError:(NSError **)error;

/**
 * Stops video capture
 */
- (void)stopCapture;

/**
 * Switches to a different camera device
 */
- (BOOL)switchToDevice:(AVCaptureDevice *)device error:(NSError **)error;

/**
 * Refreshes the list of available camera devices
 */
- (void)refreshAvailableDevices;

/**
 * Updates video quality and reconfigures session if needed
 */
- (BOOL)updateVideoQuality:(BWVideoQuality)quality error:(NSError **)error;

/**
 * Updates target frame rate
 */
- (BOOL)updateFrameRate:(NSInteger)frameRate error:(NSError **)error;

/**
 * Optimize capture settings for performance when enhancements are active
 */
- (void)optimizeCaptureForEnhancements:(BOOL)enhancementsActive;

/**
 * Returns human-readable name for video quality
 */
+ (NSString *)nameForVideoQuality:(BWVideoQuality)quality;

/**
 * Returns resolution for video quality
 */
+ (CMVideoDimensions)dimensionsForVideoQuality:(BWVideoQuality)quality;

@end

NS_ASSUME_NONNULL_END
