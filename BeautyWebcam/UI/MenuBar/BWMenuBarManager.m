//
//  BWMenuBarManager.m
//  BeautyWebcam
//
//  Created by BeautyWebcam on 2024.
//  Copyright © 2024 BeautyWebcam. All rights reserved.
//

#import "BWMenuBarManager.h"

@interface BWMenuBarManager ()
@property (nonatomic, strong, readwrite) NSStatusItem *statusItem;
@property (nonatomic, strong, readwrite) NSMenu *statusMenu;
@property (nonatomic, strong) NSTimer *animationTimer;
@property (nonatomic, assign) NSInteger animationFrame;
@end

@implementation BWMenuBarManager

- (instancetype)init {
    if (self = [super init]) {
        _currentState = BWApplicationStateInactive;
        _enhancementEnabled = NO;
        _animationFrame = 0;
    }
    return self;
}

- (void)dealloc {
    [self.animationTimer invalidate];
    [[NSStatusBar systemStatusBar] removeStatusItem:self.statusItem];
}

#pragma mark - Public Methods

- (void)setupMenuBar {
    // Create status item with variable width
    self.statusItem = [[NSStatusBar systemStatusBar] 
        statusItemWithLength:NSVariableStatusItemLength];
    
    // Configure status item
    self.statusItem.button.image = [self statusImageForState:BWApplicationStateInactive];
    self.statusItem.button.imagePosition = NSImageOnly;
    self.statusItem.button.target = self;
    self.statusItem.button.action = @selector(statusItemClicked:);
    self.statusItem.button.toolTip = @"BeautyWebcam - Click to open menu";
    
    // Create and assign menu
    [self setupStatusMenu];
    self.statusItem.menu = self.statusMenu;
    
    NSLog(@"Menu bar setup complete");
}

- (void)updateStatusWithState:(BWApplicationState)state {
    self.currentState = state;
    
    // Update on main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        self.statusItem.button.image = [self statusImageForState:state];
        self.statusItem.button.toolTip = [self tooltipForState:state];
        [self updateMenuItemsForState:state];
        
        // Handle animation for processing state
        if (state == BWApplicationStateProcessing) {
            [self startProcessingAnimation];
        } else {
            [self stopProcessingAnimation];
        }
    });
}

- (void)setEnhancementEnabled:(BOOL)enabled {
    _enhancementEnabled = enabled;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateEnhancementToggleMenuItem];
        
        // Update state based on enhancement status
        BWApplicationState newState = enabled ? BWApplicationStateActive : BWApplicationStateInactive;
        [self updateStatusWithState:newState];
    });
}

#pragma mark - Private Methods

- (void)setupStatusMenu {
    self.statusMenu = [[NSMenu alloc] init];
    self.statusMenu.delegate = self;
    
    // Enhancement toggle
    NSMenuItem *toggleItem = [[NSMenuItem alloc] 
        initWithTitle:@"Enhancement Off"
        action:@selector(toggleEnhancement:)
        keyEquivalent:@""];
    toggleItem.target = self;
    toggleItem.tag = BWMenuItemTagToggle;
    [self.statusMenu addItem:toggleItem];
    
    [self.statusMenu addItem:[NSMenuItem separatorItem]];
    
    // Preset menu items
    [self addPresetMenuItems];
    
    [self.statusMenu addItem:[NSMenuItem separatorItem]];
    
    // Settings
    NSMenuItem *settingsItem = [[NSMenuItem alloc] 
        initWithTitle:@"Settings..."
        action:@selector(showSettings:)
        keyEquivalent:@","];
    settingsItem.target = self;
    settingsItem.tag = BWMenuItemTagSettings;
    [self.statusMenu addItem:settingsItem];
    
    // Live Preview
    NSMenuItem *previewItem = [[NSMenuItem alloc] 
        initWithTitle:@"Live Preview..."
        action:@selector(showPreview:)
        keyEquivalent:@"p"];
    previewItem.target = self;
    [self.statusMenu addItem:previewItem];
    
    // Performance monitor
    NSMenuItem *performanceItem = [[NSMenuItem alloc] 
        initWithTitle:@"Performance Monitor"
        action:@selector(showPerformanceMonitor:)
        keyEquivalent:@""];
    performanceItem.target = self;
    performanceItem.tag = BWMenuItemTagPerformance;
    [self.statusMenu addItem:performanceItem];
    
    [self.statusMenu addItem:[NSMenuItem separatorItem]];
    
    // Help and support
    NSMenuItem *helpItem = [[NSMenuItem alloc] 
        initWithTitle:@"Help & Support"
        action:@selector(showHelp:)
        keyEquivalent:@""];
    helpItem.target = self;
    helpItem.tag = BWMenuItemTagHelp;
    [self.statusMenu addItem:helpItem];
    
    [self.statusMenu addItem:[NSMenuItem separatorItem]];
    
    // Quit
    NSMenuItem *quitItem = [[NSMenuItem alloc] 
        initWithTitle:@"Quit BeautyWebcam"
        action:@selector(quitApplication:)
        keyEquivalent:@"q"];
    quitItem.target = self;
    quitItem.tag = BWMenuItemTagQuit;
    [self.statusMenu addItem:quitItem];
}

- (void)addPresetMenuItems {
    // Preset submenu
    NSMenuItem *presetsMenuItem = [[NSMenuItem alloc] initWithTitle:@"Presets" action:nil keyEquivalent:@""];
    NSMenu *presetsSubmenu = [[NSMenu alloc] init];
    
    // Natural Beauty preset
    NSMenuItem *naturalItem = [[NSMenuItem alloc] 
        initWithTitle:@"🎭 Natural Beauty"
        action:@selector(selectPreset:)
        keyEquivalent:@""];
    naturalItem.target = self;
    naturalItem.tag = BWMenuItemTagPresetNatural;
    naturalItem.representedObject = @"Natural";
    [presetsSubmenu addItem:naturalItem];
    
    // Studio Professional preset
    NSMenuItem *studioItem = [[NSMenuItem alloc] 
        initWithTitle:@"🌟 Studio Professional"
        action:@selector(selectPreset:)
        keyEquivalent:@""];
    studioItem.target = self;
    studioItem.tag = BWMenuItemTagPresetStudio;
    studioItem.representedObject = @"Studio";
    [presetsSubmenu addItem:studioItem];
    
    // Creative Filters preset
    NSMenuItem *creativeItem = [[NSMenuItem alloc] 
        initWithTitle:@"🎨 Creative Filters"
        action:@selector(selectPreset:)
        keyEquivalent:@""];
    creativeItem.target = self;
    creativeItem.tag = BWMenuItemTagPresetCreative;
    creativeItem.representedObject = @"Creative";
    [presetsSubmenu addItem:creativeItem];
    
    presetsMenuItem.submenu = presetsSubmenu;
    [self.statusMenu addItem:presetsMenuItem];
}

- (NSImage *)statusImageForState:(BWApplicationState)state {
    NSString *imageName;
    
    switch (state) {
        case BWApplicationStateInactive:
            imageName = @"camera.fill";  // Using SF Symbols for now
            break;
        case BWApplicationStateActive:
            imageName = @"camera.fill";
            break;
        case BWApplicationStateProcessing:
            imageName = @"camera.fill";
            break;
        case BWApplicationStateError:
            imageName = @"camera.fill";
            break;
    }
    
    NSImage *image = [NSImage imageWithSystemSymbolName:imageName accessibilityDescription:@"BeautyWebcam"];
    
    if (!image) {
        // Fallback to a simple text-based icon
        image = [self createFallbackIcon];
    }
    
    // Configure for menu bar appearance
    image.template = YES;  // Adapts to menu bar color scheme
    
    // Tint based on state
    if (state == BWApplicationStateActive) {
        image.template = NO;  // Don't use template for active state
        // The image will show in its original colors when active
    } else if (state == BWApplicationStateError) {
        image.template = NO;
        // Could tint red for error state
    }
    
    return image;
}

- (NSImage *)createFallbackIcon {
    // Create a simple text-based icon as fallback
    NSSize iconSize = NSMakeSize(18, 18);
    NSImage *image = [[NSImage alloc] initWithSize:iconSize];
    
    [image lockFocus];
    
    // Clear background
    [[NSColor clearColor] set];
    NSRectFill(NSMakeRect(0, 0, iconSize.width, iconSize.height));
    
    // Draw simple camera representation
    NSRect rect = NSMakeRect(2, 2, iconSize.width - 4, iconSize.height - 4);
    [[NSColor controlTextColor] set];
    
    // Draw camera body
    NSBezierPath *body = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:2 yRadius:2];
    [body stroke];
    
    // Draw lens
    NSRect lensRect = NSMakeRect(rect.origin.x + 4, rect.origin.y + 4, rect.size.width - 8, rect.size.height - 8);
    NSBezierPath *lens = [NSBezierPath bezierPathWithOvalInRect:lensRect];
    [lens stroke];
    
    [image unlockFocus];
    
    return image;
}

- (NSString *)tooltipForState:(BWApplicationState)state {
    switch (state) {
        case BWApplicationStateInactive:
            return @"BeautyWebcam - Enhancement Off";
        case BWApplicationStateActive:
            return @"BeautyWebcam - Enhancement Active";
        case BWApplicationStateProcessing:
            return @"BeautyWebcam - Processing...";
        case BWApplicationStateError:
            return @"BeautyWebcam - Error (Click for details)";
        default:
            return @"BeautyWebcam";
    }
}

- (void)updateMenuItemsForState:(BWApplicationState)state {
    // Enable/disable menu items based on state
    for (NSMenuItem *item in self.statusMenu.itemArray) {
        if (item.tag == BWMenuItemTagToggle) {
            // Toggle is always enabled
            continue;
        } else if (item.tag >= BWMenuItemTagPresetNatural && item.tag <= BWMenuItemTagPresetCreative) {
            // Presets only enabled when not processing
            item.enabled = (state != BWApplicationStateProcessing);
        }
    }
}

- (void)updateEnhancementToggleMenuItem {
    NSMenuItem *toggleItem = [self.statusMenu itemWithTag:BWMenuItemTagToggle];
    if (toggleItem) {
        toggleItem.title = self.enhancementEnabled ? @"✓ Enhancement On" : @"Enhancement Off";
    }
}

- (void)startProcessingAnimation {
    if (self.animationTimer) return;  // Already animating
    
    self.animationTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                           target:self
                                                         selector:@selector(animationTick:)
                                                         userInfo:nil
                                                          repeats:YES];
}

- (void)stopProcessingAnimation {
    [self.animationTimer invalidate];
    self.animationTimer = nil;
    self.animationFrame = 0;
}

- (void)animationTick:(NSTimer *)timer {
    // Simple animation by cycling through different states
    self.animationFrame = (self.animationFrame + 1) % 3;
    
    // Update icon with animation frame
    NSImage *image = [self statusImageForState:BWApplicationStateProcessing];
    
    // Modify alpha for pulsing effect
    CGFloat alpha = 0.5 + (0.5 * (self.animationFrame / 2.0));
    // Note: For a real pulsing effect, we'd need to create a new image with alpha
    
    self.statusItem.button.image = image;
}

#pragma mark - Menu Actions

- (IBAction)statusItemClicked:(id)sender {
    // This is called when the status item is clicked
    // The menu will show automatically since we assigned it to statusItem.menu
    NSLog(@"Status item clicked");
}

- (IBAction)toggleEnhancement:(NSMenuItem *)sender {
    self.enhancementEnabled = !self.enhancementEnabled;
    
    if ([self.delegate respondsToSelector:@selector(menuBarDidToggleEnhancement:)]) {
        [self.delegate menuBarDidToggleEnhancement:self.enhancementEnabled];
    }
    
    NSLog(@"Enhancement toggled: %@", self.enhancementEnabled ? @"ON" : @"OFF");
}

- (IBAction)selectPreset:(NSMenuItem *)sender {
    NSString *presetName = sender.representedObject;
    if (!presetName) return;
    
    if ([self.delegate respondsToSelector:@selector(menuBarDidSelectPreset:)]) {
        [self.delegate menuBarDidSelectPreset:presetName];
    }
    
    NSLog(@"Preset selected: %@", presetName);
}

- (IBAction)showSettings:(NSMenuItem *)sender {
    if ([self.delegate respondsToSelector:@selector(menuBarDidRequestSettings)]) {
        [self.delegate menuBarDidRequestSettings];
    }
    
    NSLog(@"Settings requested");
}

- (IBAction)showPreview:(NSMenuItem *)sender {
    if ([self.delegate respondsToSelector:@selector(menuBarDidRequestPreview)]) {
        [self.delegate menuBarDidRequestPreview];
    }
    
    NSLog(@"Preview requested");
}

- (IBAction)showPerformanceMonitor:(NSMenuItem *)sender {
    if ([self.delegate respondsToSelector:@selector(menuBarDidRequestPerformanceMonitor)]) {
        [self.delegate menuBarDidRequestPerformanceMonitor];
    }
    
    NSLog(@"Performance monitor requested");
}

- (IBAction)showHelp:(NSMenuItem *)sender {
    if ([self.delegate respondsToSelector:@selector(menuBarDidRequestHelp)]) {
        [self.delegate menuBarDidRequestHelp];
    }
    
    // For now, open a simple alert
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"BeautyWebcam Help";
    alert.informativeText = @"BeautyWebcam provides real-time webcam enhancement for all your video calls.\n\n• Toggle enhancement on/off from the menu\n• Choose from preset filters\n• Adjust settings for custom enhancement\n• Monitor performance in real-time";
    alert.alertStyle = NSAlertStyleInformational;
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
    
    NSLog(@"Help requested");
}

- (IBAction)quitApplication:(NSMenuItem *)sender {
    if ([self.delegate respondsToSelector:@selector(menuBarDidRequestQuit)]) {
        [self.delegate menuBarDidRequestQuit];
    }
    
    NSLog(@"Quit requested");
    [NSApp terminate:nil];
}

#pragma mark - NSMenuDelegate

- (void)menuWillOpen:(NSMenu *)menu {
    NSLog(@"Menu will open");
    // Update menu items before showing
    [self updateMenuItemsForState:self.currentState];
    [self updateEnhancementToggleMenuItem];
}

- (void)menuDidClose:(NSMenu *)menu {
    NSLog(@"Menu did close");
}

@end
