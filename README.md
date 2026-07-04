Copyright 2016 - The CyanogenMod Project
Copyright 2026 - The LineageOS Project

Device configuration for vivo X9Plus / PD1619
=============================================

This tree is a LineageOS 15.1 bring-up for the vivo X9Plus (`PD1619`), based on
the LeEco s2 MSM8976 device tree.

Basic   | Spec Sheet
-------:|:-------------------------------------------------------------------------
SoC     | Qualcomm MSM8976 family
Platform properties | `msm8952` / vivo `QCOM8976`
CPU ABI | arm64-v8a, armeabi-v7a, armeabi
GPU     | Adreno 510
Display | 1080 x 1920, 480 dpi
Stock firmware used for blobs | Funtouch OS 4.0 / Android 8.1
Treble  | No, `/vendor` is a symlink to `/system/vendor`
Kernel  | Stock prebuilt kernel, Linux 3.10.84

See `PD1619_PORTING_NOTES.md` for adb findings and current bring-up status.
