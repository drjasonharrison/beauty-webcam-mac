//
//  BWSettingsWindowController.m
//  BeautyWebcam
//
//  Created by BeautyWebcam on 2024.
//  Copyright © 2024 BeautyWebcam. All rights reserved.
//

#import "BWSettingsWindowController.h"
#import "../../Application/BWApplicationCoordinator.h"
#import "../../Processing/BWVideoProcessor.h"
#import "../../Capture/BWCaptureManager.h"
#import "../Views/BWCameraPreviewView.h"
#import "BWPreviewWindowController.h"
#import <os/log.h>

static os_log_t bw_settings_log(void) {
    static os_log_t log;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        log = os_log_create("com.beautywebcam.settings", "SettingsWindow");
    });
    return log;
}

@interface BWSettingsWindowController () <BWVideoProcessorDelegate>

// Main container
@property (nonatomic, strong) NSTabView *tabView;

// Enhancement Tab
@property (nonatomic, strong) NSView *enhancementTabView;
@property (nonatomic, strong) NSSlider *skinSmoothingSlider;
@property (nonatomic, strong) NSSlider *brightnessSlider;
@property (nonatomic, strong) NSSlider *contrastSlider;
@property (nonatomic, strong) NSSlider *saturationSlider;
@property (nonatomic, strong) NSSlider *temperatureSlider;
@property (nonatomic, strong) NSSlider *sharpeningSlider;
@property (nonatomic, strong) NSSlider *noiseReductionSlider;
@property (nonatomic, strong) NSPopUpButton *presetPopup;
@property (nonatomic, strong) NSButton *enhancementToggle;

// Camera Tab
@property (nonatomic, strong) NSView *cameraTabView;
@property (nonatomic, strong) NSPopUpButton *cameraPopup;
@property (nonatomic, strong) NSPopUpButton *qualityPopup;
@property (nonatomic, strong) NSTextField *cameraInfoLabel;
// Preview view moved to separate BWPreviewWindowController

// Performance Tab
@property (nonatomic, strong) NSView *performanceTabView;
@property (nonatomic, strong) NSTextField *processingTimeLabel;
@property (nonatomic, strong) NSTextField *frameRateLabel;
@property (nonatomic, strong) NSTextField *frameCountLabel;
@property (nonatomic, strong) NSProgressIndicator *cpuUsageIndicator;
@property (nonatomic, strong) NSTimer *performanceUpdateTimer;

// About Tab
@property (nonatomic, strong) NSView *aboutTabView;

@end

static BWSettingsWindowController *sharedController = nil;

@implementation BWSettingsWindowController

+ (void)showSettingsWindow {
    if (!sharedController) {
        sharedController = [[BWSettingsWindowController alloc] init];
    }
    
    // Refresh coordinator connection when showing
    [sharedController refreshCoordinatorConnection];
    
    [sharedController showWindow:nil];
    [sharedController.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

+ (void)hideSettingsWindow {
    if (sharedController) {
        [sharedController.window close];
    }
}

- (instancetype)init {
    // Create the window
    NSRect windowFrame = NSMakeRect(0, 0, 600, 500);
    NSWindow *window = [[NSWindow alloc] initWithContentRect:windowFrame
                                                   styleMask:NSWindowStyleMaskTitled | 
                                                            NSWindowStyleMaskClosable |
                                                            NSWindowStyleMaskMiniaturizable
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    
    if (self = [super initWithWindow:window]) {
        [self setupWindow];
        [self setupTabView];
        [self setupEnhancementTab];
        [self setupCameraTab];
        [self setupPerformanceTab];
        [self setupAboutTab];
        
        os_log_info(bw_settings_log(), "🎛️ Settings window controller initialized");
    }
    return self;
}

- (void)dealloc {
    [self.performanceUpdateTimer invalidate];
}

#pragma mark - Window Setup

- (void)setupWindow {
    self.window.title = @"BeautyWebcam Settings";
    self.window.titlebarAppearsTransparent = YES;
    
    // Center the window
    [self.window center];
    
    // Make window non-resizable for cleaner look
    [self.window setContentSize:NSMakeSize(600, 500)];
    [self.window setContentMinSize:NSMakeSize(600, 500)];
    [self.window setContentMaxSize:NSMakeSize(600, 500)];
}

- (void)setupTabView {
    self.tabView = [[NSTabView alloc] initWithFrame:NSMakeRect(20, 20, 560, 460)];
    self.tabView.tabViewType = NSTopTabsBezelBorder;
    
    [self.window.contentView addSubview:self.tabView];
}

#pragma mark - Enhancement Tab

- (void)setupEnhancementTab {
    self.enhancementTabView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 540, 420)];
    
    NSTabViewItem *enhancementTab = [[NSTabViewItem alloc] initWithIdentifier:@"enhancement"];
    enhancementTab.label = @"Enhancement";
    enhancementTab.view = self.enhancementTabView;
    [self.tabView addTabViewItem:enhancementTab];
    
    CGFloat yPos = 380;
    CGFloat spacing = 45;
    
    // Enhancement Toggle
    self.enhancementToggle = [[NSButton alloc] initWithFrame:NSMakeRect(20, yPos, 200, 24)];
    [self.enhancementToggle setButtonType:NSButtonTypeSwitch];
    self.enhancementToggle.title = @"Enable Enhancement";
    self.enhancementToggle.target = self;
    self.enhancementToggle.action = @selector(enhancementToggled:);
    [self.enhancementTabView addSubview:self.enhancementToggle];
    
    // Preset Selection
    yPos -= spacing;
    NSTextField *presetLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, yPos, 100, 20)];
    presetLabel.stringValue = @"Preset:";
    presetLabel.editable = NO;
    presetLabel.bordered = NO;
    presetLabel.backgroundColor = [NSColor clearColor];
    [self.enhancementTabView addSubview:presetLabel];
    
    self.presetPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(130, yPos - 2, 150, 24)];
    [self.presetPopup addItemWithTitle:@"None"];
    [self.presetPopup addItemWithTitle:@"Natural"];
    [self.presetPopup addItemWithTitle:@"Studio"];
    [self.presetPopup addItemWithTitle:@"Creative"];
    [self.presetPopup addItemWithTitle:@"Custom"];
    [self.presetPopup selectItemWithTitle:@"Natural"];
    self.presetPopup.target = self;
    self.presetPopup.action = @selector(presetChanged:);
    [self.enhancementTabView addSubview:self.presetPopup];
    
    // Skin Smoothing
    yPos -= spacing;
    self.skinSmoothingSlider = [self addSliderWithLabel:@"Skin Smoothing:" 
                                                  value:0.3f  // This stays the same
                                                   yPos:yPos 
                                                 action:@selector(skinSmoothingChanged:)];
    
    // Brightness
    yPos -= spacing;
    self.brightnessSlider = [self addSliderWithLabel:@"Brightness:" 
                                               value:0.0f  // Updated to match new default
                                                yPos:yPos 
                                              action:@selector(brightnessChanged:)];
    
    // Contrast
    yPos -= spacing;
    self.contrastSlider = [self addSliderWithLabel:@"Contrast:" 
                                             value:1.0f  // Updated to match new default
                                              yPos:yPos 
                                            action:@selector(contrastChanged:)];
    
    // Saturation
    yPos -= spacing;
    self.saturationSlider = [self addSliderWithLabel:@"Saturation:" 
                                               value:1.0f  // Updated to match new default 
                                                yPos:yPos 
                                              action:@selector(saturationChanged:)];
    
    // Temperature
    yPos -= spacing;
    self.temperatureSlider = [self addSliderWithLabel:@"Temperature:" 
                                                value:0.0f  // Updated to match new default
                                                 yPos:yPos 
                                               action:@selector(temperatureChanged:)];
    
    // Sharpening
    yPos -= spacing;
    self.sharpeningSlider = [self addSliderWithLabel:@"Sharpening:" 
                                               value:0.1f  // Updated to match new default
                                                yPos:yPos 
                                              action:@selector(sharpeningChanged:)];
    
    // Noise Reduction
    yPos -= spacing;
    self.noiseReductionSlider = [self addSliderWithLabel:@"Noise Reduction:" 
                                                   value:0.2f  // Updated to match new default 
                                                    yPos:yPos 
                                                  action:@selector(noiseReductionChanged:)];
}

- (NSSlider *)addSliderWithLabel:(NSString *)labelText 
                           value:(float)value 
                            yPos:(CGFloat)yPos 
                          action:(SEL)action {
    
    // Label
    NSTextField *label = [[NSTextField alloc] initWithFrame:NSMakeRect(20, yPos, 120, 20)];
    label.stringValue = labelText;
    label.editable = NO;
    label.bordered = NO;
    label.backgroundColor = [NSColor clearColor];
    [self.enhancementTabView addSubview:label];
    
    // Slider
    NSSlider *slider = [[NSSlider alloc] initWithFrame:NSMakeRect(150, yPos, 250, 20)];
    
    // Set appropriate ranges for different adjustment types
    if (action == @selector(contrastChanged:) || action == @selector(saturationChanged:)) {
        // Contrast and saturation: 0.5 to 2.0 (multiplicative)
        slider.minValue = 0.5;
        slider.maxValue = 2.0;
    } else if (action == @selector(brightnessChanged:)) {
        // Brightness: -0.5 to +0.5 (additive, centered at 0)
        slider.minValue = -0.5;
        slider.maxValue = 0.5;
    } else {
        // Other adjustments (smoothing, etc.): 0.0 to 1.0
        slider.minValue = 0.0;
        slider.maxValue = 1.0;
    }
    
    slider.doubleValue = value;
    slider.target = self;
    slider.action = action;
    slider.continuous = YES;
    [self.enhancementTabView addSubview:slider];
    
    // Value label
    NSTextField *valueLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(410, yPos, 60, 20)];
    valueLabel.stringValue = [NSString stringWithFormat:@"%.2f", value];
    valueLabel.editable = NO;
    valueLabel.bordered = NO;
    valueLabel.backgroundColor = [NSColor clearColor];
    valueLabel.tag = 1000 + (NSInteger)yPos; // Unique tag for updating
    [self.enhancementTabView addSubview:valueLabel];
    
    return slider;
}

#pragma mark - Camera Tab

- (void)setupCameraTab {
    self.cameraTabView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 540, 420)];
    
    NSTabViewItem *cameraTab = [[NSTabViewItem alloc] initWithIdentifier:@"camera"];
    cameraTab.label = @"Camera";
    cameraTab.view = self.cameraTabView;
    [self.tabView addTabViewItem:cameraTab];
    
    CGFloat yPos = 350;
    
    // Camera Selection
    NSTextField *cameraLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, yPos, 150, 20)];
    cameraLabel.stringValue = @"Camera Device:";
    cameraLabel.editable = NO;
    cameraLabel.bordered = NO;
    cameraLabel.backgroundColor = [NSColor clearColor];
    cameraLabel.font = [NSFont boldSystemFontOfSize:13];
    [self.cameraTabView addSubview:cameraLabel];
    
    self.cameraPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(20, yPos - 25, 480, 24)];
    self.cameraPopup.target = self;
    self.cameraPopup.action = @selector(cameraChanged:);
    [self.cameraTabView addSubview:self.cameraPopup];
    
    // Quality Selection
    yPos -= 70;
    NSTextField *qualityLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, yPos, 150, 20)];
    qualityLabel.stringValue = @"Video Quality:";
    qualityLabel.editable = NO;
    qualityLabel.bordered = NO;
    qualityLabel.backgroundColor = [NSColor clearColor];
    qualityLabel.font = [NSFont boldSystemFontOfSize:13];
    [self.cameraTabView addSubview:qualityLabel];
    
    self.qualityPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(20, yPos - 25, 250, 24)];
    [self.qualityPopup addItemWithTitle:@"Low (640x480)"];
    [self.qualityPopup addItemWithTitle:@"Medium (1280x720)"];
    [self.qualityPopup addItemWithTitle:@"High (1920x1080)"];
    [self.qualityPopup selectItemAtIndex:1]; // Default to Medium
    self.qualityPopup.target = self;
    self.qualityPopup.action = @selector(qualityChanged:);
    [self.cameraTabView addSubview:self.qualityPopup];
    
    // Camera Info
    yPos -= 70;
    self.cameraInfoLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, yPos, 480, 40)];
    self.cameraInfoLabel.stringValue = @"Camera information will appear here...";
    self.cameraInfoLabel.editable = NO;
    self.cameraInfoLabel.bordered = NO;
    self.cameraInfoLabel.backgroundColor = [NSColor clearColor];
    self.cameraInfoLabel.font = [NSFont systemFontOfSize:11];
    self.cameraInfoLabel.textColor = [NSColor secondaryLabelColor];
    [self.cameraTabView addSubview:self.cameraInfoLabel];
    
    // Live Preview Section
    yPos -= 60;
    NSTextField *previewLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, yPos, 150, 20)];
    previewLabel.stringValue = @"Live Preview:";
    previewLabel.editable = NO;
    previewLabel.bordered = NO;
    previewLabel.backgroundColor = [NSColor clearColor];
    previewLabel.font = [NSFont boldSystemFontOfSize:13];
    [self.cameraTabView addSubview:previewLabel];
    
    // Note about separate preview window
    NSTextField *previewNote = [[NSTextField alloc] initWithFrame:NSMakeRect(20, yPos - 160, 480, 140)];
    previewNote.stringValue = @"📹 Live Preview Window\n\nFor real-time video monitoring, use:\n• Menu Bar → Live Preview... (⌘P)\n• Opens a dedicated preview window\n• Switch between Original/Enhanced views\n• Independent of settings window";
    previewNote.editable = NO;
    previewNote.bordered = NO;
    previewNote.backgroundColor = [NSColor clearColor];
    previewNote.textColor = [NSColor secondaryLabelColor];
    previewNote.font = [NSFont systemFontOfSize:12];
    previewNote.alignment = NSTextAlignmentCenter;
    previewNote.wantsLayer = YES;
    previewNote.layer.backgroundColor = [[NSColor controlBackgroundColor] CGColor];
    previewNote.layer.cornerRadius = 8.0;
    [self.cameraTabView addSubview:previewNote];
    
    [self updateCameraList];
}

#pragma mark - Performance Tab

- (void)setupPerformanceTab {
    self.performanceTabView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 540, 420)];
    
    NSTabViewItem *performanceTab = [[NSTabViewItem alloc] initWithIdentifier:@"performance"];
    performanceTab.label = @"Performance";
    performanceTab.view = self.performanceTabView;
    [self.tabView addTabViewItem:performanceTab];
    
    CGFloat yPos = 350;
    
    // Performance Metrics
    NSTextField *titleLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, yPos, 300, 24)];
    titleLabel.stringValue = @"Real-time Performance Metrics";
    titleLabel.editable = NO;
    titleLabel.bordered = NO;
    titleLabel.backgroundColor = [NSColor clearColor];
    titleLabel.font = [NSFont boldSystemFontOfSize:16];
    [self.performanceTabView addSubview:titleLabel];
    
    yPos -= 50;
    
    // Processing Time
    NSTextField *processingLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, yPos, 150, 20)];
    processingLabel.stringValue = @"Processing Time:";
    processingLabel.editable = NO;
    processingLabel.bordered = NO;
    processingLabel.backgroundColor = [NSColor clearColor];
    [self.performanceTabView addSubview:processingLabel];
    
    self.processingTimeLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(180, yPos, 200, 20)];
    self.processingTimeLabel.stringValue = @"0.00 ms";
    self.processingTimeLabel.editable = NO;
    self.processingTimeLabel.bordered = NO;
    self.processingTimeLabel.backgroundColor = [NSColor clearColor];
    self.processingTimeLabel.font = [NSFont monospacedDigitSystemFontOfSize:13 weight:NSFontWeightRegular];
    [self.performanceTabView addSubview:self.processingTimeLabel];
    
    // Frame Rate
    yPos -= 30;
    NSTextField *frameRateLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, yPos, 150, 20)];
    frameRateLabel.stringValue = @"Frame Rate:";
    frameRateLabel.editable = NO;
    frameRateLabel.bordered = NO;
    frameRateLabel.backgroundColor = [NSColor clearColor];
    [self.performanceTabView addSubview:frameRateLabel];
    
    self.frameRateLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(180, yPos, 200, 20)];
    self.frameRateLabel.stringValue = @"0.0 fps";
    self.frameRateLabel.editable = NO;
    self.frameRateLabel.bordered = NO;
    self.frameRateLabel.backgroundColor = [NSColor clearColor];
    self.frameRateLabel.font = [NSFont monospacedDigitSystemFontOfSize:13 weight:NSFontWeightRegular];
    [self.performanceTabView addSubview:self.frameRateLabel];
    
    // Frame Count
    yPos -= 30;
    NSTextField *frameCountLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, yPos, 150, 20)];
    frameCountLabel.stringValue = @"Frames Processed:";
    frameCountLabel.editable = NO;
    frameCountLabel.bordered = NO;
    frameCountLabel.backgroundColor = [NSColor clearColor];
    [self.performanceTabView addSubview:frameCountLabel];
    
    self.frameCountLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(180, yPos, 200, 20)];
    self.frameCountLabel.stringValue = @"0";
    self.frameCountLabel.editable = NO;
    self.frameCountLabel.bordered = NO;
    self.frameCountLabel.backgroundColor = [NSColor clearColor];
    self.frameCountLabel.font = [NSFont monospacedDigitSystemFontOfSize:13 weight:NSFontWeightRegular];
    [self.performanceTabView addSubview:self.frameCountLabel];
    
    // CPU Usage Indicator
    yPos -= 50;
    NSTextField *cpuLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, yPos, 150, 20)];
    cpuLabel.stringValue = @"Processing Load:";
    cpuLabel.editable = NO;
    cpuLabel.bordered = NO;
    cpuLabel.backgroundColor = [NSColor clearColor];
    [self.performanceTabView addSubview:cpuLabel];
    
    self.cpuUsageIndicator = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(180, yPos, 200, 20)];
    self.cpuUsageIndicator.style = NSProgressIndicatorStyleBar;
    self.cpuUsageIndicator.minValue = 0.0;
    self.cpuUsageIndicator.maxValue = 100.0;
    self.cpuUsageIndicator.doubleValue = 0.0;
    [self.performanceTabView addSubview:self.cpuUsageIndicator];
}

#pragma mark - About Tab

- (void)setupAboutTab {
    self.aboutTabView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 540, 420)];
    
    NSTabViewItem *aboutTab = [[NSTabViewItem alloc] initWithIdentifier:@"about"];
    aboutTab.label = @"About";
    aboutTab.view = self.aboutTabView;
    [self.tabView addTabViewItem:aboutTab];
    
    CGFloat yPos = 350;
    
    // App Name
    NSTextField *appNameLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, yPos, 500, 30)];
    appNameLabel.stringValue = @"BeautyWebcam";
    appNameLabel.editable = NO;
    appNameLabel.bordered = NO;
    appNameLabel.backgroundColor = [NSColor clearColor];
    appNameLabel.font = [NSFont boldSystemFontOfSize:24];
    appNameLabel.alignment = NSTextAlignmentCenter;
    [self.aboutTabView addSubview:appNameLabel];
    
    // Version
    yPos -= 40;
    NSTextField *versionLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, yPos, 500, 20)];
    versionLabel.stringValue = @"Version 1.0.0 (Beta)";
    versionLabel.editable = NO;
    versionLabel.bordered = NO;
    versionLabel.backgroundColor = [NSColor clearColor];
    versionLabel.font = [NSFont systemFontOfSize:14];
    versionLabel.alignment = NSTextAlignmentCenter;
    [self.aboutTabView addSubview:versionLabel];
    
    // Description
    yPos -= 60;
    NSTextField *descriptionLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, yPos, 500, 80)];
    descriptionLabel.stringValue = @"Professional webcam enhancement for macOS\n\nReal-time beauty filters and video processing\npowered by Metal and Core Image.\n\nTransform your video calls with studio-quality enhancement.";
    descriptionLabel.editable = NO;
    descriptionLabel.bordered = NO;
    descriptionLabel.backgroundColor = [NSColor clearColor];
    descriptionLabel.font = [NSFont systemFontOfSize:13];
    descriptionLabel.alignment = NSTextAlignmentCenter;
    [self.aboutTabView addSubview:descriptionLabel];
    
    // Copyright
    yPos -= 120;
    NSTextField *copyrightLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, yPos, 500, 20)];
    copyrightLabel.stringValue = @"© 2024 BeautyWebcam. All rights reserved.";
    copyrightLabel.editable = NO;
    copyrightLabel.bordered = NO;
    copyrightLabel.backgroundColor = [NSColor clearColor];
    copyrightLabel.font = [NSFont systemFontOfSize:11];
    copyrightLabel.alignment = NSTextAlignmentCenter;
    copyrightLabel.textColor = [NSColor secondaryLabelColor];
    [self.aboutTabView addSubview:copyrightLabel];
}

#pragma mark - Window Lifecycle

- (void)windowDidLoad {
    [super windowDidLoad];
    
    os_log_info(bw_settings_log(), "🪟 Settings window did load");
    
    // Get application coordinator reference
    NSApplication *app = [NSApplication sharedApplication];
    os_log_info(bw_settings_log(), "📱 App delegate: %@", app.delegate);
    
    if ([app.delegate respondsToSelector:@selector(applicationCoordinator)]) {
        self.applicationCoordinator = [(id)app.delegate applicationCoordinator];
        os_log_info(bw_settings_log(), "🔌 Application coordinator: %@", self.applicationCoordinator);
        
        if (self.applicationCoordinator) {
            // Note: Preview window handles video processor delegate, not settings window
            os_log_info(bw_settings_log(), "🎬 Settings window connected to coordinator (delegate handled by preview)");
            
            // Update controls with current values
            [self updateControlsWithCurrentSettings];
            
            // Update camera information
            [self updateCameraList];
            
            // Connect preview view to application coordinator
            // Preview view coordinator setup handled by separate preview window
            os_log_info(bw_settings_log(), "🎥 Preview view coordinator connected");
        } else {
            os_log_error(bw_settings_log(), "❌ Application coordinator is nil!");
        }
    } else {
        os_log_error(bw_settings_log(), "❌ App delegate doesn't respond to applicationCoordinator selector");
    }
    
    // Start performance monitoring
    self.performanceUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                                   target:self
                                                                 selector:@selector(updatePerformanceMetrics)
                                                                 userInfo:nil
                                                                  repeats:YES];
}

- (void)windowWillClose:(NSNotification *)notification {
    [self.performanceUpdateTimer invalidate];
    self.performanceUpdateTimer = nil;
    
    // Don't release the controller - we want to reuse it
    os_log_info(bw_settings_log(), "Settings window closed");
}

#pragma mark - Control Actions

- (void)enhancementToggled:(NSButton *)sender {
    BOOL enabled = sender.state == NSControlStateValueOn;
    [self.applicationCoordinator setEnhancementEnabled:enabled];
    
    if (enabled) {
        // Start video processing when enhancement is enabled
        os_log_info(bw_settings_log(), "🚀 Starting video processing from settings...");
        NSError *error;
        BOOL success = [self.applicationCoordinator startVideoProcessingWithError:&error];
        if (!success) {
            os_log_error(bw_settings_log(), "❌ Failed to start video processing: %@", error);
            // Revert toggle state if failed
            sender.state = NSControlStateValueOff;
        } else {
            os_log_info(bw_settings_log(), "✅ Video processing started successfully from settings");
        }
    } else {
        // Stop video processing when enhancement is disabled
        os_log_info(bw_settings_log(), "🛑 Stopping video processing from settings...");
        [self.applicationCoordinator stopVideoProcessing];
    }
    
    os_log_info(bw_settings_log(), "Enhancement toggled: %@", enabled ? @"ON" : @"OFF");
}

- (void)presetChanged:(NSPopUpButton *)sender {
    NSString *presetName = sender.selectedItem.title;
    [self.applicationCoordinator loadPreset:presetName];
    
    // Update sliders with preset values
    [self updateControlsWithCurrentSettings];
    
    os_log_info(bw_settings_log(), "Preset changed to: %@", presetName);
}

- (void)skinSmoothingChanged:(NSSlider *)sender {
    [self updateParameterAndLabel:sender];
}

- (void)brightnessChanged:(NSSlider *)sender {
    [self updateParameterAndLabel:sender];
}

- (void)contrastChanged:(NSSlider *)sender {
    [self updateParameterAndLabel:sender];
}

- (void)saturationChanged:(NSSlider *)sender {
    [self updateParameterAndLabel:sender];
}

- (void)temperatureChanged:(NSSlider *)sender {
    [self updateParameterAndLabel:sender];
}

- (void)sharpeningChanged:(NSSlider *)sender {
    [self updateParameterAndLabel:sender];
}

- (void)noiseReductionChanged:(NSSlider *)sender {
    [self updateParameterAndLabel:sender];
}

- (void)cameraChanged:(NSPopUpButton *)sender {
    NSString *selectedCameraName = sender.selectedItem.title;
    os_log_info(bw_settings_log(), "Camera changed to: %@", selectedCameraName);
    
    if (!self.applicationCoordinator || !self.applicationCoordinator.captureManager) {
        os_log_error(bw_settings_log(), "❌ Cannot switch camera - coordinator not available");
        return;
    }
    
    // Find the selected device
    AVCaptureDevice *selectedDevice = nil;
    for (AVCaptureDevice *device in self.applicationCoordinator.captureManager.availableDevices) {
        // Remove any type suffix when comparing (e.g., " (External)")
        NSString *deviceName = device.localizedName;
        if ([selectedCameraName containsString:deviceName] || [deviceName isEqualToString:selectedCameraName]) {
            selectedDevice = device;
            break;
        }
    }
    
    if (!selectedDevice) {
        os_log_error(bw_settings_log(), "❌ Could not find device with name: %@", selectedCameraName);
        return;
    }
    
    // Switch to the selected device
    NSError *error;
    BOOL success = [self.applicationCoordinator.captureManager switchToDevice:selectedDevice error:&error];
    
    if (success) {
        os_log_info(bw_settings_log(), "✅ Successfully switched to camera: %@", selectedDevice.localizedName);
        
        // Update camera info display
        [self updateCameraInfo];
        
        // Restart video processing automatically for seamless switching
        [self restartVideoProcessingForCameraSwitch];
        
        // Preview refresh handled by separate preview window
    } else {
        os_log_error(bw_settings_log(), "❌ Failed to switch camera: %@", error.localizedDescription);
        
        // Show error to user
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Camera Switch Failed";
        alert.informativeText = [NSString stringWithFormat:@"Could not switch to the selected camera: %@", error.localizedDescription];
        alert.alertStyle = NSAlertStyleWarning;
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
    }
}

- (void)qualityChanged:(NSPopUpButton *)sender {
    NSString *selectedQuality = sender.selectedItem.title;
    os_log_info(bw_settings_log(), "Quality changed to: %@", selectedQuality);
    
    if (!self.applicationCoordinator || !self.applicationCoordinator.captureManager) {
        os_log_error(bw_settings_log(), "❌ Cannot change quality - coordinator not available");
        return;
    }
    
    // Map UI selection to quality enum
    BWVideoQuality quality;
    if ([selectedQuality containsString:@"Low"]) {
        quality = BWVideoQualityLow;
    } else if ([selectedQuality containsString:@"Medium"]) {
        quality = BWVideoQualityMedium;
    } else if ([selectedQuality containsString:@"High"]) {
        quality = BWVideoQualityHigh;
    } else {
        os_log_error(bw_settings_log(), "❌ Unknown quality setting: %@", selectedQuality);
        return;
    }
    
    // Apply the quality setting
    NSError *error;
    BOOL success = [self.applicationCoordinator.captureManager updateVideoQuality:quality error:&error];
    
    if (success) {
        os_log_info(bw_settings_log(), "✅ Successfully changed video quality to: %@", selectedQuality);
        
        // Update camera info to reflect new resolution
        [self updateCameraInfo];
        
        // Restart video processing automatically for seamless quality switching
        [self restartVideoProcessingForCameraSwitch];
        
        // Preview refresh handled by separate preview window
    } else {
        os_log_error(bw_settings_log(), "❌ Failed to change video quality: %@", error.localizedDescription);
        
        // Show error to user
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Quality Change Failed";
        alert.informativeText = [NSString stringWithFormat:@"Could not change video quality: %@", error.localizedDescription];
        alert.alertStyle = NSAlertStyleWarning;
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
    }
}

- (void)restartVideoProcessingForCameraSwitch {
    os_log_info(bw_settings_log(), "🔄 Restarting video processing for camera switch...");
    
    if (!self.applicationCoordinator) {
        os_log_error(bw_settings_log(), "❌ Cannot restart video processing - coordinator not available");
        return;
    }
    
    // Get current enhancement state
    BOOL wasEnhancementEnabled = self.applicationCoordinator.enhancementEnabled;
    
    // Stop current video processing
    [self.applicationCoordinator stopVideoProcessing];
    
    // Small delay to ensure clean shutdown
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        // Restart video processing if it was previously enabled
        if (wasEnhancementEnabled) {
            NSError *error;
            BOOL success = [self.applicationCoordinator startVideoProcessingWithError:&error];
            
            if (success) {
                os_log_info(bw_settings_log(), "✅ Video processing restarted successfully after camera switch");
                
                // Re-establish video processor delegate connection for preview window
                [self reconnectPreviewWindow];
                
            } else {
                os_log_error(bw_settings_log(), "❌ Failed to restart video processing: %@", error.localizedDescription);
            }
        } else {
            os_log_info(bw_settings_log(), "💡 Enhancement was disabled - not restarting video processing");
        }
    });
}

- (void)reconnectPreviewWindow {
    // Ensure preview window has proper connection to new video stream
    BWPreviewWindowController *previewController = [BWPreviewWindowController sharedController];
    if (previewController.applicationCoordinator) {
        os_log_info(bw_settings_log(), "🔄 Reconnecting preview window to video processor");
        
        // Re-establish the delegate connection
        previewController.applicationCoordinator = self.applicationCoordinator;
        
        // Refresh preview if it's currently active
        dispatch_async(dispatch_get_main_queue(), ^{
            // Force preview refresh
            if (previewController.window.isVisible) {
                os_log_info(bw_settings_log(), "🎬 Refreshing active preview window");
            }
        });
    }
}

#pragma mark - Helper Methods

- (void)updateParameterAndLabel:(NSSlider *)slider {
    float value = slider.floatValue;
    
    // Update the corresponding parameter
    BWProcessingParameters *params = [[BWProcessingParameters alloc] init];
    
    // Copy current parameters
    BWProcessingParameters *current = self.applicationCoordinator.videoProcessor.processingParameters;
    params.skinSmoothingIntensity = current.skinSmoothingIntensity;
    params.skinBrighteningAmount = current.skinBrighteningAmount;
    params.brightnessAdjustment = current.brightnessAdjustment;
    params.contrastAdjustment = current.contrastAdjustment;
    params.saturationBoost = current.saturationBoost;
    params.temperatureShift = current.temperatureShift;
    params.sharpeningAmount = current.sharpeningAmount;
    params.noiseReductionLevel = current.noiseReductionLevel;
    params.vignetteIntensity = current.vignetteIntensity;
    
    // Update the specific parameter
    if (slider == self.skinSmoothingSlider) {
        params.skinSmoothingIntensity = value;
    } else if (slider == self.brightnessSlider) {
        params.brightnessAdjustment = value;
    } else if (slider == self.contrastSlider) {
        params.contrastAdjustment = value;
    } else if (slider == self.saturationSlider) {
        params.saturationBoost = value;
    } else if (slider == self.temperatureSlider) {
        params.temperatureShift = value;
    } else if (slider == self.sharpeningSlider) {
        params.sharpeningAmount = value;
    } else if (slider == self.noiseReductionSlider) {
        params.noiseReductionLevel = value;
    }
    
    // Apply updated parameters
    [self.applicationCoordinator.videoProcessor updateParameters:params];
    
    // Update value label
    NSInteger tag = 1000 + (NSInteger)slider.frame.origin.y;
    NSTextField *valueLabel = [self.enhancementTabView viewWithTag:tag];
    if (valueLabel) {
        valueLabel.stringValue = [NSString stringWithFormat:@"%.2f", value];
    }
    
    // Switch to custom preset
    [self.presetPopup selectItemWithTitle:@"Custom"];
    
    // Update preview with new settings
    // Preview refresh handled by separate preview window
}

- (void)updateControlsWithCurrentSettings {
    if (!self.applicationCoordinator) return;
    
    BWProcessingParameters *params = self.applicationCoordinator.videoProcessor.processingParameters;
    BOOL enhancementEnabled = self.applicationCoordinator.enhancementEnabled;
    
    // Update enhancement toggle
    self.enhancementToggle.state = enhancementEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    
    // Update sliders
    self.skinSmoothingSlider.floatValue = params.skinSmoothingIntensity;
    self.brightnessSlider.floatValue = params.brightnessAdjustment;
    self.contrastSlider.floatValue = params.contrastAdjustment;
    self.saturationSlider.floatValue = params.saturationBoost;
    self.temperatureSlider.floatValue = params.temperatureShift;
    self.sharpeningSlider.floatValue = params.sharpeningAmount;
    self.noiseReductionSlider.floatValue = params.noiseReductionLevel;
    
    // Update value labels
    [self updateAllValueLabels];
}

- (void)updateAllValueLabels {
    NSArray *sliders = @[self.skinSmoothingSlider, self.brightnessSlider, self.contrastSlider,
                        self.saturationSlider, self.temperatureSlider, self.sharpeningSlider,
                        self.noiseReductionSlider];
    
    for (NSSlider *slider in sliders) {
        NSInteger tag = 1000 + (NSInteger)slider.frame.origin.y;
        NSTextField *valueLabel = [self.enhancementTabView viewWithTag:tag];
        if (valueLabel) {
            valueLabel.stringValue = [NSString stringWithFormat:@"%.2f", slider.floatValue];
        }
    }
}

- (void)updateCameraList {
    [self.cameraPopup removeAllItems];
    
    if (self.applicationCoordinator) {
        NSArray *cameras = self.applicationCoordinator.captureManager.availableDevices;
        
        if (cameras.count == 0) {
            [self.cameraPopup addItemWithTitle:@"No cameras available"];
            self.cameraInfoLabel.stringValue = @"No camera devices found. Please connect a camera and restart the application.";
            return;
        }
        
        // Add cameras with detailed information
        for (AVCaptureDevice *device in cameras) {
            NSString *deviceTitle = device.localizedName;
            
            // Add device type info if available
            if (@available(macOS 14.0, *)) {
                if (device.deviceType == AVCaptureDeviceTypeContinuityCamera) {
                    deviceTitle = [NSString stringWithFormat:@"%@ (Continuity Camera)", device.localizedName];
                } else if (device.deviceType == AVCaptureDeviceTypeExternal) {
                    deviceTitle = [NSString stringWithFormat:@"%@ (External)", device.localizedName];
                }
            }
            
            [self.cameraPopup addItemWithTitle:deviceTitle];
        }
        
        // Select current device if available
        AVCaptureDevice *currentDevice = self.applicationCoordinator.captureManager.currentDevice;
        if (currentDevice) {
            [self.cameraPopup selectItemWithTitle:currentDevice.localizedName];
        }
        
        // Update detailed camera info
        [self updateCameraInfo];
    } else {
        [self.cameraPopup addItemWithTitle:@"Application not ready"];
        self.cameraInfoLabel.stringValue = @"Application coordinator not available.";
    }
}

- (void)refreshCoordinatorConnection {
    os_log_info(bw_settings_log(), "🔄 Refreshing coordinator connection...");
    
    // Get application coordinator reference
    NSApplication *app = [NSApplication sharedApplication];
    
    if ([app.delegate respondsToSelector:@selector(applicationCoordinator)]) {
        BWApplicationCoordinator *coordinator = [(id)app.delegate applicationCoordinator];
        
        if (coordinator && coordinator != self.applicationCoordinator) {
            self.applicationCoordinator = coordinator;
            os_log_info(bw_settings_log(), "✅ Application coordinator updated: %@", self.applicationCoordinator);
            
            // Force device discovery if capture manager exists
            if (self.applicationCoordinator.captureManager) {
                os_log_info(bw_settings_log(), "🔍 Forcing device discovery...");
                [self.applicationCoordinator.captureManager refreshAvailableDevices];
            }
            
            // Note: Preview window handles video processor delegate, not settings window
            os_log_info(bw_settings_log(), "🎬 Delegate connection handled by preview window");
            
            // Update controls with current values
            [self updateControlsWithCurrentSettings];
            
            // Update camera information
            [self updateCameraList];
            
            // Connect preview view to application coordinator
            // Preview view is now in separate window
            os_log_info(bw_settings_log(), "🎥 Preview view moved to separate window");
        } else if (!self.applicationCoordinator) {
            os_log_error(bw_settings_log(), "❌ Application coordinator still nil during refresh");
        } else {
            // Same coordinator, but force refresh anyway
            os_log_info(bw_settings_log(), "🔄 Same coordinator, forcing camera list refresh...");
            
            // Force device discovery
            if (self.applicationCoordinator.captureManager) {
                [self.applicationCoordinator.captureManager refreshAvailableDevices];
            }
            
            [self updateCameraList];
        }
    }
}

- (void)updateCameraInfo {
    if (!self.applicationCoordinator) {
        return;
    }
    
    AVCaptureDevice *currentDevice = self.applicationCoordinator.captureManager.currentDevice;
    if (currentDevice) {
        NSMutableString *info = [NSMutableString string];
        
        [info appendFormat:@"📷 %@", currentDevice.localizedName];
        
        if (currentDevice.modelID) {
            [info appendFormat:@"  •  Model: %@", currentDevice.modelID];
        }
        
        [info appendFormat:@"  •  Status: %@", currentDevice.connected ? @"Connected" : @"Disconnected"];
        
        // Add format information
        if (currentDevice.activeFormat) {
            CMVideoDimensions dims = CMVideoFormatDescriptionGetDimensions(currentDevice.activeFormat.formatDescription);
            [info appendFormat:@"  •  Resolution: %dx%d", dims.width, dims.height];
        }
        
        self.cameraInfoLabel.stringValue = info;
    } else {
        self.cameraInfoLabel.stringValue = @"No camera device selected or available.";
    }
}

- (void)updatePerformanceMetrics {
    if (!self.applicationCoordinator) return;
    
    NSDictionary *metrics = [self.applicationCoordinator getProcessingPerformanceMetrics];
    
    double processingTime = [metrics[@"averageProcessingTime"] doubleValue] * 1000.0; // Convert to ms
    double frameRate = [metrics[@"currentFrameRate"] doubleValue];
    NSInteger frameCount = [metrics[@"processedFrameCount"] integerValue];
    
    self.processingTimeLabel.stringValue = [NSString stringWithFormat:@"%.2f ms", processingTime];
    self.frameRateLabel.stringValue = [NSString stringWithFormat:@"%.1f fps", frameRate];
    self.frameCountLabel.stringValue = [NSString stringWithFormat:@"%ld", (long)frameCount];
    
    // Update CPU usage indicator based on processing time
    double targetFrameTime = 1000.0 / 30.0; // 30fps = 33.33ms per frame
    double cpuPercentage = MIN(100.0, (processingTime / targetFrameTime) * 100.0);
    self.cpuUsageIndicator.doubleValue = cpuPercentage;
}

#pragma mark - BWVideoProcessorDelegate

- (void)videoProcessor:(id)processor didUpdatePerformanceMetrics:(NSDictionary *)metrics {
    // Performance metrics are automatically updated by the timer
    // This delegate method is available for additional processing if needed
}

@end
