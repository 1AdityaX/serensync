import 'dart:async';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:usage_stats/usage_stats.dart';

import 'block_overlay.dart';
import 'foreground_app.dart';
import 'rule.dart';
import 'rule_store.dart';

const rulesChangedSignal = 'blocking.rulesChanged';
const applicationId = 'com.example.serensync';
const _ownPackage = applicationId;
const _screenOnInterval = 1000;
const _screenOffInterval = 60000;
const _permissionCheckInterval = Duration(minutes: 1);

class BlockingEngine {
  BlockingEngine({
    ForegroundApp? foregroundApp,
    BlockOverlay? overlay,
    List<BlockRule> rules = const <BlockRule>[],
    this.ownPackage = _ownPackage,
  }) : foregroundApp = foregroundApp ?? ForegroundApp(),
       overlay = overlay ?? BlockOverlay(),
       _rules = List<BlockRule>.unmodifiable(rules);

  final ForegroundApp foregroundApp;
  final BlockOverlay overlay;
  final String ownPackage;

  List<BlockRule> _rules;
  String? _previousPackage;
  Decision? _previousDecision;
  bool? _screenInteractive;

  Future<bool?> tick(DateTime now) async {
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
    if (packageName == ownPackage) {
      _remember(packageName, null);
      await overlay.hide();
      return screenTurnedOn ? true : null;
    }
    if (packageName == _previousPackage && _previousDecision is Allow) {
      return screenTurnedOn ? true : null;
    }

    final usage = await foregroundApp.todayUsage(packageName, now);
    final decision = decide(
      rules: _rules,
      package: packageName,
      now: now,
      usage: usage,
    );
    _remember(packageName, decision);
    if (decision is Block) {
      await overlay.show(packageName: packageName, rule: decision.rule);
    } else {
      await overlay.hide();
    }
    return screenTurnedOn ? true : null;
  }

  void replaceRules(List<BlockRule> rules) {
    _rules = List<BlockRule>.unmodifiable(rules);
    _previousDecision = null;
  }

  void _remember(String packageName, Decision? decision) {
    _previousPackage = packageName;
    _previousDecision = decision;
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
      channelName: 'App blocking',
      channelDescription: 'Keeps SerenSync app blocking active',
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
      notificationTitle: 'SerenSync is active',
      notificationText: 'App blocking is running',
      callback: blockingEngineCallback,
    );
  }

  Future<bool> stop() async {
    final result = await FlutterForegroundTask.stopService();
    return result is ServiceRequestSuccess;
  }
}

void signalRulesChanged() {
  FlutterForegroundTask.sendDataToTask(rulesChangedSignal);
}

class BlockingTask extends TaskHandler {
  BlockingTask({BlockingEngine? engine, RuleStore? ruleStore})
    : _engine = engine ?? BlockingEngine(),
      _ruleStore = ruleStore ?? RuleStore();

  final BlockingEngine _engine;
  final RuleStore _ruleStore;
  bool _tickActive = false;
  Timer? _permissionCheck;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await _reloadRules();
    if (!await _checkEnforcementPermissions()) return;
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
