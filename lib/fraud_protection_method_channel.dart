import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'fraud_protection_platform_interface.dart';

/// An implementation of [FraudProtectionPlatform] that uses method channels.
class MethodChannelFraudProtection extends FraudProtectionPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('fraud_protection');

  @override
  Future<bool> isDeviceAdminActive() async {
    final bool result = await methodChannel.invokeMethod('isDeviceAdminActive');
    return result;
  }

  @override
  Future<bool> isDeveloperModeEnabled() async {
    final bool result = await methodChannel.invokeMethod(
      'isDeveloperModeEnabled',
    );
    return result;
  }

  @override
  Future<void> setHideOverlayWindows(bool shouldHideOverlayWindows) async {
    await methodChannel.invokeListMethod('setHideOverlayWindows', {
      'shouldHide': shouldHideOverlayWindows,
    });
  }

  @override
  Future<void> setBlockOverlayTouches(bool shouldBlockOverlayTouches) async {
    await methodChannel.invokeListMethod('setBlockOverlayTouches', {
      'shouldBlock': shouldBlockOverlayTouches,
    });
  }

  @override
  Future<List<String>> getActiveAccessibilityServices() async {
    final List<String> activeServices =
        await methodChannel.invokeListMethod(
          'getActiveAccessibilityServices',
        ) ??
        [];
    return activeServices;
  }

  @override
  Future<bool> areAllAccessibilityServicesWhitelisted(
    List<String> whitelist,
  ) async {
    final bool result = await methodChannel.invokeMethod(
      'areAllAccessibilityServicesWhitelisted', {
        'whitelist': whitelist
      }
    );
    return result;
  }

  @override
  Future<bool> isAnyAccessibilityServiceBlacklisted(
    List<String> blacklist
  ) async {
   final bool result = await methodChannel.invokeMethod(
      'isAnyAccessibilityServiceBlacklisted', {
        'blacklist': blacklist
      }
    );
    return result;
  }
}
