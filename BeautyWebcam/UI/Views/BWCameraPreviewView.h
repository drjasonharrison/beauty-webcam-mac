//
//  BWCameraPreviewView.h
//  BeautyWebcam
//
//  Created by BeautyWebcam on 2024.
//  Copyright © 2024 BeautyWebcam. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <AVFoundation/AVFoundation.h>
#import "BWVideoProcessor.h"

NS_ASSUME_NONNULL_BEGIN

@class BWApplicationCoordinator;

/**
 * Live camera preview view that shows the enhanced video feed in real-time
 */
@interface BWCameraPreviewView : NSView <BWVideoProcessorDelegate>

@property (nonatomic, weak) BWApplicationCoordinator *applicationCoordinator;
@property (nonatomic, assign) BOOL showEnhancedFeed; // YES = enhanced, NO = original
@property (nonatomic, assign, readonly) BOOL isPreviewActive;

/**
 * Start/stop the preview
 */
- (void)startPreview;
- (void)stopPreview;

/**
 * Update the preview with current enhancement settings
 */
- (void)refreshPreview;

@end

NS_ASSUME_NONNULL_END
