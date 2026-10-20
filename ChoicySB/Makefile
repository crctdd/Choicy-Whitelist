INSTALL_TARGET_PROCESSES = SpringBoard

export CLANG_MODULE_CACHE_PATH := $(CURDIR)/.theos/module-cache
include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ChoicyWhitelistSB

ChoicyWhitelistSB_FILES = $(wildcard *.x) $(wildcard *.m) ../Shared.m ../ChoicyPrefsMigrator.m ../CHLaunchOptions.m
ChoicyWhitelistSB_CFLAGS = -fobjc-arc -Wno-unguarded-availability-new
ChoicyWhitelistSB_PRIVATE_FRAMEWORKS = BackBoardServices MobileCoreServices

include $(THEOS_MAKE_PATH)/tweak.mk
