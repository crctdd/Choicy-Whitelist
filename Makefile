THEOS ?= $(HOME)/theos-roothide
THEOS_PACKAGE_SCHEME ?= roothide
ifneq ($(THEOS_PACKAGE_SCHEME),roothide)
$(error Choicy-Whitelist supports roothide only)
endif
export TARGET = iphone:clang:16.5:15.0
export ARCHS = arm64e
export DEBUG = 0
export FINALPACKAGE = 1
export CLANG_MODULE_CACHE_PATH := $(CURDIR)/.theos/module-cache
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = ChoicyWhitelist
ChoicyWhitelist_FILES = Tweak.c gen.c nextstep_plist.c $(wildcard external/litehook/src/*.c)
ChoicyWhitelist_CFLAGS = -DTHEOS_LEAN_AND_MEAN -I./external/litehook/src -I./external/litehook/external/include -I./external/SDKHeaders
include $(THEOS_MAKE_PATH)/tweak.mk
SUBPROJECTS += ChoicyPrefs ChoicySB
include $(THEOS_MAKE_PATH)/aggregate.mk
internal-stage::
	$(ECHO_NOTHING)mv "$(THEOS_STAGING_DIR)/Library/MobileSubstrate/DynamicLibraries/ChoicyWhitelist.dylib" "$(THEOS_STAGING_DIR)/Library/MobileSubstrate/DynamicLibraries/   ChoicyWhitelist.dylib" $(ECHO_END)
	$(ECHO_NOTHING)mv "$(THEOS_STAGING_DIR)/Library/MobileSubstrate/DynamicLibraries/ChoicyWhitelist.plist" "$(THEOS_STAGING_DIR)/Library/MobileSubstrate/DynamicLibraries/   ChoicyWhitelist.plist" $(ECHO_END)
