import 'package:flutter/foundation.dart';

/// エクイティラウンドの種類
enum EquityRoundType {
  seed('シード', 500, 10, null),
  seriesA('シリーズA', 2000, 20, EquityRoundType.seed),
  seriesB('シリーズB', 5000, 25, EquityRoundType.seriesA);

  const EquityRoundType(
      this.label, this.amount, this.equityPercent, this.prerequisite);
  final String label;
  final int amount; // 調達額（万円）
  final int equityPercent; // 株式譲渡率（%）
  final EquityRoundType? prerequisite; // 前提ラウンド
}

@immutable
class EquityRound {
  const EquityRound({
    required this.type,
    required this.amount,
    required this.equityPercent,
    required this.completedTurn,
  });

  final EquityRoundType type;
  final int amount;
  final int equityPercent;
  final int completedTurn;

  factory EquityRound.create(EquityRoundType type, int turn) => EquityRound(
        type: type,
        amount: type.amount,
        equityPercent: type.equityPercent,
        completedTurn: turn,
      );

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'amount': amount,
        'equityPercent': equityPercent,
        'completedTurn': completedTurn,
      };

  factory EquityRound.fromJson(Map<String, dynamic> json) => EquityRound(
        type: EquityRoundType.values.byName(json['type'] as String),
        amount: json['amount'] as int,
        equityPercent: json['equityPercent'] as int,
        completedTurn: json['completedTurn'] as int,
      );
}
