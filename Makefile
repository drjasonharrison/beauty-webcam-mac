# BeautyWebcam Makefile
# Quick build system for development

PRODUCT_NAME = BeautyWebcam
BUILD_DIR = build/Manual

# Compiler settings
CC = clang
ARCH = arm64
SDK = macosx
MIN_VERSION = 10.15

# Paths
SDK_PATH = $(shell xcrun --show-sdk-path --sdk $(SDK))
FRAMEWORKS_PATH = $(SDK_PATH)/System/Library/Frameworks
APP_PATH = $(BUILD_DIR)/$(PRODUCT_NAME).app

# Source files
SOURCES = \
	BeautyWebcam/main.m \
	BeautyWebcam/Application/BWAppDelegate.m \
	BeautyWebcam/Application/BWApplicationCoordinator.m \
	BeautyWebcam/UI/MenuBar/BWMenuBarManager.m \
	BeautyWebcam/UI/Windows/BWSettingsWindowController.m \
	BeautyWebcam/UI/Windows/BWWindowManager.m \
	BeautyWebcam/UI/Windows/BWPreviewWindowController.m \
	BeautyWebcam/UI/Views/BWCameraPreviewView.m \
	BeautyWebcam/Capture/BWCaptureManager.m \
	BeautyWebcam/VirtualCamera/BWVirtualCameraPlugin.m \
	BeautyWebcam/Processing/BWVideoProcessor.m

# Object files
OBJECTS = $(SOURCES:.m=.o)
OBJECTS_DIR = $(BUILD_DIR)/Objects
OBJECT_FILES = $(addprefix $(OBJECTS_DIR)/,$(notdir $(OBJECTS)))

# Compiler flags
CFLAGS = \
	-target $(ARCH)-apple-$(SDK)$(MIN_VERSION) \
	-isysroot $(SDK_PATH) \
	-fobjc-arc \
	-fmodules \
	-fcxx-modules \
	-Wall \
	-Wextra \
	-O0 -g \
	-I BeautyWebcam \
	-I BeautyWebcam/Application \
	-I BeautyWebcam/UI/MenuBar \
	-I BeautyWebcam/UI/Windows \
	-I BeautyWebcam/UI/Views \
	-I BeautyWebcam/Capture \
	-I BeautyWebcam/VirtualCamera \
	-I BeautyWebcam/Processing

# Linker flags
LDFLAGS = \
	-target $(ARCH)-apple-$(SDK)$(MIN_VERSION) \
	-isysroot $(SDK_PATH) \
	-framework Cocoa \
	-framework AVFoundation \
	-framework CoreMediaIO \
	-framework CoreMedia \
	-framework Metal \
	-framework MetalKit \
	-framework CoreImage \
	-framework IOKit

.PHONY: all clean run setup

all: setup $(APP_PATH)

setup:
	@echo "🔧 Setting up build directories..."
	@mkdir -p $(BUILD_DIR)
	@mkdir -p $(OBJECTS_DIR)
	@mkdir -p $(APP_PATH)/Contents/MacOS
	@mkdir -p $(APP_PATH)/Contents/Resources

# Build application bundle
$(APP_PATH): $(APP_PATH)/Contents/MacOS/$(PRODUCT_NAME) $(APP_PATH)/Contents/Info.plist $(APP_PATH)/Contents/PkgInfo
	@echo "✅ Application bundle created: $(APP_PATH)"

# Link executable
$(APP_PATH)/Contents/MacOS/$(PRODUCT_NAME): $(OBJECT_FILES)
	@echo "🔗 Linking $(PRODUCT_NAME)..."
	$(CC) $(LDFLAGS) -o $@ $(OBJECT_FILES)

# Copy Info.plist
$(APP_PATH)/Contents/Info.plist: BeautyWebcam/Info.plist
	@echo "📄 Copying Info.plist..."
	@cp $< $@

# Create PkgInfo
$(APP_PATH)/Contents/PkgInfo:
	@echo "📄 Creating PkgInfo..."
	@echo -n "APPL????" > $@

# Compile source files
$(OBJECTS_DIR)/main.o: BeautyWebcam/main.m
	@echo "🔨 Compiling main.m..."
	$(CC) $(CFLAGS) -c $< -o $@

$(OBJECTS_DIR)/BWAppDelegate.o: BeautyWebcam/Application/BWAppDelegate.m
	@echo "🔨 Compiling BWAppDelegate.m..."
	$(CC) $(CFLAGS) -c $< -o $@

$(OBJECTS_DIR)/BWApplicationCoordinator.o: BeautyWebcam/Application/BWApplicationCoordinator.m
	@echo "🔨 Compiling BWApplicationCoordinator.m..."
	$(CC) $(CFLAGS) -c $< -o $@

$(OBJECTS_DIR)/BWMenuBarManager.o: BeautyWebcam/UI/MenuBar/BWMenuBarManager.m
	@echo "🔨 Compiling BWMenuBarManager.m..."
	$(CC) $(CFLAGS) -c $< -o $@

$(OBJECTS_DIR)/BWCaptureManager.o: BeautyWebcam/Capture/BWCaptureManager.m
	@echo "🔨 Compiling BWCaptureManager.m..."
	$(CC) $(CFLAGS) -c $< -o $@

$(OBJECTS_DIR)/BWVirtualCameraPlugin.o: BeautyWebcam/VirtualCamera/BWVirtualCameraPlugin.m
	@echo "🔨 Compiling BWVirtualCameraPlugin.m..."
	$(CC) $(CFLAGS) -c $< -o $@

$(OBJECTS_DIR)/BWVideoProcessor.o: BeautyWebcam/Processing/BWVideoProcessor.m
	@echo "🔨 Compiling BWVideoProcessor.m..."
	$(CC) $(CFLAGS) -c $< -o $@

$(OBJECTS_DIR)/BWSettingsWindowController.o: BeautyWebcam/UI/Windows/BWSettingsWindowController.m
	@echo "🔨 Compiling BWSettingsWindowController.m..."
	$(CC) $(CFLAGS) -c $< -o $@

$(OBJECTS_DIR)/BWWindowManager.o: BeautyWebcam/UI/Windows/BWWindowManager.m
	@echo "🔨 Compiling BWWindowManager.m..."
	$(CC) $(CFLAGS) -c $< -o $@

$(OBJECTS_DIR)/BWPreviewWindowController.o: BeautyWebcam/UI/Windows/BWPreviewWindowController.m
	@echo "🔨 Compiling BWPreviewWindowController.m..."
	$(CC) $(CFLAGS) -c $< -o $@

$(OBJECTS_DIR)/BWCameraPreviewView.o: BeautyWebcam/UI/Views/BWCameraPreviewView.m
	@echo "🔨 Compiling BWCameraPreviewView.m..."
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	@echo "🧹 Cleaning build artifacts..."
	@rm -rf $(BUILD_DIR)

run: all
	@echo "🚀 Running $(PRODUCT_NAME)..."
	@open $(APP_PATH)

# Development helper - quick build and run
dev: clean all run
	@echo "🎉 Development build complete!"

# Show build info
info:
	@echo "📋 Build Information:"
	@echo "Product: $(PRODUCT_NAME)"
	@echo "Architecture: $(ARCH)"
	@echo "SDK: $(SDK)"
	@echo "Min Version: $(MIN_VERSION)"
	@echo "SDK Path: $(SDK_PATH)"
	@echo "Build Dir: $(BUILD_DIR)"
	@echo "App Path: $(APP_PATH)"
