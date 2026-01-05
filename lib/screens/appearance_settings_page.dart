import 'package:flutter/material.dart';

class AppearanceSettingsPage extends StatefulWidget {
  final Color backgroundColor;
  final double fontSize;
  final String fontFamily;

  const AppearanceSettingsPage({
    super.key,
    required this.backgroundColor,
    required this.fontSize,
    required this.fontFamily,
  });

  @override
  State<AppearanceSettingsPage> createState() =>
      _AppearanceSettingsPageState();
}

class _AppearanceSettingsPageState extends State<AppearanceSettingsPage> {
  late Color _color;
  late double _size;
  late String _font;

  @override
  void initState() {
    super.initState();
    _color = widget.backgroundColor;
    _size = widget.fontSize;
    _font = widget.fontFamily;
  }

  // 🎯 どの戻り方でも値を返す共通関数
  void _returnSettings() {
    Navigator.pop(context, {
      "color": _color,
      "size": _size,
      "font": _font,
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // ←戻る / スワイプでも保存して戻る
      onWillPop: () async {
        _returnSettings();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("背景・文字設定"),
          actions: [
            TextButton(
              onPressed: _returnSettings,
              child: const Text(
                "保存",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("背景色"),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _colorButton(Colors.white),
                  _colorButton(Colors.black12),
                  _colorButton(Colors.yellow.shade100),
                  _colorButton(Colors.blue.shade50),
                ],
              ),

              const SizedBox(height: 24),
              const Text("文字サイズ"),
              Slider(
                min: 12,
                max: 32,
                value: _size,
                onChanged: (v) => setState(() => _size = v),
              ),

              const SizedBox(height: 24),
              const Text("フォント"),
              DropdownButton<String>(
                value: _font,
                items: const [
                  DropdownMenuItem(value: "System", child: Text("標準")),
                  DropdownMenuItem(value: "serif", child: Text("Serif")),
                  DropdownMenuItem(
                      value: "monospace", child: Text("Monospace")),
                ],
                onChanged: (v) => setState(() => _font = v!),
              ),

              const SizedBox(height: 24),
              const Text("プレビュー"),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                color: _color,
                child: Text(
                  "こんにちは\nプレビューです",
                  style: TextStyle(
                    fontSize: _size,
                    fontFamily: _font == "System" ? null : _font,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _colorButton(Color c) {
    return GestureDetector(
      onTap: () => setState(() => _color = c),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: c,
          border: Border.all(
            color: _color == c ? Colors.blue : Colors.grey,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }
}