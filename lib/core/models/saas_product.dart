import 'package:flutter/foundation.dart';

enum SaaSCategory {
  crm('CRM'),
  erp('ERP'),
  projectManagement('プロジェクト管理'),
  communication('コミュニケーション'),
  analytics('アナリティクス'),
  security('セキュリティ');

  const SaaSCategory(this.label);
  final String label;
}

@immutable
class SaaSProduct {
  const SaaSProduct({
    required this.id,
    required this.name,
    required this.category,
    required this.monthlyPricePerUser,
    required this.developmentCost,
    required this.requiredTechLevel,
    this.totalUsers = 0,
    this.churnRate = 5.0,
    this.growthRate = 0.0,
    this.quality = 50,
    this.isLaunched = false,
    this.developmentProgress = 0,
    this.totalDevelopmentWork = 100,
    this.monthlyMaintenanceCost = 0,
  });

  final String id;
  final String name;
  final SaaSCategory category;
  final int monthlyPricePerUser; // ユーザーあたり月額（円）
  final int developmentCost; // 初期開発コスト（万円）
  final int requiredTechLevel;
  final int totalUsers;
  final double churnRate; // 月次解約率 (%)
  final double growthRate; // 月次成長率 (%)
  final int quality; // 品質 0-100
  final bool isLaunched;
  final int developmentProgress;
  final int totalDevelopmentWork;
  final int monthlyMaintenanceCost; // 月次保守費用（万円）

  /// 月次売上（万円）
  int get monthlyRevenue =>
      isLaunched ? (totalUsers * monthlyPricePerUser / 10000).round() : 0;

  /// 月次利益（万円）
  int get monthlyProfit => monthlyRevenue - monthlyMaintenanceCost;

  /// 開発進捗率
  double get developmentRate => totalDevelopmentWork > 0
      ? developmentProgress / totalDevelopmentWork
      : 0.0;

  bool get isDevelopmentComplete => developmentProgress >= totalDevelopmentWork;

  /// 新規ユーザー数の計算
  int calculateNewUsers() {
    if (!isLaunched) return 0;
    final growth = (totalUsers * growthRate / 100).round();
    final churn = (totalUsers * churnRate / 100).round();
    return growth - churn;
  }

  SaaSProduct copyWith({
    String? id,
    String? name,
    SaaSCategory? category,
    int? monthlyPricePerUser,
    int? developmentCost,
    int? requiredTechLevel,
    int? totalUsers,
    double? churnRate,
    double? growthRate,
    int? quality,
    bool? isLaunched,
    int? developmentProgress,
    int? totalDevelopmentWork,
    int? monthlyMaintenanceCost,
  }) {
    return SaaSProduct(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      monthlyPricePerUser: monthlyPricePerUser ?? this.monthlyPricePerUser,
      developmentCost: developmentCost ?? this.developmentCost,
      requiredTechLevel: requiredTechLevel ?? this.requiredTechLevel,
      totalUsers: totalUsers ?? this.totalUsers,
      churnRate: churnRate ?? this.churnRate,
      growthRate: growthRate ?? this.growthRate,
      quality: quality ?? this.quality,
      isLaunched: isLaunched ?? this.isLaunched,
      developmentProgress: developmentProgress ?? this.developmentProgress,
      totalDevelopmentWork: totalDevelopmentWork ?? this.totalDevelopmentWork,
      monthlyMaintenanceCost:
          monthlyMaintenanceCost ?? this.monthlyMaintenanceCost,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category.name,
        'monthlyPricePerUser': monthlyPricePerUser,
        'developmentCost': developmentCost,
        'requiredTechLevel': requiredTechLevel,
        'totalUsers': totalUsers,
        'churnRate': churnRate,
        'growthRate': growthRate,
        'quality': quality,
        'isLaunched': isLaunched,
        'developmentProgress': developmentProgress,
        'totalDevelopmentWork': totalDevelopmentWork,
        'monthlyMaintenanceCost': monthlyMaintenanceCost,
      };

  factory SaaSProduct.fromJson(Map<String, dynamic> json) => SaaSProduct(
        id: json['id'] as String,
        name: json['name'] as String,
        category: SaaSCategory.values.byName(json['category'] as String),
        monthlyPricePerUser: json['monthlyPricePerUser'] as int,
        developmentCost: json['developmentCost'] as int,
        requiredTechLevel: json['requiredTechLevel'] as int,
        totalUsers: json['totalUsers'] as int? ?? 0,
        churnRate: (json['churnRate'] as num?)?.toDouble() ?? 5.0,
        growthRate: (json['growthRate'] as num?)?.toDouble() ?? 0.0,
        quality: json['quality'] as int? ?? 50,
        isLaunched: json['isLaunched'] as bool? ?? false,
        developmentProgress: json['developmentProgress'] as int? ?? 0,
        totalDevelopmentWork: json['totalDevelopmentWork'] as int? ?? 100,
        monthlyMaintenanceCost:
            json['monthlyMaintenanceCost'] as int? ?? 0,
      );
}
