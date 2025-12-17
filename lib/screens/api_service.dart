import 'package:dio/dio.dart';

class ApiService {
  final Dio _dio = Dio();
  // ローカル実行時はサーバーのIPアドレス（例: 10.0.2.2 はAndroidエミュレータ用）
  final String baseUrl = 'http://192.168.11.9:8000';

  Future<String?> uploadAndTranscribe(String filePath) async {
    try {
      FormData formData = FormData.fromMap({
        "file": await MultipartFile.fromFile(filePath, filename: "audio.m4a"),
      });

      Response response = await _dio.post(
        "$baseUrl/transcribe",
        data: formData,
      );

      return response.data["text"];
    } catch (e) {
      print("通信エラー: $e");
      return null;
    }
  }
}