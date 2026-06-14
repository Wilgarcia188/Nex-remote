package com.nexremote.nex_remote

import android.os.Handler
import android.os.Looper

/**
 * In-process shared state for toggleable modes (mouse, scroll).
 * All mutations are dispatched on the main thread to avoid data races.
 */
object NexRemoteState {

    private val handler = Handler(Looper.getMainLooper())

    @Volatile var isMouseEnabled  = false; private set
    @Volatile var isScrollEnabled = false; private set

    private val listeners = mutableListOf<() -> Unit>()

    fun toggleMouse() = post { isMouseEnabled = !isMouseEnabled; notify() }

    fun toggleScroll() = post { isScrollEnabled = !isScrollEnabled; notify() }

    fun addListener(l: () -> Unit) = post { listeners.add(l) }

    fun removeListener(l: () -> Unit) = post { listeners.remove(l) }

    private fun notify() = listeners.toList().forEach { it() }

    private fun post(block: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) block() else handler.post(block)
    }
}
