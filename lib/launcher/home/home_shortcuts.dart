import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';

const _flags = <int>[
  Flag.FLAG_ACTIVITY_NEW_TASK,
  Flag.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED,
];

const _dialerIntent = AndroidIntent(
  action: 'android.intent.action.DIAL',
  data: 'tel:',
  flags: _flags,
);

const _cameraIntent = AndroidIntent(
  action: 'android.media.action.STILL_IMAGE_CAMERA',
  flags: _flags,
);

Future<void> openDialer() => _dialerIntent.launch();

Future<void> openCamera() => _cameraIntent.launch();
