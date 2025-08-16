import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'fraud_protection_method_channel.dart';

abstract class FraudProtectionPlatform extends PlatformInterface {
  /// Constructs a FraudProtectionPlatform.
  FraudProtectionPlatform() : super(token: _token);

  static final Object _token = Object();

  static FraudProtectionPlatform _instance = MethodChannelFraudProtection();

  /// The default instance of [FraudProtectionPlatform] to use.
  ///
  /// Defaults to [MethodChannelFraudProtection].
  static FraudProtectionPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FraudProtectionPlatform] when
  /// they register themselves.
  static set instance(FraudProtectionPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<bool> isDeviceAdminActive() async {
    throw UnimplementedError('DeviceAdminActive() has not been implemented.');
  }

  Future<bool> isDeveloperModeEnabled() async {
    throw UnimplementedError(
      'DeveloperModeEnabled() has not been implemented.',
    );
  }

  Future<void> setHideOverlayWindows(bool shouldHideOverlayWindows) async {
    throw UnimplementedError(
      'setHideOverlayWindows() has not been implemented.',
    );
  }

  Future<void> setBlockOverlayTouches(bool shouldBlockOverlayTouches) async {
    throw UnimplementedError(
      'setBlockOverlayTouches() has not been implemented.',
    );
  }

  Future<List<String>> getActiveAccessibilityServices() async {
    throw UnimplementedError(
      'getActiveAccessibilityServices() has not been implemented.',
    );
  }

  Future<bool> areAllAccessibilityServicesWhitelisted(
    List<String> whitelist,
  ) async {
    throw UnimplementedError(
      'areAllAccessibilityServicesWhitelisted() has not been implemented.',
    );
  }

  Future<bool> isAnyAccessibilityServiceBlacklisted(
    List<String> blacklist,
  ) async {
    throw UnimplementedError(
      'isAnyAccessibilityServiceBlacklisted() has not been implemented.',
    );
  }
}
