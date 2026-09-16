import 'package:flutter_test/flutter_test.dart';
import 'package:serensync/main_app/blocking/rule.dart';

void main() {
  final now = DateTime(2026, 9, 16, 10);
  const usage = AppUsage(foregroundTime: Duration.zero, launches: 0);
  const paused = BlockRule(
    id: 1,
    name: 'Social',
    packages: <String>{'com.example.social'},
    websites: <String>{'social.example'},
    trigger: LaunchQuota(10),
    enabled: false,
  );

  test('a forced rule blocks its apps whatever its trigger or state', () {
    expect(
      decide(
        rules: const [paused],
        package: 'com.example.social',
        now: now,
        usage: usage,
      ),
      isA<Allow>(),
    );
    final decision = decide(
      rules: const [paused],
      package: 'com.example.social',
      now: now,
      usage: usage,
      always: const {1},
    );
    expect(decision, isA<Block>());
    expect((decision as Block).rule.name, 'Social');
  });

  test('a forced rule blocks its websites, but only its own', () {
    expect(
      decideWeb(
        rules: const [paused],
        address: (host: 'social.example', url: 'https://social.example/'),
        now: now,
        always: const {1},
      ),
      isA<Block>(),
    );
    expect(
      decideWeb(
        rules: const [paused],
        address: (host: 'news.example', url: 'https://news.example/'),
        now: now,
        always: const {1},
      ),
      isA<Allow>(),
    );
    expect(
      decide(
        rules: const [paused],
        package: 'com.example.other',
        now: now,
        usage: usage,
        always: const {1},
      ),
      isA<Allow>(),
    );
  });
}
