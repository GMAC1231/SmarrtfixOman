import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class ChatApi {
  static const String baseUrl = "http://192.168.100.15:5000";

  /// 🔥 UPLOAD IMAGE
  static Future<String?> uploadImage({
    required File file,
    required String token,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse("$baseUrl/api/chat/upload-image"),
    );

    request.headers['Authorization'] = "Bearer $token";

    request.files.add(
      await http.MultipartFile.fromPath('file', file.path),
    );

    final res = await request.send();
    final body = await res.stream.bytesToString();
    final data = jsonDecode(body);

    return data['url'];
  }

  /// 🔥 SEND MESSAGE (TEXT OR IMAGE)
  static Future<void> sendMessage({
    required String chatId,
    required String token,
    String? text,
    String? imageUrl,
  }) async {
    await http.post(
      Uri.parse("$baseUrl/api/chat/send"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token"
      },
      body: jsonEncode({
        "chatId": chatId,
        "text": text,
        "imageUrl": imageUrl,
        "type": imageUrl != null ? "image" : "text"
      }),
    );
  }
}