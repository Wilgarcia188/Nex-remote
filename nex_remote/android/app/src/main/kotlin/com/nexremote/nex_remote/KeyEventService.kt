package com.nexremote.nex_remote

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.util.Log
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent

/**
 * AccessibilityService that receives hardware key events (remote control
 * buttons), forwards every keycode to Flutter for the debug screen, and
 * launches the mapped application when a configured button is pressed.
 */
class KeyEventService : AccessibilityService() {

    companion object {
        private const val TAG = "NexRemote"
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.d(TAG, "KeyEventService connected")
    }

    override fun onKeyEvent(event: KeyEvent): Boolean {
        val keyCode = event.keyCode
        val mappedPackage = MappingStore.getPackageFor(this, keyCode)

        if (event.action == KeyEvent.ACTION_DOWN) {
            Log.d(TAG, "Key event received: keyCode=$keyCode mappedTo=${mappedPackage ?: "none"}")
            KeyEventDispatcher.dispatch(keyCode)
            if (mappedPackage != null) {
                launchApp(mappedPackage)
                return true
            }
            return false
        }

        // Consume the matching ACTION_UP of a remapped button so the system
        // never sees half of the key press. Unmapped keys pass through.
        return mappedPackage != null
    }

    private fun launchApp(targetPackage: String) {
        val pm = packageManager
        val intent = pm.getLeanbackLaunchIntentForPackage(targetPackage)
            ?: pm.getLaunchIntentForPackage(targetPackage)
        if (intent == null) {
            Log.w(TAG, "No launch intent found for $targetPackage")
            return
        }
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
        try {
            startActivity(intent)
            Log.d(TAG, "Launched $targetPackage")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to launch $targetPackage", e)
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // Not used. This service only listens for hardware key events.
    }

    override fun onInterrupt() {
        // Not used.
    }
}
