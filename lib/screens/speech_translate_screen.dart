import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SpeechTranslatePage extends StatefulWidget {
  const SpeechTranslatePage({super.key});

  @override
  State<SpeechTranslatePage> createState() => _SpeechTranslatePageState();
}

class _SpeechTranslatePageState extends State<SpeechTranslatePage> {
  final SpeechToText _speechToText = SpeechToText();
  static const int maxHistory = 8;

  bool _speechEnabled = false;
  bool _isContinuous = false;

  String _currentPartial = '';
  String _currentLocaleId = '';

  List<_SpeechPair> _history = [];
  List<LocaleName> _locales = [];
  BannerAd? _banner;

  // 🔸 リワード管理変数
  static const int rewardLimitPerDay = 3;
  static const int rewardMinutes = 15;

  int rewardUsedCount = 0;
  DateTime? rewardExpireTime;
  String lastUsedDate = "";

  RewardedAd? _rewardAd;

  @override
  void initState() {
    super.initState();
    _loadRewardState();
    _loadBanner();
    _loadRewardAd();
    _initSpeech();
  }

  // 🟡 端末に保存している利用状況を読み込み
  Future<void> _loadRewardState() async {
    final prefs = await SharedPreferences.getInstance();
    rewardUsedCount = prefs.getInt("rewardUsedCount") ?? 0;
    lastUsedDate = prefs.getString("lastUsedDate") ?? "";
    final expireMs = prefs.getInt("rewardExpireTime");
    if (expireMs != null) {
      rewardExpireTime = DateTime.fromMillisecondsSinceEpoch(expireMs);
    }

    final today = _today();

    // 🔁 日付が変わっていたらリセット
    if (lastUsedDate != today) {
      rewardUsedCount = 0;
      rewardExpireTime = null;
      lastUsedDate = today;
      await _saveRewardState();
    }

    setState(() {});
  }

  Future<void> _saveRewardState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt("rewardUsedCount", rewardUsedCount);
    await prefs.setString("lastUsedDate", lastUsedDate);
    await prefs.setInt(
        "rewardExpireTime", rewardExpireTime?.millisecondsSinceEpoch ?? 0);
  }

  String _today() {
    final now = DateTime.now();
    return "${now.year}-${now.month}-${now.day}";
  }

  // 🔹 バナー
  void _loadBanner() {
    _banner = BannerAd(
      size: AdSize.banner,
      adUnitId: 'ca-app-pub-3940256099942544/6300978111',
      listener: BannerAdListener(),
      request: const AdRequest(),
    )..load();
  }

  // 🔹 リワード広告のロード
  void _loadRewardAd() {
    RewardedAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/5224354917',
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewardAd = ad,
        onAdFailedToLoad: (e) => _rewardAd = null,
      ),
    );
  }

  // 🟣 リワード発動処理
  Future<void> _showReward() async {
    if (rewardUsedCount >= rewardLimitPerDay) {
      _showInfo("今日はリワード上限に達しました\n→ 月額プラン導線へ");
      return;
    }

    if (_rewardAd == null) {
      _showInfo("広告読み込み中… しばらくして再度お試しください");
      _loadRewardAd();
      return;
    }

    _rewardAd!.show(onUserEarnedReward: (_, reward) async {
      final now = DateTime.now();
      rewardExpireTime = now.add(const Duration(minutes: rewardMinutes));
      rewardUsedCount++;
      lastUsedDate = _today();

      await _saveRewardState();
      _loadRewardAd();

      _showInfo("15分間 広告なしで利用できます");
      setState(() {});
    });
  }

  bool get isRewardActive {
    if (rewardExpireTime == null) return false;
    return DateTime.now().isBefore(rewardExpireTime!);
  }

  void _showInfo(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ======== 音声処理ここから ========

  Future<void> _initSpeech() async {
    _speechEnabled = await _speechToText.initialize(
      onStatus: _onSpeechStatus,
      onError: (error) => debugPrint("Speech error: $error"),
    );

    if (_speechEnabled) {
      _locales = await _speechToText.locales();
      final ja = _locales.firstWhere(
        (l) => l.localeId.startsWith("ja"),
        orElse: () => _locales.first,
      );
      _currentLocaleId = ja.localeId;
    }
  }

  void _onSpeechStatus(String status) {
    if (status == "done" && _isContinuous) {
      _listenOnce();
    }
  }

  Future<void> _startListening() async {
    // 🔺 広告なし時間が切れていたらリワード要求
    if (!isRewardActive) {
      _showInfo("15分無料利用するにはリワード広告を視聴してください");
      await _showReward();
      if (!isRewardActive) return;
    }

    if (!_speechEnabled) return;

    if (_speechToText.isListening) {
      await _speechToText.stop();
      await _speechToText.cancel();
    }

    setState(() {
      _isContinuous = true;
      _currentPartial = '';
      _history.clear();
    });

    _listenOnce();
  }

  Future<void> _listenOnce() async {
    if (!_isContinuous) return;

    // ⏳ 15分を超えたら停止
    if (!isRewardActive) {
      await _stopListening();
      _showInfo("15分を超えました → 再度リワードを見て続ける");
      return;
    }

    await _speechToText.listen(
      localeId: _currentLocaleId,
      partialResults: true,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 2),
      listenMode: ListenMode.dictation,
      onResult: (result) async {
        setState(() {
          _currentPartial = result.recognizedWords;
        });

        if (result.finalResult && result.recognizedWords.isNotEmpty) {
          final jaText = result.recognizedWords;
          final enText = await translateText(jaText);

          setState(() {
            _history.add(_SpeechPair(jaText, enText));
            if (_history.length > maxHistory) {
              _history.removeAt(0);
            }
            _currentPartial = '';
          });
        }
      },
    );
  }

  Future<void> _stopListening() async {
    setState(() => _isContinuous = false);
    await _speechToText.stop();
    await _speechToText.cancel();
  }

  Future<String> translateText(String text) async {
    try {
      final uri = Uri.parse('http://192.168.11.9:8000/speech/onnx');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text}),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['translation'] ?? '';
      }
      return '翻訳失敗';
    } catch (_) {
      return '翻訳エラー';
    }
  }

  @override
  Widget build(BuildContext context) {
    final remain =
        isRewardActive ? rewardExpireTime!.difference(DateTime.now()) : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text("音声文字起こし翻訳（広告リワード）"),
      ),
      body: Column(
        children: [
          if (isRewardActive)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                "広告なし残り ${remain!.inMinutes}:${(remain.inSeconds % 60).toString().padLeft(2,'0')}",
                style: const TextStyle(color: Colors.green),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                "今日はあと ${rewardLimitPerDay - rewardUsedCount} 回リワード可能",
                style: const TextStyle(color: Colors.red),
              ),
            ),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _history.length + (_currentPartial.isNotEmpty ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _history.length) {
                  return Text(_currentPartial,
                      style: const TextStyle(fontSize: 20));
                }
                final item = _history[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.ja,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(item.en,
                          style: const TextStyle(
                              fontSize: 20, color: Colors.blue)),
                    ],
                  ),
                );
              },
            ),
          ),

          ElevatedButton.icon(
            onPressed: _isContinuous ? _stopListening : _startListening,
            icon: Icon(_isContinuous ? Icons.stop : Icons.mic),
            label: Text(_isContinuous ? "停止" : "話す"),
          ),

          const SizedBox(height: 10),

          // 🔻 リワードボタン
          ElevatedButton(
            onPressed: _showReward,
            child: const Text("15分無料で使う（リワード再生）"),
          ),

          const SizedBox(height: 10),

          // 🔻 底バナー
          if (_banner != null && !isRewardActive)
            SafeArea(
              child: SizedBox(
                height: _banner!.size.height.toDouble(),
                width: _banner!.size.width.toDouble(),
                child: AdWidget(ad: _banner!),
              ),
            ),
        ],
      ),
    );
  }
}

class _SpeechPair {
  final String ja;
  final String en;
  _SpeechPair(this.ja, this.en);
}