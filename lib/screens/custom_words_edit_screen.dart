import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CustomWordsEditPage extends StatefulWidget {
  const CustomWordsEditPage({super.key});

  @override
  State<CustomWordsEditPage> createState() => _CustomWordsEditPageState();
}

class _CustomWordsEditPageState extends State<CustomWordsEditPage> {
  final user = FirebaseAuth.instance.currentUser;
  final firestore = FirebaseFirestore.instance;

  final List<TextEditingController> _controllers =
      List.generate(20, (_) => TextEditingController());

  @override
  void initState() {
    super.initState();
    _loadExistingWords();
  }

  Future<void> _loadExistingWords() async {
    if (user == null) return;

    final doc =
        await firestore.collection("custom_words").doc(user!.uid).get();

    final words =
        (doc.data()?["words"] as List<dynamic>? ?? []).cast<String>();

    for (int i = 0; i < words.length && i < 20; i++) {
      _controllers[i].text = words[i];
    }

    setState(() {});
  }

  Future<void> _save() async {
    if (user == null) return;

    final words = _controllers
        .map((c) => c.text.trim())
        .where((w) => w.isNotEmpty)
        .toList();

    await firestore.collection("custom_words").doc(user!.uid).set({
      "words": words,
      "updated_at": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!mounted) return;
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("固有名詞を保存しました")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("固有名詞（最大20件）")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (int i = 0; i < 20; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: TextField(
                controller: _controllers[i],
                decoration: InputDecoration(
                  labelText: "固有名詞 ${i + 1}",
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
            child: const Text("登録"),
          ),
        ],
      ),
    );
  }
}