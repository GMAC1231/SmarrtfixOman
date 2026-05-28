import 'package:flutter/material.dart';

class AppConstants {
  AppConstants._();

  static const String appName = 'PakistanFixMe';
  static const String adminEmail = 'pakistanfixme.service1@gmail.com';

  static const Color brand = Color(0xFF01411C);
  static const Color brandLight = Color(0xFF0E7A35);
  static const Color surface = Color(0xFFF5F7F6);
  static const Color success = Color(0xFF16A34A);
  static const Color danger = Color(0xFFDC2626);
  static const Color warning = Color(0xFFF59E0B);

  static const List<String> serviceTypes = <String>[
    'Technician',
    'Plumber',
    'Electrician',
    'Carpenter',
    'Painter',
    'Handyman',
    'Cleaner',
  ];

  static const Map<String, String> serviceEmoji = <String, String>{
    'Technician': '🔧',
    'Plumber': '🚰',
    'Electrician': '💡',
    'Carpenter': '🪚',
    'Painter': '🎨',
    'Handyman': '🛠️',
    'Cleaner': '🧹',
  };

  static String serviceLabel(String serviceType) {
    final cleaned = serviceType.trim();
    final emoji = serviceEmoji[cleaned] ?? '🛠️';
    return '$emoji $cleaned';
  }
}
