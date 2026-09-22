import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:tamper_guard/tamper_guard.dart';

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
    await _shareData(<String, String>{
      'packageName': packageName,
      'ruleName': ruleName,
      'host': host,
    });
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

  static Future<void> _show(String ruleName) {
    return FlutterOverlayWindow.showOverlay(
      height: WindowSize.matchParent,
      width: WindowSize.matchParent,
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
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _BlockScreen(),
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
  String _packageName = '';
  String _host = '';
  String _ruleName = 'A blocking rule';

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
      'packageName': final String packageName,
      'ruleName': final String ruleName,
      'host': final String host,
    }) {
      setState(() {
        _packageName = packageName;
        _ruleName = ruleName;
        _host = host;
      });
    }
  }

  Future<void> _leave() async {
    await FlutterOverlayWindow.closeOverlay();
    if (_host.isEmpty) {
      FlutterForegroundTask.launchApp();
    } else {
      await TamperGuard.performGlobalAction(GuardAction.back);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subject = _host.isEmpty ? _packageName : _host;
    return Material(
      color: const Color(0xff12130f),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(
                Icons.lock_outline,
                color: Color(0xffd8e2c4),
                size: 48,
              ),
              const SizedBox(height: 24),
              Text(
                'Blocked by $_ruleName',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xfff3f4ed),
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subject.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  subject,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xffa9ad9f),
                    fontSize: 14,
                  ),
                ),
              ],
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _leave,
                child: Text(_host.isEmpty ? 'Return home' : 'Go back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
