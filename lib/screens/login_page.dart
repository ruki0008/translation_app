import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final auth = AuthService();
  final email = TextEditingController();
  final password = TextEditingController();
  bool isLoginMode = true;

  Future<void> submit() async {
    try {
      if (isLoginMode) {
        await auth.signIn(email.text, password.text);
      } else {
        await auth.signUp(email.text, password.text);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isLoginMode ? "ログイン" : "新規登録")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: email, decoration: const InputDecoration(labelText: "メールアドレス")),
            TextField(
              controller: password,
              decoration: const InputDecoration(labelText: "パスワード"),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: submit,
              child: Text(isLoginMode ? "ログイン" : "登録"),
            ),
            TextButton(
              onPressed: () => setState(() => isLoginMode = !isLoginMode),
              child: Text(isLoginMode ? "新規登録に切り替え" : "ログインに切り替え"),
            ),
            const Divider(height: 32),
            ElevatedButton(
              onPressed: auth.signInWithGoogle,
              child: const Text("Googleでログイン"),
            ),
          ],
        ),
      ),
    );
  }
}