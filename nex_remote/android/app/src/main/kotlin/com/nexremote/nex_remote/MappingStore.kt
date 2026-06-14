package com.nexremote.nex_remote

import android.content.Context
import android.content.SharedPreferences

/**
 * Persists keycode → package mappings in SharedPreferences so they survive
 * app restarts and device reboots. Shared by the AccessibilityService and
 * the Flutter MethodChannel.
 */
object MappingStore {

    private const val PREFS_NAME = "nex_remote_mappings"
    private const val KEY_PREFIX = "keycode_"

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun getMappings(context: Context): Map<Int, String> {
        val result = mutableMapOf<Int, String>()
        for ((key, value) in prefs(context).all) {
            if (!key.startsWith(KEY_PREFIX)) continue
            val keycode = key.removePrefix(KEY_PREFIX).toIntOrNull() ?: continue
            val packageName = value as? String ?: continue
            result[keycode] = packageName
        }
        return result
    }

    fun getPackageFor(context: Context, keyCode: Int): String? =
        prefs(context).getString(KEY_PREFIX + keyCode, null)

    fun setMapping(context: Context, keyCode: Int, packageName: String) {
        prefs(context).edit().putString(KEY_PREFIX + keyCode, packageName).apply()
    }

    fun removeMapping(context: Context, keyCode: Int) {
        prefs(context).edit().remove(KEY_PREFIX + keyCode).apply()
    }

    fun clear(context: Context) {
        prefs(context).edit().clear().apply()
    }
}
