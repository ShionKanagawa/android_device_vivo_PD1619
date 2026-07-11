LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

LOCAL_MODULE_TAGS := optional
LOCAL_SRC_FILES := $(call all-java-files-under, src)
LOCAL_PACKAGE_NAME := PD1619Parts
LOCAL_CERTIFICATE := platform
LOCAL_PRIVILEGED_MODULE := true
LOCAL_PRIVATE_PLATFORM_APIS := true
LOCAL_USE_AAPT2 := true

LOCAL_STATIC_ANDROID_LIBRARIES := \
    android-support-v14-preference \
    android-support-v7-appcompat \
    android-support-v7-palette \
    android-support-v7-preference \
    android-support-v7-recyclerview

include frameworks/base/packages/SettingsLib/common.mk

include $(BUILD_PACKAGE)
