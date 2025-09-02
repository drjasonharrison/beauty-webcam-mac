# BeautyWebcam Project Structure

## Overview
This document defines the recommended directory structure and organization for the BeautyWebcam macOS application. The structure follows Xcode best practices and separates concerns for maintainability and scalability.

## Root Directory Structure

```
BeautyWebcam/
├── BeautyWebcam.xcodeproj/
├── BeautyWebcam/                      # Main application target
│   ├── Application/                   # App lifecycle and main application logic
│   ├── Core/                         # Core business logic and services
│   ├── Capture/                      # Video capture and camera management
│   ├── Processing/                   # Image processing and enhancement engine
│   ├── VirtualCamera/                # CoreMediaIO virtual camera implementation
│   ├── UI/                          # User interface components
│   ├── Utils/                       # Shared utilities and helpers
│   ├── Resources/                   # App resources, assets, and configuration
│   └── Supporting Files/            # Info.plist, main.m, prefix headers
├── BeautyWebcamTests/               # Unit tests
├── BeautyWebcamUITests/             # UI automation tests
├── Frameworks/                      # External frameworks and libraries
├── Scripts/                         # Build scripts and automation
├── Documentation/                   # Project documentation
│   ├── PRD.md                      # Product Requirements Document
│   ├── todo.md                     # Development roadmap
│   ├── API.md                      # Internal API documentation
│   └── ARCHITECTURE.md             # Technical architecture guide
└── .cursor/                        # Cursor IDE configuration
    └── rules/                      # Code style and project rules
```

## Detailed Directory Breakdown

### `/BeautyWebcam/Application/`
**Purpose:** Application lifecycle, delegate, and main application coordination

```
Application/
├── BWAppDelegate.h
├── BWAppDelegate.m
├── BWApplicationCoordinator.h       # Main app coordinator
├── BWApplicationCoordinator.m
├── BWApplicationState.h            # App state management
├── BWApplicationState.m
└── Constants/
    ├── BWConstants.h               # Global constants
    ├── BWErrorConstants.h          # Error codes and domains
    └── BWNotificationConstants.h   # Notification names
```

**Key Responsibilities:**
- Application startup and shutdown
- Global application state management
- Menu bar setup and coordination
- System event handling (sleep/wake, etc.)

### `/BeautyWebcam/Core/`
**Purpose:** Core business logic, models, and shared services

```
Core/
├── Models/                         # Data models and structures
│   ├── BWCameraDevice.h
│   ├── BWCameraDevice.m
│   ├── BWProcessingParameters.h
│   ├── BWProcessingParameters.m
│   ├── BWUserPreferences.h
│   └── BWUserPreferences.m
├── Services/                       # Core services
│   ├── BWSettingsManager.h
│   ├── BWSettingsManager.m
│   ├── BWPerformanceMonitor.h
│   ├── BWPerformanceMonitor.m
│   ├── BWLicenseManager.h
│   └── BWLicenseManager.m
└── Protocols/                      # Core protocols and delegates
    ├── BWProcessingDelegate.h
    ├── BWCaptureDelegate.h
    └── BWPerformanceDelegate.h
```

**Key Responsibilities:**
- Data models and business objects
- Settings persistence and management
- License validation and management
- Performance monitoring and analytics

### `/BeautyWebcam/Capture/`
**Purpose:** Video capture, camera management, and AVFoundation integration

```
Capture/
├── BWCaptureManager.h
├── BWCaptureManager.m
├── BWCameraDiscovery.h             # USB camera detection
├── BWCameraDiscovery.m
├── BWCaptureSession.h              # AVFoundation session wrapper
├── BWCaptureSession.m
├── BWFrameReceiver.h               # Frame delegation and routing
├── BWFrameReceiver.m
└── Hardware/                       # Hardware-specific implementations
    ├── BWUVCCameraController.h     # UVC camera controls
    ├── BWUVCCameraController.m
    ├── BWCameraCapabilities.h      # Camera capability detection
    └── BWCameraCapabilities.m
```

**Key Responsibilities:**
- USB webcam detection and management
- AVFoundation capture session setup
- Camera capability detection
- Hardware-specific control interfaces
- Frame capture and initial routing

### `/BeautyWebcam/Processing/`
**Purpose:** Image processing, enhancement algorithms, and GPU acceleration

```
Processing/
├── BWProcessingEngine.h
├── BWProcessingEngine.m
├── BWProcessingPipeline.h          # Processing pipeline coordination
├── BWProcessingPipeline.m
├── Filters/                        # Individual processing filters
│   ├── BWBilateralFilter.h
│   ├── BWBilateralFilter.m
│   ├── BWColorEnhancer.h
│   ├── BWColorEnhancer.m
│   ├── BWNoiseReducer.h
│   ├── BWNoiseReducer.m
│   └── BWSkinSmoother.h
│   └── BWSkinSmoother.m
├── Metal/                          # Metal shaders and GPU processing
│   ├── BWMetalProcessor.h
│   ├── BWMetalProcessor.m
│   ├── BeautyWebcam_Shaders.metal  # Metal shader implementations
│   └── BWMetalUtils.h
│   └── BWMetalUtils.m
└── CoreImage/                      # Core Image filter implementations
    ├── BWCoreImageProcessor.h
    ├── BWCoreImageProcessor.m
    └── Filters/
        ├── BWCustomCIFilter.h
        └── BWCustomCIFilter.m
```

**Key Responsibilities:**
- Real-time image processing algorithms
- GPU acceleration with Metal
- Core Image filter management
- Processing pipeline optimization
- Beauty enhancement algorithms

### `/BeautyWebcam/VirtualCamera/`
**Purpose:** CoreMediaIO virtual camera implementation

```
VirtualCamera/
├── BWVirtualCameraPlugin.h
├── BWVirtualCameraPlugin.m
├── BWVirtualCameraDevice.h         # Virtual camera device
├── BWVirtualCameraDevice.m
├── BWVirtualCameraStream.h         # Stream management
├── BWVirtualCameraStream.m
├── BWFrameDelivery.h               # Frame delivery to consumers
├── BWFrameDelivery.m
├── BWPixelBufferPool.h             # Efficient buffer management
├── BWPixelBufferPool.m
└── Property/                       # CoreMediaIO property management
    ├── BWCMIOProperties.h
    ├── BWCMIOProperties.m
    ├── BWDeviceProperties.h
    └── BWDeviceProperties.m
```

**Key Responsibilities:**
- CoreMediaIO plugin registration
- Virtual camera device creation
- Frame delivery to applications
- Property management and queries
- System integration and compatibility

### `/BeautyWebcam/UI/`
**Purpose:** User interface components and AppKit integration

```
UI/
├── MenuBar/                        # Menu bar interface
│   ├── BWMenuBarManager.h
│   ├── BWMenuBarManager.m
│   ├── BWStatusItemController.h
│   └── BWStatusItemController.m
├── Windows/                        # Window controllers and views
│   ├── Settings/
│   │   ├── BWSettingsWindowController.h
│   │   ├── BWSettingsWindowController.m
│   │   ├── BWEnhancementTabView.h
│   │   ├── BWEnhancementTabView.m
│   │   ├── BWPerformanceTabView.h
│   │   └── BWPerformanceTabView.m
│   └── Performance/
│       ├── BWPerformanceWindowController.h
│       ├── BWPerformanceWindowController.m
│       ├── BWPerformanceGraphView.h
│       └── BWPerformanceGraphView.m
├── Components/                     # Reusable UI components
│   ├── BWSliderControl.h
│   ├── BWSliderControl.m
│   ├── BWToggleButton.h
│   ├── BWToggleButton.m
│   ├── BWPresetSelector.h
│   └── BWPresetSelector.m
└── Storyboards/                   # Interface Builder files
    ├── Main.storyboard
    ├── Settings.storyboard
    └── Performance.storyboard
```

**Key Responsibilities:**
- Menu bar interface and interactions
- Settings window and configuration UI
- Performance monitoring display
- Reusable UI components
- User preference interfaces

### `/BeautyWebcam/Utils/`
**Purpose:** Shared utilities, helpers, and common functionality

```
Utils/
├── Categories/                     # Objective-C categories
│   ├── NSImage+BWExtensions.h
│   ├── NSImage+BWExtensions.m
│   ├── NSColor+BWExtensions.h
│   ├── NSColor+BWExtensions.m
│   ├── CVPixelBuffer+BWExtensions.h
│   └── CVPixelBuffer+BWExtensions.m
├── Helpers/                       # Helper classes
│   ├── BWColorManager.h           # Color and appearance management
│   ├── BWColorManager.m
│   ├── BWAnimationHelper.h        # UI animation utilities
│   ├── BWAnimationHelper.m
│   ├── BWFileHelper.h             # File and path utilities
│   └── BWFileHelper.m
└── Debugging/                     # Debug and logging utilities
    ├── BWLogger.h
    ├── BWLogger.m
    ├── BWPerformanceProfiler.h
    └── BWPerformanceProfiler.m
```

**Key Responsibilities:**
- Common utility functions
- Objective-C category extensions
- Debugging and logging tools
- Performance profiling utilities
- File and system helpers

### `/BeautyWebcam/Resources/`
**Purpose:** Application resources, assets, and configuration files

```
Resources/
├── Images/                        # App icons and images
│   ├── AppIcon.iconset/
│   ├── StatusBar/
│   │   ├── StatusBarIcon_Active@2x.png
│   │   ├── StatusBarIcon_Inactive@2x.png
│   │   ├── StatusBarIcon_Processing@2x.png
│   │   └── StatusBarIcon_Error@2x.png
│   └── UI/
│       ├── Settings_Icon@2x.png
│       └── Performance_Icon@2x.png
├── Presets/                       # Default enhancement presets
│   ├── Natural.json
│   ├── Studio.json
│   ├── Creative.json
│   └── Custom.json
├── Shaders/                       # Additional shader resources
│   └── LookupTables/
│       ├── warm_tone.png
│       ├── cool_tone.png
│       └── vintage.png
└── Localization/                  # Localized strings
    ├── en.lproj/
    │   └── Localizable.strings
    └── Base.lproj/
        └── Localizable.strings
```

**Key Responsibilities:**
- Application icons and visual assets
- Default enhancement presets
- Shader resources and lookup tables
- Localization files
- Configuration data

## Build Configuration

### Xcode Project Organization

```
BeautyWebcam.xcodeproj/
├── project.pbxproj
└── xcuserdata/
    └── [username].xcuserdatad/
        ├── xcschemes/
        │   ├── BeautyWebcam.xcscheme
        │   ├── BeautyWebcam Debug.xcscheme
        │   └── BeautyWebcam Release.xcscheme
        └── WorkspaceSettings.xcsettings
```

### Build Schemes
- **BeautyWebcam Debug**: Development build with debug symbols and logging
- **BeautyWebcam Release**: Optimized release build for distribution
- **BeautyWebcam Profile**: Profiling build with instruments integration

### Target Configuration
- **Deployment Target**: macOS 10.15 (Catalina) minimum
- **Architectures**: x86_64, arm64 (Universal Binary)
- **Code Signing**: Developer ID for distribution outside App Store
- **Entitlements**: Camera access, network access for licensing

## Testing Structure

### Unit Tests (`/BeautyWebcamTests/`)
```
BeautyWebcamTests/
├── Core/
│   ├── BWSettingsManagerTests.m
│   └── BWPerformanceMonitorTests.m
├── Processing/
│   ├── BWProcessingEngineTests.m
│   ├── BWBilateralFilterTests.m
│   └── BWColorEnhancerTests.m
├── VirtualCamera/
│   ├── BWVirtualCameraDeviceTests.m
│   └── BWFrameDeliveryTests.m
└── Utils/
    ├── BWColorManagerTests.m
    └── BWPerformanceProfilerTests.m
```

### UI Tests (`/BeautyWebcamUITests/`)
```
BeautyWebcamUITests/
├── MenuBar/
│   └── BWMenuBarInteractionTests.m
├── Settings/
│   ├── BWSettingsWindowTests.m
│   └── BWEnhancementControlsTests.m
└── Integration/
    └── BWFullWorkflowTests.m
```

## External Dependencies

### Frameworks (System)
- **Foundation.framework**: Core Objective-C runtime
- **AppKit.framework**: macOS UI framework
- **AVFoundation.framework**: Video capture and processing
- **CoreMediaIO.framework**: Virtual camera implementation
- **Metal.framework**: GPU acceleration
- **MetalKit.framework**: Metal utilities
- **CoreImage.framework**: Image processing filters
- **IOKit.framework**: Hardware communication
- **Accelerate.framework**: Mathematical optimizations

### Third-Party Libraries (Optional)
```
Frameworks/
├── Sparkle.framework           # Automatic updates (optional)
└── CocoaLumberjack.framework  # Advanced logging (optional)
```

## Development Workflow

### File Naming Conventions
- **Classes**: `BW` prefix + descriptive name (e.g., `BWCaptureManager`)
- **Protocols**: `BW` prefix + descriptive name + `Delegate`/`Protocol` suffix
- **Categories**: `BW` prefix + `Extensions` suffix (e.g., `BWExtensions`)
- **Constants**: `k` + `BW` + descriptive name (e.g., `kBWMaxFrameRate`)

### Header Organization
```objc
// BWExampleClass.h
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

// Forward declarations
@class BWOtherClass;
@protocol BWExampleDelegate;

// Constants
extern NSString *const BWExampleNotificationName;

// Enums
typedef NS_ENUM(NSInteger, BWExampleState) {
    BWExampleStateInactive,
    BWExampleStateActive,
    BWExampleStateProcessing
};

// Main interface
@interface BWExampleClass : NSObject

// Properties (grouped by type)
@property (nonatomic, strong, nullable) id<BWExampleDelegate> delegate;
@property (nonatomic, assign) BWExampleState state;
@property (nonatomic, strong, readonly) NSString *identifier;

// Methods (grouped by functionality)
- (instancetype)initWithConfiguration:(BWConfiguration *)configuration NS_DESIGNATED_INITIALIZER;
- (BOOL)startWithError:(NSError **)error;
- (void)stop;

@end
```

## Deployment and Distribution

### App Store Distribution
```
Distribution/
├── AppStore/
│   ├── BeautyWebcam.app
│   ├── BeautyWebcam.pkg
│   └── Metadata/
│       ├── screenshots/
│       ├── description.txt
│       └── keywords.txt
```

### Direct Distribution
```
Distribution/
├── Direct/
│   ├── BeautyWebcam.dmg
│   ├── BeautyWebcam.zip
│   └── Updates/
│       ├── appcast.xml
│       └── release_notes.html
```

## Summary

This project structure provides:

1. **Clear Separation of Concerns**: Each directory has a specific purpose
2. **Scalability**: Easy to add new features without restructuring
3. **Maintainability**: Logical organization makes code easy to find and modify
4. **Testing**: Dedicated test structure mirrors main application structure
5. **Build Efficiency**: Organized resources and build configuration
6. **Documentation**: Comprehensive documentation alongside code

The structure follows Xcode and macOS development best practices while remaining flexible enough to accommodate the specific needs of a real-time video processing application.
