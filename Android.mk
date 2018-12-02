#
# Copyright (C) 2016 The CyanogenMod Project
# Copyright (C) 2017 The LineageOS Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

LOCAL_PATH := $(call my-dir)
PD1619_DEVICE_PATH := $(LOCAL_PATH)

ifneq ($(filter PD1619, $(TARGET_DEVICE)),)

PD1619_LD_CONFIG_SOURCE := $(PD1619_DEVICE_PATH)/configs/ld.config.legacy.txt
PD1619_LD_CONFIG_TARGET := $(TARGET_OUT_ETC)/ld.config.txt

# O's core_minimal product always pulls in system/core's ld.config.txt module.
# Keep that module intact, then overwrite its installed file with the stock
# PD1619 legacy search path so bare dlopen() can find /vendor/${LIB}/hw blobs.
include $(CLEAR_VARS)
LOCAL_MODULE := PD1619_ld_config_override
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_CLASS := ETC
LOCAL_PREBUILT_MODULE_FILE := $(PD1619_LD_CONFIG_SOURCE)
LOCAL_MODULE_PATH := $(TARGET_OUT_ETC)
LOCAL_MODULE_STEM := pd1619_ld_config_override
LOCAL_ADDITIONAL_DEPENDENCIES := $(PD1619_LD_CONFIG_TARGET)
LOCAL_POST_INSTALL_CMD := $(hide) cp $(PD1619_LD_CONFIG_SOURCE) $(PD1619_LD_CONFIG_TARGET)
include $(BUILD_PREBUILT)

PD1619_WIFI_HAL_RC_SOURCE := $(PD1619_DEVICE_PATH)/configs/android.hardware.wifi@1.0-service.rc
PD1619_WIFI_HAL_RC_TARGET := $(TARGET_OUT_VENDOR_ETC)/init/android.hardware.wifi@1.0-service.rc

# The legacy Wi-Fi HAL loads the stock pronto module via init_module() and
# touches wlan sysfs parameters. Run this device's service as root without
# changing the common hardware/interfaces rc.
include $(CLEAR_VARS)
LOCAL_MODULE := PD1619_wifi_hal_rc_override
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_CLASS := ETC
LOCAL_PREBUILT_MODULE_FILE := $(PD1619_WIFI_HAL_RC_SOURCE)
LOCAL_MODULE_PATH := $(TARGET_OUT_VENDOR_ETC)
LOCAL_MODULE_STEM := pd1619_wifi_hal_override.rc
LOCAL_ADDITIONAL_DEPENDENCIES := $(PD1619_WIFI_HAL_RC_TARGET)
LOCAL_POST_INSTALL_CMD := $(hide) cp $(PD1619_WIFI_HAL_RC_SOURCE) $(PD1619_WIFI_HAL_RC_TARGET)
include $(BUILD_PREBUILT)

include $(call all-makefiles-under,$(PD1619_DEVICE_PATH))

ifneq ($(TARGET_PREBUILT_KERNEL),)
PD1619_S2_KERNEL_SOURCE := $(abspath kernel/leeco/msm8976)
PD1619_KERNEL_HEADERS_OUT := $(TARGET_OUT_INTERMEDIATES)/KERNEL_OBJ
PD1619_KERNEL_HEADERS_INSTALL := $(PD1619_KERNEL_HEADERS_OUT)/usr
PD1619_KERNEL_HEADERS_STAMP := $(PD1619_KERNEL_HEADERS_INSTALL)/.pd1619_s2_headers_install
PD1619_BIONIC_KERNEL_HEADER_DIRS := \
	$(abspath bionic/libc/kernel/uapi) \
	$(abspath bionic/libc/kernel/android/uapi)

# The stock PD1619 kernel is prebuilt, so Lineage's kernel task will not create
# INSTALLED_KERNEL_HEADERS. Legacy Qualcomm modules still depend on that path,
# so generate UAPI headers from the s2 MSM8976 kernel source without building or
# packaging that kernel.
.PHONY: INSTALLED_KERNEL_HEADERS
INSTALLED_KERNEL_HEADERS: $(PD1619_KERNEL_HEADERS_STAMP)

$(PD1619_KERNEL_HEADERS_STAMP): $(PD1619_S2_KERNEL_SOURCE)/Makefile $(PD1619_DEVICE_PATH)/Android.mk
	@echo "PD1619 s2 kernel headers: $@"
	@rm -rf $(PD1619_KERNEL_HEADERS_INSTALL)
	@mkdir -p $(PD1619_KERNEL_HEADERS_OUT)
	$(hide) $(MAKE) -C $(PD1619_S2_KERNEL_SOURCE) \
		O=$(abspath $(PD1619_KERNEL_HEADERS_OUT)) \
		ARCH=$(TARGET_KERNEL_ARCH) \
		headers_install
	@kernel_include=$(abspath $(PD1619_KERNEL_HEADERS_INSTALL)/include); \
	for bionic_headers in $(PD1619_BIONIC_KERNEL_HEADER_DIRS); do \
		if [ -d "$$bionic_headers" ]; then \
			(cd "$$bionic_headers" && find . -type f) | while read header; do \
				rm -f "$$kernel_include/$${header#./}"; \
			done; \
		fi; \
	done
	@rm -rf $(PD1619_KERNEL_HEADERS_INSTALL)/include/asm
	@rm -f $(PD1619_KERNEL_HEADERS_INSTALL)/include/linux/android/binder.h
	@touch $@

$(PD1619_KERNEL_HEADERS_INSTALL): $(PD1619_KERNEL_HEADERS_STAMP)
endif

include $(CLEAR_VARS)

KEYMASTER_IMAGES := keymaster.b00 keymaster.b01 keymaster.b02 keymaster.b03 keymaster.mdt
KEYMASTER_SYMLINKS := $(addprefix $(TARGET_OUT_VENDOR)/firmware/keymaster/,$(notdir $(KEYMASTER_IMAGES)))
$(KEYMASTER_SYMLINKS): $(LOCAL_INSTALLED_MODULE)
	@echo "Keymaster firmware link: $@"
	@mkdir -p $(dir $@)
	@rm -rf $@
	$(hide) ln -sf /firmware/image/$(notdir $@) $@

ALL_DEFAULT_INSTALLED_MODULES += $(KEYMASTER_SYMLINKS)


WIDEVINE_IMAGES := widevine.b00 widevine.b01 widevine.b02 widevine.b03 widevine.mdt
WIDEVINE_SYMLINKS := $(addprefix $(TARGET_OUT_VENDOR)/firmware/,$(notdir $(WIDEVINE_IMAGES)))
$(WIDEVINE_SYMLINKS): $(LOCAL_INSTALLED_MODULE)
	@echo "Widevine firmware link: $@"
	@mkdir -p $(dir $@)
	@rm -rf $@
	$(hide) ln -sf /firmware/image/$(notdir $@) $@

ALL_DEFAULT_INSTALLED_MODULES += $(WIDEVINE_SYMLINKS)

IMS_LIBS := libimscamera_jni.so libimsmedia_jni.so
IMS_SYMLINKS := $(addprefix $(TARGET_OUT_APPS_PRIVILEGED)/ims/lib/arm64/,$(notdir $(IMS_LIBS)))
$(IMS_SYMLINKS): $(LOCAL_INSTALLED_MODULE)
	@echo "IMS lib link: $@"
	@mkdir -p $(dir $@)
	@rm -rf $@
	$(hide) ln -sf /system/lib64/$(notdir $@) $@

ALL_DEFAULT_INSTALLED_MODULES += $(IMS_SYMLINKS)

WCNSS_CFG_INI := $(TARGET_OUT_VENDOR)/firmware/wlan/prima/WCNSS_qcom_cfg.ini
$(WCNSS_CFG_INI): $(LOCAL_INSTALLED_MODULE)
	@echo "WCNSS_qcom_cfg.ini firmware link: $@"
	@mkdir -p $(dir $@)
	@rm -rf $@
	$(hide) ln -sf /data/misc/wifi/$(notdir $@) $@

WCNSS_PERSIST_FIRMWARE := WCNSS_qcom_wlan_nv.bin WCNSS_wlan_dictionary.dat
WCNSS_PERSIST_SYMLINKS := \
	$(addprefix $(TARGET_OUT_ETC)/firmware/wlan/prima/,$(WCNSS_PERSIST_FIRMWARE)) \
	$(addprefix $(TARGET_OUT_VENDOR)/firmware/wlan/prima/,$(WCNSS_PERSIST_FIRMWARE))
$(WCNSS_PERSIST_SYMLINKS): $(LOCAL_INSTALLED_MODULE)
	@echo "WCNSS persist firmware link: $@"
	@mkdir -p $(dir $@)
	@rm -rf $@
	$(hide) ln -sf /persist/$(notdir $@) $@

WLAN_MAC := $(TARGET_OUT_ETC)/firmware/wlan/prima/wlan_mac.bin
$(WLAN_MAC): $(LOCAL_INSTALLED_MODULE)
	@echo "wlan_mac.bin firmware link: $@"
	@mkdir -p $(dir $@)
	@rm -rf $@
	$(hide) ln -sf /persist/$(notdir $@) $@

WLAN_MODULE := $(TARGET_OUT)/lib/modules/pronto/pronto_wlan.ko
WLAN_MODULE_COPY := $(TARGET_OUT)/lib/modules/wlan.ko
$(WLAN_MODULE_COPY): $(WLAN_MODULE)
	@echo "WLAN module copy: $@"
	@mkdir -p $(dir $@)
	@rm -rf $@
	$(hide) cp -f $< $@

ALL_DEFAULT_INSTALLED_MODULES += $(WCNSS_CFG_INI) $(WCNSS_PERSIST_SYMLINKS) $(WLAN_MAC) $(WLAN_MODULE_COPY)


CMNLIB_IMAGES := cmnlib.b00 cmnlib.b01 cmnlib.b02 cmnlib.b03 cmnlib.mdt
CMNLIB_SYMLINKS := $(addprefix $(TARGET_OUT_VENDOR)/firmware/,$(notdir $(CMNLIB_IMAGES)))
$(CMNLIB_SYMLINKS): $(LOCAL_INSTALLED_MODULE)
	@echo "TZ Apps firmware link: $@"
	@mkdir -p $(dir $@)
	@rm -rf $@
	$(hide) ln -sf /firmware/image/$(notdir $@) $@

ALL_DEFAULT_INSTALLED_MODULES += $(CMNLIB_SYMLINKS)

# RFS symlinks
RFS_MSM_ADSP_SYMLINKS := $(TARGET_OUT_VENDOR)/rfs/msm/adsp/
$(RFS_MSM_ADSP_SYMLINKS): $(LOCAL_INSTALLED_MODULE)
	@echo "Creating RFS MSM ADSP folder structure: $@"
	@rm -rf $@/*
	@mkdir -p $(dir $@)/readonly/vendor
	$(hide) ln -sf /data/vendor/tombstones/rfs/lpass $@/ramdumps
	$(hide) ln -sf /persist/rfs/msm/adsp $@/readwrite
	$(hide) ln -sf /persist/rfs/shared $@/shared
	$(hide) ln -sf /persist/hlos_rfs/shared $@/hlos
	$(hide) ln -sf /firmware $@/readonly/firmware
	$(hide) ln -sf /vendor/firmware $@/readonly/vendor/firmware

RFS_MSM_MPSS_SYMLINKS := $(TARGET_OUT_VENDOR)/rfs/msm/mpss/
$(RFS_MSM_MPSS_SYMLINKS): $(LOCAL_INSTALLED_MODULE)
	@echo "Creating RFS MSM MPSS folder structure: $@"
	@rm -rf $@/*
	@mkdir -p $(dir $@)/readonly/vendor
	$(hide) ln -sf /data/vendor/tombstones/rfs/modem $@/ramdumps
	$(hide) ln -sf /persist/rfs/msm/mpss $@/readwrite
	$(hide) ln -sf /persist/rfs/shared $@/shared
	$(hide) ln -sf /persist/hlos_rfs/shared $@/hlos
	$(hide) ln -sf /firmware $@/readonly/firmware
	$(hide) ln -sf /vendor/firmware $@/readonly/vendor/firmware

RFS_MSM_SLPI_SYMLINKS := $(TARGET_OUT_VENDOR)/rfs/msm/slpi/
$(RFS_MSM_SLPI_SYMLINKS): $(LOCAL_INSTALLED_MODULE)
	@echo "Creating RFS MSM SLPI folder structure: $@"
	@rm -rf $@/*
	@mkdir -p $(dir $@)/readonly/vendor
	$(hide) ln -sf /data/vendor/tombstones/rfs/modem $@/ramdumps
	$(hide) ln -sf /persist/rfs/msm/slpi $@/readwrite
	$(hide) ln -sf /persist/rfs/shared $@/shared
	$(hide) ln -sf /persist/hlos_rfs/shared $@/hlos
	$(hide) ln -sf /firmware $@/readonly/firmware
	$(hide) ln -sf /vendor/firmware $@/readonly/vendor/firmware

ALL_DEFAULT_INSTALLED_MODULES += $(RFS_MSM_ADSP_SYMLINKS) $(RFS_MSM_MPSS_SYMLINKS) $(RFS_MSM_SLPI_SYMLINKS)

endif
