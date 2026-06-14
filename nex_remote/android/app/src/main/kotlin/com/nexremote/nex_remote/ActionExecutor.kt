package com.nexremote.nex_remote

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.content.Intent
import android.graphics.Path
import android.util.Log
import android.view.accessibility.AccessibilityNodeInfo
import org.json.JSONObject

/**
 * Executes actions on behalf of KeyEventService.
 * All methods are called from the main thread (via Handler in TimingEngine).
 */
class ActionExecutor(private val service: AccessibilityService) {

    private val tag = "NexRemote.Action"

    fun execute(actionJson: JSONObject) {
        when (val type = actionJson.optString("type")) {
            "open_app"     -> launchApp(actionJson.optString("packageName"))
            "system"       -> executeSystem(actionJson.optString("systemAction"))
            "scroll"       -> executeScroll(
                                 direction = actionJson.optString("direction", "down"),
                                 steps = actionJson.optInt("steps", 3)
                             )
            "click"        -> performClick()
            "toggle_mouse" -> NexRemoteState.toggleMouse()
            "toggle_scroll"-> NexRemoteState.toggleScroll()
            else           -> Log.w(tag, "Unknown action type: $type")
        }
    }

    private fun executeSystem(action: String) {
        val ga = when (action) {
            "back"       -> AccessibilityService.GLOBAL_ACTION_BACK
            "home"       -> AccessibilityService.GLOBAL_ACTION_HOME
            "recents"    -> AccessibilityService.GLOBAL_ACTION_RECENTS
            "screenshot" -> AccessibilityService.GLOBAL_ACTION_TAKE_SCREENSHOT
            else         -> { Log.w(tag, "Unknown system action: $action"); return }
        }
        service.performGlobalAction(ga)
    }

    private fun executeScroll(direction: String, steps: Int) {
        val root = service.rootInActiveWindow
        if (root != null) {
            val scrollable = findScrollable(root)
            if (scrollable != null) {
                val nodeAction = if (direction == "up")
                    AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD
                else
                    AccessibilityNodeInfo.ACTION_SCROLL_FORWARD
                repeat(steps.coerceIn(1, 10)) { scrollable.performAction(nodeAction) }
                scrollable.recycle()
                root.recycle()
                return
            }
            root.recycle()
        }
        // Fallback: inject swipe gesture
        injectScrollGesture(direction, steps)
    }

    private fun findScrollable(node: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        if (node.isScrollable) return node
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            val found = findScrollable(child)
            if (found != null) {
                if (found !== child) child.recycle()
                return found
            }
            child.recycle()
        }
        return null
    }

    private fun injectScrollGesture(direction: String, steps: Int) {
        val dm = service.resources.displayMetrics
        val cx = dm.widthPixels / 2f
        val cy = dm.heightPixels / 2f
        val dy = dm.heightPixels * 0.2f * steps.coerceIn(1, 5)
        val path = Path()
        if (direction == "up") {
            path.moveTo(cx, cy + dy); path.lineTo(cx, cy - dy)
        } else {
            path.moveTo(cx, cy - dy); path.lineTo(cx, cy + dy)
        }
        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0, 300))
            .build()
        service.dispatchGesture(gesture, null, null)
    }

    private fun performClick() {
        val root = service.rootInActiveWindow
        if (root != null) {
            val focused = findClickableFocused(root)
            if (focused != null) {
                focused.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                focused.recycle()
                root.recycle()
                return
            }
            root.recycle()
        }
        injectTap()
    }

    private fun findClickableFocused(node: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        if (node.isFocused && node.isClickable) return node
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            val found = findClickableFocused(child)
            if (found != null) {
                if (found !== child) child.recycle()
                return found
            }
            child.recycle()
        }
        return null
    }

    private fun injectTap() {
        val dm = service.resources.displayMetrics
        val path = Path().also { it.moveTo(dm.widthPixels / 2f, dm.heightPixels / 2f) }
        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0, 50))
            .build()
        service.dispatchGesture(gesture, null, null)
    }

    private fun launchApp(pkg: String) {
        if (pkg.isEmpty()) return
        val pm = service.packageManager
        val intent = pm.getLeanbackLaunchIntentForPackage(pkg)
            ?: pm.getLaunchIntentForPackage(pkg)
        if (intent == null) { Log.w(tag, "No launch intent for $pkg"); return }
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
        try { service.startActivity(intent) } catch (e: Exception) { Log.e(tag, "Launch failed: $pkg", e) }
    }
}
