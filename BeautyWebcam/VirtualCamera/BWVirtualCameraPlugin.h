//
//  BWVirtualCameraPlugin.h
//  BeautyWebcam
//
//  Created by BeautyWebcam on 2024.
//  Copyright © 2024 BeautyWebcam. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMediaIO/CoreMediaIO.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const BWVirtualCameraPluginName;
extern NSString *const BWVirtualCameraDeviceName;
extern NSString *const BWVirtualCameraDeviceUID;

/**
 * Main plugin class for CoreMediaIO virtual camera implementation.
 * Manages the virtual camera device lifecycle and integration with the system.
 */
@interface BWVirtualCameraPlugin : NSObject

@property (nonatomic, strong, readonly) NSUUID *pluginUUID;
@property (nonatomic, strong, readonly) NSString *pluginName;
@property (nonatomic, assign, readonly) CMIOObjectID deviceObjectID;
@property (nonatomic, assign, readonly) BOOL isDeviceCreated;

/**
 * Shared singleton instance
 */
+ (instancetype)sharedPlugin;

/**
 * Initialize the CoreMediaIO plugin and register with the system
 */
- (BOOL)initializePluginWithError:(NSError **)error;

/**
 * Create the virtual camera device
 */
- (BOOL)createVirtualDeviceWithError:(NSError **)error;

/**
 * Destroy the virtual camera device
 */
- (void)destroyVirtualDevice;

/**
 * Clean up and unregister the plugin
 */
- (void)teardownPlugin;

/**
 * Send a video frame to the virtual camera
 */
- (BOOL)sendVideoFrame:(CVPixelBufferRef)pixelBuffer 
             timestamp:(CMTime)timestamp
                 error:(NSError **)error;

/**
 * Start/stop streaming
 */
- (BOOL)startStreamingWithError:(NSError **)error;
- (void)stopStreaming;

@end

NS_ASSUME_NONNULL_END
