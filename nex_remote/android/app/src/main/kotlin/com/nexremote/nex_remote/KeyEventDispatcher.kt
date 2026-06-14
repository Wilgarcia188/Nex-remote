package com.nexremote.nex_remote

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/**
 * Bridges keycodes from [KeyEventService] to the Flutter EventChannel.
 *
 * The AccessibilityService and the Flutter activity run in the same process,
 * so a shared sink is enough. EventSink must be called on the main thread.
 */
object KeyEventDispatcher {

    @Volatile
    var eventSink: EventChannel.EventSink? = null

    private val mainHandler = Handler(Looper.getMainLooper())

    fun dispatch(keyCode: Int) {
        mainHandler.post {
            eventSink?.success(keyCode)
        }
    }
}
