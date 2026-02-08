import 'package:flutter/foundation.dart';

enum EventType {
  opportunity('好機'),
  crisis('危機'),
  market('市場変動'),
  employee('社員関連'),
  tech('技術トレンド');

  const EventType(this.label);
  final String label;
}

@immutable
class EventChoice {
  const EventChoice({
    required this.id,
    required this.text,
    required this.effects,
    this.cost = 0,
    this.apCost = 0,
  });

  final String id;
  final String text;
  final Map<String, dynamic> effects; // {money: -100, trust: 5, ...}
  final int cost; // 選択にかかるコスト（万円）
  final int apCost; // APコスト

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'effects': effects,
        'cost': cost,
        'apCost': apCost,
      };

  factory EventChoice.fromJson(Map<String, dynamic> json) => EventChoice(
        id: json['id'] as String,
        text: json['text'] as String,
        effects: Map<String, dynamic>.from(json['effects'] as Map),
        cost: json['cost'] as int? ?? 0,
        apCost: json['apCost'] as int? ?? 0,
      );
}

@immutable
class GameEvent {
  const GameEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.choices,
    this.probability = 1.0,
    this.minTurn = 1,
    this.maxTurn = 120,
    this.conditions = const {},
    this.isOneTime = false,
  });

  final String id;
  final String title;
  final String description;
  final EventType type;
  final List<EventChoice> choices;
  final double probability; // 発生確率 0.0-1.0
  final int minTurn;
  final int maxTurn;
  final Map<String, dynamic> conditions; // 発生条件
  final bool isOneTime; // 一度きりのイベント

  bool canTrigger(int currentTurn, Map<String, dynamic> gameState) {
    if (currentTurn < minTurn || currentTurn > maxTurn) return false;

    for (final entry in conditions.entries) {
      final key = entry.key;
      final required = entry.value;
      final actual = gameState[key];
      if (actual == null) return false;

      if (required is int && actual is int) {
        if (actual < required) return false;
      }
      if (required is bool && actual != required) return false;
    }
    return true;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'type': type.name,
        'choices': choices.map((c) => c.toJson()).toList(),
        'probability': probability,
        'minTurn': minTurn,
        'maxTurn': maxTurn,
        'conditions': conditions,
        'isOneTime': isOneTime,
      };

  factory GameEvent.fromJson(Map<String, dynamic> json) => GameEvent(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        type: EventType.values.byName(json['type'] as String),
        choices: (json['choices'] as List<dynamic>)
            .map((c) => EventChoice.fromJson(c as Map<String, dynamic>))
            .toList(),
        probability: (json['probability'] as num?)?.toDouble() ?? 1.0,
        minTurn: json['minTurn'] as int? ?? 1,
        maxTurn: json['maxTurn'] as int? ?? 120,
        conditions:
            Map<String, dynamic>.from(json['conditions'] as Map? ?? {}),
        isOneTime: json['isOneTime'] as bool? ?? false,
      );
}
