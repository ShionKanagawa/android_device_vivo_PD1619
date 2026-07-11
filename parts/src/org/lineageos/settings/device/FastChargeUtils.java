/*
 * Copyright (C) 2026 The LineageOS Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 */
package org.lineageos.settings.device;

import android.os.SystemProperties;

import java.io.File;

final class FastChargeUtils {
    private static final String DEVICE_PD1619 = "PD1619";
    private static final String QUICK_CHARGE_NODE =
            "/sys/class/power_supply/battery/le_quick_charge_mode";
    private static final String PROP_FAST_CHARGE = "persist.sys.le_fast_chrg_enable";

    private FastChargeUtils() {
    }

    static boolean isSupported() {
        if (new File(QUICK_CHARGE_NODE).exists()) {
            return true;
        }

        final String device = SystemProperties.get("ro.product.device", "");
        final String buildProduct = SystemProperties.get("ro.build.product", "");
        if (DEVICE_PD1619.equals(device) || DEVICE_PD1619.equals(buildProduct)) {
            return true;
        }

        return !SystemProperties.get(PROP_FAST_CHARGE, "").isEmpty();
    }

    static boolean isEnabled() {
        return "1".equals(SystemProperties.get(PROP_FAST_CHARGE, "1"));
    }

    static void setEnabled(boolean enabled) {
        SystemProperties.set(PROP_FAST_CHARGE, enabled ? "1" : "0");
    }
}
