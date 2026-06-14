package com.nexremote.nex_remote

import android.os.Handler
import android.os.Looper
import android.view.KeyEvent

/**
 * Detects single, double, long, and hold press events for hardware keys.
 *
 * - single : UP within 500 ms, no second press within 300 ms window
 * - double : second DOWN within 300 ms of first UP
 * - long   : UP after being held ≥ 500 ms
 * - hold   : repeated callback every HOLD_INTERVAL_MS while key is held (≥ 500 ms)
 *
 * All callbacks arrive on the main thread.
 * Call [process] for every ACTION_DOWN / ACTION_UP event.
 * Returns true if the engine owns this keycode (has at least one mapping).
 */
class TimingEngine(private val onEvent: (keycode: Int, eventType: String) -> Unit) {

    companion object {
        private const val DOUBLE_WINDOW_MS = 300L
        private const val LONG_HOLD_MS    = 500L
        private const val HOLD_INTERVAL_MS = 200L
    }

    private val handler = Handler(Looper.getMainLooper())

    // Per-keycode state
    private val downTime       = mutableMapOf<Int, Long>()
    private val longRunnable   = mutableMapOf<Int, Runnable>()
    private val holdRunnable   = mutableMapOf<Int, Runnable>()
    private val singleRunnable = mutableMapOf<Int, Runnable>()
    private val awaitDouble    = mutableSetOf<Int>()
    private val inHold         = mutableSetOf<Int>()

    /** Returns true when the keycode has at least one registered mapping. */
    fun process(event: KeyEvent, hasMappings: Boolean): Boolean {
        if (!hasMappings) return false
        return when (event.action) {
            KeyEvent.ACTION_DOWN -> handleDown(event.keyCode)
            KeyEvent.ACTION_UP   -> handleUp(event.keyCode)
            else                 -> false
        }
    }

    private fun handleDown(kc: Int): Boolean {
        // If waiting for a double press, cancel the single timer and mark as double-in-progress
        cancelSingle(kc)
        cancelLong(kc)
        cancelHold(kc)
        downTime[kc] = System.currentTimeMillis()

        // Long / hold detection
        val lr = Runnable {
            longRunnable.remove(kc)
            // Start hold repeating
            inHold.add(kc)
            val hr = object : Runnable {
                override fun run() {
                    if (kc in inHold) {
                        onEvent(kc, "hold")
                        handler.postDelayed(this, HOLD_INTERVAL_MS)
                    }
                }
            }
            holdRunnable[kc] = hr
            handler.post(hr)
        }
        longRunnable[kc] = lr
        handler.postDelayed(lr, LONG_HOLD_MS)
        return true
    }

    private fun handleUp(kc: Int): Boolean {
        val down = downTime.remove(kc) ?: return false
        val held = System.currentTimeMillis() - down

        cancelLong(kc)

        if (kc in inHold) {
            // Was repeating hold — also fire "long" on release
            cancelHold(kc)
            onEvent(kc, "long")
            return true
        }

        // Short press — single or double
        if (held >= LONG_HOLD_MS) {
            // Edge case: long timer fired exactly at release
            onEvent(kc, "long")
            return true
        }

        if (kc in awaitDouble) {
            awaitDouble.remove(kc)
            cancelSingle(kc)
            onEvent(kc, "double")
        } else {
            awaitDouble.add(kc)
            val sr = Runnable {
                awaitDouble.remove(kc)
                singleRunnable.remove(kc)
                onEvent(kc, "single")
            }
            singleRunnable[kc] = sr
            handler.postDelayed(sr, DOUBLE_WINDOW_MS)
        }
        return true
    }

    private fun cancelSingle(kc: Int) { singleRunnable.remove(kc)?.let { handler.removeCallbacks(it) } }
    private fun cancelLong(kc: Int)   { longRunnable.remove(kc)?.let { handler.removeCallbacks(it) } }
    private fun cancelHold(kc: Int)   { inHold.remove(kc); holdRunnable.remove(kc)?.let { handler.removeCallbacks(it) } }
}
