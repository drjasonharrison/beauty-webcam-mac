//
//  BWVideoProcessor.m
//  BeautyWebcam
//
//  Created by BeautyWebcam on 2024.
//  Copyright © 2024 BeautyWebcam. All rights reserved.
//

#import "BWVideoProcessor.h"
#import <CoreImage/CoreImage.h>
#import <os/log.h>

static os_log_t bw_processor_log(void) {
    static os_log_t log;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        log = os_log_create("com.beautywebcam.processing", "VideoProcessor");
    });
    return log;
}

#pragma mark - BWProcessingParameters

@implementation BWProcessingParameters

+ (instancetype)defaultParameters {
    BWProcessingParameters *params = [[BWProcessingParameters alloc] init];
    params.skinSmoothingIntensity = 0.3f;
    params.skinBrighteningAmount = 0.1f;  // Reduced from 0.2f
    params.brightnessAdjustment = 0.0f;   // Start at neutral, was 0.1f
    params.contrastAdjustment = 1.0f;     // Start at neutral, was 1.05f  
    params.saturationBoost = 1.0f;        // Start at neutral, was 1.1f
    params.temperatureShift = 0.0f;       // Start at neutral, was 0.05f
    params.sharpeningAmount = 0.1f;       // Reduced from 0.2f
    params.noiseReductionLevel = 0.2f;    // Reduced from 0.3f
    params.vignetteIntensity = 0.0f;
    return params;
}

+ (instancetype)parametersForPreset:(BWProcessingPreset)preset {
    BWProcessingParameters *params = [[BWProcessingParameters alloc] init];
    
    switch (preset) {
        case BWProcessingPresetNone:
            // All values at neutral/off
            params.skinSmoothingIntensity = 0.0f;
            params.skinBrighteningAmount = 0.0f;
            params.brightnessAdjustment = 0.0f;
            params.contrastAdjustment = 1.0f;
            params.saturationBoost = 1.0f;
            params.temperatureShift = 0.0f;
            params.sharpeningAmount = 0.0f;
            params.noiseReductionLevel = 0.0f;
            params.vignetteIntensity = 0.0f;
            break;
            
        case BWProcessingPresetNatural:
            // Subtle, natural enhancement
            params.skinSmoothingIntensity = 0.25f;
            params.skinBrighteningAmount = 0.15f;
            params.brightnessAdjustment = 0.05f;
            params.contrastAdjustment = 1.03f;
            params.saturationBoost = 1.05f;
            params.temperatureShift = 0.02f;
            params.sharpeningAmount = 0.1f;
            params.noiseReductionLevel = 0.2f;
            params.vignetteIntensity = 0.0f;
            break;
            
        case BWProcessingPresetStudio:
            // Professional video call look
            params.skinSmoothingIntensity = 0.4f;
            params.skinBrighteningAmount = 0.3f;
            params.brightnessAdjustment = 0.15f;
            params.contrastAdjustment = 1.1f;
            params.saturationBoost = 1.15f;
            params.temperatureShift = 0.1f;
            params.sharpeningAmount = 0.25f;
            params.noiseReductionLevel = 0.35f;
            params.vignetteIntensity = 0.0f;
            break;
            
        case BWProcessingPresetCreative:
            // More dramatic, artistic effects
            params.skinSmoothingIntensity = 0.5f;
            params.skinBrighteningAmount = 0.4f;
            params.brightnessAdjustment = 0.2f;
            params.contrastAdjustment = 1.2f;
            params.saturationBoost = 1.25f;
            params.temperatureShift = 0.15f;
            params.sharpeningAmount = 0.3f;
            params.noiseReductionLevel = 0.4f;
            params.vignetteIntensity = 0.15f;
            break;
            
        case BWProcessingPresetCustom:
        default:
            return [self defaultParameters];
    }
    
    return params;
}

@end

#pragma mark - BWVideoProcessor

@interface BWVideoProcessor ()

// Metal resources
@property (nonatomic, strong) id<MTLDevice> metalDevice;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, strong) id<MTLLibrary> shaderLibrary;

// Core Image context
@property (nonatomic, strong) CIContext *ciContext;

// Pixel buffer management
@property (nonatomic, assign) CVPixelBufferPoolRef inputBufferPool;
@property (nonatomic, assign) CVPixelBufferPoolRef outputBufferPool;

// Processing state
@property (nonatomic, assign, readwrite) BOOL isProcessingEnabled;
@property (nonatomic, assign, readwrite) BOOL isInitialized;
@property (nonatomic, strong) dispatch_queue_t processingQueue;

// Performance tracking
@property (nonatomic, assign, readwrite) double averageProcessingTime;
@property (nonatomic, assign, readwrite) double currentFrameRate;
@property (nonatomic, assign, readwrite) NSInteger processedFrameCount;
@property (nonatomic, assign) CFAbsoluteTime lastFrameTime;
@property (nonatomic, assign) double totalProcessingTime;

// Frame throttling for performance optimization
@property (nonatomic, assign) CFAbsoluteTime lastProcessedFrameTime;
@property (nonatomic, assign) CVPixelBufferRef lastProcessedFrame;
@property (nonatomic, assign) NSInteger frameSkipCount;

// Async processing optimization
@property (nonatomic, strong) dispatch_queue_t asyncProcessingQueue;
@property (nonatomic, assign) BOOL isAsyncProcessingBusy;
@property (nonatomic, assign) NSInteger pendingFrameCount;

// Core Image filters (cached for performance)
@property (nonatomic, strong) CIFilter *bilateralFilter;
@property (nonatomic, strong) CIFilter *colorControlsFilter;
@property (nonatomic, strong) CIFilter *temperatureFilter;
@property (nonatomic, strong) CIFilter *unsharpMaskFilter;
@property (nonatomic, strong) CIFilter *noiseReductionFilter;
@property (nonatomic, strong) CIFilter *vignetteFilter;

@end

@implementation BWVideoProcessor

+ (instancetype)sharedProcessor {
    static BWVideoProcessor *sharedProcessor = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedProcessor = [[BWVideoProcessor alloc] init];
    });
    return sharedProcessor;
}

- (instancetype)init {
    if (self = [super init]) {
        _processingQuality = BWProcessingQualityMedium;
        _currentPreset = BWProcessingPresetNatural;
        _processingParameters = [BWProcessingParameters parametersForPreset:_currentPreset];
        _isProcessingEnabled = NO;
        _isInitialized = NO;
        _processedFrameCount = 0;
        _averageProcessingTime = 0.0;
        _totalProcessingTime = 0.0;
        _lastFrameTime = 0.0;
        
        // Performance optimization defaults
        _maxProcessingFrameRate = 10; // Reduced to 10fps for better performance with enhancements
        _adaptiveQualityEnabled = YES;
        _lastProcessedFrameTime = 0.0;
        _lastProcessedFrame = NULL;
        _frameSkipCount = 0;
        
        // Async processing optimization
        _isAsyncProcessingBusy = NO;
        _pendingFrameCount = 0;
        
        // Create processing queues
        _processingQueue = dispatch_queue_create("com.beautywebcam.processing", 
                                               DISPATCH_QUEUE_SERIAL);
        
        // High priority async queue for smooth performance
        dispatch_queue_attr_t asyncAttr = dispatch_queue_attr_make_with_qos_class(
            DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INTERACTIVE, 0);
        _asyncProcessingQueue = dispatch_queue_create("com.beautywebcam.async", asyncAttr);
        
        os_log_info(bw_processor_log(), "🎨 BWVideoProcessor initialized");
    }
    return self;
}

- (void)dealloc {
    [self shutdown];
}

#pragma mark - Initialization

- (BOOL)initializeWithError:(NSError **)error {
    if (self.isInitialized) {
        return YES;
    }
    
    os_log_info(bw_processor_log(), "🚀 Initializing video processor...");
    
    // Initialize Metal
    if (![self setupMetalWithError:error]) {
        return NO;
    }
    
    // Initialize Core Image
    if (![self setupCoreImageWithError:error]) {
        return NO;
    }
    
    // Setup pixel buffer pools
    if (![self setupPixelBufferPoolsWithError:error]) {
        return NO;
    }
    
    // Setup filters
    [self setupCoreImageFilters];
    
    self.isInitialized = YES;
    os_log_info(bw_processor_log(), "✅ Video processor initialized successfully");
    
    return YES;
}

- (BOOL)setupMetalWithError:(NSError **)error {
    // Get default Metal device
    self.metalDevice = MTLCreateSystemDefaultDevice();
    if (!self.metalDevice) {
        os_log_error(bw_processor_log(), "❌ Metal not supported on this device");
        if (error) {
            *error = [NSError errorWithDomain:@"BWVideoProcessor"
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey: @"Metal not supported"}];
        }
        return NO;
    }
    
    // Create command queue
    self.commandQueue = [self.metalDevice newCommandQueue];
    if (!self.commandQueue) {
        os_log_error(bw_processor_log(), "❌ Failed to create Metal command queue");
        if (error) {
            *error = [NSError errorWithDomain:@"BWVideoProcessor"
                                         code:-2
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to create command queue"}];
        }
        return NO;
    }
    
    os_log_info(bw_processor_log(), "🔧 Metal setup complete: %@", self.metalDevice.name);
    return YES;
}

- (BOOL)setupCoreImageWithError:(NSError **)error {
    // Create optimized Core Image context with Metal for maximum GPU performance
    NSDictionary *options = @{
        kCIContextWorkingColorSpace: [NSNull null], // Use device RGB for best performance
        kCIContextUseSoftwareRenderer: @NO,         // Force GPU rendering
        kCIContextPriorityRequestLow: @NO,          // High priority processing
        kCIContextOutputColorSpace: [NSNull null],  // Match working color space
        kCIContextCacheIntermediates: @YES,         // Cache for performance
        kCIContextOutputPremultiplied: @YES,        // Premultiplied alpha for speed
        kCIContextHighQualityDownsample: @NO        // Faster downsampling for real-time
    };
    
    self.ciContext = [CIContext contextWithMTLDevice:self.metalDevice 
                                              options:options];
    if (!self.ciContext) {
        os_log_error(bw_processor_log(), "❌ Failed to create Core Image context");
        if (error) {
            *error = [NSError errorWithDomain:@"BWVideoProcessor"
                                         code:-3
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to create Core Image context"}];
        }
        return NO;
    }
    
    os_log_info(bw_processor_log(), "🖼️ Core Image context created");
    return YES;
}

- (BOOL)setupPixelBufferPoolsWithError:(NSError **)error {
    // Optimized pixel buffer pool configuration for performance
    
    // Pool configuration for efficient memory management
    NSDictionary *poolAttributes = @{
        (NSString *)kCVPixelBufferPoolMinimumBufferCountKey: @(3),  // Pre-allocate 3 buffers
        (NSString *)kCVPixelBufferPoolMaximumBufferAgeKey: @(0)     // Disable age-based eviction
    };
    
    // Buffer attributes optimized for Metal and Core Image performance
    NSDictionary *inputAttributes = @{
        (NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
        (NSString *)kCVPixelBufferWidthKey: @(1280),
        (NSString *)kCVPixelBufferHeightKey: @(720),
        (NSString *)kCVPixelBufferMetalCompatibilityKey: @YES,
        (NSString *)kCVPixelBufferIOSurfacePropertiesKey: @{},
        (NSString *)kCVPixelBufferBytesPerRowAlignmentKey: @(64),   // Optimal alignment
        (NSString *)kCVPixelBufferCGImageCompatibilityKey: @YES,    // Core Graphics compatibility
        (NSString *)kCVPixelBufferCGBitmapContextCompatibilityKey: @YES, // Bitmap context compatibility
        (NSString *)kCVPixelBufferOpenGLCompatibilityKey: @YES      // OpenGL compatibility for legacy
    };
    
    CVReturn status = CVPixelBufferPoolCreate(kCFAllocatorDefault, 
                                            (__bridge CFDictionaryRef)poolAttributes,
                                            (__bridge CFDictionaryRef)inputAttributes,
                                            &_inputBufferPool);
    if (status != kCVReturnSuccess) {
        os_log_error(bw_processor_log(), "❌ Failed to create input buffer pool: %d", status);
        if (error) {
            *error = [NSError errorWithDomain:@"BWVideoProcessor"
                                         code:status
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to create input buffer pool"}];
        }
        return NO;
    }
    
    // Setup output buffer pool with same optimized configuration
    status = CVPixelBufferPoolCreate(kCFAllocatorDefault, 
                                   (__bridge CFDictionaryRef)poolAttributes,
                                   (__bridge CFDictionaryRef)inputAttributes,
                                   &_outputBufferPool);
    if (status != kCVReturnSuccess) {
        os_log_error(bw_processor_log(), "❌ Failed to create output buffer pool: %d", status);
        if (error) {
            *error = [NSError errorWithDomain:@"BWVideoProcessor"
                                         code:status
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to create output buffer pool"}];
        }
        return NO;
    }
    
    os_log_info(bw_processor_log(), "💾 Pixel buffer pools created");
    return YES;
}

- (void)setupCoreImageFilters {
    // Pre-create and cache filters for better performance
    
    // Bilateral filter for skin smoothing (using Gaussian blur as approximation)
    self.bilateralFilter = [CIFilter filterWithName:@"CIGaussianBlur"];
    
    // Color controls for brightness, contrast, saturation
    self.colorControlsFilter = [CIFilter filterWithName:@"CIColorControls"];
    
    // Temperature and tint adjustment
    self.temperatureFilter = [CIFilter filterWithName:@"CITemperatureAndTint"];
    
    // Unsharp mask for sharpening
    self.unsharpMaskFilter = [CIFilter filterWithName:@"CIUnsharpMask"];
    
    // Noise reduction (using blur as approximation)
    self.noiseReductionFilter = [CIFilter filterWithName:@"CIGaussianBlur"];
    
    // Vignette effect
    self.vignetteFilter = [CIFilter filterWithName:@"CIVignette"];
    
    os_log_info(bw_processor_log(), "🎛️ Core Image filters setup complete");
}

#pragma mark - Processing Control

- (void)setProcessingEnabled:(BOOL)enabled {
    if (_isProcessingEnabled != enabled) {
        _isProcessingEnabled = enabled;
        os_log_info(bw_processor_log(), "🎨 Processing %@", enabled ? @"enabled" : @"disabled");
        
        if (enabled && !self.isInitialized) {
            NSError *error;
            if (![self initializeWithError:&error]) {
                os_log_error(bw_processor_log(), "❌ Failed to initialize processor: %@", error);
                _isProcessingEnabled = NO;
            }
        }
    }
}

- (void)setProcessingPreset:(BWProcessingPreset)preset {
    if (_currentPreset != preset) {
        _currentPreset = preset;
        self.processingParameters = [BWProcessingParameters parametersForPreset:preset];
        
        os_log_info(bw_processor_log(), "🎭 Processing preset changed to: %ld", (long)preset);
    }
}

- (void)updateParameters:(BWProcessingParameters *)parameters {
    self.processingParameters = parameters;
    self.currentPreset = BWProcessingPresetCustom;
    
    // Check if any enhancements are active and adjust frame rate accordingly
    BOOL enhancementsActive = [self areEnhancementsActive:parameters];
    [self optimizeFrameRateForEnhancements:enhancementsActive];
    
    os_log_debug(bw_processor_log(), "⚙️ Processing parameters updated, enhancements: %@", 
                enhancementsActive ? @"ON" : @"OFF");
}

- (BOOL)areEnhancementsActive:(BWProcessingParameters *)params {
    return (params.skinSmoothingIntensity > 0.0f ||
            params.brightnessAdjustment != 0.0f ||
            params.contrastAdjustment != 1.0f ||
            params.saturationBoost != 1.0f ||
            params.temperatureShift != 0.0f ||
            params.sharpeningAmount > 0.0f ||
            params.noiseReductionLevel > 0.0f ||
            params.vignetteIntensity > 0.0f);
}

- (void)optimizeFrameRateForEnhancements:(BOOL)enhancementsActive {
    if (enhancementsActive) {
        // Very aggressive frame rate reduction when enhancements are active
        self.maxProcessingFrameRate = 8; // 8fps for maximum CPU savings
        os_log_info(bw_processor_log(), "⚡ Frame rate optimized for enhancements: 8fps");
    } else {
        // Higher frame rate when only doing passthrough or basic processing
        self.maxProcessingFrameRate = 15; // 15fps for smooth operation
        os_log_info(bw_processor_log(), "⚡ Frame rate optimized for camera only: 15fps");
    }
}

#pragma mark - Frame Processing

- (CVPixelBufferRef _Nullable)processVideoFrame:(CVPixelBufferRef)inputFrame
                                      timestamp:(CMTime)timestamp
                                          error:(NSError **)error {
    
    if (!self.isProcessingEnabled || !self.isInitialized) {
        // Return original frame if processing is disabled
        CVPixelBufferRetain(inputFrame);
        
        // Notify delegate of unprocessed frame (for original preview)
        if ([self.delegate respondsToSelector:@selector(videoProcessor:didProcessFrame:timestamp:processingTimeMs:)]) {
            [self.delegate videoProcessor:self
                          didProcessFrame:inputFrame
                                timestamp:timestamp
                         processingTimeMs:0.0];
        }
        
        return inputFrame;
    }
    
    CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
    
    // Frame rate throttling for performance optimization
    double minFrameInterval = 1.0 / self.maxProcessingFrameRate; // e.g., 1/15 = 0.0667s
    if (self.lastProcessedFrameTime > 0 && 
        (currentTime - self.lastProcessedFrameTime) < minFrameInterval) {
        
        // Skip this frame - return last processed frame or original
        self.frameSkipCount++;
        
        if (self.lastProcessedFrame) {
            CVPixelBufferRetain(self.lastProcessedFrame);
            
            // Notify delegate with cached frame
            if ([self.delegate respondsToSelector:@selector(videoProcessor:didProcessFrame:timestamp:processingTimeMs:)]) {
                [self.delegate videoProcessor:self
                              didProcessFrame:self.lastProcessedFrame
                                    timestamp:timestamp
                             processingTimeMs:0.0]; // 0ms since we're using cached frame
            }
            
            return self.lastProcessedFrame;
        } else {
            // Fallback to original frame
            CVPixelBufferRetain(inputFrame);
            return inputFrame;
        }
    }
    
    CFAbsoluteTime startTime = currentTime;
    
    @autoreleasepool {
        // Create CIImage from input frame
        CIImage *inputImage = [CIImage imageWithCVPixelBuffer:inputFrame];
        if (!inputImage) {
            if (error) {
                *error = [NSError errorWithDomain:@"BWVideoProcessor"
                                             code:-10
                                         userInfo:@{NSLocalizedDescriptionKey: @"Failed to create CIImage"}];
            }
            return nil;
        }
        
        // Apply processing pipeline
        CIImage *processedImage = [self applyEnhancementsToImage:inputImage];
        
        // Create output pixel buffer
        CVPixelBufferRef outputBuffer;
        CVReturn status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault,
                                                           self.outputBufferPool,
                                                           &outputBuffer);
        if (status != kCVReturnSuccess) {
            if (error) {
                *error = [NSError errorWithDomain:@"BWVideoProcessor"
                                             code:status
                                         userInfo:@{NSLocalizedDescriptionKey: @"Failed to create output buffer"}];
            }
            return nil;
        }
        
        // Render processed image to output buffer
        [self.ciContext render:processedImage toCVPixelBuffer:outputBuffer];
        
        // Update performance metrics
        double processingTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0; // Convert to milliseconds
        [self updatePerformanceMetricsWithProcessingTime:processingTime / 1000.0]; // Keep original units for internal use
        
        // Cache processed frame for potential reuse
        if (self.lastProcessedFrame) {
            CVPixelBufferRelease(self.lastProcessedFrame);
        }
        self.lastProcessedFrame = outputBuffer;
        CVPixelBufferRetain(self.lastProcessedFrame);
        self.lastProcessedFrameTime = currentTime;
        
        // Notify delegate of processed frame
        if ([self.delegate respondsToSelector:@selector(videoProcessor:didProcessFrame:timestamp:processingTimeMs:)]) {
            [self.delegate videoProcessor:self
                          didProcessFrame:outputBuffer
                                timestamp:timestamp
                         processingTimeMs:processingTime];
        }
        
        return outputBuffer;
    }
}

- (void)processVideoFrameAsync:(CVPixelBufferRef)inputFrame
                     timestamp:(CMTime)timestamp
                    completion:(void(^)(CVPixelBufferRef _Nullable processedFrame, NSError * _Nullable error))completion {
    
    CVPixelBufferRetain(inputFrame); // Retain for async processing
    
    dispatch_async(self.processingQueue, ^{
        NSError *error;
        CVPixelBufferRef processedFrame = [self processVideoFrame:inputFrame
                                                        timestamp:timestamp
                                                            error:&error];
        
        CVPixelBufferRelease(inputFrame); // Release retained buffer
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(processedFrame, error);
            if (processedFrame) {
                CVPixelBufferRelease(processedFrame);
            }
        });
    });
}

- (void)submitFrameForAsyncProcessing:(CVPixelBufferRef)inputFrame
                            timestamp:(CMTime)timestamp {
    
    // Skip if we already have too many pending frames to prevent queue buildup
    if (self.pendingFrameCount > 2) {
        self.frameSkipCount++;
        
        // Return last processed frame if available
        if (self.lastProcessedFrame && [self.delegate respondsToSelector:@selector(videoProcessor:didProcessFrame:timestamp:processingTimeMs:)]) {
            CVPixelBufferRetain(self.lastProcessedFrame);
            [self.delegate videoProcessor:self
                          didProcessFrame:self.lastProcessedFrame
                                timestamp:timestamp
                         processingTimeMs:0.0]; // 0ms since we're using cached frame
        }
        return;
    }
    
    // If async processing is not busy, submit immediately
    if (!self.isAsyncProcessingBusy) {
        self.isAsyncProcessingBusy = YES;
        self.pendingFrameCount++;
        
        CVPixelBufferRetain(inputFrame); // Retain for async processing
        
        dispatch_async(self.asyncProcessingQueue, ^{
            NSError *error;
            CVPixelBufferRef processedFrame = [self processVideoFrame:inputFrame
                                                            timestamp:timestamp
                                                                error:&error];
            
            CVPixelBufferRelease(inputFrame); // Release retained buffer
            
            // Update state on main queue
            dispatch_async(dispatch_get_main_queue(), ^{
                self.isAsyncProcessingBusy = NO;
                self.pendingFrameCount = MAX(0, self.pendingFrameCount - 1);
                
                // Delegate callback already handled in processVideoFrame
                if (processedFrame) {
                    CVPixelBufferRelease(processedFrame);
                }
            });
        });
    } else {
        // Processing is busy, return cached frame
        if (self.lastProcessedFrame && [self.delegate respondsToSelector:@selector(videoProcessor:didProcessFrame:timestamp:processingTimeMs:)]) {
            CVPixelBufferRetain(self.lastProcessedFrame);
            [self.delegate videoProcessor:self
                          didProcessFrame:self.lastProcessedFrame
                                timestamp:timestamp
                         processingTimeMs:0.0]; // 0ms since we're using cached frame
        }
    }
}

- (CIImage *)applyEnhancementsToImage:(CIImage *)inputImage {
    CIImage *workingImage = inputImage;
    
    // Adaptive quality scaling based on system performance
    BOOL useHighQuality = YES;
    BOOL useEvenLowerQuality = NO;
    
    if (self.adaptiveQualityEnabled && self.averageProcessingTime > 0) {
        // More aggressive thresholds for better performance
        useHighQuality = (self.averageProcessingTime < 0.008); // 8ms threshold - very strict
        useEvenLowerQuality = (self.averageProcessingTime > 0.015); // 15ms threshold for ultra-low quality
        
        if ((!useHighQuality || useEvenLowerQuality) && self.processedFrameCount % 60 == 0) {
            os_log_info(bw_processor_log(), "⚡ Adaptive quality: %@ (avg: %.1fms)", 
                       useEvenLowerQuality ? @"Ultra-low quality mode" : @"Reduced quality mode",
                       self.averageProcessingTime * 1000.0);
        }
    }
    BWProcessingParameters *params = self.processingParameters;
    
    // 1. Skin smoothing (using median filter as approximation) - Skip in low quality modes
    if (params.skinSmoothingIntensity > 0.0f && useHighQuality && !useEvenLowerQuality) {
        workingImage = [self applySkinSmoothingToImage:workingImage intensity:params.skinSmoothingIntensity];
    }
    
    // 2. Color adjustments - Always apply but skip in ultra-low quality
    if (!useEvenLowerQuality && (params.brightnessAdjustment != 0.0f || 
        params.contrastAdjustment != 1.0f || 
        params.saturationBoost != 1.0f)) {
        workingImage = [self applyColorControlsToImage:workingImage parameters:params];
    }
    
    // 3. Temperature adjustment - Skip in both low quality modes
    if (params.temperatureShift != 0.0f && useHighQuality && !useEvenLowerQuality) {
        workingImage = [self applyTemperatureToImage:workingImage shift:params.temperatureShift];
    }
    
    // 4. Sharpening - Skip in ultra-low quality, reduce in low quality
    if (params.sharpeningAmount > 0.0f && !useEvenLowerQuality) {
        float sharpeningAmount = useHighQuality ? params.sharpeningAmount : params.sharpeningAmount * 0.3f;
        workingImage = [self applySharpeningToImage:workingImage intensity:sharpeningAmount];
    }
    
    // 5. Noise reduction (very expensive - skip in all low quality modes)
    if (params.noiseReductionLevel > 0.0f && useHighQuality && !useEvenLowerQuality) {
        // Only apply with very light intensity in high quality mode
        float reducedLevel = params.noiseReductionLevel * 0.5f;
        workingImage = [self applyNoiseReductionToImage:workingImage level:reducedLevel];
    }
    
    // 6. Vignette - Skip in all low quality modes (least important effect)
    if (params.vignetteIntensity > 0.0f && useHighQuality && !useEvenLowerQuality) {
        workingImage = [self applyVignetteToImage:workingImage intensity:params.vignetteIntensity];
    }
    
    return workingImage;
}

- (CIImage *)applySkinSmoothingToImage:(CIImage *)image intensity:(float)intensity {
    if (intensity <= 0.0f) {
        return image;  // No smoothing needed
    }
    
    // Use Gaussian blur for skin smoothing
    [self.bilateralFilter setValue:image forKey:kCIInputImageKey];
    // Use smaller radius for more subtle effect (0.5 to 2.0 pixels max)
    [self.bilateralFilter setValue:@(intensity * 2.0f) forKey:kCIInputRadiusKey];
    
    CIImage *smoothedImage = self.bilateralFilter.outputImage;
    if (!smoothedImage) {
        return image;  // Fallback if filter fails
    }
    
    // Simple blend using source over compositing with alpha
    CIFilter *blendFilter = [CIFilter filterWithName:@"CISourceOverCompositing"];
    [blendFilter setValue:smoothedImage forKey:kCIInputImageKey];
    [blendFilter setValue:image forKey:kCIInputBackgroundImageKey];
    
    CIImage *blendedImage = blendFilter.outputImage;
    if (!blendedImage) {
        return image;  // Fallback if blend fails
    }
    
    // Control the intensity by mixing original and blended
    CIFilter *mixFilter = [CIFilter filterWithName:@"CIColorMatrix"];
    [mixFilter setValue:blendedImage forKey:kCIInputImageKey];
    // Use alpha channel to control blend intensity
    [mixFilter setValue:[CIVector vectorWithX:1 Y:1 Z:1 W:intensity] forKey:@"inputAVector"];
    
    CIImage *finalImage = mixFilter.outputImage;
    return finalImage ?: image;  // Return original if anything fails
}

- (CIImage *)applyColorControlsToImage:(CIImage *)image parameters:(BWProcessingParameters *)params {
    [self.colorControlsFilter setValue:image forKey:kCIInputImageKey];
    [self.colorControlsFilter setValue:@(params.brightnessAdjustment) forKey:kCIInputBrightnessKey];
    [self.colorControlsFilter setValue:@(params.contrastAdjustment) forKey:kCIInputContrastKey];
    [self.colorControlsFilter setValue:@(params.saturationBoost) forKey:kCIInputSaturationKey];
    
    return self.colorControlsFilter.outputImage ?: image;
}

- (CIImage *)applyTemperatureToImage:(CIImage *)image shift:(float)shift {
    [self.temperatureFilter setValue:image forKey:kCIInputImageKey];
    
    // Convert shift to temperature (warmer = positive, cooler = negative)
    CIVector *temperature = [CIVector vectorWithX:(shift * 1000.0f) Y:0.0f];
    [self.temperatureFilter setValue:temperature forKey:@"inputNeutral"];
    
    return self.temperatureFilter.outputImage ?: image;
}

- (CIImage *)applySharpeningToImage:(CIImage *)image intensity:(float)intensity {
    [self.unsharpMaskFilter setValue:image forKey:kCIInputImageKey];
    [self.unsharpMaskFilter setValue:@(intensity * 2.0f) forKey:kCIInputRadiusKey];
    [self.unsharpMaskFilter setValue:@(intensity) forKey:kCIInputIntensityKey];
    
    return self.unsharpMaskFilter.outputImage ?: image;
}

- (CIImage *)applyNoiseReductionToImage:(CIImage *)image level:(float)level {
    // Use subtle gaussian blur for noise reduction
    [self.noiseReductionFilter setValue:image forKey:kCIInputImageKey];
    [self.noiseReductionFilter setValue:@(level * 0.5f) forKey:kCIInputRadiusKey];
    
    return self.noiseReductionFilter.outputImage ?: image;
}

- (CIImage *)applyVignetteToImage:(CIImage *)image intensity:(float)intensity {
    [self.vignetteFilter setValue:image forKey:kCIInputImageKey];
    [self.vignetteFilter setValue:@(intensity) forKey:kCIInputIntensityKey];
    [self.vignetteFilter setValue:@(0.5f) forKey:kCIInputRadiusKey];
    
    return self.vignetteFilter.outputImage ?: image;
}

#pragma mark - Performance Monitoring

- (void)updatePerformanceMetricsWithProcessingTime:(double)processingTime {
    self.processedFrameCount++;
    self.totalProcessingTime += processingTime;
    
    // Calculate moving average
    double alpha = 0.1; // Smoothing factor
    self.averageProcessingTime = (alpha * processingTime) + ((1.0 - alpha) * self.averageProcessingTime);
    
    // Calculate frame rate
    CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
    if (self.lastFrameTime > 0) {
        double timeDelta = currentTime - self.lastFrameTime;
        self.currentFrameRate = (alpha * (1.0 / timeDelta)) + ((1.0 - alpha) * self.currentFrameRate);
    }
    self.lastFrameTime = currentTime;
    
    // Log performance every 30 frames
    if (self.processedFrameCount % 30 == 0) {
        os_log_info(bw_processor_log(), "📊 Performance: %.2fms avg, %.1f fps, %ld frames processed",
                   self.averageProcessingTime * 1000.0,
                   self.currentFrameRate,
                   (long)self.processedFrameCount);
        
        // Notify delegate
        if ([self.delegate respondsToSelector:@selector(videoProcessor:didUpdatePerformanceMetrics:)]) {
            NSDictionary *metrics = [self getCurrentPerformanceMetrics];
            [self.delegate videoProcessor:self didUpdatePerformanceMetrics:metrics];
        }
    }
}

- (NSDictionary *)getCurrentPerformanceMetrics {
    return @{
        @"averageProcessingTime": @(self.averageProcessingTime),
        @"currentFrameRate": @(self.currentFrameRate),
        @"processedFrameCount": @(self.processedFrameCount),
        @"totalProcessingTime": @(self.totalProcessingTime)
    };
}

- (void)resetPerformanceMetrics {
    self.processedFrameCount = 0;
    self.averageProcessingTime = 0.0;
    self.currentFrameRate = 0.0;
    self.totalProcessingTime = 0.0;
    self.lastFrameTime = 0.0;
    
    os_log_info(bw_processor_log(), "📊 Performance metrics reset");
}

#pragma mark - Cleanup

- (void)shutdown {
    os_log_info(bw_processor_log(), "🧹 Shutting down video processor...");
    
    self.isProcessingEnabled = NO;
    self.isInitialized = NO;
    
    // Release cached processed frame
    if (self.lastProcessedFrame) {
        CVPixelBufferRelease(self.lastProcessedFrame);
        self.lastProcessedFrame = NULL;
    }
    
    // Release pixel buffer pools
    if (self.inputBufferPool) {
        CVPixelBufferPoolRelease(self.inputBufferPool);
        self.inputBufferPool = NULL;
    }
    
    if (self.outputBufferPool) {
        CVPixelBufferPoolRelease(self.outputBufferPool);
        self.outputBufferPool = NULL;
    }
    
    // Clear references
    self.metalDevice = nil;
    self.commandQueue = nil;
    self.ciContext = nil;
    
    // Clear filters
    self.bilateralFilter = nil;
    self.colorControlsFilter = nil;
    self.temperatureFilter = nil;
    self.unsharpMaskFilter = nil;
    self.noiseReductionFilter = nil;
    self.vignetteFilter = nil;
    
    os_log_info(bw_processor_log(), "✅ Video processor shutdown complete");
}

@end
