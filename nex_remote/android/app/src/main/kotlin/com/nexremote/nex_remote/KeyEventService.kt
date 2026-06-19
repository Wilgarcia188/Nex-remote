package com.nexremote.nex_remote

import android.accessibilityservice.AccessibilityService
import android.util.Log
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent

/**
 * AccessibilityService that intercepts hardware key events and dispatches
 * mapped actions via ActionExecutor. TimingEngine handles single/double/long/hold
 * detection. Every ACTION_DOWN is forwarded to Flutter for the capture UI.
 */
class KeyEventService : AccessibilityService() {

    private val tag = "NexRemote.Service"

    private lateinit var executor: ActionExecutor
    private lateinit var timing: TimingEngine
    private val stateListener = { updateOverlay() }

    override fun onServiceConnected() {
        Log.d(tag, "Service connected")
        executor = ActionExecutor(this)
        timing = TimingEngine { keycode, eventType ->
            dispatchMappedEvent(keycode, eventType)
        }
        NexRemoteState.addListener(stateListener)
    }

    override fun onKeyEvent(event: KeyEvent): Boolean {
        val kc = event.keyCode

        // Always forward ACTION_DOWN to Flutter for debug / capture screens
        if (event.action == KeyEvent.ACTION_DOWN) {
            KeyEventDispatcher.dispatch(kc)
        }

        // Capture mode: consume the event so it has no side-effects (no Back
        // navigation, no Home screen), but skip mapping execution entirely.
        if (NexRemoteState.isCaptureMode) return true

        val entries = MappingStore.getMappingsForKey(this, kc)
        return timing.process(event, entries.isNotEmpty())
    }

    private fun dispatchMappedEvent(keycode: Int, eventType: String) {
        if (NexRemoteState.isCaptureMode) return
        val entries = MappingStore.getMappingsForKey(this, keycode)
        val entry = entries.firstOrNull { it.eventType == eventType } ?: return
        Log.d(tag, "Executing $eventType for keycode=$keycode action=${entry.action.optString("type")}")
        executor.execute(entry.action)
    }

    private fun updateOverlay() {
        // No overlay shown by default; OverlayManager can be wired here if needed.
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) = Unit
    override fun onInterrupt() = Unit

    override fun onDestroy() {
        super.onDestroy()
        NexRemoteState.removeListener(stateListener)
    }
}
