package com.nexremote.nex_remote

import android.content.Context
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.TypedValue
import android.view.Gravity
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.TextView

/**
 * Optional floating overlay that shows the active mode (mouse / scroll).
 * Requires SYSTEM_ALERT_WINDOW permission.
 * Call [show] once and [updateState] whenever mode toggles.
 */
class OverlayManager(private val context: Context) {

    private var wm: WindowManager? = null
    private var root: FrameLayout? = null
    private var label: TextView? = null
    private val handler = Handler(Looper.getMainLooper())

    fun show() {
        if (root != null) return
        wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager

        label = TextView(context).apply {
            text = buildLabel(false, false)
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 10f)
            setPadding(10, 5, 10, 5)
            setBackgroundColor(Color.argb(200, 0, 128, 128))
        }

        root = FrameLayout(context).apply { addView(label) }

        @Suppress("DEPRECATION")
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        else WindowManager.LayoutParams.TYPE_SYSTEM_ALERT

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH,
            PixelFormat.TRANSLUCENT
        ).apply { gravity = Gravity.TOP or Gravity.END; x = 8; y = 8 }

        try { wm?.addView(root, params) } catch (_: Exception) { root = null; label = null }
    }

    fun updateState(mouseOn: Boolean, scrollOn: Boolean) {
        val lbl = label ?: return
        handler.post { lbl.text = buildLabel(mouseOn, scrollOn) }
    }

    fun hide() {
        root?.let { v -> try { wm?.removeView(v) } catch (_: Exception) {} }
        root = null; label = null; wm = null
    }

    private fun buildLabel(mouse: Boolean, scroll: Boolean) = buildString {
        append("NR")
        if (mouse) append(" M")
        if (scroll) append(" S")
    }
}
