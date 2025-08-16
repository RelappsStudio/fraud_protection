import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:fraud_protection/fraud_protection.dart';
import 'package:flutter/scheduler.dart';

void main() {
  runApp(const AppLifecycleListenerExample());
}

class AppLifecycleListenerExample extends StatelessWidget {
  const AppLifecycleListenerExample({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: LifecycleObserver(child: MainAppScreen()));
  }
}

class MainAppScreen extends StatefulWidget {
  const MainAppScreen({super.key});

  @override
  State<MainAppScreen> createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> {
  bool isAppForcedToTop = false;
  bool isObscuredTouchBlocked = false;
  bool overlayTapsDetected = false;
  bool blacklistedSericesDetected = false;
  bool? isDeveloperModeEnabled = null;
  bool? isAdminAppPresent = null;
  List<String>? activeAccessibilityServices = null;

  late StreamSubscription<String> _fraudProtectionTouchSubscription;

  Future<void> _detectBlacklistedServices() async {
    bool blacklistedServicesFound =
        await FraudProtection.isAnyAccessibilityServiceBlacklisted(
          FraudProtection.DEFAULT_ACCESSIBILITY_BLACKLIST +
              [], //You can use baseline blacklist and expand with your own packages. Though it is appreciated to make PR to package repo to add your package to baseline.
        );

    setState(() {
      blacklistedSericesDetected = blacklistedServicesFound;
    });
  }

  //These Subscriptions are duplicated here so they can be showcased in the example screen.
  //Recommended way to use this plugin is inside a lifecycle observer so that whole app can be monitored on every onResumed
  @override
  void initState() {
    super.initState();
    _detectBlacklistedServices();
    if (Platform.isAndroid) {
      _fraudProtectionTouchSubscription = FraudProtection.touchEvents.listen((
        touchEvent,
      ) {
        setState(() {
          overlayTapsDetected = true;
        });
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
    _fraudProtectionTouchSubscription.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 20,
            children: [
              Text(
                'Any blacklisted accessibility services enabled = $blacklistedSericesDetected',
              ),
              Text(
                'Touches through overlay detected this session = $overlayTapsDetected',
              ),
              MaterialButton(
                elevation: 10,
                color: Colors.teal,
                onPressed: () async {
                  setState(() {
                    isAppForcedToTop = !isAppForcedToTop;
                  });
                  FraudProtection.setHideOverlayWindows(isAppForcedToTop);
                },
                child: Text(
                  isAppForcedToTop
                      ? 'Allow overlays over app'
                      : 'Force app on top of overlays',
                ),
              ),
              MaterialButton(
                elevation: 10,
                color: Colors.teal,
                onPressed: () async {
                  setState(() {
                    isObscuredTouchBlocked = !isObscuredTouchBlocked;
                  });
                  FraudProtection.setBlockOverlayTouches(
                    isObscuredTouchBlocked,
                  );
                },
                child: Text(
                  isObscuredTouchBlocked
                      ? 'Allow touches through active overlays'
                      : 'Block touches coming through overlay',
                ),
              ),
              MaterialButton(
                elevation: 10,
                color: Colors.teal,
                onPressed: () async {
                  isDeveloperModeEnabled =
                      await FraudProtection.isDeveloperModeEnabled();
                  isAdminAppPresent =
                      await FraudProtection.isDeviceAdminActive();
                  activeAccessibilityServices =
                      await FraudProtection.getActiveAccessibilityServices();
                  setState(() {});
                },
                child: Text('Gather device info'),
              ),
              isDeveloperModeEnabled != null
                  ? Text('Developer mode enabled = $isDeveloperModeEnabled')
                  : SizedBox.shrink(),
              isAdminAppPresent != null
                  ? Text("Admin apps located on system = $isAdminAppPresent")
                  : SizedBox.shrink(),
              if (activeAccessibilityServices != null) ...[
                Text(
                  "Found following accessibility services (empty box means none)",
                ),
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                  child: ListView.separated(
                    itemBuilder: (context, index) {
                      return Text(activeAccessibilityServices![index]);
                    },
                    separatorBuilder: (context, index) {
                      return Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey, width: 0.5),
                        ),
                      );
                    },
                    itemCount: activeAccessibilityServices!.length,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class LifecycleObserver extends StatefulWidget {
  final Widget child;
  const LifecycleObserver({super.key, required this.child});

  @override
  State<LifecycleObserver> createState() => _LifecycleObserverState();
}

class _LifecycleObserverState extends State<LifecycleObserver> {
  late final AppLifecycleListener _listener;
  final List<String> _states = <String>[];
  late AppLifecycleState? _state;
  late StreamSubscription<String> _fraudProtectionTouchSubscription;

  Future<void> _checkDeviceCapabilities() async {
    bool isDeveloperModeEnabled =
        await FraudProtection.isDeveloperModeEnabled();
    print(
      "Fraud protection: Is developer mode enabled? = $isDeveloperModeEnabled",
    );
    bool isDeviceAdminActive = await FraudProtection.isDeviceAdminActive();
    print("Fraud protection: Are admin apps installed? = $isDeviceAdminActive");
  }

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      _checkDeviceCapabilities();
      // _fraudProtectionTouchSubscription = FraudProtection.touchEvents.listen((
      //   touchEvent,
      // ) {
      //   //Perform your handling of obscured events
      //   print("Active overlay detected: $touchEvent");
      // });
    }
    _state = SchedulerBinding.instance.lifecycleState;
    _listener = AppLifecycleListener(
      onResume: () => _checkDeviceCapabilities(),
    );
    if (_state != null) {
      _states.add(_state!.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  @override
  void dispose() {
    super.dispose();
    _fraudProtectionTouchSubscription.cancel();
  }
}
