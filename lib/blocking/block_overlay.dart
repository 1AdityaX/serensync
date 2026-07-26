import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import 'rule.dart';

class BlockOverlay {
  Future<void> show({
    required String packageName,
    required BlockRule rule,
  }) async {
    if (!await FlutterOverlayWindow.isActive()) {
      await FlutterOverlayWindow.showOverlay(
        height: WindowSize.matchParent,
        width: WindowSize.matchParent,
        flag: OverlayFlag.defaultFlag,
        overlayTitle: 'SerenSync',
        overlayContent: rule.name,
      );
      if (!await _waitUntilActive()) {
        FlutterForegroundTask.launchApp();
        return;
      }
    }
    await FlutterOverlayWindow.shareData(<String, String>{
      'packageName': packageName,
      'ruleName': rule.name,
    });
    FlutterForegroundTask.launchApp();
  }

  Future<bool> _waitUntilActive() async {
    // The plugin returns after requesting a service start, before its overlay
    // isolate is necessarily ready to receive the rule payload.
    for (var attempt = 0; attempt < 40; attempt++) {
      if (await FlutterOverlayWindow.isActive()) {
        return true;
      }
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    return false;
  }

  Future<void> hide() async {
    if (await FlutterOverlayWindow.isActive()) {
      await FlutterOverlayWindow.closeOverlay();
    }
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
    }) {
      setState(() {
        _packageName = packageName;
        _ruleName = ruleName;
      });
    }
  }

  Future<void> _returnHome() async {
    await FlutterOverlayWindow.closeOverlay();
    FlutterForegroundTask.launchApp();
  }

  List<Widget> _packageLabel() {
    if (_packageName.isEmpty) {
      return const <Widget>[];
    }
    return <Widget>[
      const SizedBox(height: 12),
      Text(
        _packageName,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xffa9ad9f), fontSize: 14),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
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
              ..._packageLabel(),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _returnHome,
                child: const Text('Return home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
