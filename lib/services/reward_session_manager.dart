import 'package:shared_preferences/shared_preferences.dart';

class RewardSessionManager {
  static const _kUnlockUntil = 'unlock_until';
  static const _kRewardCount = 'reward_count';
  static const _kRewardDate = 'reward_date';

  static const sessionMinutes = 15;
  static const maxRewardsPerDay = 3;

  DateTime _now() => DateTime.now();

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<void> _resetIfNewDay() async {
    final p = await _prefs();
    final today = _dateKey(_now());
    final saved = p.getString(_kRewardDate);

    if (saved != today) {
      await p.setString(_kRewardDate, today);
      await p.setInt(_kRewardCount, 0);
    }
  }

  String _dateKey(DateTime d) =>
      "${d.year}-${d.month}-${d.day}"; // ← 0時でリセット基準

  /// 現在使える状態か？
  Future<bool> isUnlocked() async {
    final p = await _prefs();
    final untilMs = p.getInt(_kUnlockUntil);
    if (untilMs == null) return false;

    final until = DateTime.fromMillisecondsSinceEpoch(untilMs);
    return _now().isBefore(until);
  }

  /// 残り時間（秒）
  Future<int> remainingSeconds() async {
    final p = await _prefs();
    final untilMs = p.getInt(_kUnlockUntil);
    if (untilMs == null) return 0;

    final until = DateTime.fromMillisecondsSinceEpoch(untilMs);
    final diff = until.difference(_now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  /// 今日の視聴回数
  Future<int> rewardCountToday() async {
    await _resetIfNewDay();
    final p = await _prefs();
    return p.getInt(_kRewardCount) ?? 0;
  }

  /// 上限に達している？
  Future<bool> isOverLimit() async {
    return (await rewardCountToday()) >= maxRewardsPerDay;
  }

  /// 15分付与（視聴完了後に呼ぶ）
  Future<void> grantSession() async {
    await _resetIfNewDay();
    final p = await _prefs();

    final until = _now().add(
      const Duration(minutes: sessionMinutes),
    );

    await p.setInt(_kUnlockUntil, until.millisecondsSinceEpoch);

    final used = await rewardCountToday();
    await p.setInt(_kRewardCount, used + 1);
  }
}