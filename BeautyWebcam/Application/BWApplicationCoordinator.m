//
//  BWApplicationCoordinator.m
//  BeautyWebcam
//
//  Created by BeautyWebcam on 2024.
//  Copyright © 2024 BeautyWebcam. All rights reserved.
//

#import "BWApplicationCoordinator.h"
#import "../Capture/BWCaptureManager.h"
#import "../VirtualCamera/BWVirtualCameraPlugin.h"
#import "../Processing/BWVideoProcessor.h"
#import <os/log.h>

static os_log_t bw_coordinator_log(void) {
    static os_log_t log;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        log = os_log_create("com.beautywebcam.coordinator", "ApplicationCoordinator");
    });
    return log;
}

@interface BWApplicationCoordinator () <BWCaptureManagerDelegate, BWVideoProcessorDelegate>
@property (nonatomic, strong, readwrite) BWCaptureManager *captureManager;
@property (nonatomic, strong, readwrite) BWVirtualCameraPlugin *virtualCameraPlugin;
@property (nonatomic, strong, readwrite) BWVideoProcessor *videoProcessor;
@property (nonatomic, assign, readwrite) BOOL enhancementEnabled;
@end

@implementation BWApplicationCoordinator

- (instancetype)init {
    if (self = [super init]) {
        [self startup];
    }
    return self;
}

- (void)startup {
    os_log_info(bw_coordinator_log(), "ApplicationCoordinator: Starting up...");
    
    // Initialize capture manager
    self.captureManager = [BWCaptureManager sharedManager];
    self.captureManager.delegate = self;
    
    // Initialize capture session
    NSError *error;
    if (![self.captureManager initializeCaptureSessionWithError:&error]) {
        os_log_error(bw_coordinator_log(), "Failed to initialize capture session: %@", error);
    }
    
    // Initialize virtual camera plugin
    self.virtualCameraPlugin = [BWVirtualCameraPlugin sharedPlugin];
    if (![self.virtualCameraPlugin initializePluginWithError:&error]) {
        os_log_error(bw_coordinator_log(), "Failed to initialize virtual camera plugin: %@", error);
    } else {
        os_log_info(bw_coordinator_log(), "✅ Virtual camera plugin initialized successfully");
    }
    
    // Initialize video processor
    self.videoProcessor = [BWVideoProcessor sharedProcessor];
    self.videoProcessor.delegate = self;
    if (![self.videoProcessor initializeWithError:&error]) {
        os_log_error(bw_coordinator_log(), "Failed to initialize video processor: %@", error);
    } else {
        os_log_info(bw_coordinator_log(), "✅ Video processor initialized successfully");
    }
    
    // Start with enhancement disabled by default
    self.enhancementEnabled = NO;
    
    // TODO: Initialize settings manager
    
    os_log_info(bw_coordinator_log(), "ApplicationCoordinator: Startup complete");
}

- (void)shutdown {
    os_log_info(bw_coordinator_log(), "ApplicationCoordinator: Shutting down...");
    
    // Stop video processing
    [self stopVideoProcessing];
    
    // Shutdown virtual camera
    [self.virtualCameraPlugin teardownPlugin];
    
    // Shutdown video processor
    [self.videoProcessor shutdown];
    
    // TODO: Save settings
    
    os_log_info(bw_coordinator_log(), "ApplicationCoordinator: Shutdown complete");
}

- (void)setEnhancementEnabled:(BOOL)enabled {
    if (_enhancementEnabled != enabled) {
        _enhancementEnabled = enabled;
        os_log_info(bw_coordinator_log(), "Enhancement %@", enabled ? @"enabled" : @"disabled");
        
        // Enable/disable video processing
        [self.videoProcessor setProcessingEnabled:enabled];
        
        // Optimize capture settings based on enhancement state
        [self.captureManager optimizeCaptureForEnhancements:enabled];
        
        // TODO: Update menu bar status
    }
}

- (BOOL)startVideoProcessingWithError:(NSError **)error {
    NSLog(@"🎬 ========== METHOD ENTRY TEST ==========");
    NSLog(@"🎬 startVideoProcessingWithError: method entered successfully!");
    
    os_log_info(bw_coordinator_log(), "🎬 ========== STARTING VIDEO PROCESSING PIPELINE ==========");
    os_log_info(bw_coordinator_log(), "🎬 Starting video processing...");
    
    NSLog(@"🔍 About to check camera permissions...");
    
    // Check camera permission first
    os_log_info(bw_coordinator_log(), "🔍 Checking camera permissions...");
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    
    NSLog(@"📷 Camera permission status: %ld", (long)status);
    os_log_info(bw_coordinator_log(), "📷 Camera permission status: %ld (0=NotDetermined, 1=Restricted, 2=Denied, 3=Authorized)", (long)status);
    
    switch (status) {
        case AVAuthorizationStatusNotDetermined: {
            os_log_info(bw_coordinator_log(), "📷 Camera permission not determined, requesting access...");
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (granted) {
                        os_log_info(bw_coordinator_log(), "✅ Camera permission granted");
                        [self startVideoProcessingWithError:nil];
                    } else {
                        os_log_error(bw_coordinator_log(), "❌ Camera permission denied");
                    }
                });
            }];
            return YES; // Will retry after permission response
        }
            
        case AVAuthorizationStatusDenied:
        case AVAuthorizationStatusRestricted:
            os_log_error(bw_coordinator_log(), "❌ Camera permission denied or restricted");
            if (error) {
                *error = [NSError errorWithDomain:@"BWApplicationCoordinator" 
                                             code:-1 
                                         userInfo:@{NSLocalizedDescriptionKey: @"Camera access denied. Please enable camera access in System Preferences > Privacy & Security > Camera."}];
            }
            return NO;
            
        case AVAuthorizationStatusAuthorized:
            os_log_info(bw_coordinator_log(), "✅ Camera permission already granted");
            break;
    }
    
    // List available cameras
    os_log_info(bw_coordinator_log(), "📱 Getting available cameras...");
    NSArray<AVCaptureDevice *> *devices = self.captureManager.availableDevices;
    os_log_info(bw_coordinator_log(), "📹 Found %lu available cameras", (unsigned long)devices.count);
    for (AVCaptureDevice *device in devices) {
        os_log_info(bw_coordinator_log(), "  - %@ (%@)", device.localizedName, device.uniqueID);
    }
    
    // Start capture with default device
    os_log_info(bw_coordinator_log(), "🎥 About to call captureManager startCaptureWithError...");
    BOOL captureSuccess = [self.captureManager startCaptureWithError:error];
    os_log_info(bw_coordinator_log(), "📹 captureManager startCaptureWithError returned: %@", captureSuccess ? @"SUCCESS" : @"FAILED");
    
    if (!captureSuccess) {
        os_log_error(bw_coordinator_log(), "❌ Failed to start capture: %@", error ? *error : nil);
        return NO;
    }
    
    // Start virtual camera streaming
    os_log_info(bw_coordinator_log(), "🎬 Starting virtual camera streaming...");
    BOOL virtualCameraSuccess = [self.virtualCameraPlugin startStreamingWithError:error];
    os_log_info(bw_coordinator_log(), "📺 Virtual camera streaming: %@", virtualCameraSuccess ? @"SUCCESS" : @"FAILED");
    
    if (!virtualCameraSuccess) {
        os_log_error(bw_coordinator_log(), "⚠️ Virtual camera failed to start, but continuing with capture only");
        // Don't fail the whole operation - capture can work without virtual camera
    }
    
    os_log_info(bw_coordinator_log(), "🎉 ========== VIDEO PROCESSING PIPELINE STARTED ==========");
    os_log_info(bw_coordinator_log(), "📹 Camera capture: ACTIVE");
    os_log_info(bw_coordinator_log(), "🎬 Virtual camera: %@", virtualCameraSuccess ? @"ACTIVE" : @"INACTIVE");
    os_log_info(bw_coordinator_log(), "🎨 Enhancement enabled: %@", self.enhancementEnabled ? @"YES" : @"NO");
    os_log_info(bw_coordinator_log(), "========================================================");
    return YES;
}

- (void)stopVideoProcessing {
    os_log_info(bw_coordinator_log(), "🛑 Stopping video processing...");
    
    // Stop virtual camera streaming
    [self.virtualCameraPlugin stopStreaming];
    os_log_info(bw_coordinator_log(), "🎬 Virtual camera streaming stopped");
    
    // Stop capture
    [self.captureManager stopCapture];
    os_log_info(bw_coordinator_log(), "📹 Camera capture stopped");
}

#pragma mark - BWCaptureManagerDelegate

- (void)captureManager:(id)manager didCaptureVideoFrame:(CVPixelBufferRef)pixelBuffer timestamp:(CMTime)timestamp {
    static int frameCount = 0;
    frameCount++;
    
    @autoreleasepool {
        CVPixelBufferRef frameToSend = pixelBuffer; // Default to original frame
        NSError *error;
        
        if (self.enhancementEnabled) {
            // Submit frame for async processing (non-blocking)
            // This will update cached processed frames in the background
            [self.videoProcessor submitFrameForAsyncProcessing:pixelBuffer timestamp:timestamp];
            
            // For now, send the original frame to maintain smooth output
            // The async processing will improve future frames
            frameToSend = pixelBuffer;
        }
        
        // Send frame to virtual camera (never blocked by processing!)
        BOOL success = [self.virtualCameraPlugin sendVideoFrame:frameToSend 
                                                       timestamp:timestamp 
                                                           error:&error];
        
        // Log every 30 frames (once per second at 30fps)
        if (frameCount % 30 == 0) {
            size_t width = CVPixelBufferGetWidth(frameToSend);
            size_t height = CVPixelBufferGetHeight(frameToSend);
            
            NSString *processingStatus = self.enhancementEnabled ? @"🚀 ASYNC ENHANCED" : @"📹 DIRECT";
            
            os_log_info(bw_coordinator_log(), "🎬 Frame %d: %zux%zu, %@ → Virtual Camera: %@", 
                       frameCount, width, height, processingStatus, success ? @"✅" : @"❌");
            
            if (!success) {
                os_log_error(bw_coordinator_log(), "❌ Failed to send frame to virtual camera: %@", error);
            }
        }
    }
}

- (void)captureManager:(id)manager didChangeState:(BWCaptureState)state {
    os_log_info(bw_coordinator_log(), "Capture state changed to: %ld", (long)state);
    
    // TODO: Update menu bar status indicator
}

- (void)captureManager:(id)manager didEncounterError:(NSError *)error {
    os_log_error(bw_coordinator_log(), "Capture error: %@", error);
    
    // TODO: Show error to user, attempt recovery
}

- (void)captureManagerDidUpdateAvailableCameras:(id)manager {
    os_log_info(bw_coordinator_log(), "Available cameras updated");
    
    // TODO: Update camera selection menu
}

#pragma mark - BWVideoProcessorDelegate

- (void)videoProcessor:(id)processor didProcessFrame:(CVPixelBufferRef)processedFrame 
             timestamp:(CMTime)timestamp 
      processingTimeMs:(double)processingTime {
    // Optional: Handle processed frame notifications
    // Currently handled synchronously in captureManager:didCaptureVideoFrame:
}

- (void)videoProcessor:(id)processor didUpdatePerformanceMetrics:(NSDictionary *)metrics {
    // Log performance updates
    double avgTime = [metrics[@"averageProcessingTime"] doubleValue] * 1000.0;
    double frameRate = [metrics[@"currentFrameRate"] doubleValue];
    NSInteger frameCount = [metrics[@"processedFrameCount"] integerValue];
    
    os_log_info(bw_coordinator_log(), "🎨 Processing Performance: %.2fms avg, %.1f fps, %ld frames", 
               avgTime, frameRate, (long)frameCount);
}

- (void)videoProcessor:(id)processor didEncounterError:(NSError *)error {
    os_log_error(bw_coordinator_log(), "Video processor error: %@", error);
    
    // TODO: Handle processing errors gracefully
    // TODO: Fall back to passthrough mode
}

#pragma mark - Preset Management

- (void)loadPreset:(NSString *)presetName {
    BWProcessingPreset preset = BWProcessingPresetNatural; // Default
    
    if ([presetName isEqualToString:@"Natural"]) {
        preset = BWProcessingPresetNatural;
    } else if ([presetName isEqualToString:@"Studio"]) {
        preset = BWProcessingPresetStudio;
    } else if ([presetName isEqualToString:@"Creative"]) {
        preset = BWProcessingPresetCreative;
    } else if ([presetName isEqualToString:@"None"]) {
        preset = BWProcessingPresetNone;
    }
    
    [self.videoProcessor setProcessingPreset:preset];
    os_log_info(bw_coordinator_log(), "🎭 Loaded preset: %@ (%ld)", presetName, (long)preset);
}

- (NSDictionary *)getProcessingPerformanceMetrics {
    return [self.videoProcessor getCurrentPerformanceMetrics];
}

@end
