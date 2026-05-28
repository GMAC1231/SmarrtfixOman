import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'FIXME_API_BASE_URL',
    defaultValue: 'http://192.168.100.15:5000',
  );

  static Uri _uri(String path) => Uri.parse('$baseUrl$path');

  static Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final res = await http
        .post(
          _uri(path),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));

    final decoded = res.body.isEmpty ? <String, dynamic>{} : jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return Map<String, dynamic>.from(decoded as Map);
    }
    throw Exception('API $path failed (${res.statusCode}): ${res.body}');
  }

  static Future<Map<String, dynamic>> registerUser({
    required String email,
    required String name,
    required String role,
  }) {
    return _post('/register', {
      'email': email,
      'name': name,
      'role': role,
    });
  }

  static Future<Map<String, dynamic>> updateCustomerProfile({
    required String email,
    required String name,
    required String phone,
    required String city,
    required String address,
    required String gender,
  }) {
    return _post('/update-profile', {
      'email': email,
      'name': name,
      'role': 'customer',
      'phone': phone,
      'city': city,
      'address': address,
      'gender': gender,
    });
  }

  static Future<Map<String, dynamic>> updateEmployeeProfile({
    required String email,
    required String name,
    required String profession,
    required String professionEmoji,
    required double fare,
    required String license,
    required String carPlate,
    required String? profileImage,
    required String phone,
    required String city,
    required String address,
    required String gender,
  }) {
    return _post('/update-profile', {
      'email': email,
      'name': name,
      'role': 'employee',
      'phone': phone,
      'city': city,
      'address': address,
      'gender': gender,
      'profession': profession,
      'professionEmoji': professionEmoji,
      'fare': fare,
      'license': license,
      'carPlate': carPlate,
      'profileImage': profileImage,
    });
  }
}
