//
//  BWAppDelegate.h
//  BeautyWebcam
//
//  Created by BeautyWebcam on 2024.
//  Copyright © 2024 BeautyWebcam. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "BWMenuBarManager.h"

NS_ASSUME_NONNULL_BEGIN

@class BWApplicationCoordinator;

@interface BWAppDelegate : NSObject <NSApplicationDelegate, BWMenuBarDelegate>

@property (nonatomic, strong) BWMenuBarManager *menuBarManager;
@property (nonatomic, strong) BWApplicationCoordinator *applicationCoordinator;

@end

NS_ASSUME_NONNULL_END
