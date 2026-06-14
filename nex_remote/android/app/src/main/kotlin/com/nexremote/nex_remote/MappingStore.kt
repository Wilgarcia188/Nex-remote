package com.nexremote.nex_remote

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

/**
 * Persistent storage for button mappings and profiles.
 * Each profile has its own SharedPreferences file.
 * All operations are synchronous and safe to call from a background thread.
 */
object MappingStore {

    private const val META_PREFS = "nex_remote_meta"
    private const val KEY_CURRENT_PROFILE = "current_profile"
    private const val KEY_PROFILES = "profiles_v2"
    const val DEFAULT_PROFILE_ID = "default"
    const val DEFAULT_PROFILE_NAME = "Default"

    // ── Profile management ──────────────────────────────────────────────────

    fun getProfiles(context: Context): List<Map<String, String>> {
        val raw = meta(context).getString(KEY_PROFILES, null)
        if (raw == null) {
            val defaults = listOf(mapOf("id" to DEFAULT_PROFILE_ID, "name" to DEFAULT_PROFILE_NAME))
            persistProfiles(context, defaults)
            return defaults
        }
        return parseProfileList(raw)
    }

    fun getCurrentProfileId(context: Context): String =
        meta(context).getString(KEY_CURRENT_PROFILE, DEFAULT_PROFILE_ID) ?: DEFAULT_PROFILE_ID

    fun switchProfile(context: Context, profileId: String) {
        meta(context).edit().putString(KEY_CURRENT_PROFILE, profileId).apply()
    }

    fun createProfile(context: Context, name: String): String {
        val id = UUID.randomUUID().toString()
        val list = getProfiles(context).toMutableList()
        list.add(mapOf("id" to id, "name" to name))
        persistProfiles(context, list)
        return id
    }

    fun deleteProfile(context: Context, profileId: String) {
        if (profileId == DEFAULT_PROFILE_ID) return
        persistProfiles(context, getProfiles(context).filter { it["id"] != profileId })
        profilePrefs(context, profileId).edit().clear().apply()
        if (getCurrentProfileId(context) == profileId) switchProfile(context, DEFAULT_PROFILE_ID)
    }

    // ── Mapping CRUD ────────────────────────────────────────────────────────

    fun getMappings(context: Context, profileId: String? = null): List<MappingEntry> =
        parseMappings(profilePrefs(context, profileId ?: getCurrentProfileId(context))
            .getString("mappings", "[]") ?: "[]")

    fun upsertMapping(context: Context, entry: MappingEntry, profileId: String? = null) {
        val pid = profileId ?: getCurrentProfileId(context)
        val actual = if (entry.id.isEmpty()) entry.copy(id = UUID.randomUUID().toString()) else entry
        val list = getMappings(context, pid).toMutableList()
        val idx = list.indexOfFirst { it.id == actual.id }
        if (idx >= 0) list[idx] = actual else list.add(actual)
        persistMappings(context, pid, list)
    }

    fun removeMapping(context: Context, id: String, profileId: String? = null) {
        val pid = profileId ?: getCurrentProfileId(context)
        persistMappings(context, pid, getMappings(context, pid).filter { it.id != id })
    }

    fun clearMappings(context: Context, profileId: String? = null) {
        persistMappings(context, profileId ?: getCurrentProfileId(context), emptyList())
    }

    /** Used by KeyEventService — returns all entries for a keycode in the active profile. */
    fun getMappingsForKey(context: Context, keycode: Int): List<MappingEntry> =
        getMappings(context).filter { it.keycode == keycode }

    // ── Import / Export ─────────────────────────────────────────────────────

    fun exportAll(context: Context): String {
        val root = JSONObject()
        root.put("version", 2)
        root.put("currentProfile", getCurrentProfileId(context))
        val profArr = JSONArray()
        getProfiles(context).forEach { p ->
            val po = JSONObject()
            po.put("id", p["id"])
            po.put("name", p["name"])
            val ma = JSONArray()
            getMappings(context, p["id"]).forEach { ma.put(it.toJson()) }
            po.put("mappings", ma)
            profArr.put(po)
        }
        root.put("profiles", profArr)
        return root.toString(2)
    }

    fun importAll(context: Context, json: String): Int {
        val root = JSONObject(json)
        var count = 0
        if (root.optInt("version", 1) >= 2) {
            val profArr = root.getJSONArray("profiles")
            for (i in 0 until profArr.length()) {
                val po = profArr.getJSONObject(i)
                val pid = po.getString("id")
                if (getProfiles(context).none { it["id"] == pid }) {
                    val list = getProfiles(context).toMutableList()
                    list.add(mapOf("id" to pid, "name" to po.getString("name")))
                    persistProfiles(context, list)
                }
                clearMappings(context, pid)
                val ma = po.getJSONArray("mappings")
                for (j in 0 until ma.length()) {
                    upsertMapping(context, MappingEntry.fromJson(ma.getJSONObject(j)), pid)
                    count++
                }
            }
        }
        return count
    }

    // ── Helpers ─────────────────────────────────────────────────────────────

    private fun meta(context: Context) =
        context.getSharedPreferences(META_PREFS, Context.MODE_PRIVATE)

    private fun profilePrefs(context: Context, profileId: String) =
        context.getSharedPreferences("nex_profile_$profileId", Context.MODE_PRIVATE)

    private fun persistProfiles(context: Context, list: List<Map<String, String>>) {
        val arr = JSONArray()
        list.forEach { p -> arr.put(JSONObject().also { o -> o.put("id", p["id"]); o.put("name", p["name"]) }) }
        meta(context).edit().putString(KEY_PROFILES, arr.toString()).apply()
    }

    private fun persistMappings(context: Context, profileId: String, list: List<MappingEntry>) {
        val arr = JSONArray()
        list.forEach { arr.put(it.toJson()) }
        profilePrefs(context, profileId).edit().putString("mappings", arr.toString()).apply()
    }

    private fun parseProfileList(raw: String): List<Map<String, String>> {
        val arr = JSONArray(raw)
        return (0 until arr.length()).map { i ->
            val o = arr.getJSONObject(i); mapOf("id" to o.getString("id"), "name" to o.getString("name"))
        }
    }

    private fun parseMappings(raw: String): List<MappingEntry> {
        val arr = JSONArray(raw)
        return (0 until arr.length()).mapNotNull { i ->
            runCatching { MappingEntry.fromJson(arr.getJSONObject(i)) }.getOrNull()
        }
    }

    // ── Data model ───────────────────────────────────────────────────────────

    data class MappingEntry(
        val id: String,
        val keycode: Int,
        val eventType: String,  // single | double | long | hold
        val action: JSONObject
    ) {
        fun toJson(): JSONObject = JSONObject().also {
            it.put("id", id); it.put("keycode", keycode)
            it.put("eventType", eventType); it.put("action", action)
        }

        companion object {
            fun fromJson(o: JSONObject) = MappingEntry(
                id = o.optString("id").ifEmpty { UUID.randomUUID().toString() },
                keycode = o.getInt("keycode"),
                eventType = o.optString("eventType", "single"),
                action = o.getJSONObject("action")
            )
        }
    }
}
