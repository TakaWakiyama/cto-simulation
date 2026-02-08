import 'package:flutter/foundation.dart';

enum ServerTier {
  shared('共有サーバー', 1),
  vps('VPS', 2),
  dedicated('専用サーバー', 3),
  cloud('クラウド', 4),
  enterprise('エンタープライズ', 5);

  const ServerTier(this.label, this.level);
  final String label;
  final int level;
}

@immutable
class Server {
  const Server({
    required this.id,
    required this.name,
    required this.tier,
    required this.capacity,
    required this.monthlyCost,
    this.currentLoad = 0,
    this.reliability = 95.0,
    this.isDown = false,
  });

  final String id;
  final String name;
  final ServerTier tier;
  final int capacity; // 同時接続ユーザー数
  final int monthlyCost; // 月額費用（万円）
  final int currentLoad; // 現在の負荷（ユーザー数）
  final double reliability; // 信頼性 0-100%
  final bool isDown; // 障害発生中

  /// 負荷率 0.0〜1.0+
  double get loadRate => capacity > 0 ? currentLoad / capacity : 0.0;

  /// 障害発生確率（負荷率ベース）
  double get failureProbability {
    if (isDown) return 0.0;
    final baseFailRate = (100 - reliability) / 100.0;
    if (loadRate > 1.0) {
      return (baseFailRate + (loadRate - 1.0) * 0.5).clamp(0.0, 1.0);
    }
    if (loadRate > 0.8) {
      return (baseFailRate + (loadRate - 0.8) * 0.2).clamp(0.0, 1.0);
    }
    return baseFailRate;
  }

  bool get isOverloaded => loadRate > 1.0;
  bool get isHighLoad => loadRate > 0.8;

  Server copyWith({
    String? id,
    String? name,
    ServerTier? tier,
    int? capacity,
    int? monthlyCost,
    int? currentLoad,
    double? reliability,
    bool? isDown,
  }) {
    return Server(
      id: id ?? this.id,
      name: name ?? this.name,
      tier: tier ?? this.tier,
      capacity: capacity ?? this.capacity,
      monthlyCost: monthlyCost ?? this.monthlyCost,
      currentLoad: currentLoad ?? this.currentLoad,
      reliability: reliability ?? this.reliability,
      isDown: isDown ?? this.isDown,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'tier': tier.name,
        'capacity': capacity,
        'monthlyCost': monthlyCost,
        'currentLoad': currentLoad,
        'reliability': reliability,
        'isDown': isDown,
      };

  factory Server.fromJson(Map<String, dynamic> json) => Server(
        id: json['id'] as String,
        name: json['name'] as String,
        tier: ServerTier.values.byName(json['tier'] as String),
        capacity: json['capacity'] as int,
        monthlyCost: json['monthlyCost'] as int,
        currentLoad: json['currentLoad'] as int? ?? 0,
        reliability: (json['reliability'] as num?)?.toDouble() ?? 95.0,
        isDown: json['isDown'] as bool? ?? false,
      );
}
