import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'speech_translate_screen.dart';
import 'whisper_stt_azure_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ホーム'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "ログアウト",
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              // AuthGate が自動で LoginPage に戻します
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.mic),
              label: const Text('音声文字起こし翻訳無料'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SpeechTranslatePage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.cloud),
              label: const Text('音声文字起こし翻訳有料'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const WhisperAzureTranslatePage(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}