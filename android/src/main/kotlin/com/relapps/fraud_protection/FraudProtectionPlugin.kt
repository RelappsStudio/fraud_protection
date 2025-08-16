package com.relapps.fraud_protection

import android.accessibilityservice.AccessibilityServiceInfo.FEEDBACK_ALL_MASK
import android.app.admin.DevicePolicyManager
import android.content.Context
import android.database.ContentObserver
import android.content.ContentResolver
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.provider.Settings
import android.util.Log
import android.view.MotionEvent
import android.view.View
import android.view.Window
import android.view.accessibility.AccessibilityManager
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result

/**
 * FraudProtectionPlugin provides native Android security checks and fraud-prevention
 * features, exposed to Flutter via [MethodChannel] and [EventChannel].
 *
 * It supports:
 * - Overlay protection (hiding overlay windows, blocking overlay touches).
 * - Accessibility service validation (whitelisting/blacklisting).
 * - Device administration and developer mode checks.
 * - Event streams for touch, screenshot, and limited screen capture detection.
 */
class FraudProtectionPlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    ActivityAware {

    private lateinit var channel: MethodChannel

    // Event channels
    private lateinit var touchEventChannel: EventChannel
    private lateinit var screenshotEventChannel: EventChannel
    private lateinit var captureEventChannel: EventChannel

    // Event sinks
    private var touchEvents: EventChannel.EventSink? = null
    private var screenshotEvents: EventChannel.EventSink? = null
    private var captureEvents: EventChannel.EventSink? = null

    private val handler = Handler(Looper.getMainLooper())
    private lateinit var applicationContext: Context
    private var activityBinding: ActivityPluginBinding? = null

    private var screenshotObserver: ContentObserver? = null

    // --- Flutter Plugin lifecycle ---

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "fraud_protection")
        channel.setMethodCallHandler(this)

        // Setup event channels
        touchEventChannel =
            EventChannel(flutterPluginBinding.binaryMessenger, "fraud_protection/touches")
        screenshotEventChannel =
            EventChannel(flutterPluginBinding.binaryMessenger, "fraud_protection/screenshots")
        captureEventChannel =
            EventChannel(flutterPluginBinding.binaryMessenger, "fraud_protection/capture")

        setupEventHandlers()

        applicationContext = flutterPluginBinding.applicationContext
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        touchEventChannel.setStreamHandler(null)
        screenshotEventChannel.setStreamHandler(null)
        captureEventChannel.setStreamHandler(null)
    }

    // --- Event channel setup ---

    /**
     * Initializes event stream handlers for touches, screenshots, and capture.
     */
    private fun setupEventHandlers() {
        touchEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                touchEvents = events
                startObservingTouchEvents()
            }
            override fun onCancel(arguments: Any?) {
                stopObservingTouchEvents()
            }
        })

        screenshotEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                screenshotEvents = events
                startObservingScreenshots()
            }
            override fun onCancel(arguments: Any?) {
                stopObservingScreenshots()
            }
        })

        captureEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                captureEvents = events
                startObservingScreenCapture()
            }
            override fun onCancel(arguments: Any?) {
                stopObservingScreenCapture()
            }
        })
    }

    // --- Method channel handling ---

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "isDeviceAdminActive" -> result.success(isDeviceAdminActive())
            "isDeveloperModeEnabled" -> result.success(isDeveloperModeEnabled())
            "getActiveAccessibilityServices" -> result.success(getActiveAccessibilityServices(applicationContext))
            "areAllAccessibilityServicesWhitelisted" -> {
                val whitelist = call.argument<List<String>>("whitelist") ?: emptyList()
                result.success(areAllAccessibilityServicesWhitelisted(whitelist))
            }
            "isAnyAccessibilityServiceBlacklisted" -> {
                val blacklist = call.argument<List<String>>("blacklist") ?: emptyList()
                result.success(isAnyAccessibilityServiceBlacklisted(blacklist))
            }
            "setBlockOverlayTouches" -> {
                val shouldBlock = call.argument<Boolean>("shouldBlock") ?: false
                setBlockOverlayTouches(shouldBlock)
                result.success(null)
            }
            "setHideOverlayWindows" -> {
                val shouldHide = call.argument<Boolean>("shouldHide") ?: false
                setHideOverlayWindows(shouldHide)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    // --- Overlay protections ---

    /**
     * Prevents other apps from overlaying windows on top of the activity.
     *
     * @param shouldHideOverlays If true, overlay windows are hidden (API 31+ only).
     */
    private fun setHideOverlayWindows(shouldHideOverlays: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val activity = activityBinding?.activity ?: return
            activity.window.setHideOverlayWindows(shouldHideOverlays)
        }
    }

    /**
     * Blocks touches if the window is obscured by overlays.
     *
     * @param shouldBlockOverlayTouches If true, obscured touches are filtered out.
     */
    private fun setBlockOverlayTouches(shouldBlockOverlayTouches: Boolean) {
        val activity = activityBinding?.activity ?: return
        val rootView = activity.findViewById<View>(android.R.id.content)?.rootView
        rootView?.filterTouchesWhenObscured = shouldBlockOverlayTouches
    }

    // --- Touch observing ---

    /**
     * Starts observing touch events and emits warnings for obscured or partially obscured touches.
     */
    private fun startObservingTouchEvents() {
        val activity = activityBinding?.activity ?: return
        val originalCallback = activity.window.callback

        activity.window.callback = object : Window.Callback by originalCallback {
            override fun dispatchTouchEvent(event: MotionEvent): Boolean {
                if (event.action == MotionEvent.ACTION_DOWN) {
                    if (event.flags and MotionEvent.FLAG_WINDOW_IS_OBSCURED != 0) {
                        touchEvents?.success("Obscured touch detected at: ${System.currentTimeMillis()}")
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
                        event.flags and MotionEvent.FLAG_WINDOW_IS_PARTIALLY_OBSCURED != 0
                    ) {
                        touchEvents?.success("Partially obscured touch detected at: ${System.currentTimeMillis()}")
                    }
                }
                return originalCallback.dispatchTouchEvent(event)
            }
        }
    }

    /**
     * Stops observing touch events.
     */
    private fun stopObservingTouchEvents() {
        handler.removeCallbacksAndMessages(null)
        touchEvents = null
    }

    // --- Screenshot observing ---

    /**
     * Starts monitoring MediaStore for new screenshots.
     *
     * ⚠️ Requires storage access, unreliable on newer Android versions.
     */
    private fun startObservingScreenshots() {
        val resolver = applicationContext.contentResolver
        screenshotObserver = object : ContentObserver(null) {
            override fun onChange(selfChange: Boolean, uri: Uri?) {
                super.onChange(selfChange, uri)
                val projection = arrayOf(
                    MediaStore.Images.Media.DISPLAY_NAME,
                    MediaStore.Images.Media.DATE_ADDED
                )
                resolver.query(
                    uri ?: MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                    projection,
                    null,
                    null,
                    null
                )?.use { cursor ->
                    if (cursor.moveToLast()) {
                        val nameIndex =
                            cursor.getColumnIndex(MediaStore.Images.Media.DISPLAY_NAME)
                        if (nameIndex >= 0) {
                            val name = cursor.getString(nameIndex)
                            if (name.lowercase().contains("screenshot") || name.lowercase().contains("scr")) {
                                screenshotEvents?.success("Screenshot detected at: ${System.currentTimeMillis()}")
                            }
                        }
                    }
                }
            }
        }
        resolver.registerContentObserver(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            true,
            screenshotObserver!!
        )
    }

    /**
     * Stops monitoring for screenshots.
     */
    private fun stopObservingScreenshots() {
        screenshotObserver?.let {
            applicationContext.contentResolver.unregisterContentObserver(it)
        }
        screenshotObserver = null
        screenshotEvents = null
    }

    // --- Screen capture observing ---

    /**
     * Starts limited screen capture detection.
     *
     * ⚠️ Android does not provide global callbacks for external screen recording,
     * only self-initiated captures can be detected.
     */
    private fun startObservingScreenCapture() {
        captureEvents?.success("Screen capture observing started (limited)")
    }

    /**
     * Stops screen capture detection.
     */
    private fun stopObservingScreenCapture() {
        captureEvents = null
    }

    // --- Security checks ---

    /**
     * Retrieves a list of currently active accessibility service IDs.
     *
     * @param context Application context.
     * @return List of enabled accessibility services.
     */
    private fun getActiveAccessibilityServices(context: Context) : List<String> {
        val accessibilityManager =
            context.getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
        val enabledServices =
            accessibilityManager.getEnabledAccessibilityServiceList(FEEDBACK_ALL_MASK)
        var activeServicesFound = emptyList<String>()
        for (serviceInfo in enabledServices) {
            activeServicesFound += serviceInfo.id
        }
        return activeServicesFound
    }

    /**
     * Checks if all enabled accessibility services are within a whitelist.
     *
     * @param whitelist List of allowed accessibility service IDs.
     * @return True if all services are whitelisted.
     */
    private fun areAllAccessibilityServicesWhitelisted(whitelist: List<String>): Boolean {
        val accessibilityManager =
            applicationContext.getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
        val enabledServices =
            accessibilityManager.getEnabledAccessibilityServiceList(FEEDBACK_ALL_MASK)
                .map { it.id }
        return enabledServices.all { it in whitelist }
    }

    /**
     * Checks if any enabled accessibility service matches a blacklist.
     *
     * Supports wildcard matching with suffix `*`.
     *
     * @param blacklist List of blacklisted package names (with optional wildcards).
     * @return True if a blacklisted service is active.
     */
    private fun isAnyAccessibilityServiceBlacklisted(blacklist: List<String>): Boolean {
        val accessibilityManager =
            applicationContext.getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
        val enabledPackages = accessibilityManager
            .getEnabledAccessibilityServiceList(FEEDBACK_ALL_MASK)
            .map { it.resolveInfo.serviceInfo.packageName }

        return enabledPackages.any { pkg ->
            blacklist.any { entry ->
                entry.endsWith("*") && pkg.startsWith(entry.removeSuffix("*")) || pkg == entry
            }
        }
    }

    /**
     * Checks if any device administrator apps are active.
     *
     * @return True if at least one admin is active.
     */
    private fun isDeviceAdminActive(): Boolean {
        val dpm =
            applicationContext.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        val admins = dpm.activeAdmins
        return !admins.isNullOrEmpty()
    }

    /**
     * Checks if developer mode is enabled on the device.
     *
     * Evaluates global developer setting, ADB over USB, and ADB over Wi-Fi.
     *
     * @return True if developer mode is active.
     */
    private fun isDeveloperModeEnabled(): Boolean {
        val cr = applicationContext.contentResolver
        val devGlobal = getGlobalInt(cr, Settings.Global.DEVELOPMENT_SETTINGS_ENABLED, -1)
        val adbUsb  = getGlobalInt(cr, Settings.Global.ADB_ENABLED, 0) == 1
        val adbWifi = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R)
            getGlobalInt(cr, "adb_wifi_enabled", 0) == 1 else false

        val enabled = (devGlobal == 1) || adbUsb || adbWifi

        Log.d("FraudProtection", "DevMode check -> devGlobal=$devGlobal adbUsb=$adbUsb adbWifi=$adbWifi enabled=$enabled")
        return enabled
    }

    /**
     * Safely retrieves a global integer setting value.
     *
     * @param cr ContentResolver instance.
     * @param key Setting key.
     * @param def Default value if not found.
     * @return Setting value or default.
     */
    private fun getGlobalInt(cr: ContentResolver, key: String, def: Int): Int {
        return try { Settings.Global.getInt(cr, key) } catch (_: Exception) { def }
    }

    // --- ActivityAware lifecycle ---

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activityBinding = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activityBinding = binding
    }

    override fun onDetachedFromActivity() {
        activityBinding = null
    }
}
