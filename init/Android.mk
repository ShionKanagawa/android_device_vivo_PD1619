LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

LOCAL_C_INCLUDES := \
    system/core/base/include \
    system/core/init \
    external/selinux/libselinux/include

LOCAL_CFLAGS := -Wall -DANDROID_TARGET=\"$(TARGET_BOARD_PLATFORM)\"
LOCAL_SRC_FILES := init_PD1619.cpp

LOCAL_MODULE := libinit_PD1619
LOCAL_MODULE_TAGS := optional
include $(BUILD_STATIC_LIBRARY)
