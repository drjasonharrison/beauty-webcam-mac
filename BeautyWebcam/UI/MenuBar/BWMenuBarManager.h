//
//  BWMenuBarManager.h
//  BeautyWebcam
//
//  Created by BeautyWebcam on 2024.
//  Copyright © 2024 BeautyWebcam. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, BWApplicationState) {
    BWApplicationStateInactive,
    BWApplicationStateActive,
    BWApplicationStateProcessing,
    BWApplicationStateError
};

typedef NS_ENUM(NSInteger, BWMenuItemTag) {
    BWMenuItemTagToggle = 1000,
    BWMenuItemTagPresetNatural = 2000,
    BWMenuItemTagPresetStudio = 2001,
    BWMenuItemTagPresetCreative = 2002,
    BWMenuItemTagSettings = 3000,
    BWMenuItemTagPerformance = 3001,
    BWMenuItemTagHelp = 4000,
    BWMenuItemTagQuit = 5000
};

@protocol BWMenuBarDelegate <NSObject>
@optional
- (void)menuBarDidToggleEnhancement:(BOOL)enabled;
- (void)menuBarDidSelectPreset:(NSString *)presetName;
- (void)menuBarDidRequestSettings;
- (void)menuBarDidRequestPreview;
- (void)menuBarDidRequestPerformanceMonitor;
- (void)menuBarDidRequestHelp;
- (void)menuBarDidRequestQuit;
@end

/**
 * Manages the menu bar interface and user interactions.
 * Provides quick access to common BeautyWebcam features and settings.
 */
@interface BWMenuBarManager : NSObject <NSMenuDelegate>

@property (nonatomic, strong, readonly) NSStatusItem *statusItem;
@property (nonatomic, strong, readonly) NSMenu *statusMenu;
@property (nonatomic, weak) id<BWMenuBarDelegate> delegate;
@property (nonatomic, assign) BWApplicationState currentState;
@property (nonatomic, assign) BOOL enhancementEnabled;

/**
 * Sets up the menu bar status item and menu structure.
 */
- (void)setupMenuBar;

/**
 * Updates the status item appearance based on application state.
 */
- (void)updateStatusWithState:(BWApplicationState)state;

/**
 * Updates the enhancement toggle state in the menu.
 */
- (void)setEnhancementEnabled:(BOOL)enabled;

@end

NS_ASSUME_NONNULL_END
