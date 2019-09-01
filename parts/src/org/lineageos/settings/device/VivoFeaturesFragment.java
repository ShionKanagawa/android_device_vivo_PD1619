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

import android.os.Bundle;
import androidx.preference.PreferenceFragment;
import androidx.preference.SwitchPreference;
import androidx.preference.Preference;
import androidx.preference.PreferenceScreen;

public class VivoFeaturesFragment extends PreferenceFragment
        implements Preference.OnPreferenceChangeListener {
    private static final String KEY_FAST_CHARGE = "fast_charge";
    private static final String KEY_HIFI_DAC = "hifi_dac";

    private SwitchPreference mFastChargePreference;
    private SwitchPreference mHifiPreference;

    @Override
    public void onActivityCreated(Bundle savedInstanceState) {
        super.onActivityCreated(savedInstanceState);
        if (getActivity().getActionBar() != null) {
            getActivity().getActionBar().setDisplayHomeAsUpEnabled(true);
        }
    }

    @Override
    public void onCreatePreferences(Bundle savedInstanceState, String rootKey) {
        addPreferencesFromResource(R.xml.vivo_features);

        final PreferenceScreen screen = getPreferenceScreen();

        mHifiPreference = (SwitchPreference) findPreference(KEY_HIFI_DAC);
        mHifiPreference.setChecked(HifiUtils.isEnabled(getActivity()));
        mHifiPreference.setOnPreferenceChangeListener(this);

        mFastChargePreference = (SwitchPreference) findPreference(KEY_FAST_CHARGE);
        if (FastChargeUtils.isSupported()) {
            mFastChargePreference.setChecked(FastChargeUtils.isEnabled());
            mFastChargePreference.setOnPreferenceChangeListener(this);
        } else {
            screen.removePreference(mFastChargePreference);
        }
    }

    @Override
    public void onResume() {
        super.onResume();
        getListView().setPadding(0, 0, 0, 0);
    }

    @Override
    public boolean onPreferenceChange(Preference preference, Object newValue) {
        final boolean enabled = (Boolean) newValue;
        final String key = preference.getKey();

        if (KEY_HIFI_DAC.equals(key)) {
            HifiUtils.setEnabled(getActivity(), enabled);
            return true;
        }

        if (KEY_FAST_CHARGE.equals(key)) {
            FastChargeUtils.setEnabled(enabled);
            return true;
        }

        return false;
    }
}
