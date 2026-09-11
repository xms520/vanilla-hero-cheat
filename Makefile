THEOS_DEVICE_IP = localhost
THEOS_DEVICE_PORT = 22
TARGET = iphone:clang:latest:14.0

VanillaHeroCheat_INSTALL_PATH = /Library/MobileSubstrate/DynamicLibraries
VanillaHeroCheat_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore
VanillaHeroCheat_PRIVATE_FRAMEWORKS = Security
VanillaHeroCheat_CFLAGS = -fobjc-arc -Wall -std=c++11
VanillaHeroCheat_FILES = VanillaHeroCheat_v2.xm

include $(THEOS_MAKE_PATH)/aggregate.mk

include $(THEOS_MAKE_PATH)/library.mk
