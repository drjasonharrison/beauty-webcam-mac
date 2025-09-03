//
//  BWCameraPreviewView.m
//  BeautyWebcam
//
//  Created by BeautyWebcam on 2024.
//  Copyright © 2024 BeautyWebcam. All rights reserved.
//

#import "BWCameraPreviewView.h"
#import "../../Application/BWApplicationCoordinator.h"
#import "../../Capture/BWCaptureManager.h"
#import "../../Processing/BWVideoProcessor.h"
#import <os/log.h>

static os_log_t bw_preview_log(void) {
    static os_log_t log;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        log = os_log_create("com.beautywebcam.preview", "CameraPreview");
    });
    return log;
}

@interface BWCameraPreviewView () <BWCaptureManagerDelegate>

@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, strong) AVCaptureSession *previewSession;
@property (nonatomic, strong) AVCaptureDeviceInput *deviceInput;
@property (nonatomic, strong) NSImageView *enhancedImageView;
@property (nonatomic, strong) dispatch_queue_t previewQueue;

// Private readwrite version of the public readonly property
@property (nonatomic, assign, readwrite) BOOL isPreviewActive;

// Frame storage for real-time display
@property (nonatomic, assign) CVPixelBufferRef lastProcessedFrame;
@property (nonatomic, assign) CVPixelBufferRef lastOriginalFrame;

// UI Elements
@property (nonatomic, strong) NSTextField *statusLabel;
@property (nonatomic, strong) NSButton *toggleButton;
@property (nonatomic, strong) NSSegmentedControl *modeSelector;

@end

@implementation BWCameraPreviewView

- (instancetype)initWithFrame:(NSRect)frameRect {
    if (self = [super initWithFrame:frameRect]) {
        [self setupPreview];
    }
    return self;
}

- (void)dealloc {
    [self stopPreview];
    
    // Release stored pixel buffers
    if (_lastProcessedFrame) {
        CVPixelBufferRelease(_lastProcessedFrame);
        _lastProcessedFrame = NULL;
    }
    if (_lastOriginalFrame) {
        CVPixelBufferRelease(_lastOriginalFrame);
        _lastOriginalFrame = NULL;
    }
}

#pragma mark - Setup

- (void)setupPreview {
    self.showEnhancedFeed = YES;
    self.previewQueue = dispatch_queue_create("com.beautywebcam.preview", DISPATCH_QUEUE_SERIAL);
    
    // Set background
    self.wantsLayer = YES;
    self.layer.backgroundColor = [[NSColor blackColor] CGColor];
    self.layer.cornerRadius = 8.0;
    
    [self setupUI];
    [self setupPreviewSession];
    
    os_log_info(bw_preview_log(), "🎥 Camera preview view initialized");
}

- (void)setupUI {
    // Mode selector (Original/Enhanced)
    self.modeSelector = [[NSSegmentedControl alloc] initWithFrame:NSMakeRect(10, self.bounds.size.height - 35, 150, 25)];
    self.modeSelector.segmentCount = 2;
    [self.modeSelector setLabel:@"Original" forSegment:0];
    [self.modeSelector setLabel:@"Enhanced" forSegment:1];
    self.modeSelector.selectedSegment = 1; // Enhanced by default
    self.modeSelector.target = self;
    self.modeSelector.action = @selector(modeChanged:);
    [self addSubview:self.modeSelector];
    
    // Status label
    self.statusLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 10, self.bounds.size.width - 20, 20)];
    self.statusLabel.stringValue = @"Camera preview ready";
    self.statusLabel.editable = NO;
    self.statusLabel.bordered = NO;
    self.statusLabel.backgroundColor = [NSColor clearColor];
    self.statusLabel.textColor = [NSColor whiteColor];
    self.statusLabel.font = [NSFont systemFontOfSize:11];
    [self addSubview:self.statusLabel];
    
    // Toggle button
    self.toggleButton = [[NSButton alloc] initWithFrame:NSMakeRect(self.bounds.size.width - 80, self.bounds.size.height - 35, 70, 25)];
    [self.toggleButton setButtonType:NSButtonTypeMomentaryPushIn];
    self.toggleButton.title = @"Start";
    self.toggleButton.target = self;
    self.toggleButton.action = @selector(togglePreview:);
    [self addSubview:self.toggleButton];
    
    // Enhanced image view (for processed frames)
    CGFloat previewHeight = self.bounds.size.height - 70; // Leave space for controls
    self.enhancedImageView = [[NSImageView alloc] initWithFrame:NSMakeRect(10, 35, self.bounds.size.width - 20, previewHeight)];
    self.enhancedImageView.imageScaling = NSImageScaleProportionallyUpOrDown;
    self.enhancedImageView.wantsLayer = YES;
    self.enhancedImageView.layer.cornerRadius = 4.0;
    self.enhancedImageView.hidden = YES;
    [self addSubview:self.enhancedImageView];
}

- (void)setupPreviewSession {
    self.previewSession = [[AVCaptureSession alloc] init];
    self.previewSession.sessionPreset = AVCaptureSessionPresetMedium;
    
    // Create preview layer (for original feed)
    self.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.previewSession];
    self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    
    CGFloat previewHeight = self.bounds.size.height - 70;
    self.previewLayer.frame = CGRectMake(10, 35, self.bounds.size.width - 20, previewHeight);
    self.previewLayer.cornerRadius = 4.0;
    
    [self.layer addSublayer:self.previewLayer];
    self.previewLayer.hidden = YES; // Hidden by default (we show enhanced by default)
}

#pragma mark - Public Methods

- (void)startPreview {
    if (self.isPreviewActive) {
        os_log_info(bw_preview_log(), "⚠️ Preview already active");
        return;
    }
    
    os_log_info(bw_preview_log(), "▶️ Starting camera preview...");
    
    dispatch_async(self.previewQueue, ^{
        // Get the current camera device from application coordinator
        AVCaptureDevice *device = nil;
        if (self.applicationCoordinator && self.applicationCoordinator.captureManager) {
            device = self.applicationCoordinator.captureManager.currentDevice;
        }
        
        if (!device) {
            // Fallback to default device
            device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        }
        
        if (!device) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.statusLabel.stringValue = @"No camera available";
            });
            return;
        }
        
        NSError *error;
        self.deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
        
        if (!self.deviceInput) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.statusLabel.stringValue = [NSString stringWithFormat:@"Camera error: %@", error.localizedDescription];
            });
            return;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.previewSession beginConfiguration];
            
            // Remove existing inputs
            for (AVCaptureInput *input in self.previewSession.inputs) {
                [self.previewSession removeInput:input];
            }
            
            // Add new input
            if ([self.previewSession canAddInput:self.deviceInput]) {
                [self.previewSession addInput:self.deviceInput];
            }
            
            [self.previewSession commitConfiguration];
            [self.previewSession startRunning];
            
            self.isPreviewActive = YES;
            self.toggleButton.title = @"Stop";
            self.statusLabel.stringValue = @"Preview active";
            
            // Show appropriate preview based on mode
            [self updatePreviewMode];
            
            os_log_info(bw_preview_log(), "✅ Camera preview started");
        });
    });
}

- (void)stopPreview {
    if (!self.isPreviewActive) {
        return;
    }
    
    os_log_info(bw_preview_log(), "⏹️ Stopping camera preview...");
    
    [self.previewSession stopRunning];
    
    self.isPreviewActive = NO;
    self.toggleButton.title = @"Start";
    self.statusLabel.stringValue = @"Preview stopped";
    self.previewLayer.hidden = YES;
    self.enhancedImageView.hidden = YES;
    
    os_log_info(bw_preview_log(), "✅ Camera preview stopped");
}

- (void)refreshPreview {
    if (!self.isPreviewActive) {
        return;
    }
    
    // Update enhanced preview if showing enhanced mode
    if (self.showEnhancedFeed) {
        [self updateEnhancedPreview];
    }
}

#pragma mark - UI Actions

- (void)togglePreview:(NSButton *)sender {
    if (self.isPreviewActive) {
        [self stopPreview];
    } else {
        [self startPreview];
    }
}

- (void)modeChanged:(NSSegmentedControl *)sender {
    self.showEnhancedFeed = (sender.selectedSegment == 1);
    [self updatePreviewMode];
    
    // 🎯 CRITICAL: Tell coordinator to enable/disable processing based on preview mode
    if (self.applicationCoordinator) {
        // Only enable enhancement processing when Enhanced tab is selected
        [self.applicationCoordinator setEnhancementEnabled:self.showEnhancedFeed];
        
        os_log_info(bw_preview_log(), "⚡ Processing optimization: %@ (mode: %@)", 
                   self.showEnhancedFeed ? @"Enhancement ENABLED" : @"Enhancement DISABLED",
                   self.showEnhancedFeed ? @"Enhanced" : @"Original");
    }
    
    os_log_info(bw_preview_log(), "🔄 Preview mode changed to: %@", 
               self.showEnhancedFeed ? @"Enhanced" : @"Original");
}

#pragma mark - Helper Methods

- (void)updatePreviewMode {
    if (!self.isPreviewActive) {
        return;
    }
    
    if (self.showEnhancedFeed) {
        // Show enhanced preview
        self.previewLayer.hidden = YES;
        self.enhancedImageView.hidden = NO;
        // Try to show actual frame first, fallback to info display
        [self updateEnhancedPreviewWithActualFrame];
    } else {
        // Show original preview
        self.previewLayer.hidden = NO;
        self.enhancedImageView.hidden = YES;
    }
}

- (void)updateEnhancedPreview {
    if (!self.applicationCoordinator) {
        return;
    }
    
    // Show the same preview as original, but indicate that enhancements would be applied
    // In a real-time enhanced preview, we would need to tap into the video processing pipeline
    
    BWProcessingParameters *params = self.applicationCoordinator.videoProcessor.processingParameters;
    BOOL enhancementEnabled = self.applicationCoordinator.enhancementEnabled;
    
    if (!enhancementEnabled) {
        // Show message that enhancement is disabled
        [self createInfoImage:@"Enhancement is OFF\n\nEnable enhancement in settings\nto see processed video" 
                   textColor:[NSColor orangeColor]
                 backgroundColor:[NSColor colorWithRed:0.2 green:0.1 blue:0.0 alpha:1.0]];
        return;
    }
    
    // Show enhancement settings info with better formatting
    NSString *enhancementInfo = [NSString stringWithFormat:
        @"🎨 ENHANCED PREVIEW\n\n"
        @"✨ Skin Smoothing: %.1f\n"
        @"☀️ Brightness: %+.1f\n" 
        @"🌈 Contrast: %.1fx\n"
        @"🎨 Saturation: %.1fx\n\n"
        @"Note: This shows enhancement\nsettings. Full video processing\noccurs in the main pipeline.",
        params.skinSmoothingIntensity,
        params.brightnessAdjustment,
        params.contrastAdjustment,
        params.saturationBoost];
    
    [self createInfoImage:enhancementInfo 
               textColor:[NSColor whiteColor]
             backgroundColor:[NSColor colorWithRed:0.1 green:0.3 blue:0.1 alpha:1.0]];
}

- (void)createInfoImage:(NSString *)text textColor:(NSColor *)textColor backgroundColor:(NSColor *)backgroundColor {
    // Create a better-looking info display
    NSRect textRect = NSMakeRect(0, 0, 280, 160);
    NSImage *textImage = [[NSImage alloc] initWithSize:textRect.size];
    
    [textImage lockFocus];
    
    // Draw gradient background
    NSGradient *gradient = [[NSGradient alloc] initWithStartingColor:backgroundColor
                                                         endingColor:[backgroundColor colorWithAlphaComponent:0.7]];
    [gradient drawInRect:textRect angle:45];
    
    // Draw border
    [[NSColor grayColor] setStroke];
    NSFrameRectWithWidth(textRect, 2.0);
    
    // Draw text with better formatting
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.alignment = NSTextAlignmentCenter;
    paragraphStyle.lineSpacing = 2.0;
    
    NSDictionary *textAttributes = @{
        NSForegroundColorAttributeName: textColor,
        NSFontAttributeName: [NSFont systemFontOfSize:11],
        NSParagraphStyleAttributeName: paragraphStyle
    };
    
    NSRect textDrawRect = NSInsetRect(textRect, 15, 15);
    [text drawInRect:textDrawRect withAttributes:textAttributes];
    
    [textImage unlockFocus];
    
    self.enhancedImageView.image = textImage;
}

- (void)resizeSubviewsWithOldSize:(NSSize)oldSize {
    [super resizeSubviewsWithOldSize:oldSize];
    
    // Update frame positions when view is resized
    if (self.modeSelector) {
        self.modeSelector.frame = NSMakeRect(10, self.bounds.size.height - 35, 150, 25);
    }
    
    if (self.toggleButton) {
        self.toggleButton.frame = NSMakeRect(self.bounds.size.width - 80, self.bounds.size.height - 35, 70, 25);
    }
    
    if (self.statusLabel) {
        self.statusLabel.frame = NSMakeRect(10, 10, self.bounds.size.width - 20, 20);
    }
    
    if (self.enhancedImageView) {
        CGFloat previewHeight = self.bounds.size.height - 70;
        self.enhancedImageView.frame = NSMakeRect(10, 35, self.bounds.size.width - 20, previewHeight);
    }
    
    if (self.previewLayer) {
        CGFloat previewHeight = self.bounds.size.height - 70;
        self.previewLayer.frame = CGRectMake(10, 35, self.bounds.size.width - 20, previewHeight);
    }
}

#pragma mark - Properties

- (void)setApplicationCoordinator:(BWApplicationCoordinator *)applicationCoordinator {
    // Remove previous delegate connection if any
    if (_applicationCoordinator && _applicationCoordinator.videoProcessor) {
        _applicationCoordinator.videoProcessor.delegate = nil;
    }
    
    _applicationCoordinator = applicationCoordinator;
    
    // Set ourselves as the video processor delegate to receive processed frames
    if (applicationCoordinator && applicationCoordinator.videoProcessor) {
        applicationCoordinator.videoProcessor.delegate = self;
        os_log_info(bw_preview_log(), "🎥 Preview view set as video processor delegate");
        
        // Force immediate refresh if preview is active
        if (self.isPreviewActive) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self updatePreviewMode];
            });
        }
    } else {
        os_log_info(bw_preview_log(), "⚠️ Application coordinator or video processor not available");
    }
}

#pragma mark - BWVideoProcessorDelegate

- (void)videoProcessor:(BWVideoProcessor *)processor 
        didProcessFrame:(CVPixelBufferRef)processedFrame 
              timestamp:(CMTime)timestamp 
       processingTimeMs:(double)processingTime {
    
    // Log frame reception for debugging (every 30 frames = ~1 second at 30fps)
    static int frameCount = 0;
    frameCount++;
    if (frameCount % 30 == 0) {
        os_log_info(bw_preview_log(), "🎬 Received frame %d - Processing: %s, Preview active: %s, Show enhanced: %s", 
                   frameCount, 
                   processor.isProcessingEnabled ? "YES" : "NO", 
                   self.isPreviewActive ? "YES" : "NO",
                   self.showEnhancedFeed ? "YES" : "NO");
    }
    
    // Store the frame (retain it since we're storing the reference)
    CVPixelBufferRetain(processedFrame);
    
    // Release previous frame if it exists
    if (processor.isProcessingEnabled) {
        // This is an enhanced frame
        if (_lastProcessedFrame) {
            CVPixelBufferRelease(_lastProcessedFrame);
        }
        _lastProcessedFrame = processedFrame;
    } else {
        // This is the original frame (processing disabled)
        if (_lastOriginalFrame) {
            CVPixelBufferRelease(_lastOriginalFrame);
        }
        _lastOriginalFrame = processedFrame;
    }
    
    // Update the enhanced preview if we're showing enhanced feed
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.showEnhancedFeed && self.isPreviewActive) {
            [self updateEnhancedPreviewWithActualFrame];
        }
    });
}

- (void)updateEnhancedPreviewWithActualFrame {
    if (!self.applicationCoordinator) {
        return;
    }
    
    CVPixelBufferRef frameToDisplay = NULL;
    BOOL enhancementEnabled = self.applicationCoordinator.enhancementEnabled;
    
    if (enhancementEnabled && _lastProcessedFrame) {
        // Show the actual processed frame
        frameToDisplay = _lastProcessedFrame;
    } else if (!enhancementEnabled && _lastOriginalFrame) {
        // Show original frame with a note that enhancement is off
        frameToDisplay = _lastOriginalFrame;
    }
    
    if (frameToDisplay) {
        // Convert CVPixelBuffer to NSImage and display it
        CIImage *ciImage = [CIImage imageWithCVPixelBuffer:frameToDisplay];
        if (ciImage) {
            NSCIImageRep *rep = [NSCIImageRep imageRepWithCIImage:ciImage];
            NSImage *image = [[NSImage alloc] init];
            [image addRepresentation:rep];
            
            self.enhancedImageView.image = image;
            
            // Update status
            NSString *status = enhancementEnabled ? 
                @"🎨 Enhanced preview - Real-time processed video" : 
                @"📹 Original preview - Enhancement disabled";
            self.statusLabel.stringValue = status;
            
            os_log_debug(bw_preview_log(), "🖼️ Updated enhanced preview with actual frame");
        }
    } else {
        // Fallback to info display if no frames available
        [self updateEnhancedPreview];
    }
}

@end
