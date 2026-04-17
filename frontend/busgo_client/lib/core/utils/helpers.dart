import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class Helpers {
  Helpers._();

  static String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning 👋';
    if (hour < 17) return 'Good afternoon 👋';
    return 'Good evening 👋';
  }

  static Color getCrowdColor(CrowdLevel level) {
    switch (level) {
      case CrowdLevel.low:
        return AppColors.success;
      case CrowdLevel.moderate:
        return AppColors.warning;
      case CrowdLevel.high:
        return AppColors.danger;
    }
  }

  static String getCrowdLabel(CrowdLevel level) {
    switch (level) {
      case CrowdLevel.low:
        return 'Low';
      case CrowdLevel.moderate:
        return 'Moderate';
      case CrowdLevel.high:
        return 'High';
    }
  }

  static double getCrowdPercentage(CrowdLevel level) {
    switch (level) {
      case CrowdLevel.low:
        return 0.3;
      case CrowdLevel.moderate:
        return 0.6;
      case CrowdLevel.high:
        return 0.85;
    }
  }

  static Color getEtaColor(int minutes) {
    if (minutes <= 5) return AppColors.success;
    if (minutes <= 10) return AppColors.warning;
    return AppColors.danger;
  }
}

enum CrowdLevel { low, moderate, high }
