import 'package:flutter/foundation.dart';

enum TechCategory {
  language('言語'),
  framework('フレームワーク'),
  infrastructure('インフラ'),
  devops('DevOps'),
  security('セキュリティ'),
  ai('AI/ML');

  const TechCategory(this.label);
  final String label;
}

@immutable
class Technology {
  const Technology({
    required this.id,
    required this.name,
    required this.category,
    required this.researchCost,
    required this.researchTurns,
    this.description = '',
    this.isUnlocked = false,
    this.currentResearchProgress = 0,
    this.prerequisites = const [],
    this.productivityBonus = 0,
    this.qualityBonus = 0,
    this.unlocksSaaSIds = const [],
  });

  final String id;
  final String name;
  final TechCategory category;
  final String description;
  final int researchCost; // 研究コスト（万円）
  final int researchTurns; // 必要ターン数
  final bool isUnlocked;
  final int currentResearchProgress;
  final List<String> prerequisites; // 前提技術のID
  final int productivityBonus; // 生産性ボーナス (%)
  final int qualityBonus; // 品質ボーナス (%)
  final List<String> unlocksSaaSIds; // 解禁するSaaS製品

  bool get isResearching =>
      !isUnlocked && currentResearchProgress > 0;

  double get researchRate => researchTurns > 0
      ? currentResearchProgress / researchTurns
      : 0.0;

  bool get isResearchComplete => currentResearchProgress >= researchTurns;

  bool canResearch(List<String> unlockedTechIds) {
    if (isUnlocked) return false;
    return prerequisites.every(unlockedTechIds.contains);
  }

  Technology copyWith({
    String? id,
    String? name,
    TechCategory? category,
    String? description,
    int? researchCost,
    int? researchTurns,
    bool? isUnlocked,
    int? currentResearchProgress,
    List<String>? prerequisites,
    int? productivityBonus,
    int? qualityBonus,
    List<String>? unlocksSaaSIds,
  }) {
    return Technology(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      description: description ?? this.description,
      researchCost: researchCost ?? this.researchCost,
      researchTurns: researchTurns ?? this.researchTurns,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      currentResearchProgress:
          currentResearchProgress ?? this.currentResearchProgress,
      prerequisites: prerequisites ?? this.prerequisites,
      productivityBonus: productivityBonus ?? this.productivityBonus,
      qualityBonus: qualityBonus ?? this.qualityBonus,
      unlocksSaaSIds: unlocksSaaSIds ?? this.unlocksSaaSIds,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category.name,
        'description': description,
        'researchCost': researchCost,
        'researchTurns': researchTurns,
        'isUnlocked': isUnlocked,
        'currentResearchProgress': currentResearchProgress,
        'prerequisites': prerequisites,
        'productivityBonus': productivityBonus,
        'qualityBonus': qualityBonus,
        'unlocksSaaSIds': unlocksSaaSIds,
      };

  factory Technology.fromJson(Map<String, dynamic> json) => Technology(
        id: json['id'] as String,
        name: json['name'] as String,
        category: TechCategory.values.byName(json['category'] as String),
        description: json['description'] as String? ?? '',
        researchCost: json['researchCost'] as int,
        researchTurns: json['researchTurns'] as int,
        isUnlocked: json['isUnlocked'] as bool? ?? false,
        currentResearchProgress:
            json['currentResearchProgress'] as int? ?? 0,
        prerequisites:
            (json['prerequisites'] as List<dynamic>?)?.cast<String>() ??
                const [],
        productivityBonus: json['productivityBonus'] as int? ?? 0,
        qualityBonus: json['qualityBonus'] as int? ?? 0,
        unlocksSaaSIds:
            (json['unlocksSaaSIds'] as List<dynamic>?)?.cast<String>() ??
                const [],
      );
}
