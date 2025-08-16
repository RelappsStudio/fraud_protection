import 'package:flutter_test/flutter_test.dart';
import 'package:fraud_protection/fraud_protection.dart';
import 'package:fraud_protection/fraud_protection_platform_interface.dart';
import 'package:fraud_protection/fraud_protection_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFraudProtectionPlatform
    with MockPlatformInterfaceMixin
    implements FraudProtectionPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final FraudProtectionPlatform initialPlatform =
      FraudProtectionPlatform.instance;

  test('$MethodChannelFraudProtection is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFraudProtection>());
  });

  test('getPlatformVersion', () async {
    FraudProtection fraudProtectionPlugin = FraudProtection();
    MockFraudProtectionPlatform fakePlatform = MockFraudProtectionPlatform();
    FraudProtectionPlatform.instance = fakePlatform;

    expect(await fraudProtectionPlugin.getPlatformVersion(), '42');
  });
}
