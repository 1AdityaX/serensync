import 'dart:async';

import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:tamper_guard/tamper_guard.dart';

import '../../theme.dart';
import 'blocking_colors.dart';
import 'rule.dart';

class BlockOverlay {
  BlockOverlay({
    Future<bool> Function()? isActive,
    Future<void> Function(String ruleName)? showOverlay,
    Future<void> Function(Map<String, String> data)? shareData,
    Future<void> Function()? closeOverlay,
    void Function()? launchApp,
  }) : _isActive = isActive ?? FlutterOverlayWindow.isActive,
       _showOverlay = showOverlay ?? _show,
       _shareData = shareData ?? FlutterOverlayWindow.shareData,
       _closeOverlay = closeOverlay ?? FlutterOverlayWindow.closeOverlay,
       _launchApp = launchApp ?? FlutterForegroundTask.launchApp;

  final Future<bool> Function() _isActive;
  final Future<void> Function(String ruleName) _showOverlay;
  final Future<void> Function(Map<String, String> data) _shareData;
  final Future<void> Function() _closeOverlay;
  final void Function() _launchApp;
  String? _visiblePackage;
  String? _visibleHost;
  String? _visibleRuleName;

  /// Shows the block screen named after [ruleName] over [packageName]. Pass
  /// [address] when a page inside the app is what is blocked.
  Future<void> show({
    required String packageName,
    required String ruleName,
    WebAddress? address,
  }) async {
    final host = address?.host ?? '';
    final active = await _isActive();
    if (active &&
        packageName == _visiblePackage &&
        host == _visibleHost &&
        ruleName == _visibleRuleName) {
      return;
    }

    if (!active) {
      await _showOverlay(ruleName);
      if (!await _waitUntilActive()) {
        _launchApp();
        return;
      }
    }
    await _shareData(<String, String>{'ruleName': ruleName, 'host': host});
    _visiblePackage = packageName;
    _visibleHost = host;
    _visibleRuleName = ruleName;
  }

  Future<bool> _waitUntilActive() async {
    // The plugin returns after requesting a service start, before its overlay
    // isolate is necessarily ready to receive the rule payload.
    for (var attempt = 0; attempt < 40; attempt++) {
      if (await _isActive()) {
        return true;
      }
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    return false;
  }

  Future<void> hide() async {
    _visiblePackage = null;
    _visibleHost = null;
    _visibleRuleName = null;
    if (await _isActive()) {
      await _closeOverlay();
    }
  }

  // The plugin centres the window and then nudges it up by the status bar
  // height, which it wrongly treats as dp, so the bottom of the screen is
  // left bare. Pinning the top-left corner at the origin with a height that
  // overshoots the display covers everything.
  static Future<void> _show(String ruleName) {
    return FlutterOverlayWindow.showOverlay(
      height: WindowSize.fullCover,
      width: WindowSize.matchParent,
      alignment: OverlayAlignment.topLeft,
      startPosition: const OverlayPosition(0, 0),
      flag: OverlayFlag.defaultFlag,
      overlayTitle: 'SerenSync',
      overlayContent: ruleName,
    );
  }
}

class BlockOverlayApp extends StatelessWidget {
  const BlockOverlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      home: const _BlockScreen(),
    );
  }
}

class _BlockScreen extends StatefulWidget {
  const _BlockScreen();

  @override
  State<_BlockScreen> createState() => _BlockScreenState();
}

class _BlockScreenState extends State<_BlockScreen> {
  StreamSubscription<Object?>? _messages;
  String _host = '';
  String _ruleName = 'A block';

  @override
  void initState() {
    super.initState();
    final events = FlutterOverlayWindow.overlayListener.cast<Object?>();
    _messages = events.listen(_receive);
  }

  @override
  void dispose() {
    unawaited(_messages?.cancel());
    super.dispose();
  }

  void _receive(Object? message) {
    if (message case {
      'ruleName': final String ruleName,
      'host': final String host,
    }) {
      setState(() {
        _ruleName = ruleName;
        _host = host;
      });
    }
  }

  Future<void> _leave() async {
    await FlutterOverlayWindow.closeOverlay();
    if (_host.isEmpty) {
      await const AndroidIntent(
        action: 'android.intent.action.MAIN',
        category: 'android.intent.category.HOME',
        flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
      ).launch();
    } else {
      await TamperGuard.performGlobalAction(GuardAction.back);
    }
  }

  @override
  Widget build(BuildContext context) {
    // The window is taller than the display, so centre on the visible part.
    final view = View.of(context);
    final overshoot =
        (view.physicalSize.height - view.display.size.height) /
        view.devicePixelRatio;
    return Material(
      color: BlockingColors.background,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            32,
            32,
            32,
            32 + overshoot.clamp(0, 400),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: BlockingColors.accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline,
                  color: BlockingColors.accent,
                  size: 32,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Blocked',
                textAlign: TextAlign.center,
                style: sectionLabel,
              ),
              const SizedBox(height: 6),
              Text(
                _ruleName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                ),
              ),
              if (_host.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _host,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: BlockingColors.textMuted,
                  ),
                ),
              ],
              const SizedBox(height: 36),
              FilledButton(
                onPressed: _leave,
                child: Text(_host.isEmpty ? 'Go home' : 'Go back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
