//
//  BWVideoProcessor.h
//  BeautyWebcam
//
//  Created by BeautyWebcam on 2024.
//  Copyright © 2024 BeautyWebcam. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreMedia/CoreMedia.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, BWProcessingQuality) {
    BWProcessingQualityLow,     // Fast processing, lower quality
    BWProcessingQualityMedium,  // Balanced performance and quality
    BWProcessingQualityHigh,    // Best quality, higher CPU/GPU usage
    BWProcessingQualityUltra    // Maximum quality for high-end hardware
};

typedef NS_ENUM(NSInteger, BWProcessingPreset) {
    BWProcessingPresetNone,
    BWProcessingPresetNatural,     // Subtle, natural enhancement
    BWProcessingPresetStudio,      // Professional video call look
    BWProcessingPresetCreative,    // More dramatic, artistic effects
    BWProcessingPresetCustom       // User-defined settings
};

/**
 * Parameters for video processing effects
 */
@interface BWProcessingParameters : NSObject

// Skin enhancement
@property (nonatomic, assign) float skinSmoothingIntensity;    // 0.0 - 1.0
@property (nonatomic, assign) float skinBrighteningAmount;     // 0.0 - 1.0

// Color adjustments  
@property (nonatomic, assign) float brightnessAdjustment;      // -1.0 to 1.0
@property (nonatomic, assign) float contrastAdjustment;        // 0.0 to 2.0
@property (nonatomic, assign) float saturationBoost;           // 0.0 to 2.0
@property (nonatomic, assign) float temperatureShift;          // -1.0 to 1.0 (cool to warm)

// Advanced effects
@property (nonatomic, assign) float sharpeningAmount;          // 0.0 - 1.0
@property (nonatomic, assign) float noiseReductionLevel;       // 0.0 - 1.0
@property (nonatomic, assign) float vignetteIntensity;         // 0.0 - 1.0

+ (instancetype)defaultParameters;
+ (instancetype)parametersForPreset:(BWProcessingPreset)preset;

@end

@protocol BWVideoProcessorDelegate <NSObject>
@optional
/**
 * Called when a processed frame is ready
 */
- (void)videoProcessor:(id)processor didProcessFrame:(CVPixelBufferRef)processedFrame
             timestamp:(CMTime)timestamp
      processingTimeMs:(double)processingTime;

/**
 * Called when processing performance changes
 */
- (void)videoProcessor:(id)processor didUpdatePerformanceMetrics:(NSDictionary *)metrics;

/**
 * Called when an error occurs during processing
 */
- (void)videoProcessor:(id)processor didEncounterError:(NSError *)error;

@end

/**
 * High-performance video processor using Metal for real-time enhancement
 */
@interface BWVideoProcessor : NSObject

@property (nonatomic, weak) id<BWVideoProcessorDelegate> delegate;
@property (nonatomic, assign) BWProcessingQuality processingQuality;
@property (nonatomic, assign) BWProcessingPreset currentPreset;
@property (nonatomic, strong) BWProcessingParameters *processingParameters;
@property (nonatomic, assign, readonly) BOOL isProcessingEnabled;
@property (nonatomic, assign, readonly) BOOL isInitialized;

// Performance metrics
@property (nonatomic, assign, readonly) double averageProcessingTime;
@property (nonatomic, assign, readonly) double currentFrameRate;
@property (nonatomic, assign, readonly) NSInteger processedFrameCount;

// Performance optimization properties
@property (nonatomic, assign) NSInteger maxProcessingFrameRate; // Default: 10fps
@property (nonatomic, assign) BOOL adaptiveQualityEnabled; // Default: YES

/**
 * Dynamically adjust processing frame rate based on system performance
 */
- (void)optimizeFrameRateForEnhancements:(BOOL)enhancementsActive;

/**
 * Shared processor instance
 */
+ (instancetype)sharedProcessor;

/**
 * Initialize the Metal processing pipeline
 */
- (BOOL)initializeWithError:(NSError **)error;

/**
 * Enable or disable processing (passthrough when disabled)
 */
- (void)setProcessingEnabled:(BOOL)enabled;

/**
 * Process a video frame with current settings
 */
- (CVPixelBufferRef _Nullable)processVideoFrame:(CVPixelBufferRef)inputFrame
                                      timestamp:(CMTime)timestamp
                                          error:(NSError **)error;

/**
 * Process frame asynchronously with completion callback
 */
- (void)processVideoFrameAsync:(CVPixelBufferRef)inputFrame
                     timestamp:(CMTime)timestamp
                    completion:(void(^)(CVPixelBufferRef _Nullable processedFrame, NSError * _Nullable error))completion;

/**
 * Submit frame for async processing (non-blocking, returns immediately)
 * Uses delegate callbacks for results
 */
- (void)submitFrameForAsyncProcessing:(CVPixelBufferRef)inputFrame
                            timestamp:(CMTime)timestamp;

/**
 * Update processing preset (will adjust parameters automatically)
 */
- (void)setProcessingPreset:(BWProcessingPreset)preset;

/**
 * Update individual processing parameters
 */
- (void)updateParameters:(BWProcessingParameters *)parameters;

/**
 * Get current performance metrics
 */
- (NSDictionary *)getCurrentPerformanceMetrics;

/**
 * Reset performance statistics
 */
- (void)resetPerformanceMetrics;

/**
 * Cleanup resources
 */
- (void)shutdown;

@end

NS_ASSUME_NONNULL_END
