import 'dart:async';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:usage_stats/usage_stats.dart';

import 'block_overlay.dart';
import 'browser_watcher.dart';
import 'foreground_app.dart';
import 'rule.dart';
import 'rule_store.dart';

const rulesChangedSignal = 'blocking.rulesChanged';
const applicationId = 'com.example.serensync';
const _screenOnInterval = 1000;
const _screenOffInterval = 60000;
const _permissionCheckInterval = Duration(minutes: 1);

class BlockingEngine {
  BlockingEngine({
    ForegroundApp? foregroundApp,
    BlockOverlay? overlay,
    List<BlockRule> rules = const <BlockRule>[],
    this.ownPackage = applicationId,
  }) : foregroundApp = foregroundApp ?? ForegroundApp(),
       overlay = overlay ?? BlockOverlay(),
       _rules = List<BlockRule>.unmodifiable(rules);

  final ForegroundApp foregroundApp;
  final BlockOverlay overlay;
  final String ownPackage;

  List<BlockRule> _rules;
  final Map<String, WebAddress> _addresses = <String, WebAddress>{};
  Future<void> _queue = Future<void>.value();
  String? _previousPackage;
  bool? _screenInteractive;

  Future<bool?> tick(DateTime now) => _serialized(() => _tick(now));

  /// Records what a browser shows and re-evaluates it while it is the
  /// foreground app. Other browsers are evaluated once they come forward.
  Future<void> addressChanged(BrowserAddress change, DateTime now) {
    return _serialized(() async {
      final address = change.address;
      if (address == null) {
        _addresses.remove(change.browser);
      } else {
        _addresses[change.browser] = address;
      }
      if (change.browser == _previousPackage && _screenInteractive != false) {
        await _evaluate(change.browser, now);
      }
    });
  }

  void replaceRules(List<BlockRule> rules) {
    _rules = List<BlockRule>.unmodifiable(rules);
  }

  Future<bool?> _tick(DateTime now) async {
    final foreground = await foregroundApp.foregroundState(now);
    if (!foreground.screenInteractive) {
      final screenTurnedOff = _screenInteractive != false;
      _screenInteractive = false;
      if (screenTurnedOff) {
        await overlay.hide();
        return false;
      }
      return null;
    }

    final screenTurnedOn = _screenInteractive == false;
    _screenInteractive = true;
    final packageName = foreground.packageName;
    if (packageName == null) {
      await overlay.hide();
      return screenTurnedOn ? true : null;
    }

    if (packageName != _previousPackage) {
      foregroundApp.invalidateUsage();
    }
    _previousPackage = packageName;
    if (packageName == ownPackage) {
      await overlay.hide();
    } else {
      await _evaluate(packageName, now);
    }
    return screenTurnedOn ? true : null;
  }

  // Runs on every tick so a schedule or limit can start while the app stays
  // open; the usage read behind it is cached by the foreground app.
  Future<void> _evaluate(String packageName, DateTime now) async {
    final usage = await foregroundApp.todayUsage(packageName, now);
    var decision = decide(
      rules: _rules,
      package: packageName,
      now: now,
      usage: usage,
    );
    final address = _addresses[packageName];
    WebAddress? blockedAddress;
    if (decision is Allow && address != null) {
      decision = decideWeb(rules: _rules, address: address, now: now);
      if (decision is Block) blockedAddress = address;
    }
    if (decision is Block) {
      await overlay.show(
        packageName: packageName,
        rule: decision.rule,
        address: blockedAddress,
      );
    } else {
      await overlay.hide();
    }
  }

  // Ticks and address changes both drive the overlay, so they run one at a
  // time to keep the last decision and the overlay in step.
  Future<T> _serialized<T>(Future<T> Function() work) {
    final result = _queue.then((_) => work());
    _queue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }
}

@pragma('vm:entry-point')
void blockingEngineCallback() {
  FlutterForegroundTask.setTaskHandler(BlockingTask());
}

void initializeBlockingService() {
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'blocking_engine',
      channelName: 'App limits',
      channelDescription: 'Shown while app limits are being enforced.',
      onlyAlertOnce: true,
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: false,
      playSound: false,
    ),
    foregroundTaskOptions: _taskOptions(_screenOnInterval),
  );
}

class BlockingService {
  Future<bool> get isRunning => FlutterForegroundTask.isRunningService;

  Future<ServiceRequestResult> start() {
    return FlutterForegroundTask.startService(
      serviceTypes: const <ForegroundServiceTypes>[
        ForegroundServiceTypes.specialUse,
      ],
      notificationTitle: 'App limits are on',
      notificationText: 'Blocking runs while this is showing.',
      callback: blockingEngineCallback,
    );
  }

  Future<bool> stop() async {
    final result = await FlutterForegroundTask.stopService();
    return result is ServiceRequestSuccess;
  }
}

class BlockingTask extends TaskHandler {
  BlockingTask({
    BlockingEngine? engine,
    RuleStore? ruleStore,
    BrowserWatcher? browserWatcher,
  }) : _engine = engine ?? BlockingEngine(),
       _ruleStore = ruleStore ?? RuleStore(),
       _browserWatcher = browserWatcher ?? BrowserWatcher();

  final BlockingEngine _engine;
  final RuleStore _ruleStore;
  final BrowserWatcher _browserWatcher;
  StreamSubscription<BrowserAddress>? _addresses;
  bool _tickActive = false;
  Timer? _permissionCheck;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await _reloadRules();
    if (!await _checkEnforcementPermissions()) return;
    _addresses = _browserWatcher.addresses().listen(
      (change) => unawaited(_engine.addressChanged(change, DateTime.now())),
    );
    _permissionCheck = Timer.periodic(_permissionCheckInterval, (_) {
      unawaited(_checkEnforcementPermissions());
    });
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    if (!_tickActive) {
      unawaited(_runTick(timestamp));
    }
  }

  @override
  void onReceiveData(Object data) {
    if (data == rulesChangedSignal) {
      unawaited(_reloadRules());
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _permissionCheck?.cancel();
    await _addresses?.cancel();
    await _engine.overlay.hide();
    await _ruleStore.close();
  }

  Future<bool> _checkEnforcementPermissions() async {
    final usageAccess = await UsageStats.checkUsagePermission() ?? false;
    final overlay = await FlutterForegroundTask.canDrawOverlays;
    if (usageAccess && overlay) return true;

    await _engine.overlay.hide();
    await FlutterForegroundTask.stopService();
    return false;
  }

  Future<void> _runTick(DateTime timestamp) async {
    _tickActive = true;
    try {
      final screenInteractive = await _engine.tick(timestamp);
      if (screenInteractive != null) {
        await FlutterForegroundTask.updateService(
          foregroundTaskOptions: _taskOptions(
            screenInteractive ? _screenOnInterval : _screenOffInterval,
          ),
        );
      }
    } finally {
      _tickActive = false;
    }
  }

  Future<void> _reloadRules() async {
    _engine.replaceRules(await _ruleStore.readAll());
  }
}

ForegroundTaskOptions _taskOptions(int interval) {
  return ForegroundTaskOptions(
    eventAction: ForegroundTaskEventAction.repeat(interval),
    autoRunOnBoot: true,
    autoRunOnMyPackageReplaced: true,
    allowWakeLock: false,
  );
}
