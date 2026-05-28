import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'PakistanFixMe';
  static const String adminEmail = 'pakistanfixme.service1@gmail.com';
  static const Color brand = Color(0xFF01411C);
  static const Color brandLight = Color(0xFF0E7A35);
  static const Color surface = Color(0xFFF5F7F6);

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
}
