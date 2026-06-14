package com.nexremote.nex_remote

import android.content.ComponentName
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {

    companion object {
        private const val EVENT_CHANNEL  = "nex_remote/key_events"
        private const val METHOD_CHANNEL = "nex_remote/methods"
        private const val ICON_SIZE      = 96
        private const val EXPORT_FILE    = "nex_remote_mappings.json"
    }

    private val worker      = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)

        // ── Key event stream ──────────────────────────────────────────────
        EventChannel(engine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, sink: EventChannel.EventSink) {
                    KeyEventDispatcher.eventSink = sink
                }
                override fun onCancel(args: Any?) {
                    KeyEventDispatcher.eventSink = null
                }
            })

        // ── Method channel ────────────────────────────────────────────────
        MethodChannel(engine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    // ── Mappings ─────────────────────────────────────────
                    "getMappings" -> async(result) {
                        val pid = call.argument<String>("profileId")
                        val list = MappingStore.getMappings(this, pid)
                        val arr = JSONArray(); list.forEach { arr.put(it.toJson()) }
                        arr.toString()
                    }

                    "upsertMapping" -> async(result) {
                        val json = call.argument<String>("mapping")!!
                        val pid  = call.argument<String>("profileId")
                        MappingStore.upsertMapping(this,
                            MappingStore.MappingEntry.fromJson(JSONObject(json)), pid)
                        "ok"
                    }

                    "removeMapping" -> async(result) {
                        val id  = call.argument<String>("id")!!
                        val pid = call.argument<String>("profileId")
                        MappingStore.removeMapping(this, id, pid)
                        "ok"
                    }

                    "clearMappings" -> async(result) {
                        MappingStore.clearMappings(this, call.argument<String>("profileId"))
                        "ok"
                    }

                    // ── Profiles ──────────────────────────────────────────
                    "getProfiles" -> async(result) {
                        val arr = JSONArray()
                        MappingStore.getProfiles(this).forEach { p ->
                            arr.put(JSONObject().also { o -> o.put("id", p["id"]); o.put("name", p["name"]) })
                        }
                        arr.toString()
                    }

                    "getCurrentProfile" -> result.success(
                        MappingStore.getCurrentProfileId(this)
                    )

                    "switchProfile" -> async(result) {
                        MappingStore.switchProfile(this, call.argument<String>("id")!!)
                        "ok"
                    }

                    "createProfile" -> async(result) {
                        MappingStore.createProfile(this, call.argument<String>("name")!!)
                    }

                    "deleteProfile" -> async(result) {
                        MappingStore.deleteProfile(this, call.argument<String>("id")!!)
                        "ok"
                    }

                    // ── Apps ──────────────────────────────────────────────
                    "getInstalledApps" -> async(result) { getInstalledAppsJson() }

                    "getAppDetails" -> async(result) {
                        getAppDetailsJson(call.argument<List<String>>("packages") ?: emptyList())
                    }

                    // ── Export / Import ───────────────────────────────────
                    "exportMappings" -> async(result) {
                        val json = MappingStore.exportAll(this)
                        val file = exportFile(); file.writeText(json)
                        JSONObject().also { o -> o.put("path", file.absolutePath); o.put("json", json) }.toString()
                    }

                    "importMappings" -> async(result) {
                        val file = exportFile()
                        check(file.exists()) { "Backup file not found: ${file.absolutePath}" }
                        MappingStore.importAll(this, file.readText()).toString()
                    }

                    // ── Accessibility ─────────────────────────────────────
                    "isAccessibilityEnabled" -> result.success(isA11yEnabled())

                    "openAccessibilitySettings" -> {
                        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                        result.success("ok")
                    }

                    else -> result.notImplemented()
                }
            }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private fun <T> async(result: MethodChannel.Result, block: android.content.Context.() -> T) {
        worker.submit {
            try {
                val v = applicationContext.block()
                mainHandler.post { result.success(v) }
            } catch (e: Exception) {
                mainHandler.post { result.error("NATIVE_ERROR", e.message, null) }
            }
        }
    }

    private fun getInstalledAppsJson(): String {
        val pm = packageManager
        val seen = LinkedHashSet<String>()
        val apps = mutableListOf<JSONObject>()
        for (cat in listOf(Intent.CATEGORY_LEANBACK_LAUNCHER, Intent.CATEGORY_LAUNCHER)) {
            val intent = Intent(Intent.ACTION_MAIN).addCategory(cat)
            for (ri in pm.queryIntentActivities(intent, 0)) {
                val pkg = ri.activityInfo.packageName
                if (pkg == packageName || !seen.add(pkg)) continue
                apps.add(JSONObject().also { o ->
                    o.put("name", ri.loadLabel(pm).toString())
                    o.put("packageName", pkg)
                    o.put("icon", drawableToPng(ri.loadIcon(pm)))
                })
            }
        }
        apps.sortBy { it.getString("name").lowercase() }
        val arr = JSONArray(); apps.forEach { arr.put(it) }
        return arr.toString()
    }

    private fun getAppDetailsJson(packages: List<String>): String {
        val pm = packageManager
        val arr = JSONArray()
        packages.forEach { pkg ->
            val o = JSONObject()
            o.put("packageName", pkg)
            try {
                val ai = pm.getApplicationInfo(pkg, 0)
                o.put("name", pm.getApplicationLabel(ai).toString())
                o.put("icon", drawableToPng(pm.getApplicationIcon(ai)))
            } catch (_: Exception) {
                o.put("name", pkg); o.put("icon", JSONObject.NULL)
            }
            arr.put(o)
        }
        return arr.toString()
    }

    private fun drawableToPng(drawable: Drawable?): ByteArray? {
        if (drawable == null) return null
        val bmp = if (drawable is BitmapDrawable && drawable.bitmap != null) {
            Bitmap.createScaledBitmap(drawable.bitmap, ICON_SIZE, ICON_SIZE, true)
        } else {
            Bitmap.createBitmap(ICON_SIZE, ICON_SIZE, Bitmap.Config.ARGB_8888).also { bmp ->
                drawable.setBounds(0, 0, ICON_SIZE, ICON_SIZE); drawable.draw(Canvas(bmp))
            }
        }
        val out = ByteArrayOutputStream()
        bmp.compress(Bitmap.CompressFormat.PNG, 100, out)
        if (bmp !== (drawable as? BitmapDrawable)?.bitmap) bmp.recycle()
        return out.toByteArray()
    }

    private fun exportFile(): File = File(getExternalFilesDir(null) ?: filesDir, EXPORT_FILE)

    private fun isA11yEnabled(): Boolean {
        val expected = ComponentName(this, KeyEventService::class.java)
        val enabled  = Settings.Secure.getString(
            contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES) ?: return false
        return enabled.split(':').any { ComponentName.unflattenFromString(it) == expected }
    }
}
