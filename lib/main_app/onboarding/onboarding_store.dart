import 'package:shared_preferences/shared_preferences.dart';

class OnboardingStore {
  static const _completeKey = 'onboarding.complete';

  Future<bool> get isComplete async =>
      await SharedPreferencesAsync().getBool(_completeKey) ?? false;

  Future<void> markComplete() =>
      SharedPreferencesAsync().setBool(_completeKey, true);
}
