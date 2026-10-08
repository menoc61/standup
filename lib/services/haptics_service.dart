import 'package:flutter/services.dart';

class HapticsService {
  static bool enabled = true;

  static Future<void> selection() async {
    if (!enabled) return;
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }

  static Future<void> light() async {
    if (!enabled) return;
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }

  static Future<void> medium() async {
    if (!enabled) return;
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  static Future<void> heavy() async {
    if (!enabled) return;
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  static Future<void> celebration() async {
    if (!enabled) return;
    try {
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 120));
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  static Future<void> vibrate() async {
    if (!enabled) return;
    try {
      await HapticFeedback.vibrate();
    } catch (_) {}
  }
}
