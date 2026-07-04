# PD1619 Prebuilt Kernel

PD1619 uses the stock closed-source kernel, with small binary patches applied
for bring-up.

Current artifact:

- `kernel`: based on
  `/home/shion/boot_dumped_PD1619/split_img/boot.img-kernel`, with the gzip
  Image payload replaced by the locally patched raw Image from
  `/home/shion/Desktop/kernel`.
- The original appended DTB/FDT tail is retained byte-for-byte.
- Current artifact sha256:
  `f704e6d8d5560211bfccb40ab24dc027c96a854c3eb5399e41569150d2755833`.

`BoardConfig.mk` points `TARGET_PREBUILT_KERNEL` at this file and uses the
matching stock split_img boot parameters with SELinux permissive added for
early bring-up.
