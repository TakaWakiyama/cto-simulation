import 'package:flutter/foundation.dart';

@immutable
class Office {
  const Office({
    required this.id,
    required this.name,
    required this.maxEmployees,
    required this.monthlyCost,
    this.happinessBonus = 0,
    this.productivityBonus = 0,
    this.description = '',
  });

  final String id;
  final String name;
  final int maxEmployees;
  final int monthlyCost; // 月額家賃（万円）
  final int happinessBonus; // 幸福度ボーナス
  final int productivityBonus; // 生産性ボーナス (%)
  final String description;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'maxEmployees': maxEmployees,
        'monthlyCost': monthlyCost,
        'happinessBonus': happinessBonus,
        'productivityBonus': productivityBonus,
        'description': description,
      };

  factory Office.fromJson(Map<String, dynamic> json) => Office(
        id: json['id'] as String,
        name: json['name'] as String,
        maxEmployees: json['maxEmployees'] as int,
        monthlyCost: json['monthlyCost'] as int,
        happinessBonus: json['happinessBonus'] as int? ?? 0,
        productivityBonus: json['productivityBonus'] as int? ?? 0,
        description: json['description'] as String? ?? '',
      );

  /// 利用可能なオフィス一覧（アップグレード順）
  static const List<Office> allOffices = [
    Office(
      id: 'office_garage',
      name: 'ガレージオフィス',
      maxEmployees: 5,
      monthlyCost: 5,
      description: 'スタートアップの原点。狭いが家賃は安い。',
    ),
    Office(
      id: 'office_coworking',
      name: 'コワーキングスペース',
      maxEmployees: 10,
      monthlyCost: 15,
      happinessBonus: 5,
      productivityBonus: 5,
      description: '他の起業家と交流できる共有オフィス。',
    ),
    Office(
      id: 'office_small',
      name: '小規模オフィス',
      maxEmployees: 20,
      monthlyCost: 30,
      happinessBonus: 10,
      productivityBonus: 10,
      description: '自社専用の小さなオフィス。チームの一体感が生まれる。',
    ),
    Office(
      id: 'office_medium',
      name: '中規模オフィス',
      maxEmployees: 40,
      monthlyCost: 60,
      happinessBonus: 15,
      productivityBonus: 15,
      description: '会議室やリフレッシュスペース完備。',
    ),
    Office(
      id: 'office_large',
      name: '大規模オフィス',
      maxEmployees: 80,
      monthlyCost: 120,
      happinessBonus: 20,
      productivityBonus: 20,
      description: 'フロア全体を使った本格的なオフィス。',
    ),
  ];

  /// アップグレード費用（月額の6ヶ月分）
  int get upgradeCost => monthlyCost * 6;
}
