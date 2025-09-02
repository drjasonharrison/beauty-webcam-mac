//
//  BWCaptureManager.m
//  BeautyWebcam
//
//  Created by BeautyWebcam on 2024.
//  Copyright © 2024 BeautyWebcam. All rights reserved.
//

#import "BWCaptureManager.h"
#import <os/log.h>
#import <math.h>

static os_log_t bw_capture_log(void) {
    static os_log_t log;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        log = os_log_create("com.beautywebcam.capture", "CaptureManager");
    });
    return log;
}

@interface BWCaptureManager () <AVCaptureVideoDataOutputSampleBufferDelegate>

@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureDeviceInput *videoInput;
@property (nonatomic, strong) AVCaptureVideoDataOutput *videoOutput;
@property (nonatomic, strong) dispatch_queue_t videoQueue;
@property (nonatomic, assign, readwrite) BWCaptureState currentState;
@property (nonatomic, strong, readwrite) AVCaptureDevice *currentDevice;
@property (nonatomic, strong, readwrite) NSArray<AVCaptureDevice *> *availableDevices;

@end

@implementation BWCaptureManager

+ (instancetype)sharedManager {
    static BWCaptureManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[BWCaptureManager alloc] init];
    });
    return sharedManager;
}

- (instancetype)init {
    if (self = [super init]) {
        _currentState = BWCaptureStateIdle;
        _videoQuality = BWVideoQualityMedium;
        _targetFrameRate = 30;
        
        // Create video processing queue
        _videoQueue = dispatch_queue_create("com.beautywebcam.video", DISPATCH_QUEUE_SERIAL);
        
        // Discover available cameras
        [self discoverAvailableDevices];
        
        // Monitor device changes
        [self setupDeviceChangeNotifications];
        
        os_log_info(bw_capture_log(), "CaptureManager initialized");
    }
    return self;
}

- (void)dealloc {
    [self stopCapture];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Public Methods

- (BOOL)initializeCaptureSessionWithError:(NSError **)error {
    if (self.currentState != BWCaptureStateIdle) {
        if (error) {
            *error = [NSError errorWithDomain:@"BWCaptureManager" 
                                         code:-1 
                                     userInfo:@{NSLocalizedDescriptionKey: @"Capture session already initialized"}];
        }
        return NO;
    }
    
    self.currentState = BWCaptureStateConfiguring;
    
    // Create capture session
    self.captureSession = [[AVCaptureSession alloc] init];
    
    // Create video output
    self.videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    self.videoOutput.videoSettings = @{
        (NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)
    };
    [self.videoOutput setSampleBufferDelegate:self queue:self.videoQueue];
    self.videoOutput.alwaysDiscardsLateVideoFrames = YES;
    
    if ([self.captureSession canAddOutput:self.videoOutput]) {
        [self.captureSession addOutput:self.videoOutput];
    } else {
        os_log_error(bw_capture_log(), "Failed to add video output to capture session");
        if (error) {
            *error = [NSError errorWithDomain:@"BWCaptureManager" 
                                         code:-2 
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to add video output"}];
        }
        self.currentState = BWCaptureStateError;
        return NO;
    }
    
    os_log_info(bw_capture_log(), "Capture session initialized successfully");
    return YES;
}

- (BOOL)startCaptureWithError:(NSError **)error {
    // Use default/preferred device
    AVCaptureDevice *defaultDevice = [self preferredCaptureDevice];
    if (!defaultDevice) {
        os_log_error(bw_capture_log(), "No suitable capture device found");
        if (error) {
            *error = [NSError errorWithDomain:@"BWCaptureManager" 
                                         code:-3 
                                     userInfo:@{NSLocalizedDescriptionKey: @"No camera available"}];
        }
        return NO;
    }
    
    return [self startCaptureWithDevice:defaultDevice error:error];
}

- (BOOL)startCaptureWithDevice:(AVCaptureDevice *)device error:(NSError **)error {
    if (!device) {
        os_log_error(bw_capture_log(), "Device is nil");
        if (error) {
            *error = [NSError errorWithDomain:@"BWCaptureManager" 
                                         code:-4 
                                     userInfo:@{NSLocalizedDescriptionKey: @"Invalid device"}];
        }
        return NO;
    }
    
    // Initialize session if needed
    if (!self.captureSession) {
        if (![self initializeCaptureSessionWithError:error]) {
            return NO;
        }
    }
    
    self.currentState = BWCaptureStateConfiguring;
    
    // Remove existing input if any
    if (self.videoInput) {
        [self.captureSession removeInput:self.videoInput];
        self.videoInput = nil;
    }
    
    // Create new input
    NSError *inputError;
    self.videoInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:&inputError];
    if (!self.videoInput) {
        os_log_error(bw_capture_log(), "Failed to create device input: %@", inputError);
        if (error) *error = inputError;
        self.currentState = BWCaptureStateError;
        return NO;
    }
    
    // Add input to session
    if ([self.captureSession canAddInput:self.videoInput]) {
        [self.captureSession addInput:self.videoInput];
        self.currentDevice = device;
    } else {
        os_log_error(bw_capture_log(), "Cannot add device input to session");
        if (error) {
            *error = [NSError errorWithDomain:@"BWCaptureManager" 
                                         code:-5 
                                     userInfo:@{NSLocalizedDescriptionKey: @"Cannot add device input"}];
        }
        self.currentState = BWCaptureStateError;
        return NO;
    }
    
    // Configure video format and frame rate
    if (![self configureDeviceForCurrentQuality:error]) {
        return NO;
    }
    
    // Start session
    [self.captureSession startRunning];
    self.currentState = BWCaptureStateRunning;
    
    os_log_info(bw_capture_log(), "Started capture with device: %@", device.localizedName);
    
    // Notify delegate
    if ([self.delegate respondsToSelector:@selector(captureManager:didChangeState:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate captureManager:self didChangeState:self.currentState];
        });
    }
    
    return YES;
}

- (void)stopCapture {
    if (self.captureSession && self.captureSession.isRunning) {
        [self.captureSession stopRunning];
        os_log_info(bw_capture_log(), "Capture session stopped");
    }
    
    self.currentState = BWCaptureStateStopped;
    
    // Notify delegate
    if ([self.delegate respondsToSelector:@selector(captureManager:didChangeState:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate captureManager:self didChangeState:self.currentState];
        });
    }
}

- (BOOL)switchToDevice:(AVCaptureDevice *)device error:(NSError **)error {
    if (self.currentState != BWCaptureStateRunning) {
        return [self startCaptureWithDevice:device error:error];
    }
    
    // Stop current session
    [self stopCapture];
    
    // Start with new device
    return [self startCaptureWithDevice:device error:error];
}

- (BOOL)updateVideoQuality:(BWVideoQuality)quality error:(NSError **)error {
    self.videoQuality = quality;
    
    if (self.currentState == BWCaptureStateRunning) {
        return [self configureDeviceForCurrentQuality:error];
    }
    
    return YES; // Will be applied when capture starts
}

- (BOOL)updateFrameRate:(NSInteger)frameRate error:(NSError **)error {
    self.targetFrameRate = frameRate;
    
    if (self.currentState == BWCaptureStateRunning) {
        return [self configureDeviceForCurrentQuality:error];
    }
    
    return YES; // Will be applied when capture starts
}

- (void)optimizeCaptureForEnhancements:(BOOL)enhancementsActive {
    if (enhancementsActive) {
        // Aggressive optimization when enhancements are active
        
        // Reduce to low quality for maximum CPU savings
        BWVideoQuality optimizedQuality = BWVideoQualityLow; // 640x480
        NSInteger optimizedFrameRate = 20; // Reduce from 30fps to 20fps
        
        os_log_info(bw_capture_log(), "⚡ Optimizing capture for enhancements: %@ at %ld fps", 
                   [BWCaptureManager nameForVideoQuality:optimizedQuality], (long)optimizedFrameRate);
        
        // Apply optimizations
        NSError *error;
        [self updateVideoQuality:optimizedQuality error:&error];
        [self updateFrameRate:optimizedFrameRate error:&error];
        
        if (error) {
            os_log_error(bw_capture_log(), "❌ Failed to optimize capture settings: %@", error);
        }
        
    } else {
        // Restore normal quality when enhancements are disabled
        BWVideoQuality normalQuality = BWVideoQualityMedium; // 1280x720
        NSInteger normalFrameRate = 30; // Standard 30fps
        
        os_log_info(bw_capture_log(), "🔄 Restoring normal capture settings: %@ at %ld fps", 
                   [BWCaptureManager nameForVideoQuality:normalQuality], (long)normalFrameRate);
        
        // Restore normal settings
        NSError *error;
        [self updateVideoQuality:normalQuality error:&error];
        [self updateFrameRate:normalFrameRate error:&error];
        
        if (error) {
            os_log_error(bw_capture_log(), "❌ Failed to restore capture settings: %@", error);
        }
    }
}

#pragma mark - Device Discovery

- (void)discoverAvailableDevices {
    // Build device types array with proper version checking
    NSMutableArray<AVCaptureDeviceType> *deviceTypes = [NSMutableArray arrayWithObject:AVCaptureDeviceTypeBuiltInWideAngleCamera];
    
    // Add external/continuity camera support based on OS version
    if (@available(macOS 14.0, *)) {
        // Use the newer Continuity Camera type on macOS 14+
        [deviceTypes addObject:AVCaptureDeviceTypeContinuityCamera];
        [deviceTypes addObject:AVCaptureDeviceTypeExternal];
    } else {
        // Use the legacy external type on older systems
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [deviceTypes addObject:AVCaptureDeviceTypeExternalUnknown];
        #pragma clang diagnostic pop
    }
    
    // Get all video capture devices
    AVCaptureDeviceDiscoverySession *discoverySession = [AVCaptureDeviceDiscoverySession 
        discoverySessionWithDeviceTypes:deviceTypes
                              mediaType:AVMediaTypeVideo
                               position:AVCaptureDevicePositionUnspecified];
    
    self.availableDevices = discoverySession.devices;
    
    os_log_info(bw_capture_log(), "Discovered %lu video devices", (unsigned long)self.availableDevices.count);
    for (AVCaptureDevice *device in self.availableDevices) {
        os_log_info(bw_capture_log(), "Device: %@ (%@) Type: %@", device.localizedName, device.uniqueID, device.deviceType);
    }
}

- (AVCaptureDevice *)preferredCaptureDevice {
    // Prefer external cameras over built-in
    for (AVCaptureDevice *device in self.availableDevices) {
        // Check for external devices based on OS version
        if (@available(macOS 14.0, *)) {
            if (device.deviceType == AVCaptureDeviceTypeContinuityCamera || 
                device.deviceType == AVCaptureDeviceTypeExternal) {
                return device;
            }
        } else {
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Wdeprecated-declarations"
            if (device.deviceType == AVCaptureDeviceTypeExternalUnknown) {
                return device;
            }
            #pragma clang diagnostic pop
        }
    }
    
    // Fall back to built-in camera
    return self.availableDevices.firstObject;
}

- (void)refreshAvailableDevices {
    os_log_info(bw_capture_log(), "🔄 Refreshing available camera devices...");
    [self discoverAvailableDevices];
}

#pragma mark - Device Configuration

- (BOOL)configureDeviceForCurrentQuality:(NSError **)error {
    if (!self.currentDevice) return YES;
    
    NSError *configError;
    if ([self.currentDevice lockForConfiguration:&configError]) {
        
        // Find best format for current quality
        AVCaptureDeviceFormat *bestFormat = [self findBestFormatForQuality:self.videoQuality];
        if (bestFormat) {
            self.currentDevice.activeFormat = bestFormat;
            os_log_info(bw_capture_log(), "Set device format: %@", bestFormat);
        }
        
        // Set frame rate using device's supported ranges
        [self configureSupportedFrameRateForDevice:self.currentDevice];
        
        [self.currentDevice unlockForConfiguration];
        
        os_log_info(bw_capture_log(), "Configured device for quality: %@ at %ld fps", 
                   [BWCaptureManager nameForVideoQuality:self.videoQuality], 
                   (long)self.targetFrameRate);
        return YES;
        
    } else {
        os_log_error(bw_capture_log(), "Failed to lock device for configuration: %@", configError);
        if (error) *error = configError;
        return NO;
    }
}

- (void)configureSupportedFrameRateForDevice:(AVCaptureDevice *)device {
    if (!device || !device.activeFormat) {
        os_log_error(bw_capture_log(), "⚠️ Cannot configure frame rate - no device or format");
        return;
    }
    
    NSArray<AVFrameRateRange *> *frameRateRanges = device.activeFormat.videoSupportedFrameRateRanges;
    if (frameRateRanges.count == 0) {
        os_log_error(bw_capture_log(), "⚠️ No supported frame rate ranges found");
        return;
    }
    
    // Find the best frame rate range that supports our target frame rate
    AVFrameRateRange *bestRange = nil;
    double bestScore = -1;
    
    for (AVFrameRateRange *range in frameRateRanges) {
        os_log_info(bw_capture_log(), "🎬 Available range: %.2f - %.2f fps", range.minFrameRate, range.maxFrameRate);
        
        // Calculate how well this range matches our target
        double score = 0;
        if (self.targetFrameRate >= range.minFrameRate && self.targetFrameRate <= range.maxFrameRate) {
            // Target is within range - excellent match
            score = 100;
        } else {
            // Calculate distance from range
            double distance = MIN(fabs(self.targetFrameRate - range.minFrameRate), 
                                fabs(self.targetFrameRate - range.maxFrameRate));
            score = MAX(0, 50 - distance);
        }
        
        if (score > bestScore) {
            bestScore = score;
            bestRange = range;
        }
    }
    
    if (bestRange) {
        // Use the closest supported frame rate within the best range
        double frameRate = MIN(MAX(self.targetFrameRate, bestRange.minFrameRate), bestRange.maxFrameRate);
        
        // Use the device's native frame rate timing
        CMTime frameDuration = CMTimeMake(1000000, (int32_t)(frameRate * 1000000));
        
        // Set both min and max to the same value for consistent frame rate
        device.activeVideoMinFrameDuration = frameDuration;
        device.activeVideoMaxFrameDuration = frameDuration;
        
        os_log_info(bw_capture_log(), "✅ Set frame rate to %.2f fps (target: %ld) using range %.2f-%.2f", 
                   frameRate, (long)self.targetFrameRate, bestRange.minFrameRate, bestRange.maxFrameRate);
        
        // Update our target to match what we actually set
        self.targetFrameRate = (NSInteger)frameRate;
        
    } else {
        os_log_error(bw_capture_log(), "❌ No suitable frame rate range found for target %ld fps", (long)self.targetFrameRate);
    }
}

- (AVCaptureDeviceFormat *)findBestFormatForQuality:(BWVideoQuality)quality {
    CMVideoDimensions targetDimensions = [BWCaptureManager dimensionsForVideoQuality:quality];
    
    AVCaptureDeviceFormat *bestFormat = nil;
    int32_t bestScore = 0;
    
    for (AVCaptureDeviceFormat *format in self.currentDevice.formats) {
        CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription);
        
        // Score format based on resolution match and frame rate support
        int32_t score = 0;
        
        // Resolution score (prefer exact match, then closest)
        if (dimensions.width == targetDimensions.width && dimensions.height == targetDimensions.height) {
            score += 100;
        } else {
            int32_t widthDiff = abs(dimensions.width - targetDimensions.width);
            int32_t heightDiff = abs(dimensions.height - targetDimensions.height);
            score += MAX(0, 50 - (widthDiff + heightDiff) / 100);
        }
        
        // Frame rate support score
        for (AVFrameRateRange *range in format.videoSupportedFrameRateRanges) {
            if (range.maxFrameRate >= self.targetFrameRate && range.minFrameRate <= self.targetFrameRate) {
                score += 25;
                break;
            }
        }
        
        // Prefer formats with 32BGRA pixel format
        FourCharCode pixelFormat = CMFormatDescriptionGetMediaSubType(format.formatDescription);
        if (pixelFormat == kCVPixelFormatType_32BGRA || pixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange) {
            score += 10;
        }
        
        if (score > bestScore) {
            bestScore = score;
            bestFormat = format;
        }
    }
    
    return bestFormat;
}

#pragma mark - Notifications

- (void)setupDeviceChangeNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(deviceWasConnected:)
                                                 name:AVCaptureDeviceWasConnectedNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(deviceWasDisconnected:)
                                                 name:AVCaptureDeviceWasDisconnectedNotification
                                               object:nil];
}

- (void)deviceWasConnected:(NSNotification *)notification {
    os_log_info(bw_capture_log(), "Device connected: %@", notification.object);
    [self discoverAvailableDevices];
    
    if ([self.delegate respondsToSelector:@selector(captureManagerDidUpdateAvailableCameras:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate captureManagerDidUpdateAvailableCameras:self];
        });
    }
}

- (void)deviceWasDisconnected:(NSNotification *)notification {
    os_log_info(bw_capture_log(), "Device disconnected: %@", notification.object);
    [self discoverAvailableDevices];
    
    // If current device was disconnected, stop capture
    if ([notification.object isEqual:self.currentDevice]) {
        [self stopCapture];
        self.currentState = BWCaptureStateError;
    }
    
    if ([self.delegate respondsToSelector:@selector(captureManagerDidUpdateAvailableCameras:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate captureManagerDidUpdateAvailableCameras:self];
        });
    }
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)output 
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer 
       fromConnection:(AVCaptureConnection *)connection {
    
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CMTime timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    
    if (pixelBuffer && [self.delegate respondsToSelector:@selector(captureManager:didCaptureVideoFrame:timestamp:)]) {
        [self.delegate captureManager:self didCaptureVideoFrame:pixelBuffer timestamp:timestamp];
    }
}

- (void)captureOutput:(AVCaptureOutput *)output 
  didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer 
       fromConnection:(AVCaptureConnection *)connection {
    os_log_debug(bw_capture_log(), "Dropped video frame");
}

#pragma mark - Utility Methods

+ (NSString *)nameForVideoQuality:(BWVideoQuality)quality {
    switch (quality) {
        case BWVideoQualityLow:    return @"Low (480p)";
        case BWVideoQualityMedium: return @"Medium (720p)";
        case BWVideoQualityHigh:   return @"High (1080p)";
        case BWVideoQualityUltra:  return @"Ultra (1440p)";
    }
}

+ (CMVideoDimensions)dimensionsForVideoQuality:(BWVideoQuality)quality {
    switch (quality) {
        case BWVideoQualityLow:    return (CMVideoDimensions){640, 480};
        case BWVideoQualityMedium: return (CMVideoDimensions){1280, 720};
        case BWVideoQualityHigh:   return (CMVideoDimensions){1920, 1080};
        case BWVideoQualityUltra:  return (CMVideoDimensions){2560, 1440};
    }
}

@end
