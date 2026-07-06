#
# Copyright (C) 2017 The Android Open-Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# Audio
PRODUCT_PACKAGES += \
    android.hardware.audio@2.0-impl \
    android.hardware.audio@2.0-service \
    android.hardware.audio.effect@2.0-impl \
    android.hardware.audio.effect@2.0-service \
    android.hardware.soundtrigger@2.0-impl \
    android.hardware.soundtrigger@2.0-service

# Camera
# Use the stock PD1619 camera HIDL wrapper stack. Vivo's provider links its
# own camera provider extension and behaves differently from the generic
# android.hardware.camera.provider@2.4 implementation.

# Configstore
PRODUCT_PACKAGES += \
    android.hardware.configstore@1.0-service

# Consumer IR
PRODUCT_PACKAGES += \
    android.hardware.ir@1.0-impl

# Display
PRODUCT_PACKAGES += \
    android.hardware.graphics.allocator@2.0-impl \
    android.hardware.graphics.allocator@2.0-service \
    android.hardware.graphics.composer@2.1-impl \
    android.hardware.graphics.composer@2.1-service \
    android.hardware.graphics.mapper@2.0-impl \
    android.hardware.memtrack@1.0-impl \
    android.hardware.memtrack@1.0-service

# DRM
PRODUCT_PACKAGES += \
    android.hardware.drm@1.0-impl \
    android.hardware.drm@1.0-service

# Gatekeeper
# Use the stock PD1619 service/impl pair from proprietary-files.txt. The
# generic service opens a legacy gatekeeper HAL that must match vivo's QSEE
# userspace.

# Fingerprint
PRODUCT_PACKAGES += \
    android.hardware.biometrics.fingerprint@2.0-service-custom

# GNSS
# Use the stock PD1619 GNSS stack from proprietary-files.txt. The stock
# `vendor.qti.gnss@1.0-service` still expects the stock passthrough
# `android.hardware.gnss@1.0-impl-qti.so` underneath it, plus
# `vendor.qti.gnss@1.0-impl.so` for vivo's vendor extension service.

# Health HAL
PRODUCT_PACKAGES += \
    android.hardware.health@1.0-impl \
    android.hardware.health@1.0-convert \
    android.hardware.health@1.0-service \
    android.hardware.health@1.0

# Keymaster
# Use the stock PD1619 service/impl pair alongside the stock TrustZone blobs.

# Light
PRODUCT_PACKAGES += \
    android.hardware.light@2.0-impl

# Net
PRODUCT_PACKAGES += \
    android.system.net.netd@1.0

# OMX
PRODUCT_PACKAGES += \
    android.hardware.media.omx@1.0-impl

# Power
PRODUCT_PACKAGES += \
    android.hardware.power@1.0-service-qti

# RenderScript
PRODUCT_PACKAGES += \
    android.hardware.renderscript@1.0-impl

# Sensors
# Use the stock PD1619 service/impl pair from proprietary-files.txt. Vivo's
# userspace expects the stock SSC registry and initialization path.

# Thermal
PRODUCT_PACKAGES += \
    android.hardware.thermal@1.0-impl \
    android.hardware.thermal@1.0-service

# USB
PRODUCT_PACKAGES += \
    android.hardware.usb@1.0-service

# Vibrator
PRODUCT_PACKAGES += \
    android.hardware.vibrator@1.0-impl \
    android.hardware.vibrator@1.0-service

# VR
PRODUCT_PACKAGES += \
    android.hardware.vr@1.0-impl \
    android.hardware.vr@1.0-service

# Wi-Fi
# Use the stock PD1619 service and vendor extension library. The source-built
# generic service can load the module now, but it cannot talk to this stock
# driver through cld80211.
