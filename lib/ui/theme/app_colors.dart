import 'package:flutter/material.dart';

class AppColors {
  // ターミナル風ダークテーマカラー
  static const Color background = Color(0xFF0D1117);
  static const Color surface = Color(0xFF161B22);
  static const Color surfaceLight = Color(0xFF21262D);
  static const Color border = Color(0xFF30363D);

  // テキスト
  static const Color textPrimary = Color(0xFFE6EDF3);
  static const Color textSecondary = Color(0xFF8B949E);
  static const Color textMuted = Color(0xFF484F58);

  // アクセントカラー
  static const Color green = Color(0xFF3FB950);
  static const Color greenDark = Color(0xFF238636);
  static const Color blue = Color(0xFF58A6FF);
  static const Color purple = Color(0xFFBC8CFF);
  static const Color orange = Color(0xFFD29922);
  static const Color red = Color(0xFFF85149);
  static const Color yellow = Color(0xFFE3B341);
  static const Color cyan = Color(0xFF39D2C0);

  // ゲーム固有カラー
  static const Color money = Color(0xFF3FB950);
  static const Color trust = Color(0xFF58A6FF);
  static const Color danger = Color(0xFFF85149);
  static const Color warning = Color(0xFFD29922);
  static const Color info = Color(0xFF58A6FF);
  static const Color success = Color(0xFF3FB950);

  // プログレスバー
  static const Color progressBg = Color(0xFF21262D);
  static const Color progressGreen = Color(0xFF3FB950);
  static const Color progressOrange = Color(0xFFD29922);
  static const Color progressRed = Color(0xFFF85149);

  // サーバー負荷
  static Color serverLoadColor(double loadRate) {
    if (loadRate > 1.0) return red;
    if (loadRate > 0.8) return orange;
    if (loadRate > 0.5) return yellow;
    return green;
  }
}
