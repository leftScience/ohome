import 'package:flutter/material.dart';

/// 全局浅色主题色板。
///
/// 页面底色使用浅灰蓝，内容承载在纯白卡片上，通过细边框与柔和阴影分层。
/// 品牌蓝 / 紫色作为强调色保留。
class AppThemeColors {
  // ── 品牌色 ──
  static const primary = Color(0xFF186EEF);
  static const primaryDeep = Color(0xFF0F5AD6);
  static const secondary = Color(0xFF5B97FF);
  static const accent = Color(0xFF7C4DFF);

  // ── 页面背景 ──
  static const pageBackground = Color(0xFFF4F6FB);
  static const pageBackgroundDeep = Color(0xFFEDF1F8);

  // ── 卡片 / 表面 ──
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF8FAFD);
  static const surfaceSunken = Color(0xFFF1F4F9);

  // ── 边框 / 分割线 ──
  static const border = Color(0xFFE6EBF3);
  static const borderStrong = Color(0xFFD7DEEA);
  static const divider = Color(0xFFEDF1F7);

  // ── 文本 ──
  static const textPrimary = Color(0xFF101828);
  static const textSecondary = Color(0xFF475467);
  static const textMuted = Color(0xFF667085);
  static const textDisabled = Color(0xFF98A2B3);
  static const textOnAccent = Color(0xFFFFFFFF);

  // ── 状态色 ──
  static const success = Color(0xFF12B76A);
  static const warning = Color(0xFFF79009);
  static const danger = Color(0xFFF04438);

  // ── 阴影 / 遮罩 ──
  static const shadowSoft = Color(0x0F101828);
  static const shadowMedium = Color(0x1A101828);
  static const shadowStrong = Color(0x26101828);
  static const scrim = Color(0x66000000);

  /// 卡片通用柔和阴影
  static const cardShadow = <BoxShadow>[
    BoxShadow(color: shadowSoft, blurRadius: 18, offset: Offset(0, 6)),
  ];

  /// 浮层（底栏 / 悬浮按钮）阴影
  static const floatingShadow = <BoxShadow>[
    BoxShadow(color: shadowMedium, blurRadius: 24, offset: Offset(0, 10)),
  ];
}
