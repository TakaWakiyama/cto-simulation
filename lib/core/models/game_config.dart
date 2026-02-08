import 'package:flutter/foundation.dart';

import 'ceo_background.dart';

enum Difficulty {
  easy('イージー', 1.5, 0.5),
  normal('ノーマル', 1.0, 1.0),
  hard('ハード', 0.7, 1.5),
  nightmare('ナイトメア', 0.5, 2.0);

  const Difficulty(this.label, this.rewardMultiplier, this.eventSeverity);
  final String label;
  final double rewardMultiplier;
  final double eventSeverity;
}

@immutable
class GameConfig {
  const GameConfig({
    this.difficulty = Difficulty.normal,
    this.maxTurns = 120,
    this.startingMoney = 600, // 万円
    this.startingTrust = 30,
    this.apPerTurn = 3,
    this.background,
  });

  final Difficulty difficulty;
  final int maxTurns;
  final int startingMoney;
  final int startingTrust;
  final int apPerTurn;
  final CeoBackground? background;

  /// 学生起業家の初期資金ペナルティを適用した実効開始資金
  int get effectiveStartingMoney {
    if (background == CeoBackground.studentEntrepreneur) {
      return (startingMoney * 0.6).round();
    }
    return startingMoney;
  }

  Map<String, dynamic> toJson() => {
        'difficulty': difficulty.name,
        'maxTurns': maxTurns,
        'startingMoney': startingMoney,
        'startingTrust': startingTrust,
        'apPerTurn': apPerTurn,
        'background': background?.name,
      };

  factory GameConfig.fromJson(Map<String, dynamic> json) => GameConfig(
        difficulty:
            Difficulty.values.byName(json['difficulty'] as String? ?? 'normal'),
        maxTurns: json['maxTurns'] as int? ?? 120,
        startingMoney: json['startingMoney'] as int? ?? 300,
        startingTrust: json['startingTrust'] as int? ?? 30,
        apPerTurn: json['apPerTurn'] as int? ?? 3,
        background: json['background'] != null
            ? CeoBackground.values.byName(json['background'] as String)
            : null,
      );
}
