import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../screens/login_page.dart';

class TicketService {
  // Cloud Functions のリージョン指定
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');

  // ログインチェック
  Future<void> ensureSignedIn(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // ログインしていなければログイン画面に遷移
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
      // この後の処理を止める
      throw Exception("User not logged in");
    }
  }

  Future<void> startTimer(BuildContext context) async {
    await ensureSignedIn(context);
    try {
      await _functions.httpsCallable('startTimer').call();
    } catch (e) {
      print("StartTimer Error: $e");
    }
  }

  Future<int> stopTimer(BuildContext context) async {
    await ensureSignedIn(context);
    try {
      final result = await _functions.httpsCallable('stopTimer').call();
      return result.data['remaining_seconds'] ?? 0;
    } catch (e) {
      print("StopTimer Error: $e");
      return 0;
    }
  }
  Future<int> getRemainingTime(BuildContext context) async {
    await ensureSignedIn(context);
    try {
      final result =
          await _functions.httpsCallable('getRemainingTime').call();

      return result.data['remaining_seconds'] ?? 0;
    } catch (e) {
      print("GetRemaining Error: $e");
      return 0;
    }
  }
}