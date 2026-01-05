import 'package:google_mobile_ads/google_mobile_ads.dart';

class RewardAdService {
  RewardedAd? _ad;

  Future<void> load() async {
    await RewardedAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111', //本番差し替え
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _ad = ad,
        onAdFailedToLoad: (_) => _ad = null,
      ),
    );
  }

  Future<bool> showAndWaitReward() async {
    if (_ad == null) {
      await load();
      if (_ad == null) return false;
    }

    bool rewarded = false;

    await _ad!.show(
      onUserEarnedReward: (_, __) {
        rewarded = true;
      },
    );

    _ad = null; // 再利用しない
    await load(); // 事前ロード

    return rewarded;
  }
}