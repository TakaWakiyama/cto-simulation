import 'dart:math';

import 'game_state.dart';
import 'models/event.dart';

/// イベント抽選・条件判定エンジン
class EventEngine {
  static final _random = Random();

  /// イベントの抽選
  static GameEvent? rollEvent(GameState state, List<GameEvent> allEvents) {
    final eligibleEvents = allEvents.where((event) {
      if (state.triggeredEventIds.contains(event.id) && event.isOneTime) {
        return false;
      }
      return event.canTrigger(state.currentTurn, state.toConditionMap());
    }).toList();

    if (eligibleEvents.isEmpty) return null;

    // 確率に基づいて抽選
    for (final event in eligibleEvents) {
      final roll = _random.nextDouble();
      final adjustedProb =
          event.probability * state.config.difficulty.eventSeverity;
      if (roll < adjustedProb) {
        return event;
      }
    }

    return null;
  }

  /// イベント選択肢の適用
  static GameState applyEventChoice(
    GameState state,
    GameEvent event,
    EventChoice choice,
  ) {
    var updatedState = state;

    // AP消費
    if (choice.apCost > 0) {
      updatedState = updatedState.copyWith(
        ap: (updatedState.ap - choice.apCost).clamp(0, 99),
      );
    }

    // コスト支払い
    if (choice.cost > 0) {
      updatedState = updatedState.copyWith(
        money: updatedState.money - choice.cost,
      );
    }

    // 効果の適用
    for (final entry in choice.effects.entries) {
      updatedState = _applyEffect(updatedState, entry.key, entry.value);
    }

    // イベントを記録
    updatedState = updatedState.copyWith(
      triggeredEventIds: [...updatedState.triggeredEventIds, event.id],
      pendingEvent: () => null,
      turnLog: [
        ...updatedState.turnLog,
        'イベント「${event.title}」: ${choice.text}を選択',
      ],
    );

    return updatedState;
  }

  static GameState _applyEffect(
    GameState state,
    String key,
    dynamic value,
  ) {
    final intValue = value is int ? value : (value as num).toInt();

    return switch (key) {
      'money' => state.copyWith(money: state.money + intValue),
      'trust' => state.copyWith(
          trust: (state.trust + intValue).clamp(0, 100)),
      'debt' => state.copyWith(
          debt: (state.debt + intValue).clamp(0, 99999)),
      'allHappiness' => state.copyWith(
          employees: state.employees
              .map((e) => e.copyWith(
                  happiness: (e.happiness + intValue).clamp(0, 100)))
              .toList()),
      'allFatigue' => state.copyWith(
          employees: state.employees
              .map((e) => e.copyWith(
                  fatigue: (e.fatigue + intValue).clamp(0, 100)))
              .toList()),
      _ => state,
    };
  }

  /// 初期イベントデータ
  static List<GameEvent> getDefaultEvents() {
    return [
      GameEvent(
        id: 'evt_talent_market',
        title: '人材市場の活況',
        description: '優秀なエンジニアが転職市場に出ています。今がチャンスです。',
        type: EventType.opportunity,
        probability: 0.3,
        choices: [
          EventChoice(
            id: 'hire_bonus',
            text: '採用ボーナスを出して引き抜く',
            effects: {},
            cost: 50,
          ),
          EventChoice(
            id: 'ignore',
            text: '見送る',
            effects: {},
          ),
        ],
      ),
      GameEvent(
        id: 'evt_server_attack',
        title: 'サイバー攻撃の脅威',
        description: '不審なアクセスが急増しています。対策が必要かもしれません。',
        type: EventType.crisis,
        probability: 0.2,
        minTurn: 10,
        conditions: {'hasSaaS': true},
        choices: [
          EventChoice(
            id: 'invest_security',
            text: 'セキュリティ対策に投資する',
            effects: {'trust': 5},
            cost: 30,
          ),
          EventChoice(
            id: 'ignore_risk',
            text: '様子を見る',
            effects: {'trust': -10},
          ),
        ],
      ),
      GameEvent(
        id: 'evt_tech_conference',
        title: '技術カンファレンスの招待',
        description: '有名な技術カンファレンスへの参加機会があります。',
        type: EventType.tech,
        probability: 0.25,
        minTurn: 5,
        choices: [
          EventChoice(
            id: 'attend',
            text: '参加する（社員の成長に繋がる）',
            effects: {'allHappiness': 10},
            cost: 20,
            apCost: 1,
          ),
          EventChoice(
            id: 'skip',
            text: '今回はスキップする',
            effects: {},
          ),
        ],
      ),
      GameEvent(
        id: 'evt_market_boom',
        title: 'IT市場の好況',
        description: 'IT投資が活発化しています。案件の報酬が上がるかもしれません。',
        type: EventType.market,
        probability: 0.15,
        minTurn: 15,
        choices: [
          EventChoice(
            id: 'aggressive',
            text: '積極的に営業をかける',
            effects: {'trust': 5},
            cost: 10,
            apCost: 1,
          ),
          EventChoice(
            id: 'steady',
            text: '現状維持で進める',
            effects: {'trust': 2},
          ),
        ],
      ),
      GameEvent(
        id: 'evt_employee_burnout',
        title: '社員のバーンアウト危機',
        description: '社員たちに疲労の色が見えます。何か対策が必要かもしれません。',
        type: EventType.employee,
        probability: 0.3,
        minTurn: 8,
        choices: [
          EventChoice(
            id: 'team_building',
            text: 'チームビルディングイベントを開催',
            effects: {'allHappiness': 15, 'allFatigue': -20},
            cost: 15,
          ),
          EventChoice(
            id: 'bonus',
            text: '特別ボーナスを支給',
            effects: {'allHappiness': 20},
            cost: 30,
          ),
          EventChoice(
            id: 'nothing',
            text: '特に何もしない',
            effects: {'allHappiness': -5},
          ),
        ],
      ),
      GameEvent(
        id: 'evt_big_client',
        title: '大口クライアントからの問い合わせ',
        description: '大手企業からシステム開発の相談が入りました。信頼度が高ければ受注できるかもしれません。',
        type: EventType.opportunity,
        probability: 0.15,
        minTurn: 20,
        conditions: {'trust': 50},
        isOneTime: true,
        choices: [
          EventChoice(
            id: 'accept_big',
            text: '積極的に提案する',
            effects: {'trust': 10, 'money': 100},
          ),
          EventChoice(
            id: 'decline_big',
            text: '今の規模では難しいと辞退する',
            effects: {'trust': -5},
          ),
        ],
      ),
      // --- 投資家イベント ---
      GameEvent(
        id: 'evt_investor_demand_saas',
        title: '投資家が新規事業を要求',
        description: '投資家から「次のSaaSプロダクトの計画を見せてほしい」と要求がありました。',
        type: EventType.market,
        probability: 0.2,
        minTurn: 10,
        conditions: {'hasEquity': true},
        choices: [
          EventChoice(
            id: 'comply_saas',
            text: '新規SaaS開発を約束する',
            effects: {'trust': 3},
            apCost: 1,
          ),
          EventChoice(
            id: 'refuse_saas',
            text: '現状のロードマップで進める',
            effects: {'trust': -8},
          ),
        ],
      ),
      GameEvent(
        id: 'evt_investor_report',
        title: '投資家が報告を要求',
        description: '投資家から月次レポートの提出を求められています。対応にはAPが必要です。',
        type: EventType.market,
        probability: 0.25,
        minTurn: 5,
        conditions: {'hasEquity': true},
        choices: [
          EventChoice(
            id: 'submit_report',
            text: '詳細なレポートを作成する',
            effects: {'trust': 2},
            apCost: 1,
          ),
          EventChoice(
            id: 'brief_report',
            text: '簡易報告で済ませる',
            effects: {'trust': -3},
          ),
        ],
      ),
      GameEvent(
        id: 'evt_board_direction',
        title: '取締役会で方針変更を要求',
        description: '投資家主導の取締役会で、事業方針の見直しが提案されました。',
        type: EventType.crisis,
        probability: 0.15,
        minTurn: 15,
        conditions: {'hasEquity': true},
        choices: [
          EventChoice(
            id: 'accept_change',
            text: '方針変更を受け入れる（コスト発生）',
            effects: {'trust': 3},
            cost: 50,
          ),
          EventChoice(
            id: 'resist_change',
            text: '現方針を維持する',
            effects: {'trust': -10},
          ),
        ],
      ),
      GameEvent(
        id: 'evt_investor_referral',
        title: '投資家がクライアントを紹介',
        description: '投資家のネットワークから、新しいクライアントを紹介してもらえました！',
        type: EventType.opportunity,
        probability: 0.2,
        minTurn: 8,
        conditions: {'hasEquity': true},
        choices: [
          EventChoice(
            id: 'accept_referral',
            text: 'ありがたく受ける',
            effects: {'money': 80, 'trust': 5},
          ),
          EventChoice(
            id: 'polite_decline',
            text: '今はキャパシティが足りないと辞退する',
            effects: {'trust': -2},
          ),
        ],
      ),
    ];
  }
}
