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
  was only extremely dim; manually setting
  `/sys/class/leds/lcd-backlight/brightness=255`,
  `/sys/class/leds/lm3697-backlight/brightness=255`, and
  `/sys/class/leds/wled/brightness=4095` made the panel bright. PD1619 now
  fans out Android lights HAL backlight writes to `lcd-backlight`,
  `lm3697-backlight`, and scaled `wled`, and init grants system write access to
  the extra nodes. Recovery was also still pointing at the old dim path, so
  `TARGET_RECOVERY_BACKLIGHT_PATH` is now `/sys/class/leds/wled`.
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
  current `proprietary-files.txt` has 949 real entries.
