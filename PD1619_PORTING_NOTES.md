# vivo X9Plus / PD1619 LineageOS 15.1 Porting Notes

This file records the initial constraints and working assumptions for the
PD1619 device tree bring-up, so the project context survives future sessions.

## Device And Base

- Target device: vivo X9Plus, codename `PD1619`.
- SoC: Qualcomm MSM8976.
- Current working directory initially contains the `lecco_s2` device tree.
- `lecco_s2` is used as the bring-up base because it shares the MSM8976 SoC.
- ROM source root: `/run/media/shion/GameTurbo/LinuxZone/los-15.1/`.
- Target ROM: LineageOS 15.1 / Android 8.1.

## Stock System Context

- Original shipping Android version: Android 6.0.
- No Project Treble support is expected.
- The currently running stock firmware is vivo Funtouch OS 4.0 based on
  Android 8.1.
- Treble/non-Treble state and other runtime facts can be confirmed through
  `adb`.
- Confirmed by adb:
  - `ro.treble.enabled=false`.
  - `/vendor` is a symlink to `/system/vendor`; there is no standalone vendor
    partition.
  - Stock build is Android 8.1.0 / SDK 27 with November 2018 security patch.
  - Product identity is `vivo X9Plus` / `PD1619`, hardware `PD1619MA`.
  - vivo product platform property reports `QCOM8976`, while Android platform
    properties use the Qualcomm `msm8952` family name.

## Kernel Policy

- vivo did not provide usable kernel source for this bring-up.
- Use the stock/prebuilt closed-source kernel.
- Direct extraction from the live boot block was blocked by the stock kernel,
  but an unpacked stock boot image is now available locally.
- Device root flow: use `adb shell`, then `suu` rather than `su`.
- There is no `adb root` because of kernel restrictions.
- Confirmed kernel details from adb:
  - Linux `3.10.84-perf-gd238831b`, built 2018-11-10.
  - `androidboot.hardware=qcom`.
  - Boot device is `7824900.sdhci`.
  - Display panel from cmdline:
    `qcom,mdss_dsi_sharp_td4322_1080p_cmd`.
  - Kernel has `CONFIG_ANDROID_BINDER_DEVICES="binder,hwbinder,vndbinder"`.
  - Kernel has `CONFIG_SECCOMP=y` and `CONFIG_SECCOMP_FILTER=y`.
  - Direct block reads from the boot partition are blocked even from `suu -c`
    root (`Permission denied`).
- Boot image dump is now available at `/home/shion/boot_dumped_PD1619/`.
  Relevant stock split_img values:
  - Kernel image: `split_img/boot.img-kernel`, copied to `prebuilt/kernel`.
  - Kernel sha256:
    `1b1e46de1f03579f4a0d749c81d59a7aa82126abb0f4f7d14f9739cf261af6a7`.
  - Base `0x80000000`, pagesize `2048`.
  - Kernel offset `0x00008000`, ramdisk offset `0x01000000`, second offset
    `0x00f00000`, tags offset `0x00000100`.
  - Stock boot cmdline is used in `BoardConfig.mk` with
    `androidboot.selinux=permissive` appended for early bring-up.
  - Stock boot header version is `0`; stock boot metadata reports Android
    `8.1.0` and patch level `2018-11`.
  - Stock unpack metadata reports `sigtype=AVBv1`, `avbtype=boot`,
    `hashtype=sha1`, and `imgtype=AOSP`. A temporary mkbootimg repack with the
    stock kernel, stock ramdisk, and stock offsets succeeds, but does not match
    the stock boot hash because the AVBv1 signing/footer data is not reproduced.

## Magisk 24+ Boot Quirk

- PD1619 boots Magisk 23.0 and a Magisk 24.0 image patched with the 32-bit
  `magiskinit`, but bootloops before boot animation when Magisk 24.0 uses the
  arm64 `magiskinit` as ramdisk `/init`.
- This is an early PID 1 / ramdisk-stage issue only. The Android userspace and
  Magisk runtime can still use the 64-bit `magisk64` binary after init has
  handed off to the normal system.
- Treat the working recipe as: 32-bit early init/tooling, 64-bit runtime.
- Do not use official Magisk 24+ direct install on PD1619 unless the installer
  is patched to select `lib/armeabi-v7a/libmagiskinit.so` for `/init`.
- Host-side helper:
  `tools/patch-magisk-boot-pd1619.sh <Magisk.apk> <boot.img> [out.img]`.
  It extracts 32-bit `magiskinit`, detects both old Magisk APK layouts
  (`libmagisk32`/`libmagisk64`) and newer layouts (`libmagisk` plus
  `init-ld`/`stub.apk`), removes DT fstab verity flags, applies the
  `skip_initramfs` to `want_initramfs` kernel patch, and repacks a flashable
  boot image.

## Bring-Up Philosophy

- Practical bring-up style: "works first"; full OSS purity is not required.
- Proprietary blobs should be collected from the connected PD1619 device where
  possible.
- Create/update `proprietary-files.txt` for PD1619.
- Remove the extra `qc` proprietary file list that came from the base tree if it
  is not appropriate for this device.

## Build Environment Notes

- Full ROM builds are expected to run in Docker on this newer Linux host; do not
  run `make bacon` directly on the host.
- Host-only smoke builds can be misleading because `/usr/bin/python` points to
  Python 3, while LineageOS 15.1 still has Python 2 scripts such as
  `build/tools/findleaves.py`. If host validation reports device modules as
  unknown, first retry with a temporary `python -> python2` PATH wrapper or use
  the Docker build environment.
- The host currently lacks ImageMagick's `mogrify`; when doing host-only parse
  checks, set a temporary `TARGET_BOOTANIMATION` to an existing zip if needed.

## Android O / Legacy Device Notes

- Watch for Android O upgrade requirements on old devices, including:
  - hwbinder service separation/state.
  - seccomp policy availability/compatibility.
  - pre-Treble vendor layout assumptions.
- Confirmed O-era runtime state:
  - `/dev/binder`, `/dev/hwbinder`, and `/dev/vndbinder` all exist.
  - `hwservicemanager` and `vndservicemanager` are running.
  - `lshal` reports many HIDL HALs, but the device remains non-Treble because
    the vendor tree lives under `/system/vendor`.
  - Device manifest is at `/vendor/manifest.xml` (`/system/vendor/manifest.xml`)
    rather than `/vendor/etc/vintf/manifest.xml`.
  - Manifest sepolicy version is `27.0`.
  - Stock exposes vendor seccomp policies under `/vendor/etc/seccomp_policy/`.

## Confirmed Partition Layout

From `/dev/block/bootdevice/by-name` and `/proc/partitions`:

- `modem`: `mmcblk0p1`, about 86 MiB, mounted at `/firmware`.
- `dsp`: `mmcblk0p12`, about 16 MiB, mounted at `/dsp`.
- `boot`: `mmcblk0p21`, 64 MiB.
- `recovery`: `mmcblk0p22`, 64 MiB.
- `system`: `mmcblk0p24`, about 3 GiB, mounted through dm-verity as `/system`.
- `cache`: `mmcblk0p25`, 256 MiB.
- `persist`: `mmcblk0p26`, 32 MiB.
- `misc`: `mmcblk0p27`, 1 MiB.
- `oem`: `mmcblk0p30`, 64 MiB, mounted through dm-verity as `/oem`.
- `apps`: `mmcblk0p50`, 512 MiB, mounted at `/apps`.
- `userdata`: `mmcblk0p51`, about 54 GiB.

Stock `/fstab.qcom` mounts `/oem`, `/apps`, `/data`, `/dsp`, `/persist`, and
`/cache`. It also declares removable SD and USB OTG vold-managed entries.

## Confirmed Hardware Notes

- Screen: 1080x1920, density 480.
- Audio card: `msm8952-cdp-snd-card`.
- Touch/input:
  - Main touch: `vivo_ts`.
  - Synaptics input path also appears as `synaptics_dsx`.
  - Virtual capacitive keys: `vivo_virtual_key` with menu/back/homepage.
  - Fingerprint input: `fpc1245`.
- Fingerprint:
  - Sensor/TEE path is FPC1245 and loads the stock `fpc1245` QSEE app.
  - Stock FPC HAL module is `fpc_1245.default.so`.
  - The tree uses a Lineage custom 2.1 HIDL service plus the stock FPC legacy
    HAL module, opened directly by its vivo module id `fpc_1245`.
- Sensors observed from `dumpsys sensorservice`:
  - Accelerometer/gyro: ST LSM6DS3.
  - Magnetometer: AKM AK09911.
  - Proximity: PA224.
  - Light: ROHM BH1745.
- Camera:
  - Stock camera service reports 3 normal camera devices.
  - Camera blobs reference IMX298, IMX376, and S5K3H7 sensor families.
- Device-specific stock vendor config files include:
  - `/vendor/etc/mixer_paths.PD1619.xml`
  - `/vendor/etc/ftm-mixerpath.PD1619.xml`
  - `/vendor/etc/audio_policy_configuration/audio_policy_configuration.PD1619.xml`
  - `/vendor/etc/audio_policy_configuration/default_volume_tables.PD1619.xml`
  - `/vendor/etc/tfa98xx_PD1619.cnt`

## Confirmed Stock HIDL / Vendor Services

Important HIDL services observed through `lshal` and init scripts include:

- Audio/effects 2.0.
- Bluetooth 1.0 QTI.
- Camera provider 2.4 `legacy/0`.
- Gatekeeper 1.0.
- GNSS 1.0 and `vendor.qti.gnss@1.0`.
- Graphics allocator 2.0 / composer 2.1 / mapper 2.0.
- Health 1.0.
- Keymaster 3.0.
- Light 2.0 plus vivo light 1.0 blobs.
- Memtrack 1.0.
- Power 1.0.
- Radio 1.0/1.1 for dual SIM slots.
- Sensors 1.0.
- SoundTrigger 2.0.
- Tether offload config/control 1.0.
- Vibrator 1.0.

GNSS note: PD1619 uses the stock `vendor.qti.gnss@1.0-service` plus
`vendor.qti.gnss@1.0-impl.so` vendor extension path, but that stock service
still depends on the stock passthrough
`android.hardware.gnss@1.0-impl-qti.so` underneath it for
`android.hardware.gnss@1.0::IGnss/default`. A partial swap is worse than either
side alone: if only the source-built `android.hardware.gnss@1.0-impl-qti` is
present, the service cannot expose `vendor.qti.gnss@1.0::ILocHidlGnss`; if only
`vendor.qti.gnss@1.0-impl.so` is present, the service fails with
`Could not get passthrough implementation for android.hardware.gnss@1.0::IGnss/default`
and `system_server` eventually aborts with
`Abort due to IGNSS hidl service failure, restarting system server`. Ship the
full stock GNSS userspace stack instead.

Alarm/factory note: the stock `vendor.qti.hardware.alarm@1.0-service` and
`vendor.qti.hardware.factory@1.0-service` are also passthrough-backed. Their
manifest entries alone are not enough; both services additionally require the
stock `vendor.qti.hardware.alarm@1.0-impl.so` and
`vendor.qti.hardware.factory@1.0-impl.so` under both `vendor/lib/hw` and
`vendor/lib64/hw`. If those impl blobs are missing, logs show
`Could not get passthrough implementation for vendor.qti.hardware.alarm@1.0::IAlarm/default`
and the corresponding factory error. Once the four impl blobs are present, both
HALs register normally through `lshal`.
- Wi-Fi 1.0/1.1 and supplicant 1.0.
- QTI IMS, UCE, radio, perf, qteeconnector, alarm, factory, and Wi-Fi keystore
  HALs.
- vivo private HIDL HALs:
  - `vendor.vivo.hardware.bbkts@1.0`
  - `vendor.vivo.hardware.biometrics.analysis@1.0`
  - `vendor.vivo.hardware.biometrics.fingerprint@2.0` blobs are present, but
    the stock FPC service is not started for Lineage.
  - `vendor.vivo.hardware.camera.provider@1.0`
  - `vendor.vivo.hardware.camera.vif@1.0`
  - `vendor.vivo.hardware.camera.vivodevice@1.0`
  - `vendor.vivo.hardware.light@1.0`
  - `vendor.vivo.hardware.wifiap@1.0`

## Open Questions To Resolve During Bring-Up

- Revisit boot image AVBv1 signing/footer requirements after the first
  successful `boot.img` build and flash attempt.
- Confirm init scripts, fstab, SELinux policy source, and proprietary HAL set.
- Continue trimming inherited LeEco/Qualcomm-common assumptions that are not
  appropriate for PD1619.
- Decide whether the first boot attempt should reuse stock `/vendor/manifest.xml`
  closely or trim it to services Lineage actually starts.

## Bring-Up Changes Started

- Product identity was switched from `s2`/LeEco to `PD1619`/vivo:
  - `lineage_PD1619-userdebug` lunch target.
  - `full_PD1619.mk`.
  - `vendor/vivo/PD1619` proprietary path.
- `lunch lineage_PD1619-userdebug` succeeds on the host. Full ROM builds should
  still be done only in Docker.
- `proprietary-files-qc.txt` was removed from the extraction flow and deleted.
- `proprietary-files.txt` was replaced with an initial PD1619 seed list.
- `extract-files.sh` successfully pulled 245 seed blobs from the connected
  device into `/run/media/shion/GameTurbo/LinuxZone/los-15.1/vendor/vivo/PD1619`.
- After recovery came up, `proprietary-files.txt` was expanded using the
  `DT_NEEDED` dependency closure of the already-selected stock blobs. The list
  now includes system-side private libraries needed by stock camera/vivo/QTI
  HALs and a larger vendor-side set for camera, radio/IMS, CNE, location, DRM,
  OpenCL, and sensor support. The generated vendor tree now extracts 427 files.
- The expansion intentionally avoids stock copies of common platform libraries
  such as `libc`, `libbinder`, `libhidlbase`, and display/source-provided
  pieces such as `libqservice`/`libqdMetaData`. `libalsautils.so` and
  `libnbaio_mono.so` were also left to the source tree after they produced
  duplicate install-path warnings.
- Current dependency-scan leftovers to remember:
  - `libloc_externalDrcore.so` is referenced by stock `libloc_externalDr.so`,
    but no matching file was found under stock `/system` or `/oem`.
  - `libqomx_core.so` and `libsensorndkbridge.so` are expected from source for
    now.
- Stock PD1619 ships `/system/bin/ebtables`, `/system/etc/ethertypes`, and
  `/system/lib*/libebtc.so`. These are extracted as prebuilts, and
  `device.mk` does not request the source `external/ebtables` modules because
  those require generated kernel headers.
- The stock PD1619 kernel binary stays prebuilt from the vivo boot image. Kernel
  headers are generated separately from the s2 MSM8976 kernel source at
  `kernel/leeco/msm8976` via `make headers_install`; this creates the legacy
  `KERNEL_OBJ/usr/include` path and `INSTALLED_KERNEL_HEADERS` dependency needed
  by old CAF modules without building or packaging the s2 kernel. The generated
  headers are pruned anywhere bionic already provides the same UAPI path, and
  the generated `asm/` directory is removed after install so bionic's
  target-arch, binder, signal, and other common UAPI headers remain
  authoritative for userspace builds.
- The source CAF `audio.primary.msm8952`, `libtinycompress`, Qualcomm soundfx
  modules, `audio.r_submix.default`, and `audio.usb.default` are not requested
  from `PRODUCT_PACKAGES` for now. Stock PD1619 ships compatible Android 8.1
  blobs for the primary audio HAL, USB/remote-submix HALs, qcom sound effects,
  and `libtinycompress_vendor.so`, so those are extracted as prebuilts instead.
- The source CAF `libbt-vendor` is disabled. Stock PD1619 ships
  `vendor/lib*/libbt-vendor.so`; the source build expects Qualcomm private tty
  PM ioctls such as `TIOCPMGET/TIOCPMPUT/TIOCPMACT`. `BOARD_HAVE_BLUETOOTH`
  stays true for framework feature support, but `BOARD_HAVE_BLUETOOTH_QCOM` and
  the bt-caf private options stay false so the source module is not defined with
  the same install path as the stock blob.
- The media-caf OMX/c2d/stagefrighthw stack is also using stock PD1619
  prebuilts for now. The source `libOmxVdec` path requires Qualcomm VIDC V4L2
  kernel definitions that are not available from the sanitized header set, and
  stock media XMLs are extracted alongside the OMX blobs so codec registration
  matches vivo's Android 8.1 stack.
- `libQWiFiSoftApCfg` is not included for now. It is the old Qualcomm SoftAP JNI
  helper, stock PD1619 does not ship a matching library or obvious
  `com.qualcomm.wifi.softap` consumer, and it is not required for first boot.
- Camera uses the stock proprietary HAL/stack for now (`USE_PROPRIETARY_CAMERA :=
  true`). The source QCamera2 stack came from the s2 base and quickly hit missing
  MSM kernel UAPI headers such as `linux/msm_ion.h`; stock camera blobs should
  be a closer match for vivo's sensors and tuning.
- ANT+ is present on stock PD1619:
  - Stock has `/system/lib*/libantradio.so`.
  - Stock vendor manifest declares `com.qualcomm.qti.ant@1.0::IAntHci/default`.
  - The `libantradio` blobs are packaged as prebuilt multilib modules so
    `AntHalService` and `antradio_app` do not depend on the source HIDL ANT
    native build path.
- The inherited LeEco `audio_amplifier.msm8952` HAL depended on
  `libtfa9890.so`, which is not present on stock PD1619. The unused source HAL
  was removed from this tree; PD1619 still keeps the stock
  `tfa98xx_PD1619.cnt` config blob for later audio/smartpa bring-up.
- Stock `vendor/etc/init/vndservicemanager.rc` and stock
  `audio.primary.default.so` were intentionally not extracted after they caused
  duplicate install paths with platform/generic modules.
- `rootdir/etc/fstab.qcom` was aligned with the live PD1619 partition layout:
  ext4 `/data`, `/cache`, `/persist`, plus `/oem`, `/apps`, and `/frp`.
- `BoardConfig.mk` now uses:
  - `DEVICE_PATH := device/vivo/PD1619`.
  - stock split_img kernel cmdline, with SELinux permissive appended.
  - `TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt/kernel`.
  - stock split_img mkbootimg offsets.
  - corrected `/system` and `/data` partition sizes from `/proc/partitions`.
- The stock prebuilt kernel from `/home/shion/boot_dumped_PD1619/split_img` was
  copied to `prebuilt/kernel`.
- `rootdir/etc/fstab.qcom` keeps PD1619 stock data/cache fs_mgr flags while
  intentionally omitting stock `/oem` verity for the first bring-up path.
- Stock ramdisk mount-point creation and secure-touch permissions were merged
  into `rootdir/etc/init.target.rc`. Stock `default.prop` was reviewed but not
  copied wholesale because several values would make debugging harder on a
  Lineage userdebug build.
- The LeEco modem MBN copy logic in `init.qcom.sh` was replaced with a PD1619
  stock-like full copy of `/firmware/image/modem_pr/mcfg`.
- `TARGET_HW_DISK_ENCRYPTION` is disabled for bring-up. Stock PD1619 reports
  `ro.crypto.state=unsupported`, stock fstab has no `encryptable` or
  `forceencrypt` flags, and the inherited LeEco setting pulled in
  `libcryptfs_hw`, which needs kernel headers that are not generated for our
  stock prebuilt kernel path.
- `make nothing` with `OUT_DIR=/tmp/los15-pd1619-out-codex` succeeds on the
  host, confirming the make/Soong graph can parse after the ANT/TFA fixes.
  The normal source `out/` directory is currently root-owned from an external
  build context, so host smoke tests should use a temporary `OUT_DIR` unless
  ownership is fixed. Full ROM builds still belong in Docker.
- `make nothing` also succeeds after the 427-file blob expansion, with no
  duplicate/overriding install-path warnings in the checked log. The usual
  host-side Python 2 `findleaves.py` warnings still appear on the modern host.
- A first boot attempt reached the vivo/Lineage logo but did not bring up ADB.
  The likely early-userspace blocker was that `init.qcom.rc`, `init.target.rc`,
  `init.PD1619.usb.rc`, `init.qcom.power.rc`, `ueventd.qcom.rc`, and
  `fstab.qcom` were being installed under `/system/vendor`, while generic
  `init.rc` imports `/init.${ro.hardware}.rc` before `/system` exists. For this
  non-Treble device the boot-critical init/fstab files now install to the
  ramdisk root, their imports use root paths, `mount_all` reads `/fstab.qcom`,
  and the `/system` fstab entry is marked `recoveryonly` because first-stage
  init mounts it before the normal Android `on fs` action runs.
- Bring-up also forces `persist.sys.usb.config`/`sys.usb.config` to
  `mass_storage,adb` from the target init scripts so a debug ADB path has a
  chance to appear even if Android later falls into the charger path.
- The official PD1619 Android 8.1 system dump at
  `/run/media/shion/GameTurbo/PD1619_A_8.12.1-Magisk_23.0_Suu-Riru_26.1.7-Patched/system`
  was compared against the current packaged system. Stock `/system/vendor`
  contains many more files than the current Lineage output, so the expansion
  remains conservative: do not import every vendor test/diag binary blindly.
  The first extra batch added to `proprietary-files.txt` is limited to stock
  daemons already referenced by our init scripts (`irsc_util`, `tftp_server`,
  `wcnss_filter`, `btnvtool`, `sensors.qcom`, `ATFWD-daemon`,
  `msm_irqbalance`, `mm-pp-daemon`, `pm-service`, `pm-proxy`) plus direct
  dependencies needed by those blobs.
- `extract-files.sh` supports expanded ROM directories. The stock dump can be
  used as a source with
  `./extract-files.sh /run/media/shion/GameTurbo/PD1619_A_8.12.1-Magisk_23.0_Suu-Riru_26.1.7-Patched`,
  which extracts from its `system/` subtree and regenerates
  `vendor/vivo/PD1619/PD1619-vendor.mk`.
- `make nothing` with `OUT_DIR=/tmp/los15-pd1619-afterdump-codex` succeeds
  after the ramdisk-root init/fstab changes and the 518-file dump-backed blob
  expansion, with no duplicate install-path failure observed.
- A later stuck-logo test still did not bring up adb in Android. Recovery-side
  collection from `logs/recovery-20260703-214459` showed no persisted Android
  failure context: `/proc/last_kmsg` and `/cache/recovery/last_log.gz` were
  empty, and `/sys/fs/pstore` was absent.
- To make the next failed boot observable from recovery, `init.target.rc` now
  writes boot-stage breadcrumbs under `/cache/pd1619-stage-*`, updates
  `/cache/pd1619-last-stage`, and requests `mass_storage,adb` from `on fs`
  onward. After a failed boot, inspect `/cache/pd1619-*` to see whether init
  reached the target `on fs` action after `mount_all`, `post-fs`,
  `post-fs-data`, `early-boot`, `boot`, `zygote`, or `surfaceflinger`.
  `on fs` also logs before/after `mount_all` markers to `/dev/kmsg`, because
  `/cache` must not be mounted by hand before `mount_all`.
- First useful userspace boot log:
  `/home/shion/AIK-Linux_vivo/bootlogs/20260703-223020/20260703-223020-r1`.
  Kernel logs were still unavailable/empty, but logcat showed the system got
  through init far enough to start graphics services. The primary display
  blocker was `libEGL` aborting with `couldn't find an OpenGL ES
  implementation`; HWC also logged `libC2D2.so` missing. The proprietary list
  now includes the stock vendor Adreno/EGL/C2D stack (`vendor/lib*/egl`,
  `libC2D2.so`, `libadreno_utils.so`, `libgsl.so`, `libllvm-glnext.so`,
  related C2D and RenderScript blobs). `extract-files.sh` now extracts 558
  files from the stock dump, and `make nothing` with
  `OUT_DIR=/tmp/los15-pd1619-gfx-codex` succeeds after this expansion.
- The same logcat missing-library scan showed only four explicit missing
  dlopen libraries: `libC2D2.so`, `libaudioroute.so`,
  `libsensorndkbridge.so`, and `sensors.ssc.so`. `libC2D2.so` is covered by
  the Adreno/C2D blob expansion. `sensors.ssc.so` is now extracted from stock
  for both 32-bit and 64-bit vendor paths. `libaudioroute` and
  `libsensorndkbridge` are source modules and are now explicitly requested in
  `device.mk` because the stock prebuilt HALs do not pull source dependencies
  into the product graph automatically. The proprietary extraction count is now
  560 files, and `make nothing` with
  `OUT_DIR=/tmp/los15-pd1619-missinglibs-codex` succeeds.
- Bring-up ADB auth is disabled through `PRODUCT_DEFAULT_PROPERTY_OVERRIDES +=
  ro.adb.secure=0` in `device.mk`; putting `ADDITIONAL_DEFAULT_PROPERTIES` in
  `BoardConfig.mk` is rejected by the Android 8 build system.
- Second useful Android userspace log:
  `/home/shion/AIK-Linux_vivo/bootlogs/20260704-064816/20260704-064816-r1`.
  Adreno EGL now loads, so the previous missing-EGL blocker is gone. The new
  graphics blocker is the stock kernel KGSL path repeatedly requesting
  `a530_pm4.fw`, while `ueventd` reports it cannot find that firmware; the
  resulting KGSL open failure returns `errno 12`/`-12`, but `/proc/meminfo`
  still shows more than 5 GiB free, so this is not ordinary userspace OOM.
  Stock Funtouch stores the Adreno and related firmware under
  `/system/etc/firmware`, and Android 8.1 `ueventd` searches `/etc/firmware`,
  `/vendor/firmware`, and `/firmware/image`, so the ordinary files from stock
  `system/etc/firmware` are now listed in `proprietary-files.txt`. The stock
  firmware symlinks observed were Wi-Fi related:
  `etc/firmware/wlan/qca_cld/WCNSS_qcom_cfg.ini ->
  /system/etc/wifi/WCNSS_qcom_sdio_cfg.ini` plus
  `vendor/firmware/wlan/prima/*` links into `/data/misc/wifi` or `/persist`;
  those symlinks are recorded but not imported in this GPU-firmware pass.
- The same 20260704 logcat missing-library scan showed three unique missing
  dlopen targets: `libsensor_reg.so`, `libaudioparsers.so`, and
  `vendor.vivo.hardware.camera.vif@1.0-impl.so`. The first two are now added
  from stock (`lib*/`/`vendor/lib*/` as present). The camera VIF impl blob was
  already extracted under `vendor/lib*/hw`; if it remains missing at runtime,
  the likely next check is linker search paths, because stock
  `/system/etc/ld.config.txt` includes `/vendor/${LIB}/hw`.
- The default Oreo non-Treble build installs
  `system/core/rootdir/etc/ld.config.legacy.txt` as `/system/etc/ld.config.txt`;
  product-side `PRODUCT_COPY_FILES` to the same destination would lose or
  conflict with that module. PD1619 now keeps the core module, then uses a
  device-local prebuilt marker module in `Android.mk` to overwrite the installed
  file from `configs/ld.config.legacy.txt` during post-install. This matches
  stock by adding `/vendor/${LIB}/hw` to the default namespace.
- Third useful Android userspace log:
  `/home/shion/AIK-Linux_vivo/bootlogs/20260704-082208/20260704-082208-r1`.
  The device now reaches the Lineage boot animation and surfaceflinger stays
  running, but `zygote` and `system_server` never start. `mount_all
  /fstab.qcom` returned 255 because `/system` had already been mounted by
  first-stage init and `/cache` had been mounted manually by `init.target.rc`
  before `mount_all`. That prevented init from setting `ro.crypto.state`, so
  the standard Oreo `zygote-start && property:ro.crypto.state=unsupported`
  trigger never matched. The current fix keeps `/system` in fstab for
  recovery/OTA packaging but marks it `recoveryonly`, so normal Android
  `mount_all` skips the already-mounted system partition while releasetools
  can still find `/system`. It also lets `mount_all` mount `/cache` itself.
- The same 20260704-082208 log showed the next secure-world stack problem:
  `qseecomd` repeatedly failed `dlopen(libssd.so)`, `qteeconnector-hal-1-0`
  could not get its service, and `android.hardware.gatekeeper@1.0-service`
  aborted with `Unable to open GateKeeper HAL`. Stock provides
  `vendor/lib/libssd.so` and `vendor/lib64/libssd.so`; both are now listed in
  `proprietary-files.txt` and extracted. The generated vendor set is currently
  669 files. If gatekeeper still aborts after the next boot, investigate the
  QSEE/gatekeeper firmware and service interaction rather than another plain
  missing `libssd.so`.
- Fourth useful Android userspace log:
  `/home/shion/AIK-Linux_vivo/bootlogs/20260704-091002/20260704-091046-r2`.
  This boot reaches Android framework: `zygote`, `zygote_secondary`,
  `system_server`, `surfaceflinger`, and `SystemUI` are running, bootanimation
  stops, and both `sys.boot_completed` and `dev.bootcomplete` are `1`.
  `/system`, `/data`, `/cache`, `/persist`, `/firmware`, `/dsp`, `/oem`, and
  `/apps` are mounted, and `ro.crypto.state` is now `unsupported`, validating
  the `mount_all`/`fstab.qcom` fix. Remaining blockers are now HAL/daemon
  cleanup rather than pre-framework bring-up: `mm-qcamera-daemon` was a 32-bit
  executable missing `vendor/lib/libmmcamera2_is.so`, while the 64-bit
  `adsprpcd` was repeatedly missing `vendor/lib64/libadsp_default_listener.so`.
  Stock also provides the 32-bit listener, so both `vendor/lib` and
  `vendor/lib64` copies are now listed. The generated vendor set is currently
  672 files, and a host `make nothing` parse check with
  `OUT_DIR=/tmp/los15-pd1619-091046-codex` succeeds. Gatekeeper/qteeconnector
  still restart even after `libssd.so`; WCNSS also reports a watchdog startup
  timeout, and Bluetooth has a native crash, so those are the next runtime
  investigations after the obvious missing-library noise is reduced.
- Follow-up secure-world pass after the same log: stock PD1619 provides its
  own 64-bit `android.hardware.gatekeeper@1.0-service`,
  `android.hardware.keymaster@3.0-service`, init fragments, HIDL impls,
  `gatekeeper.msm8952.so`, and `libkeymasterprovision.so`. The device tree now
  stops requesting the generic source-built gatekeeper/keymaster HIDL services
  from `hidl-hals.mk` and lists the stock files in `proprietary-files.txt`.
  `gatekeeper.msm8952.so` dynamically loads `libQSEEComAPI.so` and the
  `keymaster` QSEE app, so this better matches the stock `vivokeymaster.*`
  firmware already present. The generated vendor set is now 680 files, and a
  host `make nothing` parse check with
  `OUT_DIR=/tmp/los15-pd1619-secureworld-codex` succeeds. The build still emits
  non-fatal override warnings for some stock-vs-source paths; the copy rules
  are currently expected to win.
- Fifth useful Android userspace log:
  `/home/shion/AIK-Linux_vivo/bootlogs/20260704-094655/20260704-094655-r1`.
  This boot is no longer stuck at bootanimation: live adb reports
  `sys.boot_completed=1`, `dev.bootcomplete=1`, surfaceflinger/zygotes running,
  bootanimation stopped, and SetupWizard resumed. ADB screencap shows the
  Lineage SetupWizard, so the SF/HWC/GPU path is rendering. The physical panel
  was only extremely dim. Later isolated sysfs testing showed
  `/sys/class/leds/lm3697-backlight/brightness` is the only normal runtime
  dimming control: sweeping it visibly changes panel brightness, while sweeping
  `/sys/class/leds/lcd-backlight/brightness` has no visible effect on PD1619.
  Keep `/sys/class/leds/wled/brightness` high as a helper/supply path, but do
  Android lights HAL runtime dimming through `lm3697-backlight`. The helper
  script `tools/backlight-probe.sh` records the repeatable adb tests. Because
  bootanimation starts before Android's display power stack has applied the
  user brightness through lights HAL, init also boosts `wled` and
  `lm3697-backlight` when `init.svc.bootanim=running`; normal runtime brightness
  is handed back to lights HAL after system_server is up.
- The same 20260704-094655 log reduced the obvious missing-library noise to
  `libadsprpc.so` for `adsprpcd` and
  `libmmcamera2_stats_algorithm.so` for 32-bit `mm-qcamera-daemon`, plus one
  `libmm-disp-apis.so` dlopen. Stock has all of these in both 32-bit and
  64-bit vendor paths, so `proprietary-files.txt` now includes
  `libadsprpc.so`, `libmm-disp-apis.so`, and the 32-bit/64-bit camera frame
  and stats algorithm blobs. `extract-files.sh` now extracts 686 files, and the
  generated vendor makefile includes the new copy rules.
- First post-boot functional triage with live adb:
  logs were captured under `logs/20260704-live-blob-scan/`. The currently
  flashed build is older than the tree and still reports missing
  `libadsprpc.so` for `adsprpcd` plus `libmmcamera2_stats_algorithm.so` for
  `mm-qcamera-daemon`; those are already listed above and should disappear
  after the next package is flashed. Wi-Fi is a clearer missing-file case:
  the kernel requests
  `vendor/firmware/wlan/prima/WCNSS_qcom_wlan_nv.bin`, stock implements it and
  `WCNSS_wlan_dictionary.dat` as symlinks to `/persist`, and the Android Wi-Fi
  HAL expects `/system/lib/modules/wlan.ko`. PD1619 now packages stock
  `pronto_wlan.ko`, creates the `wlan.ko` symlink at build time, creates the
  WCNSS persist symlinks under both `etc/firmware` and `vendor/firmware`, and
  sets `WIFI_DRIVER_MODULE_*` to load `/system/lib/modules/wlan.ko` with
  `con_mode=5`. The symlinks are intentionally generated from `Android.mk`
  instead of copied from `proprietary-files.txt`, because LOS15's
  `PRODUCT_COPY_FILES` uses plain `cp` and would follow the host-side
  `/persist` symlinks. Netmgr/baseband also had an obvious stock-config gap:
  `netmgrd` restarted with `unable to load config for target:Eldarion`, so the
  stock `vendor/etc/data/{dsi,netmgr,qmi}_config.xml` files are now included.
  The current `proprietary-files.txt` has 690 real copy entries, with the
  symlinks generated separately. A targeted host build using
  `OUT_DIR=/tmp/los15-pd1619-blobscan-codex` successfully creates the WCNSS
  symlinks and `/system/lib/modules/wlan.ko` link. Audio and Bluetooth did not
  show simple missing-linker-library failures in this pass; Bluetooth is
  currently timing out at the HCI/controller layer, and audio needs a config
  comparison against stock after the easy blob fixes are tested.
- Sixth useful Android userspace log:
  `/home/shion/AIK-Linux_vivo/bootlogs/20260704-105025/20260704-105025-r1`.
  Brightness is usable and baseband is now far enough to read the SIM. Wi-Fi
  progressed from missing firmware/module paths to a legacy HAL state bug:
  `android.hardware.wifi@1.0-service` was running as `wifi` and repeatedly
  failed `init_module(/system/lib/modules/wlan.ko)` with `Operation not
  permitted`. Live adb showed `wlan` already present in `/proc/modules` and
  `wlan0` present but down, while `wlan.driver.status` was empty. After
  manually setting `wlan.driver.status=ok`, the next failure became
  `chown(/sys/module/wlan/parameters/fwpath): Operation not permitted`, so the
  device now overrides the common Wi-Fi HAL rc with
  `capabilities CHOWN SYS_MODULE NET_ADMIN NET_RAW`. `init.qcom.rc` also now
  mirrors stock more closely by setting `wifi.interface=wlan0`, attempting
  `insmod /system/lib/modules/wlan.ko con_mode=5`, chowning the firmware reload
  sysfs node, and setting `wlan.driver.status=ok`. A targeted host build with
  `OUT_DIR=/tmp/los15-pd1619-blobscan-codex` confirms the root rc and Wi-Fi HAL
  rc override install into the product image.
- The same log showed audio effects were missing stock Qualcomm soundfx blobs:
  `libqcbassboost.so`, `libqcvirt.so`, and `libqcreverb.so` in both 32-bit and
  64-bit `vendor/*/soundfx`. Those six blobs are now listed and extracted.
  `audio_effects.xml` no longer references `libswdap.so`/`ds`, because the
  stock PD1619 system dump does not contain `libswdap.so`. The current
  `proprietary-files.txt` has 696 real copy entries. Audio may still need a
  deeper policy/HAL pass, but this should remove the obvious EffectsFactory
  missing-library spam on the next flash.
- Post-flash WLAN/audio triage with live adb:
  logs were captured under `logs/20260704-postflash-wlan-audio/`. This build
  did flash the system/vendor-side pieces: the device has the Wi-Fi HAL rc
  override under `/vendor/etc/init/`, and the Qualcomm soundfx blobs are present
  in both `/vendor/lib/soundfx` and `/vendor/lib64/soundfx`. The boot ramdisk did
  not appear to be updated, however: live `/init.qcom.rc` did not contain the
  PD1619 Wi-Fi `insmod`, `wifi.interface`, or `wlan.driver.status` changes. Any
  future rootdir/init change still needs the matching `boot.img` to be fastboot
  flashed.
- The same post-flash log showed Wi-Fi still failing before firmware bring-up:
  `android.hardware.wifi@1.0-service` repeatedly hit
  `init_module(/system/lib/modules/wlan.ko)` with `Operation not permitted`.
  Although the flashed service rc requested
  `capabilities CHOWN SYS_MODULE NET_ADMIN NET_RAW`, live `/proc/<pid>/status`
  only showed `NET_ADMIN` and `NET_RAW` in the effective set. For this bring-up
  stage, the device Wi-Fi HAL override now runs the service as `root` with
  `root wifi gps` groups so module insertion and `fwpath` ownership do not
  depend on init's non-root capability handling.
- Audio effects are no longer the main blocker after the soundfx blob pass.
  `dumpsys media.audio_flinger` shows the Qualcomm bassboost, virtualizer, and
  reverb libraries being loaded from `/vendor/lib/soundfx`. The primary audio
  HAL now fails because `/system/lib/hw/audio.primary.msm8952.so` depends on
  `libktv_qcom.so`, which was missing from the image. Stock has both 32-bit and
  64-bit copies, so `vendor/lib/libktv_qcom.so` and
  `vendor/lib64/libktv_qcom.so` are now listed, extracted, and present in the
  generated vendor makefile. The current `proprietary-files.txt` has 698 real
  copy entries. A targeted host build with
  `OUT_DIR=/tmp/los15-pd1619-blobscan-codex` confirms the root Wi-Fi HAL rc
  override plus both `libktv_qcom.so` copies install into the product image.
- Follow-up WLAN/audio triage with live adb:
  logs were captured under `logs/20260704-114931-wlan-audio-followup/`. The
  flashed package includes the root Wi-Fi HAL rc and `libktv_qcom.so`, so the
  previous fixes did take effect. Wi-Fi now has two later-stage failures: init's
  boot-time `insmod /system/lib/modules/wlan.ko con_mode=5` rejects the
  generated `wlan.ko` symlink with "Too many symbolic links encountered", and
  the source-built `android.hardware.wifi@1.0-service` can briefly load the
  stock pronto driver but then fails through cld80211/wificond:
  `Could not resolve cld80211 family id`, `Failed to get wiphy index`, and
  `Wifi turn on failed`. PD1619 now installs `/system/lib/modules/wlan.ko` as a
  real copy of `pronto_wlan.ko` instead of a symlink, stops building the generic
  Wi-Fi HAL service, and extracts the stock PD1619 service plus its 64-bit
  support libraries: `vendor/bin/hw/android.hardware.wifi@1.0-service`,
  `vendor/lib64/libwifi-hal.so`, and
  `vendor/lib64/vendor.qti.hardware.wifi@1.0_vendor.so`. The extraction list is
  now 701 real copy entries. A targeted host build with
  `OUT_DIR=/run/media/shion/GameTurbo/tmp/los15-pd1619-wifi-prebuilt-codex`
  confirms the installed Wi-Fi service and helper libraries match the stock
  blob hashes, including the 64-bit stock `libcld80211.so`, and that
  `/system/lib/modules/wlan.ko` is a real file matching `pronto_wlan.ko` rather
  than a symlink.
- The same follow-up log shows the audio HAL has moved past the missing
  `libktv_qcom.so` dependency. `audio.primary.msm8952` now aborts because it
  tries to open `/vendor/etc/mixer_paths.xml`, while the image only had
  `mixer_paths_qrd_skun_cajon.xml`. Stock PD1619 has a device-specific
  `mixer_paths.PD1619.xml`, so the tree now copies that file to both
  `/vendor/etc/mixer_paths.xml` and `/vendor/etc/mixer_paths.PD1619.xml`.
  Stock `audio_platform_info.xml`, `audio_platform_info_extcodec.xml`, and
  `/system/etc/sound_trigger_mixer_paths.xml` are also imported so the primary
  audio HAL and sound-trigger HAL see the same control names as the stock
  mixer paths. The same targeted host build confirms these XML files install to
  the expected system/vendor paths.
- Call-audio debugging showed Telecom enters `MODE_IN_CALL` and QTI sends
  `vsid/call_state` to audioserver, but all Voice/VoLTE tinymix routes remain
  off. Stock PD1619 keeps `audio_platform_info*.xml` under `/system/etc` and
  ships `/system/etc/acdbdata`, so the system-side platform XMLs and full stock
  ACDB calibration set are extracted for the primary audio HAL. A live hot-push
  of these files plus the stock-aligned audio properties restored in-call audio
  on a VoLTE 10086 test call.
- Hi-Fi DAC bring-up notes:
  the prebuilt kernel already probes the ES9018 path at I2C `1-0048` and exposes
  `/sys/kernel/debug/es9018/reg`, `hifi-codec-pd1619`, and the
  `VIVO_HiFi_Playback` mixer control. Stock sets
  `ro.config.hifi_config_state=2`, `persist.vivo.phone.hifi=Have_hifi`, and
  `ro.config.hifi_always_on=no`. A live `AudioSystem.setParameters()` test with
  `enable_hifi=1` and `force_enable_hifi=1` returned success, switched tinymix
  to `VIVO_HiFi_Playback On`, `HiFi Mute None`, `QUIN_MI2S Bit Format S24_LE`,
  and produced audible headphone output through the Hi-Fi path. The stock
  `AudioEffect.apk` is therefore UI/whitelist glue; the useful integration point
  is a small settings/service wrapper around these HAL parameters.
- Hi-Fi UI integration:
  PD1619 now keeps device-specific toggles under a dedicated `Vivo Features`
  entry in `Settings > System` so the implementation stays device-side. The
  page currently exposes Hi-Fi DAC and fast charging; it reuses the existing
  `pd1619_hifi_enabled` secure setting, applies `enable_hifi` plus
  `force_enable_hifi` immediately, and lets `PD1619Parts` restore the saved
  Hi-Fi state after boot. Disabling Hi-Fi also restarts `audioserver` so the
  HAL actually drops back out of the external DAC path. HOME-touch remapping
  and virtual-key haptics should stay fixed device behavior rather than
  user-facing feature switches.
- Camera follow-up after WLAN/audio/baseband booted:
  logs captured under `logs/20260704-124156-camera-followup/` showed the camera
  provider and `mm-qcamera-daemon` running, but `dumpsys media.camera` reported
  `Number of camera devices: 0`. Snap then crashed only because it assumed at
  least one camera ID existed. Live adb confirmed the device image had no
  `/system/etc/camera`, no `/vendor/etc/camera`, and zero `libchromatix*`
  libraries. Stock PD1619 contains `etc/camera/camera_config.xml` with three
  modules (`imx298_pd1617`, `imx376`, `s5k3h7`) plus per-sensor chromatix XMLs,
  `frontFlashConfig.xml`, `preisp_profiles.xml`, and 143
  `vendor/lib/libchromatix_*.so` tuning libraries. Those stock camera tuning
  assets, plus `libflash_bd7710.so`, `libflash_lm3646.so`, and
  `libflash_pmic.so`, are now listed in `proprietary-files.txt` and extracted
  into `vendor/vivo/PD1619/proprietary`. The regenerated vendor makefile installs
  the XMLs to `/system/etc/camera` and the tuning libraries to
  `/system/vendor/lib`. Stock `frontFlashConfig.xml` is rootless pseudo-XML,
  so `extract-files.sh` wraps it in a `<frontFlashConfig>` root after extraction;
  otherwise Android's `PRODUCT_COPY_FILES` XML validation fails at `xmllint`.
  `USE_PROPRIETARY_CAMERA := true` and
  `BOARD_QTI_CAMERA_32BIT_ONLY := true` are already set, and the stock
  `camera.msm8952.so` in the image matches the stock dump hash, so the next test
  should focus on whether these tuning assets make the provider enumerate camera
  IDs.
- Live validation of the camera tuning pass:
  after `adb root && adb remount`, the stock camera XMLs plus chromatix/flash
  libraries were hot-pushed to the running system and camera services were
  restarted. `dumpsys media.camera` changed from 0 devices to 3 normal camera
  devices. With `persist.camera.HAL3.enabled=1`, Snap used Camera2/HAL3 and could
  open camera 0, but `Camera3-Device` failed the first capture request with
  `Function not implemented (-38)`. Setting `persist.camera.HAL3.enabled=0` and
  restarting the camera stack made Snap use API1/HAL1; it then opened camera 0,
  selected a 1440x1080 preview, and reached the preview path without the
  `Function not implemented` error or app crash. The tree now defaults
  `persist.camera.HAL3.enabled=0` in `system.prop`.
- Camera wrapper follow-up:
  logs captured under `logs/20260704-135748-camera-current/` show that the HAL1
  enumeration side is now healthy: `dumpsys media.camera` reports 3 normal
  camera devices, `cameraserver`, `camera-provider-2-4`, and `mm-qcamera-daemon`
  are running, and Open Camera connects/disconnects camera IDs 0, 1, and 2
  through Camera API1. There is no provider/daemon crash in that log. The
  remaining failure is in the HAL1 preview path, where
  `camera.device@1.0-impl` repeatedly logs `getHidlStatus: unknown HAL status
  code -2147483648` immediately after opening a camera. That value is Android's
  `UNKNOWN_ERROR`, so the generic O camera wrapper is likely not compatible with
  vivo's stock HAL behavior. The tree now stops building Lineage's generic
  `camera.device@*-impl` and `android.hardware.camera.provider@2.4-*` modules
  and instead extracts the stock PD1619 provider/wrapper stack, including
  `android.hardware.camera.provider@2.4-service`, the 32/64-bit
  `camera.device@1.0/3.2/3.3-impl.so` files, the provider impls, and
  `vendor.qti.hardware.camera.device@1.0_vendor.so`. The extracted stock
  provider service links vivo's private
  `vendor.vivo.hardware.camera.provider@1.0_vendor.so`, which the generic source
  service does not.
- Camera preview fix:
  after switching to the stock camera provider/wrapper stack, preview still
  failed in both Open Camera and Snap. The stable signature was
  `camera.device@1.0-impl` reporting `getHidlStatus: unknown HAL status code
  -2147483648`, while `dumpsys media.camera` stayed at `Is Preview Running: 0`
  and `QCAMERA_SM_STATE_PREVIEW_STOPPED`. Disassembling the stock
  `camera.msm8952.so` showed that `QCamera2HardwareInterface::startPreview()`
  returns `0x80000000` when the preview channel pointer is absent or channel
  setup fails. Comparing the stock dump against the extracted image then found
  a missing runtime set of 64 32-bit vendor camera modules, including
  `libSonyIMX298PdafLibrary.so`, `libmmcamera2_dcrf.so`,
  `libmmcamera2_mct_shimlayer.so`, the full `libmmcamera_isp_*.so` module set,
  `libmmcamera_cac3_lib.so`, `libmmcamera_sw2d_lib.so`, and vivo camera filter
  libraries. Hot-pushing that set to `/system/vendor/lib`, restoring contexts,
  and restarting `camera-provider-2-4`, `cameraserver`, and `qcamerasvr` made
  Snap reach `Is Preview Running: 1` / `QCAMERA_SM_STATE_PREVIEWING` in
  `logs/20260704-144121-camera-missing-mm-modules-livepush2-test/`. These files
  are now added to `proprietary-files.txt`; re-running `extract-files.sh`
  extracted 940 files and regenerated `vendor/vivo/PD1619/PD1619-vendor.mk`.
  This means the previous `startPreview failed` path was a missing preview/ISP
  module set, not a SurfaceFlinger issue and not primarily a QTI callback issue.
- Camera capture/JPEG fix:
  once preview was running, pressing the shutter still failed to save a picture.
  Snap reached `RawPictureCallback`, but the camera provider logged
  `qomx_image_core: OMX_GetHandle: Cannot load the library`, followed by a
  camera error callback with `-2147483648`. Stock PD1619's JPEG OMX stack was
  missing from the image: `libjpegdhw.so`, `libjpegdmahw.so`, `libjpegehw.so`,
  `libmmjpeg.so`, `libmmqjpeg_codec.so`, `libmmqjpegdma.so`,
  `libqomx_jpegdec.so`, `libqomx_jpegenc.so`, and
  `libqomx_jpegenc_pipe.so`. Hot-pushing those nine 32-bit vendor libraries
  fixed capture: `logs/20260704-144657-camera-snapshot-jpeg-livepush-test/`
  shows `OMX_GetHandle: Success`, `JpegE library loaded successfully`,
  `JPEG_EVT_SESSION_DONE`, `JpegPictureCallback`, and a new saved file at
  `/sdcard/DCIM/Camera/IMG_20260704_144713.jpg`. These libraries are now listed
  in `proprietary-files.txt`; re-running `extract-files.sh` extracted 949 files
  and regenerated the vendor makefile.
- Fingerprint bring-up after the main hardware bring-up:
  live adb showed `sys.fingerprint.boot=fpc_1245`, `/sys/fp_id/fp_id` reporting
  `fpc_1245`, the SPI driver bound at `/sys/bus/spi/drivers/fpc1245/spi3.0`,
  and the stock FPC service successfully loading the `fpc1245` QSEE app and
  creating the `uinput-fpc` input device. However, Lineage's
  `FingerprintService` still logged `Fingerprint HAL id: 0` followed by
  `Failed to open Fingerprint HAL!`. This looks like a vivo framework contract
  mismatch: the stock service initializes hardware but returns an id that AOSP
  treats as failure. The tree therefore stops installing the stock
  `vendor.vivo.hardware.biometrics.fingerprint@2.0-service-fpc1245` service and
  rc, keeps the stock init detector script, and starts the Lineage custom
  fingerprint HIDL service from the `sys.fingerprint.boot=fpc_1245` trigger
  instead. The custom service now checks `sys.fingerprint.boot`, opens the FPC
  module id directly with `hw_get_module("fpc_1245", ...)`, accepts the stock
  HAL's 2.1 device version, and returns a non-zero legacy HAL pointer to the
  framework. Live testing loaded the `fpc1245` trustlet, created `uinput-fpc`,
  called `fpc_set_notify`, exposed `android.hardware.fingerprint`, and
  successfully enrolled a fingerprint; `dumpsys fingerprint` then reported one
  template. A targeted host build using
  `OUT_DIR=/run/media/shion/GameTurbo/tmp/los15-pd1619-fp-codex` successfully
  builds `fingerprint.msm8952` for 32/64-bit and
  `android.hardware.biometrics.fingerprint@2.0-service-custom`. The custom init
  rc was renamed to
  `android.hardware.biometrics.fingerprint@2.0-service-custom.rc` to avoid
  colliding with Lineage's generic 2.0 fingerprint service rc target. The
  current `proprietary-files.txt` has 1041 real entries.
- Fingerprint persistence follow-up:
  the reboot-loses-enrollment bug was not caused by the fingerprint HIDL
  service failing to start. Live checks showed
  `android.hardware.biometrics.fingerprint@2.1-service.PD1619` running,
  `lshal` exposing `android.hardware.biometrics.fingerprint@2.1::IBiometricsFingerprint/default`,
  and `dumpsys fingerprint` reporting one enrolled print. The real breakage was
  in the custom `gdxbiometrics/BiometricsFingerprint.cpp`: its
  `enumerate()` path always forced the old array-return pre-2.1 ABI, and its
  `notify()` handler dropped `FINGERPRINT_TEMPLATE_ENUMERATING` entirely. On
  FPC 2.1 this made boot-time cleanup misread hardware enumeration, log
  `Removing dangling enrolled fingerprint` plus dozens of bogus unknown prints,
  and then delete framework-side enrollment state. The fix is to call
  `mDevice->enumerate(mDevice)` when `mDevice->common.version >= 2.1`, keep the
  array-return shim only for older HALs, and forward
  `FINGERPRINT_TEMPLATE_ENUMERATING` to the client callback.
- Sensor/auto-rotate follow-up:
  auto-rotate was not a framework setting issue. Live adb showed
  `dumpsys sensorservice` returning `No Sensors on the device`, while
  `dumpsys window policy` had auto-rotation support enabled but no selected
  orientation sensor. The sensor1 path itself was alive: the HAL logged
  `SMGR version=23`, then `processAllSensorInfoResp: SensorInfo_len: 0`.
  That means `sensors.qcom` and ADSP/SMGR can talk, but the registry defaults
  did not produce any physical sensor entries. The tree now replaces the LeEco
  generic `sensor_def_qcomdev.conf` with stock PD1619's copy, installs it to
  both `/system/etc/sensors` and `/system/vendor/etc/sensors`, restores stock
  `init.qcom.sensors.sh`, makes the `sensors` daemon disabled like stock, and
  lets `sensor-sh` prepare `/persist/sensors/registry/registry` before starting
  it. The source-built `android.hardware.sensors@1.0-{impl,service}` pair is
  no longer requested; stock PD1619 sensors HIDL blobs and sensor calibrate
  libraries are extracted instead. If sensors are still empty after a clean
  flash, delete `/persist/sensors/sns.reg` once and recheck SMGR registry
  responses.
- Android 9 sensor follow-up:
  after the cleanup tree booted, sensors regressed to `No Sensors on the
  device` again. Runtime testing showed that deleting `/persist/sensors/sns.reg`
  made `sensors.qcom` regenerate it, but did not restore any framework-visible
  sensors. The stock PD1619 sensors HIDL service logged
  `HAL specifies version 1.4, but does not implement set_operation_mode()`;
  switch the HIDL wrapper to the s2 source-built
  `android.hardware.sensors@1.0-service.s2` while keeping the PD1619 stock
  `sensors.qcom`, `sensors.msm8952_64.so`, `sensors.ssc.so`, and registry
  configs.
- Android 9 sensor follow-up, round 2:
  the device-local wrapper was later renamed to
  `android.hardware.sensors@1.0-service.PD1619`. After flashing a build with
  the matching `file_contexts` entry, the service finally ran in
  `u:r:hal_sensors_default:s0` instead of `u:r:init:s0`, so the remaining
  sensor regression is no longer a service-label problem. Live logs still show
  the stock prebuilt `android.hardware.sensors@1.0-impl.so` reporting
  `HAL specifies version 1.4, but does not implement set_operation_mode()`,
  plus repeated `libsensor1: qmi_client_get_service_list error -2` and
  `qti_sensors_hal: addSensor : Not supported sensor with handle ...`. The next
  experiment is to stop shipping the prebuilt HIDL impl and build
  `android.hardware.sensors@1.0-impl` from source while keeping the stock
  legacy sensor blobs (`sensors.msm8952_64.so`, `sensors.ssc.so`,
  `libsensor1.so`, registry configs).
- Android 9 sensor follow-up, round 3:
  additional live adb checks on 2026-07-08 ruled out several easy answers.
  The current booted image already has `/vendor/dsp -> /dsp` and
  `/vendor/firmware_mnt -> /firmware`, plus source-built
  `vendor/lib(64)/libsensorndkbridge.so`. Hot-adding the symlinks earlier did
  not change the `qmi_client_get_service_list error -2` behavior, so the
  missing symlink was a real tree bug but not the only cause of the Pie
  regression. Checksums of the live sensor userspace chain
  (`sensors.qcom`, `sensors.ssc.so`, `libsensor1.so`, `libqmi_cci.so`,
  `libqmi_common_so.so`, `libqmi_csi.so`, `libqmi_encdec.so`, `libdiag.so`)
  match the stock PD1619 dump exactly, which argues against a mixed vendor
  sensor/QMI stack. However, the Pie build still uses non-stock framework-side
  sensor bridge libraries (`libsensorservice.so`, `libsensorservicehidl.so`,
  `libsensor.so`, `android.frameworks.sensorservice@1.0.so`,
  `android.hardware.sensors@1.0.so`, `libsensorndkbridge.so` all differ from
  stock checksums), so the remaining regression is now more likely to live in
  the Pie bridge/runtime layer or in an earlier boot-time subsystem path than
  in missing sensor blobs.
- Android 9 sensor follow-up, round 4:
  a live adb A/B test replaced the 64-bit framework-side sensor bridge stack
  with stock Oreo copies:
  `android.frameworks.sensorservice@1.0.so`,
  `android.hardware.sensors@1.0.so`, `libsensor.so`,
  `libsensorservice.so`, `libsensorservicehidl.so`, and
  `vendor/lib64/libsensorndkbridge.so`. The replacement hashes matched the
  stock dump exactly after `adb remount`, so this was not a packaging mistake.
  The result was worse, not better: `system_server` failed to come up,
  `bootanim` stayed running, and the phone never reached
  `sys.boot_completed=1` until the original Pie-built libraries were restored
  from `/data/local/tmp/pd1619-sensor-bridge-backup-20260708-172003`. After
  restoring the original hashes and rebooting, the device returned to the prior
  baseline (`system_server` alive, normal boot complete, sensors still missing).
  Conclusion: the stock Oreo framework bridge libraries are not drop-in
  compatible with the current Pie system image, so the fix is not a simple
  system-lib swap.
- IMS/call bring-up follow-up:
  mobile data and SMS worked, but outgoing calls disconnected immediately while
  the framework logged `ImsManager: getServiceProxy: b is null` and
  `ImsException: Binder is not active!(106)`. Native IMS daemons were running,
  but `cmd package query-services -a android.telephony.ims.ImsService` returned
  no services. Stock PD1619 provides the missing framework side as
  `/system/app/ims/ims.apk`, package `org.codeaurora.ims`, shared UID
  `android.uid.phone`, and service `.ImsService` with
  `android.permission.BIND_IMS_SERVICE`. Because the stock APK is signed with
  BBK's platform key and our phone stack is signed with the Lineage platform
  key, it must be extracted as a prebuilt APK module and re-signed by the build
  system, not copied raw with `PRODUCT_COPY_FILES`. The stock APK is also odexed
  and has no `classes.dex`, so `extract-files.sh` must deodex it from
  `app/ims/oat/arm64/ims.vdex`. The tree now extracts `ims.apk`, its required
  `com.qti.vzw.ims.internal` shared library jar/xml, IMS JNI/video libraries,
  `imsrcsd`, and the stock `qcril.db`; `init.target.rc` also starts the
  correctly named `vendor.imsrcsservice`.
- The first `org.codeaurora.ims` bring-up build registered
  `android.telephony.ims.ImsService`, but `com.android.phone` crashed on
  `VivoInfoImsExceptionFactory.addQueueIMSChanged()`. The real missing class is
  not in IMS: vivo added `com.android.internal.telephony.CollectonUtils`
  (spelled that way) to stock `boot-telephony-common.vdex`. That class only
  backs vivo IMS exception/telemetry collection, so importing stock
  `telephony-common.jar` would be much riskier than the feature is worth.
  `extract-files.sh` now runs `tools/patch-vivo-ims-apk.sh` after extraction to
  decompile `ims.apk`, replace `VivoInfoImsExceptionFactory` public entry points
  with no-ops, remove stale APK signatures, and let the build re-sign the APK
  with the Lineage platform key.
- The patched stock vivo IMS stack still left Android's `ImsPhone` out of
  service even though the radio side reported IMS registration. Logs showed the
  dial path falling back to CS (`BIND_CS` / `RIL_REQUEST_DIAL`) and the modem
  rejecting it with `INVALID_MODEM_STATE`; `ImsPhoneCallTracker` kept VoLTE
  disabled because the expected O-era registration/capability callbacks never
  reached the framework. To test a coherent O stack, the tree now kanges the
  LeEco s2 / SRT Phone Oreo IMS and QTI telephony addon set from
  `vendor/leeco/s2`, commit `420e5505e7ffebf141f357ff45d54bdc843d21fa`
  (`s2: Update blobs to oreo`). This includes `ims.apk`, `imssettings`,
  `uceShimService`, `QtiTelephonyService`, `qcrilmsgtunnel`,
  `qcrilhook.jar`, `qti-telephony-common.jar`,
  `QtiTelephonyServicelibrary.jar`, `qti-vzw-ims-internal.jar`,
  `com.qualcomm.qti.imscmservice@1.0-java.jar`, IMS/RTP/UCE native blobs,
  and `vendor.qti.hardware.radio.ims/qcrilhook@1.0` HIDL blobs. Core PD1619
  RIL, netmgr, qcril database, and vivo-only blobs are still kept unless the
  next test shows the wider radio stack must also be swapped.
- `tools/patch-vivo-ims-apk.sh` is now tolerant of both APK families: for vivo
  IMS it no-ops the vivo telemetry hook, while for SRT/LeEco IMS that class is
  absent and the script only applies the PD1619 slot-0-active
  `ImsSubController` patch. The pinned `app/ims/ims.apk` hash in
  `proprietary-files.txt` is the patched SRT/LeEco APK, not the raw source blob.
- `qcrilmsgtunnel.apk` requests shared library
  `android.hidl.manager@1.0-java`, while the Android O source jar is named
  `android.hidl.manager-V1.0-java.jar`; `qti_libpermissions.xml` deliberately
  exposes the former name while pointing at the latter file.
- Android 9 sensor follow-up, round 5:
  the live device is back on the stock PD1619 low-level sensor blobs
  (`sensors.qcom`, `sensors.ssc.so`, `libsensor1.so`, `libsensor_reg.so`,
  `sensor_calibrate.so`) plus the source-built Pie wrapper service
  `android.hardware.sensors@1.0-service.PD1619` and source-built
  `android.hardware.sensors@1.0-impl`. `dumpsys sensorservice` still reports
  `No Sensors on the device` / `devInitCheck : 0`, but the current logs are
  now well-characterized: `qti_sensors_hal` does enumerate PD1619-specific
  details such as `AKM09911`, `AK09911-uncal_mag`, and multiple sensor handles,
  then fails while requesting algorithm attributes through `libsensor1` with
  repeated `qmi_client_get_service_list error -2`, `Unable to create client
  connection`, `SensorsContext::getSensor handle ... is NULL!`, and
  `Not supported sensor with handle ...` messages. That means the stock PD1619
  blob stack is at least closer to the real hardware than a foreign one.
- Android 9 sensor follow-up, round 6:
  a surgical live swap of only `libsensor1.so` from `vendor/leeco/s2` changed
  the failure mode, but did not recover sensors. Instead of only
  `qmi_client_get_service_list error -2`, the log also produced
  `Requested service is invalid or disallowed 67/69/70` and
  `Service object not found`, which suggests the foreign `libsensor1` reaches a
  slightly different service table but still mismatches the PD1619 stack.
- Android 9 sensor follow-up, round 7:
  a live swap of the whole `s2` low-level sensor set
  (`sensors.qcom`, `sensors.ssc.so`, `libsensor1.so`, `libsensor_reg.so`,
  `sensor_calibrate.so`) also failed to bring sensors up. The result remained
  `No Sensors on the device`, and the logs lost some of the useful PD1619-
  specific `AKM09911` detail that the stock vivo blobs expose. Conclusion:
  stealing the entire LeEco `s2` sensor blob stack is not the right fix path
  for PD1619; if any cross-device borrowing is attempted later, it should be
  very targeted and only after identifying a donor stack that matches the same
  sensor/QMI layout.
- Android 9 sensor follow-up, round 8:
  the device tree itself still had sensor-init drift versus other msm8976
  bring-ups. `rootdir/etc/init.qcom.rc` only created `/persist/sensors` and
  touched `sensors_settings`, while `s2` also fixes ownership for `sns.reg`,
  registry directories, and related files. The packaged
  `rootdir/etc/init.qcom.sh` also still used old `chmod -h` / `chown -h`
  forms, which the current shell rejects. Live adb testing confirmed that
  aligning `/persist/sensors`, `sns.reg`, and registry ownership to
  `system:system` is hygienically correct but still not sufficient: the HAL
  remains stuck at `qmi_client_get_service_list error -2` and
  `devInitCheck : 0`. The tree should still carry the init/permission cleanup,
  but the remaining breakage is deeper than a simple persist ownership issue.
- Android 9 sensor follow-up, round 9:
  the current Pie userspace was also missing a legacy identity that the stock
  Qualcomm sensor daemon still expects. `strings /vendor/bin/sensors.qcom`
  shows it tries `getpwnam/getgrnam("sensors")` and explicitly falls back to
  `nobody` if that lookup fails. On the running Pie build, `id sensors` fails,
  `generated_android_ids.h` contains `system`, `radio`, `gps`, `input`, and
  `nobody` but not `sensors`, and the live daemon indeed runs as
  `uid=9999(nobody) gid=9999(nobody)`. That in turn explains the ugly
  capability/ownership smell around `/persist/sensors/*`: the blob is being
  forced down its fallback path. `system/core` history confirms this is not a
  made-up local hack: commit `f55d74fbe2b` (`system: core: Add Sensors group`)
  originally defined `AID_SENSORS 3012` for exactly this legacy Qualcomm
  sensor socket/service use case. The tree now restores `AID_SENSORS 3012` in
  `system/core/libcutils/include/private/android_filesystem_config.h` so
  `bionic` can regenerate a `generated_android_ids` entry for `sensors`.
- Android 9 sensor follow-up, round 10:
  the useful breakthrough was not in `dmesg` but in the userspace sensor
  daemon itself. Kernel-side logging is effectively useless on this device for
  the sensor path: `dmesg` stays empty, `/proc/kmsg` and `/dev/kmsg` do not
  emit meaningful `sensor|adsp|dsps|slpi|sns|qmi|smgr` lines, and the closed
  3.10 kernel exposes only a writable `/sys/kernel/boot_adsp/boot` node with
  no readable `status`/`subsys_state` companion nodes. The productive debug
  path is:
  `setprop debug.vendor.sns.daemon 1`, then restart `sensors.qcom`, and if
  needed temporarily widen `/persist/sensors/sensors_dbg_config.txt`.
  With that enabled, `sensors.qcom` prints its real init sequence:
  `sns_em_init`, `sns_reg_init`, `sns_time_init`, `sns_debug_test_init2`,
  `sns_aon_algo_init`, then `All modules initializied`, followed by
  `Register for SMRG service`, `Waiting for SMGR service up`,
  `Get SMGR servive info`, `Initialize client for SMRG`,
  `Register for SMGR error notification`, and finally
  `sns_daemonctrl_sem! waiting %d`.
  Framework-side symptoms match that story exactly:
  `libsensor1: wait_for_service: Service 0 is not available (5000 ms)` and
  `qti_sensors_hal: SMGRSensor_sensor1_cb: SENSOR1_MSG_TYPE_RETRY_OPEN`, while
  `dumpsys sensorservice` still shows `No Sensors on the device` /
  `devInitCheck : 0`.
  Conclusion: the remaining Pie regression is no longer "HAL wrapper is wrong"
  but "the ADSP/SMGR side never becomes ready for the daemon to bind to". This
  makes the next debugging target the ADSP/DSPS bring-up path and service
  readiness rather than more blind HIDL or framework churn.
- Android 9 sensor follow-up, round 11:
  a partial msm8953 Qualcomm BSP at
  `/run/media/shion/GameTurbo/LinuxZone/vendor_qcom_proprietary-msm8953/`
  was enough to recover the control flow behind the debug strings.
  `sensordaemon/main/src/sns_main.c` confirms:
  `Register for SMRG service` -> `Waiting for SMGR service up` ->
  `Get SMGR servive info` -> `Initialize client for SMRG` ->
  `Register for SMGR error notification` all belong to
  `sns_monitor_smgr_restart()`. If that wait actually times out, the daemon
  logs `Timeout waiting for SMGR service. Exit sensors daemon!` and calls
  `sns_main_exit()`. The later `sns_daemonctrl_sem! waiting %d` log is *not*
  the SMGR wait; it is only the daemon's final idle loop after startup has
  already completed and root privileges have been dropped. In other words:
  seeing `sns_daemonctrl_sem! waiting` means `sensors.qcom` did manage to see
  an SMGR service and register an error callback at least once.
  The same BSP also proves that the framework-side
  `libsensor1: wait_for_service: Service 0 is not available (5000 ms)` message
  refers specifically to `SNS_SMGR_SVC_ID_V01` (`sns_common_v01.h` defines
  service ID 0 as SMGR), and that `SENSOR1_MSG_TYPE_RETRY_OPEN` is the normal
  async notification posted after an earlier `sensor1_open()` had to return
  `SENSOR1_EWOULDBLOCK` while waiting for SMGR.
  This narrows the interpretation of the live logs:
  the problem is probably not "ADSP is completely dead", but rather that SMGR
  readiness is late/flaky from the framework client's point of view and/or
  later algorithm services (SAM family) still fail to come up after the base
  SMGR path becomes visible.
- Android 9 sensor follow-up, final:
  the real LOS 16 root cause was much simpler than the framework/HIDL symptoms
  suggested: the legacy Qualcomm daemon `/vendor/bin/sensors.qcom` was never
  starting. In `rootdir/etc/init.qcom.rc` the `service sensors` stanza existed,
  but it was marked `disabled`, there was no matching `start sensors` trigger
  anywhere in the device/vendor init scripts, and the companion `sensor-sh`
  helper also had no active trigger. That left
  `init.svc.vendor.sensors-hal-1-0=running` while `init.svc.sensors` stayed
  empty, so the HIDL wrapper registered successfully but could only return an
  empty sensor list.
  Live validation was decisive: manually starting `sensors.qcom`, then
  restarting `vendor.sensors-hal-1-0` and `system_server`, immediately
  restored a full working `dumpsys sensorservice` listing with live sensor
  events. The correct device-tree fix is simply to let `service sensors
  /vendor/bin/sensors.qcom` start normally with its `class core` instead of
  leaving it permanently disabled. All temporary framework/HIDL debug and
  retry experiments from this investigation were removed after confirmation.

## LineageOS 17.1 Early-Boot Breadcrumbs

- The Android 10 bring-up can currently fail before boot animation and before
  adbd becomes usable, while the stock kernel also provides no useful dmesg.
  `init.target.rc` therefore keeps a temporary persistent early-boot trace on
  the physical cache partition.
- This deliberately differs from the old Oreo bring-up rule that let
  `mount_all` mount cache. For LOS 17.1 only, the cache fstab entry is marked
  `recoveryonly`; normal boot starts `ueventd` and mounts cache directly from
  the device `early-init` action. This avoids waiting for the full fstab pass,
  which may block on userdata before any breadcrumb can be persisted.
- Stage files cover `early-init`, `init`, `late-init`, `fs`, `post-fs`,
  `post-fs-data`, APEX, logd, service managers, vold, zygote, SurfaceFlinger,
  boot animation, and the ordinary boot actions. The newest reached stage is
  stored in `/cache/pd1619-last-stage`.
- The trace also saves the kernel command line, kernel version, mount tables
  from before and after `mount_all`, and any available `last_kmsg`/pstore
  console. Once logd starts, a small rotating userspace log is written to
  `/cache/pd1619-logcat.txt` (up to two 2 MiB rotations).
- After a failed boot, enter recovery and inspect or pull
  `/cache/pd1619-*`. If no file exists at all, second-stage init either did not
  import `init.target.rc`, failed before its device `early-init` action, or
  could not expose/mount the cache block device.
- The first LOS 17.1 test exposed an early uevent race: waiting only for the
  bootdevice directory did not guarantee that its `by-name/cache` link already
  existed. The early action now waits for that exact link and mounts it through
  the platform path. The `on fs` fallback also stops and restarts the logcat
  collector after mounting cache, so a logger first opened against the ramdisk
  mountpoint cannot remain hidden behind the real cache filesystem.

## LineageOS 17.1 Init/Kernel Blocker

- The stock kernel does expose `/proc/last_kmsg` after an init panic. Recovery
  can therefore preserve the only useful evidence even though normal dmesg is
  disabled. Every failing Android 10 boot currently reaches the successful
  system mount and `Switching root to '/system'`, then panics at about 2.5
  seconds with `Attempted to kill init! exitcode=0x00000000`, before any
  second-stage init output or device rc action.
- The boot image, system image, root symlink, SELinux split/monolithic policy,
  `/vendor` symlink, and moved `/dev` mount were each checked independently.
  None explains the failure. The live `/system/bin/init` is the expected
  Android 10 binary using `/system/bin/bootstrap/linker64`.
- A minimal static ARM64 PID 1 that calls `exit(42)` works and produces kernel
  panic code `0x00002a00`. First-stage mount, switch-root, path lookup, exec,
  and static ARM64 execution are therefore all working.
- Minimal 32-bit and 64-bit dynamic binaries both run correctly as ordinary
  chroot processes when `/dev` is available, and both return 42 when launched
  through an explicit Android linker command. The Android 10 linker and both
  execution ABIs are usable after early init.
- The same dynamic binaries do not reach their entry points when used as PID
  1. Explicit linker trampolines fail in the same place. Static 64-bit and
  32-bit PID 1 supervisors were also tested; their dynamic init child exits
  immediately with status 0 before second-stage logging, even when linker64 is
  invoked explicitly. Replacing Android init with the minimal dynamic
  `exit(42)` payload does not change the result: that child also exits as 0
  before its entry point. The behavior is therefore tied to the vendor
  kernel's early-init process model, not Android init's PID checks and not
  merely a 64-bit ELF or `PT_INTERP` issue.
- This is related to the device's known Magisk quirk, where a 64-bit early
  `magiskinit` fails while a 32-bit implementation works, but it is not an
  exact duplicate: a 32-bit static supervisor still cannot hand Android 10
  init off to its dynamic child.
- Building the full Android 10 second-stage init statically from the device
  tree is not a small workaround. Core dependencies including `libbinder` and
  `libprocessgroup_setup` only provide shared variants in this branch. A real
  continuation therefore requires either reverse-engineering/patching the
  closed kernel's early-exec restrictions or a deliberate platform-level init
  architecture change. Further fstab, rc, linker-config, or sepolicy changes
  should not be treated as fixes for this specific 2.5-second panic.
- The next diagnostic build instruments
  `bionic/linker/linker_main.cpp::__linker_init_post_relocation()` immediately
  before the direct-linker/helper-mode check. For PID 1 it writes a
  `PD1619_LINKER` record containing `AT_BASE`, `AT_ENTRY`, `_start`, `AT_PHDR`,
  `AT_PHNUM`, `argc`, and the helper-mode result directly to `/dev/kmsg`.
  First-stage init has already created `/dev/kmsg` before it execs the dynamic
  `/system/bin/init`, whose interpreter is
  `/system/bin/bootstrap/linker64`; the record should therefore survive in
  `/proc/last_kmsg` after the init panic. If `helper=1` and `AT_ENTRY` equals
  `_start`, Android 10's linker is mistaking second-stage init for a direct
  linker invocation and taking its normal `exit(0)` help path.
- `tools/install-debug-linker64.sh` can install the diagnostic linker into an
  already-flashed LOS 17.1 system from recovery. It mounts system read-write,
  saves the original linker on the host, preserves the destination inode while
  replacing its contents, and verifies the resulting SHA-256 hash.

## Reconstructed-Kernel Audio Bring-Up

- The first audio baseline with the reconstructed kernel was captured on the
  Android 9 test system using the stock PD1619 DTB bundle. `audioserver` and
  `android.hardware.audio@2.0-service` were running, but
  `/proc/asound/cards` reported `--- no soundcards ---`. This is an ASoC card
  registration failure, not initially an Android audio-policy problem.
- The QDSP PCM platforms, `msm8x16_wcd_codec`, stub codec, and their DAIs were
  all present under debugfs. The unbound platform device was
  `c051000.sound`, whose live OF compatible is the standard
  `qcom,msm8952-audio-codec`; it matches the compiled
  `msm8952-asoc-wcd` machine driver.
- A manual sysfs bind exposed the actual probe failure:
  `is_us_eu_switch_gpio_support()` returned `-EINVAL`. The stock DTB provides
  `qcom,cdc-us-euro-gpios`, but does not provide the CAF gpioset entry named
  `us_eu_gpio` expected by the public driver. The driver now treats that
  mismatch as an optional-feature failure: it disables automatic US/EU
  headset wiring exchange instead of rejecting the entire sound card.
- The stock DTB also exposes Vivo-specific follow-up work that is deliberately
  separate from basic card registration: `vivo,hifi-codec-pd1619`, an
  `ess,es9018-2m` DAC at I2C address `0x48`, and custom dynamic QUIN MI2S links
  for Hi-Fi and the left/right speaker paths. Those features may still require
  reconstruction after ordinary speaker, microphone, call, and headset audio
  are tested with the base card registered.
- The base CAF QUIN MI2S callbacks are not compatible with this DT/ADSP pair.
  Explicitly enabling the LPASS clock there caused an ADSP SSR with
  `adsp_mi2s_count: clk_enable_cnt exception`. Vivo instead uses dynamic ASoC
  links and lets its codec path own the QUIN lifecycle. The PD1619 path now
  replaces the base QUIN codec with `vivo-snd-soc-dummy`, uses no-op machine
  callbacks, and appends the two DT-selected SmartPA links.
- The closest GPL source for the external amplifier is Vivo Y51 commit
  `3e31bae17d7365cf3f5576e17a912984287421a6` (`Initial for Y51`). PD1619 needs
  a stereo/multi-instance reconstruction on top: I2C `1-0036` is left and
  `1-0034` is right, both identify as TFA9897 revision `0x0b97`, and expose
  DAIs `SmartPA left` and `SmartPA right`. Per-device copies of the DAI, DAPM
  widgets, controls, and routes are required; sharing and mutating Y51's
  single-instance static objects caused the v9 splash-screen hang.
- Do not call `dev_set_name()` on the already-registered I2C clients to obtain
  friendly codec names. It changes `dev_name()` without renaming the sysfs
  kobject directory, so `request_firmware()` emits an impossible path such as
  `.../tfa98xx-left/firmware/...` while the real directory remains `1-0036`.
  Ueventd then cannot open the firmware `loading` node. Keep the native I2C
  names and bind the links to ASoC codec names `tfa98xx.1-0036` and
  `tfa98xx.1-0034`.
- `tfa98xx_PD1619.cnt` must be installed under `vendor/firmware`, not only
  `vendor/etc`, because the driver uses `request_firmware()`. The confirmed
  stock container is 7255 bytes, describes two devices and six profiles, and
  selects the expected `left` and `right` records for addresses `0x36` and
  `0x34` respectively.
- The v12 validation registers `msm8952-cdp-snd-card`, both TFA codecs, both
  SmartPA DAIs, and controls `VIVO_SmartPA_L_Playback` and
  `VIVO_SmartPA_R_Playback`. During framework playback both controls and DAPM
  switches turn on, but the amplifier remains silent because both unmute paths
  stop at `tfa98xx_dsp_power_on() not calibration`.
- Stock performs SmartPA calibration immediately after card registration. Its
  machine driver starts a standalone 48 kHz, 16-bit stereo QUIN AFE port,
  enables the 1.536 MHz LPASS IBIT clock and `quin_i2s` gpioset, waits 50 ms,
  invokes the codec calibration callback, then closes the port and clock. The
  stock TFA implementation keeps all clients on a list and calibrates in
  reverse probe order (right, then left), rather than using Y51's single
  global client.
- The reconstructed v13 path follows that sequence and obtains exactly the
  stock impedances: right `7.98 ohm`, then left `32.82 ohm`. Subsequent
  playback reaches `tfaRunSpeakerBoost(force=0)` for both amplifiers without
  `not calibration`, ADSP SSR, or the former clock-count exception.
- v13 still has no audible speaker output. During playback both TFA devices
  remain at status `0x001c`: `AMPS=0` and `AREFS|CLKS=0`. Power-up clears
  `PWDN` (`SYS_CTRL 0x0265 -> 0x0264`) but then times out waiting for a bit
  clock. This is a playback-time QUIN clock ownership failure, not another
  calibration or final-unmute failure.
- The stock machine driver exposes an enum control named exactly
  `Vivo MI2S Clock`. Its `put` callback calls the same standalone QUIN AFE,
  LPASS IBIT, and gpioset sequence used for calibration. Stock QUIN startup,
  prepare, and shutdown callbacks are no-ops; restoring the generic CAF
  startup is therefore incorrect. The reconstructed control is state-guarded
  and retained as a manual diagnostic/calibration interface. It is not part
  of the normal speaker mixer path because its standalone AFE port may race
  the DPCM backend.
- Stock QUIN `hw_params` is not a no-op. For the speaker path's `Master` mode
  it applies `SND_SOC_DAIFMT_CBS_CFS` to both the CPU and codec DAIs; this lets
  the normal Q6 backend own playback clocking without the CAF startup's extra
  clock operation. The reconstructed PD1619 ops now preserve the generic
  format mask and restore this DAI-format setup.
- v14 confirms that DAI format setup reaches both TFA devices but does not by
  itself expose a clock at the amplifier pins. Calibration suspends the
  `quin_i2s` gpioset when it finishes, while the former no-op playback startup
  never reactivates it. The PD1619 startup now programs the QUIN mux and
  activates only the `quin_i2s` gpioset; shutdown suspends it. It deliberately
  does not call `msm_mi2s_sclk_ctl()`, so Q6 retains sole LPASS clock ownership
  and the earlier ADSP clock-count SSR is not reintroduced.
- V15 proves that pinctrl alone is insufficient. Running the TFA debug clock
  command while the DPCM route is active changes the amplifier status from
  `0x001c` to `0xd05e`, reports `AMPS=1`, and restores audible output. The
  control's standalone `afe_port_start()` fails against the active DPCM port,
  but LPASS clock setup has already succeeded and its error path leaves the
  clock enabled. This explains why V14 appeared to recover after diagnostics.
- Until a safe on-demand clock reference scheme is reconstructed, calibration
  teardown closes only its standalone QUIN AFE port and deliberately leaves
  the already-enabled 1.536 MHz LPASS IBIT clock running. Playback continues
  to activate/suspend the `quin_i2s` pins. This costs some idle power but
  avoids both silent playback and repeated clock-enable operations that caused
  the earlier ADSP SSR.
- `tools/package-reconstructed-kernel.sh <label>` packages the current
  `out/pd1619-pstore/.../Image` with the stock DTB bundle and AIK's original
  ramdisk. It always uses `--original --origsize`, restores the prior AIK split
  kernel on exit, then unpacks the result and compares the kernel, ramdisk, and
  final image size. Use this instead of manually invoking `repackimg.sh`; a
  failed root-owned ramdisk repack previously produced a dangerous 20-byte
  ramdisk while still printing `Done`.
- Validate the clock control independently before rebuilding the ROM:
  `tinymix | grep 'Vivo MI2S Clock'`, set it with
  `tinymix 'Vivo MI2S Clock' 1`, then start speaker playback and confirm the
  TFA status reports `CLKS`/`AREFS` instead of timing out. Keep this separate
  from the normal mixer path unless testing proves that the DPCM backend and
  standalone AFE port can share the QUIN lifecycle safely.
- Avoid `dumpsys media.audio_flinger` on the Android 9 test build. Its closed
  32-bit `android.hardware.audio@2.0-impl.so` has a null debug callback and
  crashes audioserver in `Device::debug()`. Three observed audioserver crashes
  matched the diagnostic dump calls exactly and were not playback failures.
- Ghidra analysis of stock `PD1619-vmlinux.elf` resolves the actual Vivo QUIN
  lifecycle. The PD1619 variants of `msm_quin_mi2s_snd_startup`,
  `hw_params`, `prepare`, and `shutdown` only log and return; stock also makes
  `msm_quin_mi2s_clock_enable` and the `Vivo MI2S Clock` put callback no-ops.
  The active configuration is instead supplied by
  `msm_quin_be_hw_params_fixup`, which applies the separate
  `quin_mi2s_bit_format`, forces 48 kHz and the selected QUIN RX channel
  count, and lets the Q6 MI2S DAI build and start the AFE port. Stock exposes
  this state as `QUIN_MI2S Bit Format`. This documents the stock ownership
  model, but cannot be copied alone: the reconstructed SmartPA path retains a
  board-specific persistent QUIN clock that stock does not expose this way.
- The retained v4/v5 test images and Codex session log identify the first
  playback regression precisely. V4 selected 1.536 or 3.072 MHz from backend
  `hw_params` through the AVS-version-aware clock API and played S24 normally.
  V5 moved that update into the `MI2S_RX Format` mixer put callback; changing
  the clock during Audio HAL route teardown/startup caused the stream to stop
  advancing. A later experiment binding the stock QUIN fixup before the
  reconstructed clock update also made ADSP reject backend `hw_params` with
  `-EINVAL`. For the isolated A/B baseline, restore v4's generic fixup and
  perform the reconstructed board's required clock update from backend
  `hw_params` after applying `MI2S_RX Format`.
  Preserve both AVS 2.6 `afe_set_lpass_clock` and AVS 2.7
  `afe_set_lpass_clock_v2` paths. Do not update the clock from mixer put.
  Restore the 1.536 MHz S16 baseline from backend shutdown before suspending
  the QUIN pins; omitting that v4 step leaves the ADSP clock state stale after
  an `ON -> OFF -> ON` transition, and the next S24 backend setup fails with
  `afe_set_lpass_clock_v2() = -EINVAL`. MBHC protection handles the separate
  analog-switch jack bounce.
- A live v4 capture isolated that jack bounce from the physical connector.
  While GPIO 914 continuously reported the headset as inserted, switching
  Hi-Fi off and back on made the framework report headset states `1 -> 32`,
  then about 3.16 seconds later `32 -> 0 -> 2`. AudioPolicy consequently
  disconnected and reconnected the wired output several times. The existing
  MBHC guard only covered the interval where the ES9018 was active, so it
  expired before the delayed removal IRQ. Keep MBHC removal suppression active
  for five seconds after either analog path transition, but only ignore the
  electrical removal while the dedicated headset GPIO still reports inserted.
  This preserves real unplug detection while covering the measured comparator
  settling interval.

## Reconstructed-Kernel Remaining Work

- Confirmed working with the reconstructed kernel: display and backlight,
  touchscreen, vibrator, battery reporting, ordinary charging, USB, RIL,
  GNSS, sensors, WLAN, microphone input, Bluetooth audio, and the dual-TFA9897
  loudspeakers.
- The standalone CYTTSP controller at I2C `8-0028` now registers
  `vivo_virtual_key`; MENU and BACK work. Light-touch HOME remains part of the
  FPC1245 path rather than the CYTTSP controller.
- Fingerprint still needs the FPC1245 kernel ABI reconstructed around the
  active `spi3.0` device.
- Camera is wholly unavailable with the reconstructed kernel. Recover the
  PD1619 camera sensor, power, clock, ISP, and flash differences before
  treating any userspace camera issue as independently actionable.
- Hi-Fi remains separate from the working SmartPA speaker path. Restore the
  ES9018 and `vivo,hifi-codec-pd1619` integration after the ordinary audio
  routes are complete.
  - The first reconstructed ES9018 driver successfully detects chip ID `0x32`,
    enables the 1.8 V and 3.3 V rails, drives reset and MCLK high, selects the
    external path, and writes the stock register table. It still produced no
    audio because the reconstructed `msm8952.c` handled only the two SmartPA
    entries from `qcom,msm-dynamic-dai-links`; the stock DT Hi-Fi RX/TX entries
    were skipped as unsupported. Restore `VIVO_HiFi_Playback` and
    `VIVO_HiFi_Capture` links plus the `vivo-codec`/`VIVO-HiFi` ASoC DAI so the
    existing audio HAL can route playback to QUIN MI2S at S24_LE.
- The STM32L011 low-level fast-charge path is reconstructed and proven on
  hardware. The first persistent policy is implemented default-off and still
  requires staged validation of its automatic entry, monitoring, and fallback
  behavior before it can be exposed through DeviceParts.
  - PD1619 does not use the BQ25890 slave-charger path inherited by some Vivo
    trees. The stock DT and runtime identify an STM32L011 MCU at I2C `6-0050`
    (`st,stm32l011-mcu`) alongside the QPNP SMB charger and BQ27546 fuel gauge.
  - Its stock GPIOs are power GPIO115, interrupt GPIO107, USB-select GPIO66,
    and level-shift enable GPIO105. With the current TLMM base these appear as
    Linux GPIOs 994, 986, 945, and 984 respectively.
  - The existing DeviceParts fast-charge switch only writes
    `persist.sys.le_fast_chrg_enable`; stock `charger-monitor` consumed that
    property. It does not control the reconstructed kernel by itself.
  - The first reconstruction stage is intentionally diagnostic-only. It
    binds the MCU, resets and powers it with USB kept on the AP path, and
    exposes read-only firmware, IRQ, control, GPIO, and register state under
    `/sys/bus/i2c/devices/6-0050/`. It does not write the MCU control register
    or enable direct charging.
  - Hardware validation with the Vivo DCP adapter confirms the private
    protocol path works. A cold MCU reset reports IRQ A `0x80` (`INIT_DONE`),
    switching DP/DM to the MCU advances it to `0xc0` (`HANDSHAKE_SUCCESS`) and
    then `0xc2` (`POWER_MATCHED`). At a full battery it reports IRQ B `0x05`,
    including the high-battery/exit condition, and safely abandons direct
    charge. The adapter, cable, GPIO routing, MCU firmware, and handshake are
    therefore operational; the remaining work is AP-side policy and safety
    monitoring rather than hardware discovery.
  - At 38% and about 4.03 V, the MCU progresses from `0xc2` to IRQ A `0xca`
    (`VBAT_GOOD`) and then `0xda` (`PMI_SUSPEND`). The main charger current
    drops from about 1.6 A to zero, proving that the MCU requests the normal
    PMI path to yield, but direct-charge current does not take over without
    the AP monitor. Stock disassembly shows that monitor writes `1` to MCU
    watchdog register `0x07` every cycle while PMI is suspended. The bounded
    follow-up probe restores only that confirmed watchdog kick; it still does
    not write direct-charge control register `0x04`.
  - The 2 A control probe confirms register `0x21 = 4` and REG04 bit 2 are
    accepted, but that alone only stops normal charging: battery current falls
    from about 1.58 A to zero and resumes after the bounded probe exits. The
    MCU handshake, watchdog, and fallback remain healthy.
  - Full stock disassembly identifies the missing handoff after
    `PMI_SUSPEND`. The handler disables `battery`'s
    `POWER_SUPPLY_PROP_CHARGING_ENABLED`, waits one second, verifies
    `POWER_SUPPLY_PROP_CHARGE_TYPE == NONE`, and only then sets REG04 bit 0.
    The earlier decompilation ended at an indirect power-supply call and hid
    this continuation. The next bounded probe reconstructs that sequence and
    restores PMI charging on every exit path; it is not yet a production
    charging policy.
  - Hardware validation of that handoff succeeds. REG04 advances from `0x04`
    to `0x05`; while the QPNP battery supply reports
    `charging_enabled=0` and `charge_type=N/A`, BQ27546 current rises from a
    short transition discharge to 0.49 A, 1.03 A, 1.48 A, and finally about
    1.58 A. The STM32 direct-charge path is therefore physically conducting,
    not merely acknowledging commands. At timeout REG04 becomes `0x15`, USB
    returns to the AP, QPNP charging is re-enabled, and ordinary charging
    resumes around 1.5 A. Battery temperature changed only from 35.7 C to
    35.8 C during the bounded test.
  - This proves the reconstructed low-level sequence, but the current sysfs
    trigger remains a laboratory probe. A production implementation still
    needs continuous battery/connector thermal limits, voltage and SOC policy,
    screen/call derating, MCU exception handling, unplug handling, and a
    fail-closed watchdog before DeviceParts may enable it persistently.
  - Stock IRQ dispatch uses handlers for IRQ A bit 1 (`POWER_MATCHED`), bit 3
    (`VBAT_GOOD`), bit 4 (`PMI_SUSPEND`), bit 5 (`HANDSHAKE_FAIL`), bit 6
    (`HANDSHAKE_SUCCESS`), bit 7 (`INIT_DONE`), and IRQ B bit 0
    (`DCHG_EXIT`). IRQ B bit 2 is the polled high-voltage exit. The first
    persistent policy treats either B exit bit, any C/D event, or handshake
    failure as fail-closed.
  - Stock powers and resets the MCU on USB insertion, enables the level
    shifter after 10 ms, starts its first monitor after one second, and then
    monitors every two seconds. On unplug it cancels monitoring and powers the
    MCU down. The reconstructed persistent state machine follows that power
    lifecycle instead of leaving the diagnostic MCU continuously powered.
  - Stock CMS permits broader temperature/current ranges: its battery table
    uses full scale from 25.0 through 44.9 C and 50 percent from 45.0 through
    54.9 C; the display-on board-temperature table selects 4.5 A at or below
    35 C, 3 A at 36-37 C, 2.5 A at 38-44 C, and 2 A at 45 C or above. Stock
    STM32 monitoring exits after repeated battery-voltage disagreement around
    4.42/4.45 V or excessive battery current.
  - The initial persistent implementation is deliberately narrower. Entry
    requires a DCP, healthy/present battery, 5-74 percent SOC, 15.0-40.0 C,
    and at most 4.25 V. Runtime exits at 80 percent, outside 12.0-42.0 C, at
    4.35 V, after three low-current monitor cycles, after 30 minutes, or on
    any MCU/I2C/USB fault. Requested current is limited to 3 A below 35.0 C,
    2.5 A through 38.0 C, and 2 A above that. Policy runs every two seconds,
    watchdog every second, and imposes a 60-second retry cooldown.
  - Persistent mode is default-off and exposed separately as
    `fast_charge_enable` and `fast_charge_status`. The existing bounded
    `handshake_probe` remains available. This first build must validate
    automatic start, unplug, explicit disable, thermal/current adjustment,
    timeout, and reboot behavior before the policy is connected to
    DeviceParts or enabled by default.
  - The first persistent-policy hardware test passed automatic entry,
    explicit disable, unplug fallback, and automatic re-entry after reconnect.
    The MCU progressed through IRQ A `0x80`, `0xc0`, `0xc2`, `0xca`, and
    `0xda`; REG04 reached `0x05`, and a 2.5 A request produced a stable
    measured battery current around 2.15-2.20 A. Explicit disable and unplug
    both cleared the direct-charge state, powered down the MCU and level
    shifter, returned USB to the AP, and restored PMI charging around 1.6 A.
  - Runtime current adjustment is also confirmed: a 3 A request produced
    about 2.71 A at 34.8 C, then automatically changed to 2.5 A as battery
    temperature crossed 35 C, stabilizing near 2.27 A. Temperature remained
    around 35.4-35.7 C during these short tests.
  - The first policy used only battery temperature and briefly requested 3 A
    even though the available `case_therm` zone reported about 38 C. The next
    build includes that board-temperature source in entry, current selection,
    and runtime exit decisions. It also reports the battery as charging while
    the external direct-charge path is active; QPNP otherwise reports
    `Discharging` because its own charger is deliberately suspended during
    the handoff.
  - The board-temperature/status build is validated. At `case_therm` 40 C it
    selected 2 A immediately and delivered about 1.67 A; direct-charge state
    reported `Charging` through the battery power supply. At 4.253 V the
    policy refused to power the MCU or begin a handshake and reported
    `reason=voltage`, confirming the high-voltage entry guard.
  - The existing Vivo Features switch now controls the reconstructed
    `/sys/bus/i2c/devices/6-0050/fast_charge_enable` node through the persistent
    property/init bridge. A missing property defaults to disabled, and the
    boot receiver reapplies the saved state after startup. This replaces the
    obsolete LeEco `le_quick_charge_mode` node while retaining the existing
    property name for upgrade compatibility. The node is already labeled
    `sysfs_batteryinfo`; init receives write permission only for that device
    type so the property bridge also works under enforcing SELinux.
  - Stock-compatible policy v2 is based on the actual shipping DT rather than
    inferred limits. PD1619 sets `primary-fastchg-ma = 4000`; although the
    generic board-temperature table contains a 4500 mA tier and the MCU API
    accepts up to 4500 mA, the device limit wins in normal production policy.
  - The shipping screen-on primary table is: through 35 C, 4500 mA; 36-37 C,
    3000 mA; 38-44 C, 2500 mA; and 45 C or above, 2000 mA. The screen-off table
    is: through 36.0 C, 4500 mA; above 36.0 C, 3500 mA. Both are capped at the
    PD1619 4000 mA primary limit. Stock passes integer degrees to the screen-on
    table but 0.1 C units to the screen-off table; recovery dmesg and CMS call
    sites confirm this otherwise surprising unit difference.
  - The shipping `tc-data` direct-charge scale is 100 percent from 15.0 through
    44.9 C, 75 percent from 10.0 through 14.9 C, 50 percent from 45.0 through
    54.9 C, 30 percent from 0 through 9.9 C, and zero outside that range. The
    reconstructed policy keeps an extra no-entry guard below 10 C rather than
    attempting the stock sub-1.5-A corner case.
  - Stock STM monitoring checks approximately 4421/4451 mV and 4701 mA and
    requires four consecutive exceptional samples before exit. Policy v2 runs
    at the same one-second cadence, counts four samples at 4421 mV and 4701 mA,
    and retains 4451 mV as an immediate hard-voltage guard because only one of
    the two stock voltage sources is presently exposed through the rebuilt
    power-supply stack.
  - Policy v2 also registers an framebuffer notifier and changes between the
    shipping screen-on/off tables at runtime. Downward current changes are
    immediate; upward changes require three consecutive policy samples. The
    30-minute session timeout and fail-closed MCU/I2C/USB handling remain as
    reconstruction-specific safety additions.
  - Full connector NTC parity is not claimed yet. Stock DT defines USB
    connector 70 C and battery-board 65 C maxima, and the MCU exposes separate
    battery/PCB/USB/adapter ADC channels. Until the private NTC conversion table
    and every channel mapping are restored, policy v2 keeps a 60 C board hard
    exit and treats all MCU C/D exception events as immediate failures.
  - Hardware testing found that the target current must not be used for the
    initial MCU handshake. Starting directly at the screen-off 3500 mA tier
    reached IRQ `0xc2 05` and the MCU exited before enabling direct charge. The
    production sequence now always handshakes at 2500 mA and raises to the
    temperature-selected target only after the direct path is active and PMI
    charging is suspended.
  - The corrected sequence is validated at 51 percent SOC, 31.1 C battery
    temperature, and 35 C board temperature. It completed the 2500 mA
    handshake, enabled direct charging, then raised to the capped 4000 mA tier
    after three policy samples. Measured battery current briefly reached about
    3.61 A before the MCU/adapter settled near 2.2-2.3 A. Screen state tracking
    changed correctly in both directions, and explicit disable restored PMI
    charging around 1.72 A with the MCU power, USB-select, and level-shifter
    GPIOs all inactive.
  - Stock disassembly completes the MCU NTC register map. PCB connector uses
    `0x10/0x11`, battery connector `0x12/0x13`, adapter connector `0x18/0x19`,
    adapter temperature `0x1a/0x1b`, USB connector `0x3f/0x40`, and battery
    board temperature `0x41/0x42`. The USB and battery-board high bytes are
    masked to seven bits. Table1 handles both board connectors, table2 handles
    USB and battery-board temperature, and table4 handles the adapter pair.
    All three tables are reproducibly extracted from the shipping GPL image;
    known stock samples reproduce `1672 mV -> 42.0 C`, `1677 mV -> 41.0 C`,
    `1584 mV -> 38.0 C`, and `1660 mV -> 35.0 C`.
  - Runtime protection enforces the shipping 100 C PCB/battery-connector
    maxima; both physical channels are present on PD1619 and become mandatory
    after a three-second post-handoff settling period. Hardware testing shows
    the MCU's USB and battery-board ADC registers remain zero, matching the
    stock path where both private capability flags are clear and the driver
    substitutes 25 C. Their 70 C and 65 C limits are therefore applied only
    when those MCU channels report valid data; the reconstructed policy still
    retains the fuel-gauge battery and `case_therm` guards instead of using the
    stock constant. Adapter temperatures remain diagnostic because the
    shipping CMS DT does not define separate adapter thresholds.
  - The shipping `fbon-timer-limit = 2` is a CMS-cycle count, not two minutes.
    Stock logs show roughly ten-second monitor cycles and apply
    `fbon-batt-scale = 38` after the third completed cycle, about 30 seconds
    after an unblank event. While direct charging, the parallel
    `fbon-dchg-scale = 67` caps PD1619's 4000 mA request at 2680 mA, which the
    MCU's 500 mA register granularity represents as 2500 mA. The reconstructed
    policy applies that 2500 mA cap after 30 seconds of continuous screen-on
    time and returns through the existing delayed upward-current path when the
    display turns off.
- Stock DT identifies the missing lights as a KTD2026 at I2C `6-0030`, with
  child IDs 1/2/3 for `button-backlight`, `green`, and `red`. The reconstructed
  driver consumes those existing nodes and preserves the binary blink API used
  by the device light HAL. Button backlight, solid red/green output, boolean
  hardware blinking, and restoration of the green charging indication are all
  confirmed working on hardware.
- Wired-headset insertion is not detected and the 3.5 mm output is unusable.
  Microphone input and Bluetooth audio are working, which narrows this to the
  headset-detection and analog routing path rather than the entire audio card.
- Voice calls connect through the working RIL, but call audio is silent. The
  earpiece/voice PCM route remains distinct from the now-working media speaker
  path and needs its own validation.
- Reboot targets are wrong: requests for recovery and bootloader do not reach
  the requested mode. Reconstruct the Vivo reboot-reason/poweroff behavior.
- Suspend/Doze has not been characterized. Revisit the previously observed
  lock-related behavior and verify suspend entry, wake sources, and idle power
  before considering power management complete.

## Reconstructed-Kernel Headset Bring-Up

- With a 3.5 mm headset physically inserted, the ASoC `Headset Jack` input
  device reports switch bitmap `0x80`: `SW_JACK_PHYSICAL_INSERT` is set, but
  `SW_HEADPHONE_INSERT` and `SW_MICROPHONE_INSERT` are not. Android therefore
  receives no wired-device connection. The PMIC mechanical path works, while
  MBHC never completes electrical classification.
- The stock codec DT node provides an additional
  `qcom,headset-irq-gpio = GPIO35` and the `headset_gpio_irq` pinctrl state.
  The shipping symbol table contains `wcd_mbhc_gpio_plug_detect_irq`,
  `wcd_mbhc_swch_gpio_irq_handler`, and
  `wcd_mhbc_wait_gpio_irp_dwork`; none exists in public CAF.
- GPIO35 maps to Linux GPIO 914 with this kernel. A live read while the
  headset remained inserted returned a stable low level, confirming the
  stock/Y51 active-low convention. The GPIO was unrequested before the MBHC
  reconstruction.
- Stock disassembly confirms a threaded GPIO IRQ that queues delayed work,
  followed by repeated GPIO sampling before the normal WCD electrical
  classification. The closest GPL implementation is Vivo Y51's
  `BBK_HEADSET_GPIO` path, but the complete Y51 MBHC file cannot be copied over
  the newer CAF register/callback implementation safely.
- The scoped reconstruction keeps the existing CAF classification logic and
  adds only the Vivo mechanical source: select the stock pinctrl state,
  request the active-low GPIO with both-edge IRQ and wake support, debounce it
  in delayed work, then feed its stable state into the existing WCD MBHC
  insertion/removal handler. Devices without the DT property retain the CAF
  PMIC IRQ path.
- `msm_audrx_init()` also called `msm8x16_wcd_hs_detect()` twice after a
  successful first start. The headset patch returns the first result instead,
  matching the Vivo reference behavior and preventing duplicate external-IRQ
  activation.
- The first GPIO-IRQ build proves the mechanical reconstruction works: GPIO
  914 is owned by `headset-detect`, both edges generate IRQ 712, and the
  delayed worker reports stable insertion/removal. ASoC nevertheless reports
  insertion as `0x108`, which is `SND_JACK_UNSUPPORTED` plus
  `SND_JACK_MECHANICAL`, rather than a headphone/headset.
- That result identifies the next missing stock path. The MBHC classifier sees
  a GND/MIC cross-connection, but `swap_gnd_mic` was disabled because public
  CAF requires an `us_eu_gpio` gpioset that the PD1619 stock DT does not list.
  The DT does expose `qcom,cdc-us-euro-gpios = GPIO142`, and stock
  `msm8952_swap_gnd_mic()` reads that GPIO, toggles it, and lets MBHC continue
  polling. Static hot tests with GPIO142 forced low and high both remained
  unsupported; they do not reproduce the required in-classification state
  transition.
- The follow-up reconstruction requests GPIO142 directly as an output and
  installs `msm8952_swap_gnd_mic` without the CAF gpioset wrapper. This keeps
  the stock state-machine behavior while matching the actual PD1619 DT.
- The GPIO142 build proves the switch path itself works: GPIO1021 is owned by
  `us-euro-switch`, and classification dynamically toggles it from low to high.
  The resulting jack state is still `0x108`, so the remaining fault is in the
  public CAF classifier rather than GPIO, pinctrl, or Android audio policy.
- Stock `wcd_mbhc_detect_plug_type()` does not run the public CAF four-sample
  cross-connection check or pre-set `current_plug` to `GND_MIC_SWAP`. It only
  prepares micbias and schedules `correct_plug_swch`; that worker owns the
  swap, resampling, and final classification. The next test removes the early
  CAF preclassification so the state machine can evaluate the jack after the
  US/EU GPIO transition.
- Removing the early preclassification allows the jack to reach Android, but
  the result is unstable between `LINEOUT` (`0x0c0` including the physical
  bit) and `UNSUPPORTED` (`0x108`). ASoC register tracing proves the dedicated
  jack GPIO remains inserted and GPIO142 flips, while the public CAF Schmitt
  test continues to report a cross-connection afterward.
- The reconstructed stock `wcd_correct_swch_plug()` confirms Vivo replaced
  that final CAF decision with a private button/impedance classifier. Until
  its complete impedance extensions are reconstructed, the scoped fallback
  treats `HIGH_HPH` or `GND_MIC_SWAP` as a headset only when the dedicated
  Vivo jack GPIO is active and the US/EU switch was actually toggled. This
  does not alter the generic PMIC-only CAF path.
- A correctly reported wired headset initially remained silent even though
  AudioPolicy selected `AUDIO_DEVICE_OUT_WIRED_HEADSET`, PCM12 was running,
  and the complete Cajon DAPM path through both HPH DACs and PAs was powered.
  The missing board-level gate is `vivo,hifi-switch-sel-gpio = GPIO69` from
  the stock `vivo,hifi-codec-pd1619` node. Vivo places an analog selector
  between the internal Cajon codec, the external ES9018 path, and the physical
  3.5 mm jack.
- Stock `vivo_codec_parse_dt()` requests that GPIO and drives it high during
  probe. A live test on Linux GPIO948 reproduced the behavior exactly: low
  remained silent, while high immediately restored wired-headset audio with
  playback uninterrupted. The reconstructed minimal platform driver now owns
  the GPIO and selects the normal codec path at boot; it is also the correct
  ownership point for the eventual full Hi-Fi implementation.
- The first cold boot with that driver confirms GPIO948 is owned by
  `hifi-switch-sel` and remains output-high without userspace intervention.
  The inserted accessory reports `SW_HEADPHONE_INSERT` plus
  `SW_JACK_PHYSICAL_INSERT` (`0x84`), Android connects
  `AUDIO_DEVICE_OUT_WIRED_HEADPHONE`, and analog media playback is audible.
  Basic wired-headphone detection and playback are therefore complete.

## Reconstructed-Kernel Camera Bring-Up

- The Vivo camera sensor-init ABI uses 13 submodule slots. Restoring that
  layout allows all three sensors (`imx298_pd1617`, `imx376`, and `s5k3h7`)
  to probe and exposes their V4L2 subdevices; EEPROM/OTP reads also complete.
- The camera provider still aborted in
  `QCameraParameters::initDefaultParameters()` because the sensor module
  never completed its asynchronous initialization. Kernel logs identified
  the immediate failure as `msm_actuator_set_param: Actuator function table
  not found`, followed by actuator initialization returning `-EFAULT`.
- Ghidra analysis of the stock PD1619 kernel shows five actuator table
  entries, while public CAF only provides four. The extra entry has type
  value 4 and uses the normal VCM operations except that lens parking is
  disabled.
- Vivo's published X21 kernel names this ABI extension
  `ACTUATOR_MIDVCM`; its function table exactly matches the PD1619 stock
  binary. The reconstructed kernel now exposes that enum value and registers
  the matching MIDVCM table. This should allow the proprietary sensor module
  to finish initialization and populate preview/picture capabilities.
- Both PD1619 camera-flash nodes reference the same PMIC `switch_trigger`.
  Public CAF attempts to register that trigger twice; the second registration
  fails with `-EEXIST`, leaving the rear flash controller with a null switch
  pointer. The HAL can then program `torch_0` but cannot enable the shared
  flash block, so CameraService reports the torch as on while no rear light
  appears. Stock Ghidra analysis shows a `global_switch_trigger` fallback:
  the second controller reuses the trigger registered by the first. The
  reconstructed flash driver now restores that behavior.

## Reconstructed-Kernel Device Tree Baseline

- The verified kernel configuration now has a device-specific
  `arch/arm64/configs/lineage_pd1619_defconfig`. It was generated with
  `savedefconfig` from `out/pd1619-fastcharge-v1/.config`; regenerating a
  fresh `.config` and comparing it with the Python 2 `scripts/diffconfig`
  produced no semantic differences before the DTB name was added.
- `CONFIG_BUILD_ARM64_APPENDED_DTB_IMAGE_NAMES="pd1619"` makes the native
  `Image.gz-dtb` contain only the PD1619 tree even though the legacy Qualcomm
  `dtbs` target still builds the complete `CONFIG_ARCH_MSM8916` board list.
- The first source-controlled board tree is intentionally lossless:
  `pd1619.dts` includes `pd1619.dtsi`, which is the selected PD1619 entry from
  the stock multi-DTB bundle. The generated `pd1619.dtb` is 281325 bytes and
  has SHA-256
  `7ae6651d681e6e931a22b4c9dedd17c4990a1ea3a679cb7024e8acaf21901c3c`,
  exactly matching `reverse/stock-8.12.1/stock-pd1619.dtb`.
- Do not use the runtime `/proc/device-tree` dump as the packaged source. It
  contains bootloader fixups such as `/chosen`, initrd addresses, serial
  number, command line, aliases, and reordered nodes. The bootloader must
  continue applying those fixups to the source-built stock input tree.
- The legacy in-tree DTC needs `HOSTCFLAGS=-fcommon` with current host GCC.
  A verified standalone build command is:

  ```sh
  make O=out/pd1619-fastcharge-v1 ARCH=arm64 \
      lineage_pd1619_defconfig
  make -j12 O=out/pd1619-fastcharge-v1 ARCH=arm64 \
      HOSTCFLAGS=-fcommon \
      CROSS_COMPILE="$PWD/../../../prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/bin/aarch64-linux-android-" \
      CROSS_COMPILE_ARM32="$PWD/../../../prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9/bin/arm-linux-androideabi-" \
      Image.gz-dtb
  ```

- `tools/package-reconstructed-kernel.sh` accepts `KERNEL_DTB_IMAGE` so the
  native `Image.gz-dtb` can be packaged without appending the stock bundle.
  The first verified package is
  `/home/shion/AIK-Linux_MySelf/boot-PD1619-rr-CAF-pstore-v6-bq27546-pronto-module-dts-v1-single-pd1619-Magisk-v30.7.img`
  with SHA-256
  `85475e8d92886f9d8b45421f24b6981cf6ae28683e4ced8488e077f2d495034f`.
- Hardware validation passed: the device boots Android normally with the
  kernel-native `Image.gz-dtb` containing only the source-built
  `pd1619.dtb`. The complete stock multi-DTB bundle is no longer required.
  Split the flat tree incrementally into pinctrl, display, camera, audio,
  input, power, and PMIC includes, testing each group rather than replacing
  the whole tree with inherited CAF files at once.
- The structured follow-up now inherits only `msm8976-v1.1.dtsi`; it does not
  inherit `msm8976-mtp.dtsi`, because the latter adds reference-board NFC,
  Synaptics touch, camera keys, WSA881x audio, reference camera, and panel
  supply nodes that are not the PD1619 board design.
- The flat 12917-line board dump has been reduced to an aggregator plus eight
  focused board files: memory, pinctrl, display, camera, audio, input, power,
  and remaining board overrides. The board-specific source totals about 2350
  lines while the Qualcomm SoC description remains in the common DTSI.
- Structural validation against the stock selected DTB reports exactly 1237
  nodes and 9207 properties on both sides. All node paths, property presence,
  scalar/byte values, phandle presence, and decoded phandle targets match;
  semantic differences are zero. Binary hashes differ because the structured
  source allocates phandle numbers and string-table entries in a different
  order, which does not alter the resulting hardware description.
- The structured test package is
  `/home/shion/AIK-Linux_MySelf/boot-PD1619-rr-CAF-pstore-v6-bq27546-pronto-module-dts-v2-structured-pd1619-Magisk-v30.7.img`
  with SHA-256
  `1bfda1644b60ea444632ba21c6110d7f796a80c1fba26bd84f27b5b42b211e41`.
  It requires one final hardware boot and peripheral smoke test before this
  DTS restructuring is committed.

## Android 10 Legacy Linker Configuration

- The reconstructed kernel allows Android 10 `init`, APEX activation, and
  early userspace logging to run normally. This confirms that the previous
  PID 1 failure came from the stock kernel rather than fstab, SELinux, or the
  Android linker itself.
- The first useful Android 10 log is
  `/home/shion/AIK-Linux_17.1/initial.log`. Its repeated failures include
  `app_process`, `audioserver`, and `mediaserver` being unable to find
  `libnativeloader.so` or `libandroidicu.so` even though the Runtime APEX is
  mounted successfully.
- The device tree still installed its Android O-era
  `configs/ld.config.legacy.txt` through a post-install override. That file
  replaced Android 10's generated non-Treble linker configuration and removed
  the `runtime`, `conscrypt`, `media`, and `resolv` APEX namespaces.
- Android 10 must use the platform-provided
  `system/core/rootdir/etc/ld.config.legacy.txt`. Non-Treble describes the
  partition/runtime model; it does not make an old linker configuration valid
  across Android releases. Device-specific bare `dlopen()` compatibility must
  be handled at the affected blob or library path instead of replacing the
  global linker namespace configuration.
- After the linker fix, zygote no longer crashes but is not started because
  `ro.crypto.state` remains unset. Android 10 mounts the system partition as
  the read-only root, so legacy init-time `mkdir` commands for `/persist`,
  `/firmware`, and `/dsp` fail with `EROFS`. The fstab also tried to mount the
  unused stock `/apps` partition into another missing directory. `mount_all`
  then returns 255 and never publishes the crypto state used by the
  `zygote-start` triggers.
- Declare `/cache`, `/persist`, `/firmware`, and `/dsp` with
  `BOARD_ROOT_EXTRA_FOLDERS` so they are part of the system-as-root image.
  Drop the stock `/apps` and `/oem` mounts: they only contain Funtouch/Google
  preload packages and have no Lineage consumer. Do not replace this with a
  forced `ro.crypto.state`; the real fs_mgr result is also required for
  persist, modem/ADSP firmware, sensors, and other legacy services.

### 3.10.108 OSS Kernel Runtime Validation

- The reconstructed 3.10.108 kernel exposes the primary block controller at
  `/dev/block/platform/soc/7824900.sdhci`; the older PD1619 rc used
  `/dev/block/platform/soc.0/7824900.sdhci`. This caused `mount_all` to skip
  userdata and all legacy partitions before Android framework startup.
- The Android 10 boot image was hot-tested with the `soc` path, the generated
  linker configuration, and system-as-root root directories. `userdata`,
  `persist`, `firmware`, and `dsp` mounted successfully; `zygote64`,
  `zygote`, `system_server`, and boot animation completed normally, with
  `sys.boot_completed=1`.
- The successful test image was built from the existing boot image with
  `magiskboot`, preserving its kernel, DTB, and header while injecting the
  current `fstab.qcom`, `init.target.rc`, and USB rc. Remaining failures are
  peripheral HAL/blob issues, not early kernel, linker, or mount failures.
