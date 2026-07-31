import 'package:flutter/services.dart';

class LauncherController {
  static const _channel = MethodChannel('serensync/launcher');

  Future<bool> get isEnabled async {
    try {
      return await _channel.invokeMethod<bool>('isEnabled') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> get openedAsLauncher async {
    try {
      return await _channel.invokeMethod<bool>('openedAsLauncher') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> setEnabled(bool enabled) async {
    await _channel.invokeMethod<void>('setEnabled', enabled);
  }

  void listenForPresentationChanges(ValueChanged<bool> onChanged) {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'showLauncher':
          onChanged(true);
        case 'showMainApp':
          onChanged(false);
      }
    });
  }

  void stopListening() {
    _channel.setMethodCallHandler(null);
  }
}
