import 'package:flutter/services.dart';
import 'fraud_protection_platform_interface.dart';

/// Provides access to device security and fraud protection checks.
///
/// This class exposes a set of static methods and event streams that allow
/// Flutter applications to detect potential security threats such as:
///
/// - Active device administrator apps
/// - Developer mode status
/// - Overlay windows and touch blocking
/// - Accessibility service whitelisting / blacklisting
/// - Obscured or partially obscured touches (from overlays)
///
/// Intended for use in high-security applications such as banking,
/// authentication, and enterprise apps.
class FraudProtection {
  static const _touchEvents = EventChannel("fraud_protection/touches");
  // static const _screenshotEvents = EventChannel("fraud_protection/screenshots");
  // static const _captureEvents = EventChannel("fraud_protection/capture");

  /// Checks whether any device administrator applications are currently active.
  ///
  /// Device administrator apps can gain elevated permissions that may pose
  /// a security risk if abused.
  ///
  /// Returns `true` if at least one device admin app is active, otherwise `false`.
  static Future<bool> isDeviceAdminActive() async {
    return FraudProtectionPlatform.instance.isDeviceAdminActive();
  }

  /// Checks whether developer mode is enabled on the device.
  ///
  /// Developer mode can weaken device security and make certain attacks easier
  /// to execute. Sensitive applications may want to disallow operation when
  /// developer mode is active.
  ///
  /// Returns `true` if developer mode is enabled, otherwise `false`.
  static Future<bool> isDeveloperModeEnabled() async {
    return FraudProtectionPlatform.instance.isDeveloperModeEnabled();
  }

  /// Controls whether overlay windows should be hidden.
  ///
  /// Passing `true` requests that all overlay windows be hidden while
  /// the application is in the foreground. This can prevent overlay attacks
  /// such as clickjacking.
  static Future<void> setHideOverlayWindows(
    bool shouldHideOverlayWindows,
  ) async {
    FraudProtectionPlatform.instance.setHideOverlayWindows(
      shouldHideOverlayWindows,
    );
  }

  /// Controls whether touches coming through overlay windows should be blocked.
  ///
  /// Passing `true` blocks touches when the system detects they originated
  /// from an overlay. This helps prevent tapjacking and other overlay-based
  /// input attacks.
  static Future<void> setBlockOverlayTouches(
    bool shouldBlockOverlayTouches,
  ) async {
    FraudProtectionPlatform.instance.setBlockOverlayTouches(
      shouldBlockOverlayTouches,
    );
  }

  /// Verifies that all enabled accessibility services are included in a whitelist.
  ///
  /// Accessibility services can be abused to capture user input or manipulate
  /// UI interactions. This method ensures that only explicitly allowed services
  /// are active.
  ///
  /// The [whitelist] parameter should contain a list of trusted service IDs
  /// or package names.
  ///
  /// Returns `true` if all enabled services are whitelisted, otherwise `false`.
  static Future<bool> areAllAccessibilityServicesWhitelisted(
    List<String> whitelist,
  ) async {
    return FraudProtectionPlatform.instance
        .areAllAccessibilityServicesWhitelisted(whitelist);
  }

  /// Checks if any enabled accessibility service is included in a blacklist.
  ///
  /// The [blacklist] parameter should contain package names or service IDs
  /// known to be malicious or unsafe. It can use 'wildcard' notation `*`. Package written as com.android.example*
  /// will verify all services if said package has any active
  ///
  /// Returns `true` if at least one blacklisted service is active, otherwise `false`.
  static Future<bool> isAnyAccessibilityServiceBlacklisted(
    List<String> blacklist,
  ) async {
    return FraudProtectionPlatform.instance
        .isAnyAccessibilityServiceBlacklisted(blacklist);
  }

  /// Retrieves a list of all currently active accessibility services.
  ///
  /// Returns a list of service IDs for all enabled accessibility services.
  /// Useful for auditing or debugging.
  static Future<List<String>> getActiveAccessibilityServices() async {
    return FraudProtectionPlatform.instance.getActiveAccessibilityServices();
  }

  /// Broadcast stream of obscured and partially obscured touch events.
  ///
  /// Events are reported when:
  /// - A touch is detected as coming from a full overlay → reported as **obscured touch**.
  /// - A touch is detected as coming from a partial overlay → reported as **partially obscured touch**.
  ///
  /// Each event is emitted as a string containing the event description and a timestamp.
  ///
  /// Touch events from overlays enabled with accessibility service are not tracked by Android OS as obscured touches.
  static Stream<String> get touchEvents =>
      _touchEvents.receiveBroadcastStream().map((e) => e.toString());

  // TODO: Expose screenshot and capture events once implemented natively.
  // static Stream<String> get screenshotEvents =>
  //     _screenshotEvents.receiveBroadcastStream().map((e) => e.toString());
  // static Stream<String> get screenRecordingEvents =>
  //     _captureEvents.receiveBroadcastStream().map((e) => e.toString());

  ///Example whitelist for initial accessibility verification
  static const DEFAULT_ACCESSIBILITY_WHITELIST = [
    // --- SYSTEM ACCESSIBILITY SERVICES ---
    "com.android.talkback/.TalkBackService",
    "com.google.android.marvin.talkback/.TalkBackService",
    "com.google.android.apps.accessibility.voiceaccess/.VoiceAccessService",
    "com.google.android.apps.accessibility.auditor/.AuditorService",
    "com.google.android.accessibility.switchaccess/.SwitchAccessService",
    "com.android.accessibility/.CaptioningService",
    "com.android.accessibility/.ShortcutService",

    // --- GOOGLE SERVICES ---
    "com.google.android.accessibility.talkback/.TalkBackService",
    "com.google.android.apps.accessibility.magnifier/.MagnifierService",
    "com.google.android.apps.accessibility.transcribe/.LiveTranscribeService",
    "com.google.android.apps.accessibility.voiceaccess/.VoiceAccessService",
    "com.google.android.accessibility.talkback/.TalkBackService",

    // --- SAMSUNG SERVICES ---
    "com.samsung.android.accessibility.talkback/.TalkBackService",
    "com.samsung.android.accessibility.switchaccess/.SwitchAccessService",
    "com.samsung.android.accessibility.magnifier/.MagnifierService",

    // --- LG SERVICES ---
    "com.lge.accessibility/.TalkBackService",
    "com.lge.accessibility/.SwitchAccessService",

    // --- XIAOMI / MIUI SERVICES ---
    "com.miui.accessibility/.TalkBackService",
    "com.miui.accessibility/.MagnifierService",

    // --- HUAWEI / EMUI SERVICES ---
    "com.huawei.accessibility/.TalkBackService",
    "com.huawei.accessibility/.MagnifierService",

    // --- COMMON THIRD-PARTY APPS USING ACCESSIBILITY ---
    // Password managers / autofill apps
    "com.onepassword/.autofill.AccessibilityService",
    "com.lastpass.lpandroid/.autofill.AccessibilityService",
    "com.bitwarden/.autofill.AccessibilityService",
    "com.dashlane/.autofill.AccessibilityService",
    "com.1password/.autofill.AccessibilityService",
    "com.roboform.android/.accessibility.RoboFormAccessibilityService",

    // Clipboard managers
    "com.rookout.android/.ClipboardService",
    "com.clipstack/.ClipboardAccessibilityService",
    "com.clipper/.ClipperService",

    // Automation / helper apps
    "com.tasker/.TaskerAccessibilityService",
    "com.automate/.AutomateAccessibilityService",
    "com.macrodroid/.MacroDroidAccessibilityService",

    // Other popular accessibility-enabled apps
    "com.nianticlabs.pokemongo/.AccessibilityService", // e.g., for accessibility cheats / UI helpers
    "com.instagram.android/.AccessibilityService", // optional for accessibility overlays
    "com.facebook.katana/.AccessibilityService", // optional
  ];

  static const DEFAULT_ACCESSIBILITY_BLACKLIST = [
    // --- Known overlay abuse / phishing / ad-fraud apps ---
    "com.kairosoft.twilightfilter", // Twilight-style screen filter
    "com.nightshield.screenfilter", // Night filter apps known for overlays
    "com.holaverse.screenfilter", // Screen dimming / overlay apps

    // --- Aggressive adware / overlay abuse ---
    "com.facebook.lite.adx", // aggressive ad overlays
    "com.shareit.*", // older versions were known for overlay abuse
    "com.cleanmaster.mguard", // ad-fraud / aggressive overlays
    "com.kingroot.kinguser", // rooted devices, overlay abuse

    // --- Known clickjacking / phishing apps ---
    "com.fakebanking.app", // real malware sample used for banking phishing
    "com.paypal.security.update", // phishing overlay targeting PayPal users
    "com.facebook.light.fake", // known phishing overlay for FB login
    "com.whatsapp.messenger.fake", // WhatsApp phishing/fake login

    // --- Suspicious automation / accessibility abusers ---
    "com.android.autoclicker", // automation apps abusing accessibility
    "com.autotap.autoclicker", // auto-tap apps that simulate clicks
    "com.touchracer.*", // touch injection apps
    "com.tapjoy.touchinjector", // overlay + automated clicks

    // --- Generic malware families / spyware / keyloggers ---
    "com.spyhunter.*", // spyware family
    "com.flexispy.*", // spyware
    "com.mspy.android.*", // spyware
    "com.hidemyphone.*", // cloaking/malware
    "com.keylogger.*", // keylogger family
  ];
}
