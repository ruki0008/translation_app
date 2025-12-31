import 'package:dio/dio.dart';

class ApiService {
  final Dio _dio = Dio();
  final String baseUrl = 'http://192.168.11.9:8000';

  /// 音声アップロード → 文字起こし + 翻訳 + プロンプト
  Future<Map<String, String>?> transcribeAndTranslate(
    String filePath, {
    String? prompt,   // ← ★ 追加
  }) async {
    try {
      FormData formData = FormData.fromMap({
        "file": await MultipartFile.fromFile(
          filePath,
          filename: "audio.m4a",
        ),

        // 🔹 Firestore などから取得した固有名詞辞書
        if (prompt != null && prompt.isNotEmpty)
          "prompt": prompt,
      });

      final Response response = await _dio.post(
        "$baseUrl/whisper/onnx",
        data: formData,
      );

      if (response.statusCode == 200) {
        final transcript = response.data["transcript"] ?? "";
        final translation = response.data["translation"] ?? "";

        return {
          "text": transcript,
          "translation": translation,
        };
      }

      return null;
    } catch (e) {
      print("通信エラー: $e");
      return null;
    }
  }
}