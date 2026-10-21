import 'package:flutter_test/flutter_test.dart';
import 'package:serensync/main_app/blocking/rule.dart';
import 'package:serensync/main_app/onboarding/plan.dart';

void main() {
  test('each goal starts from its own kind of block', () {
    expect(goalTrigger(Goal.scrolling), isA<UsageQuota>());
    expect(goalTrigger(Goal.pickups), isA<LaunchQuota>());
    final work = goalTrigger(Goal.work) as Schedule;
    expect(work.weekdays, hasLength(5));
    expect(work.weekdays, isNot(contains(DateTime.saturday)));
    final nights = goalTrigger(Goal.nights) as Schedule;
    expect(nights.weekdays, hasLength(7));
    expect(nights.startMinute > nights.endMinute, isTrue);
  });

  test('a window across midnight still has a length', () {
    expect(windowMinutes(goalTrigger(Goal.nights) as Schedule), 9 * 60);
    expect(windowMinutes(goalTrigger(Goal.work) as Schedule), 8 * 60);
  });

  test('the ring maps to five-minute steps with a floor', () {
    const quota = UsageQuota(Duration(minutes: 45));
    expect(limitFraction(quota), 45 / 240);
    expect((quotaAt(quota, 0) as UsageQuota).limit, const Duration(minutes: 5));
    expect(
      (quotaAt(quota, 0.26) as UsageQuota).limit,
      const Duration(minutes: 60),
    );
    expect((quotaAt(const LaunchQuota(5), 0) as LaunchQuota).limit, 1);
    expect((quotaAt(const LaunchQuota(5), 0.5) as LaunchQuota).limit, 15);
    expect(limitFraction(goalTrigger(Goal.work)), 8 / 24);
  });

  test('the plan sentence agrees with one app or many', () {
    expect(
      planSentence(['Instagram'], const UsageQuota(Duration(minutes: 45))),
      'Instagram closes after 45m a day.',
    );
    expect(
      planSentence(['Instagram', 'TikTok'], const LaunchQuota(1)),
      'Instagram and TikTok close after 1 open a day.',
    );
    expect(
      planSentence(['A', 'B', 'C'], goalTrigger(Goal.nights)),
      'A and 2 more stay closed Mon–Sun, 22:00–07:00.',
    );
  });

  test('chips keep to a few words', () {
    expect(appsChip(['Instagram']), 'Instagram');
    expect(appsChip(['Instagram', 'TikTok', 'X']), 'Instagram +2');
    expect(limitChip(const UsageQuota(Duration(minutes: 90))), '1h 30m a day');
    expect(limitChip(const LaunchQuota(1)), '1 open a day');
    expect(limitChip(goalTrigger(Goal.work)), '09:00–17:00');
  });
}
