import 'package:dio/dio.dart';

class ApiService {
  final Dio _dio = Dio();
  final String baseUrl = 'http://192.168.11.9:8000';

  /// 音声アップロード → 文字起こし + 翻訳
  Future<Map<String, String>?> transcribeAndTranslate(String filePath) async {
    try {
      FormData formData = FormData.fromMap({
        "file": await MultipartFile.fromFile(filePath, filename: "audio.m4a"),
      });

      Response response = await _dio.post(
        "$baseUrl/translate_transcribe",
        data: formData,
      );

      if (response.statusCode == 200) {
        // サーバー側のキーに合わせて取得
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