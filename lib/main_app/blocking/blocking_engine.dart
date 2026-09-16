import 'dart:async';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:usage_stats/usage_stats.dart';

import '../pomodoro/pomodoro_alerts.dart';
import '../pomodoro/pomodoro_session.dart';
import '../pomodoro/pomodoro_store.dart';
import 'block_overlay.dart';
import 'browser_watcher.dart';
import 'foreground_app.dart';
import 'rule.dart';
import 'rule_store.dart';

const stateChangedSignal = 'blocking.stateChanged';
const applicationId = 'com.example.serensync';
const _screenOnInterval = 1000;
const _screenOffInterval = 60000;
const _permissionCheckInterval = Duration(minutes: 1);
const _idleNotification = (
  title: 'App limits are on',
  text: 'Blocking runs while this is showing.',
);

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
  Set<int> _forced = const <int>{};
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

  /// Rules that block outright until the next call, during a focus session.
  void forceRules(Set<int> ruleIds) {
    _forced = Set<int>.unmodifiable(ruleIds);
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
      always: _forced,
    );
    final address = _addresses[packageName];
    WebAddress? blockedAddress;
    if (decision is Allow && address != null) {
      decision = decideWeb(
        rules: _rules,
        address: address,
        now: now,
        always: _forced,
      );
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

/// Whether the service has work: an enabled block, or a session in focus or
/// on a break. A session waiting for a tap or finished needs nothing running.
bool _enforcementWanted(
  List<BlockRule> rules,
  PomodoroSession? session,
  DateTime now,
) {
  if (rules.any((rule) => rule.enabled)) return true;
  return switch (session?.stateAt(now).phase) {
    PomodoroPhase.focus ||
    PomodoroPhase.shortBreak ||
    PomodoroPhase.longBreak => true,
    _ => false,
  };
}

Future<bool> _enforcementPermitted() async {
  final usageAccess = await UsageStats.checkUsagePermission() ?? false;
  return usageAccess && await FlutterForegroundTask.canDrawOverlays;
}

class BlockingService {
  BlockingService({PomodoroStore? pomodoroStore})
    : _pomodoroStore = pomodoroStore ?? PomodoroStore();

  final PomodoroStore _pomodoroStore;

  Future<bool> get isRunning => FlutterForegroundTask.isRunningService;

  /// Starts or stops the service to match what there is to enforce. Call
  /// after a block or a focus session changes.
  Future<void> sync(RuleStore ruleStore) async {
    final wanted = _enforcementWanted(
      await ruleStore.readAll(),
      await _pomodoroStore.readSession(),
      DateTime.now(),
    );
    final running = await isRunning;
    if (!wanted) {
      if (running) await stop();
    } else if (running) {
      FlutterForegroundTask.sendDataToTask(stateChangedSignal);
    } else if (await _enforcementPermitted()) {
      await start();
    }
  }

  Future<ServiceRequestResult> start() {
    return FlutterForegroundTask.startService(
      serviceTypes: const <ForegroundServiceTypes>[
        ForegroundServiceTypes.specialUse,
      ],
      notificationTitle: _idleNotification.title,
      notificationText: _idleNotification.text,
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
    PomodoroStore? pomodoroStore,
    BrowserWatcher? browserWatcher,
  }) : _engine = engine ?? BlockingEngine(),
       _ruleStore = ruleStore ?? RuleStore(),
       _pomodoroStore = pomodoroStore ?? PomodoroStore(),
       _browserWatcher = browserWatcher ?? BrowserWatcher();

  final BlockingEngine _engine;
  final RuleStore _ruleStore;
  final PomodoroStore _pomodoroStore;
  final BrowserWatcher _browserWatcher;
  StreamSubscription<BrowserAddress>? _addresses;
  bool _tickActive = false;
  Timer? _permissionCheck;
  List<BlockRule> _rules = const <BlockRule>[];
  PomodoroSession? _session;
  PomodoroPhase? _phase;
  Timer? _phaseClock;
  ({String title, String text})? _notification;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await _reload();
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
    if (data == stateChangedSignal) {
      unawaited(_reload());
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _permissionCheck?.cancel();
    _phaseClock?.cancel();
    await _addresses?.cancel();
    await _engine.overlay.hide();
    await _ruleStore.close();
  }

  Future<bool> _checkEnforcementPermissions() async {
    if (await _enforcementPermitted()) return true;
    await _engine.overlay.hide();
    await FlutterForegroundTask.stopService();
    return false;
  }

  Future<void> _runTick(DateTime timestamp) async {
    _tickActive = true;
    try {
      // The phase clock normally lands first; this catches a late timer.
      if (_session?.stateAt(timestamp).phase != _phase) {
        await _applySession(timestamp);
      } else {
        await _showNotification(timestamp);
      }
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

  Future<void> _reload() async {
    // Cancelled before the reads so a boundary cannot fire on stale state.
    _phaseClock?.cancel();
    _rules = await _ruleStore.readAll();
    _engine.replaceRules(_rules);
    _session = await _pomodoroStore.readSession();
    // A phase seen right after a user action is not a transition to alert.
    _phase = null;
    await _applySession(DateTime.now());
  }

  Future<void> _applySession(DateTime now) async {
    final session = _session;
    final phase = session?.stateAt(now).phase;
    _engine.forceRules(
      phase == PomodoroPhase.focus ? session!.ruleIds : const <int>{},
    );
    final previous = _phase;
    _phase = phase;
    _phaseClock?.cancel();
    final next = session?.nextChangeAt(now);
    if (next != null) {
      _phaseClock = Timer(
        next.difference(now) + const Duration(milliseconds: 100),
        () => unawaited(_applySession(DateTime.now())),
      );
    }
    if (previous != null && phase != null && session != null) {
      await showPhaseAlert(phase, session);
    }
    if (!_enforcementWanted(_rules, session, now)) {
      await FlutterForegroundTask.stopService();
      return;
    }
    await _showNotification(now);
  }

  Future<void> _showNotification(DateTime now) async {
    final session = _session;
    final notification = session == null
        ? _idleNotification
        : _sessionNotification(session, session.stateAt(now));
    if (notification == _notification) return;
    _notification = notification;
    await FlutterForegroundTask.updateService(
      notificationTitle: notification.title,
      notificationText: notification.text,
    );
  }
}

({String title, String text}) _sessionNotification(
  PomodoroSession session,
  PomodoroState state,
) {
  final rounds = 'Round ${session.round} of ${session.settings.rounds}';
  final left = '${(state.remaining.inSeconds / 60).ceil()} min left';
  return switch (state.phase) {
    PomodoroPhase.focus => (title: 'Focus, $left', text: rounds),
    PomodoroPhase.shortBreak ||
    PomodoroPhase.longBreak => (title: 'Break, $left', text: '$rounds done'),
    PomodoroPhase.waiting => (
      title: 'Break over',
      text: 'Open SerenSync to start round ${session.round + 1}',
    ),
    PomodoroPhase.finished => _idleNotification,
  };
}

ForegroundTaskOptions _taskOptions(int interval) {
  return ForegroundTaskOptions(
    eventAction: ForegroundTaskEventAction.repeat(interval),
    autoRunOnBoot: true,
    autoRunOnMyPackageReplaced: true,
    allowWakeLock: false,
  );
}
