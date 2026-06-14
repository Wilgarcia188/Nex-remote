package com.nexremote.nex_remote

import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {

    companion object {
        private const val KEY_EVENT_CHANNEL = "nex_remote/key_events"
        private const val METHOD_CHANNEL = "nex_remote/methods"
        private const val EXPORT_FILE_NAME = "nex_remote_mappings.json"
        private const val ICON_SIZE = 96
    }

    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, KEY_EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    KeyEventDispatcher.eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    KeyEventDispatcher.eventSink = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result -> handleMethodCall(call, result) }
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getInstalledApps" -> runAsync(result) { getInstalledApps() }

            "getMappings" -> result.success(mappingsWithStringKeys())

            "setMapping" -> {
                val keycode = call.argument<Int>("keycode")
                val packageName = call.argument<String>("packageName")
                if (keycode == null || packageName.isNullOrEmpty()) {
                    result.error("BAD_ARGS", "keycode and packageName are required", null)
                } else {
                    MappingStore.setMapping(this, keycode, packageName)
                    result.success(null)
                }
            }

            "removeMapping" -> {
                val keycode = call.argument<Int>("keycode")
                if (keycode == null) {
                    result.error("BAD_ARGS", "keycode is required", null)
                } else {
                    MappingStore.removeMapping(this, keycode)
                    result.success(null)
                }
            }

            "clearMappings" -> {
                MappingStore.clear(this)
                result.success(null)
            }

            "getAppDetails" -> {
                val packages = call.argument<List<String>>("packages") ?: emptyList()
                runAsync(result) { getAppDetails(packages) }
            }

            "exportMappings" -> runAsync(result) { exportMappings() }

            "importMappings" -> runAsync(result) { importMappings() }

            "isAccessibilityServiceEnabled" -> result.success(isAccessibilityServiceEnabled())

            "openAccessibilitySettings" -> {
                startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    /** Runs [block] off the main thread and replies on the main thread. */
    private fun <T> runAsync(result: MethodChannel.Result, block: () -> T) {
        executor.execute {
            try {
                val value = block()
                mainHandler.post { result.success(value) }
            } catch (e: Exception) {
                mainHandler.post { result.error("NATIVE_ERROR", e.message, null) }
            }
        }
    }

    private fun mappingsWithStringKeys(): Map<String, String> =
        MappingStore.getMappings(this).mapKeys { it.key.toString() }

    /**
     * Returns every launchable app on the device (Leanback first, then
     * regular launcher activities) with name, package and PNG icon bytes.
     */
    private fun getInstalledApps(): List<Map<String, Any?>> {
        val pm = packageManager
        val seen = LinkedHashMap<String, Map<String, Any?>>()
        val categories = listOf(Intent.CATEGORY_LEANBACK_LAUNCHER, Intent.CATEGORY_LAUNCHER)
        for (category in categories) {
            val intent = Intent(Intent.ACTION_MAIN).addCategory(category)
            for (info in pm.queryIntentActivities(intent, 0)) {
                val pkg = info.activityInfo.packageName
                if (pkg == packageName || seen.containsKey(pkg)) continue
                seen[pkg] = mapOf(
                    "name" to info.loadLabel(pm).toString(),
                    "packageName" to pkg,
                    "icon" to drawableToPngBytes(info.loadIcon(pm)),
                )
            }
        }
        return seen.values.sortedBy { (it["name"] as String).lowercase() }
    }

    /** Resolves name and icon for specific packages (e.g. current mappings). */
    private fun getAppDetails(packages: List<String>): Map<String, Map<String, Any?>> {
        val pm = packageManager
        val result = mutableMapOf<String, Map<String, Any?>>()
        for (pkg in packages) {
            try {
                val appInfo = pm.getApplicationInfo(pkg, 0)
                result[pkg] = mapOf(
                    "name" to pm.getApplicationLabel(appInfo).toString(),
                    "packageName" to pkg,
                    "icon" to drawableToPngBytes(pm.getApplicationIcon(appInfo)),
                )
            } catch (e: PackageManager.NameNotFoundException) {
                // App was uninstalled; let Flutter fall back to the package name.
            }
        }
        return result
    }

    private fun drawableToPngBytes(drawable: Drawable): ByteArray {
        val bitmap = Bitmap.createBitmap(ICON_SIZE, ICON_SIZE, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, ICON_SIZE, ICON_SIZE)
        drawable.draw(canvas)
        val out = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
        bitmap.recycle()
        return out.toByteArray()
    }

    private fun exportFile(): File = File(getExternalFilesDir(null), EXPORT_FILE_NAME)

    private fun exportMappings(): Map<String, String> {
        val json = JSONObject()
        for ((keycode, pkg) in MappingStore.getMappings(this)) {
            json.put(keycode.toString(), pkg)
        }
        val pretty = json.toString(2)
        val file = exportFile()
        file.writeText(pretty)
        return mapOf("path" to file.absolutePath, "json" to pretty)
    }

    private fun importMappings(): Map<String, String> {
        val file = exportFile()
        check(file.exists()) { "No mappings file found at ${file.absolutePath}" }
        val json = JSONObject(file.readText())
        val imported = mutableMapOf<String, String>()
        for (key in json.keys()) {
            val keycode = key.toIntOrNull() ?: continue
            val pkg = json.optString(key)
            if (pkg.isNotEmpty()) {
                MappingStore.setMapping(this, keycode, pkg)
                imported[key] = pkg
            }
        }
        return imported
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val expected = ComponentName(this, KeyEventService::class.java)
        val enabled = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
        ) ?: return false
        return enabled.split(':').any { ComponentName.unflattenFromString(it) == expected }
    }
}
