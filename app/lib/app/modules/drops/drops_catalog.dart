import 'package:flutter/material.dart';

const Map<String, String> dropsScopeLabels = <String, String>{
  'shared': '家庭共享',
  'personal': '个人私有',
};

const Map<String, String> dropsCategoryLabels = <String, String>{
  'kitchen': '厨房用品',
  'food': '食品',
  'medicine': '药品',
  'clothing': '衣物',
  'other': '其他',
};

const Map<String, String> dropsEventTypeLabels = <String, String>{
  'birthday': '生日',
  'anniversary': '纪念日',
  'custom': '自定义',
};

const Map<String, String> dropsCalendarLabels = <String, String>{
  'solar': '公历',
  'lunar': '农历',
};

const Map<String, Color> dropsCategoryColors = <String, Color>{
  'kitchen': Color(0xFF00897B),
  'food': Color(0xFFF57C00),
  'medicine': Color(0xFFE53935),
  'clothing': Color(0xFF1E88E5),
  'other': Color(0xFF7E57C2),
};

String dropsScopeLabel(String value) => dropsScopeLabels[value] ?? '未知';

String dropsCategoryLabel(String value) =>
    dropsCategoryLabels[value] ?? (value.trim().isEmpty ? '未分类' : value);

String dropsEventTypeLabel(String value) =>
    dropsEventTypeLabels[value] ?? (value.trim().isEmpty ? '自定义' : value);

String dropsCalendarLabel(String value) =>
    dropsCalendarLabels[value] ?? (value.trim().isEmpty ? '公历' : value);
