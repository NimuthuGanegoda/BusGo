import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class Helpers {
  Helpers._();

  static String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  static String formatDuration(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m > 0 ? '${h}h ${m}m' : '${h}h';
  }

  static String formatDistance(double km) {
    if (km < 1) return '${(km * 1000).toInt()}m';
    return '${km.toStringAsFixed(1)} km';
  }

  static String formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static Color statusColor(TripStatus status) {
    switch (status) {
      case TripStatus.idle:      return AppColors.textMuted;
      case TripStatus.active:    return AppColors.tripActive;
      case TripStatus.atStop:    return AppColors.warning;
      case TripStatus.completed: return AppColors.success;
      case TripStatus.emergency: return AppColors.sosRed;
    }
  }

  static String statusLabel(TripStatus status) {
    switch (status) {
      case TripStatus.idle:      return 'Idle';
      case TripStatus.active:    return 'On Route';
      case TripStatus.atStop:    return 'At Stop';
      case TripStatus.completed: return 'Completed';
      case TripStatus.emergency: return 'Emergency';
    }
  }
}

enum TripStatus { idle, active, atStop, completed, emergency }
