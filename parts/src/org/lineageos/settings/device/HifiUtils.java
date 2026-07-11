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

import android.content.Context;
import android.media.AudioManager;
import android.os.SystemProperties;
import android.provider.Settings;
import android.util.Log;

final class HifiUtils {
    static final String SETTING_HIFI_ENABLED = "pd1619_hifi_enabled";

    private static final String TAG = "PD1619Parts";

    private HifiUtils() {
    }

    static boolean isEnabled(Context context) {
        return Settings.Secure.getInt(context.getContentResolver(),
                SETTING_HIFI_ENABLED, 0) != 0;
    }

    static void setEnabled(Context context, boolean enabled) {
        Settings.Secure.putInt(context.getContentResolver(), SETTING_HIFI_ENABLED, enabled ? 1 : 0);
        applyMode(context, enabled);

        if (!enabled) {
            restartAudioServer();
        }
    }

    static void applySavedState(Context context) {
        applyMode(context, isEnabled(context));
    }

    static void applyMode(Context context, boolean enabled) {
        final AudioManager audioManager =
                (AudioManager) context.getSystemService(Context.AUDIO_SERVICE);
        if (audioManager == null) {
            Log.w(TAG, "AudioManager unavailable");
            return;
        }

        if (enabled) {
            audioManager.setParameters("enable_hifi=1");
            audioManager.setParameters("force_enable_hifi=1");
        } else {
            audioManager.setParameters("force_enable_hifi=0");
            audioManager.setParameters("enable_hifi=0");
        }
        Log.i(TAG, "Applied Hi-Fi DAC state: " + enabled);
    }

    private static void restartAudioServer() {
        try {
            SystemProperties.set("ctl.restart", "audioserver");
            Log.i(TAG, "Restarted audioserver after disabling Hi-Fi DAC");
        } catch (RuntimeException e) {
            Log.w(TAG, "Unable to restart audioserver", e);
        }
    }
}
