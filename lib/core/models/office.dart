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
}
