//
//  BWPreviewWindowController.h
//  BeautyWebcam
//
//  Copyright © 2024 BeautyWebcam. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "BWApplicationCoordinator.h"

@interface BWPreviewWindowController : NSWindowController

@property (nonatomic, weak) BWApplicationCoordinator *applicationCoordinator;

+ (instancetype)sharedController;
- (void)showPreviewWindow;
- (void)hidePreviewWindow;

@end
