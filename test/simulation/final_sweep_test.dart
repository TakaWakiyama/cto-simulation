import 'package:cto_simulator/core/contract_engine.dart';
import 'package:cto_simulator/core/event_engine.dart';
import 'package:cto_simulator/core/game_state.dart';
import 'package:cto_simulator/core/models/ceo_background.dart';
import 'package:cto_simulator/core/models/contract_project.dart';
import 'package:cto_simulator/core/models/game_config.dart';
import 'package:cto_simulator/core/turn_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'bot_strategy.dart';

class StructuralTweak {
  const StructuralTweak({
    this.label = '',
    this.rewardMultiplier = 1.0,
    this.workMultiplier = 1.0,
    this.startingMoney = 300,
    this.upfrontRate = 0.0,
    this.fatigueReduction = 0,
    this.happinessBoost = 0,
    this.overdueTrustRestore = 0,
  });

  final String label;
  final double rewardMultiplier;
  final double workMultiplier;
  final int startingMoney;
  final double upfrontRate;
  final int fatigueReduction;
  final int happinessBoost;
  final int overdueTrustRestore;
}

class StructuralBot extends BotStrategy {
  StructuralBot({required this.inner, required this.tweak});
  final BotStrategy inner;
  final StructuralTweak tweak;
  final Set<String> _modifiedIds = {};
  final Set<String> _upfrontPaidIds = {};

  @override
  String get name => tweak.label;

  @override
  GameState playTurn(GameState state) {
    var s = _tweakProjects(state);
    if (s.pendingEvent != null) s = _resolveEvent(s);

    final beforeIds = s.contractProjects
        .where((p) => p.status == ProjectStatus.inProgress)
        .map((p) => p.id)
        .toSet();

    s = inner.doActions(s);
    s = _tweakProjects(s);

    // 前払い
    if (tweak.upfrontRate > 0) {
      for (final p in s.contractProjects) {
        if (p.status == ProjectStatus.inProgress &&
            !beforeIds.contains(p.id) &&
            !_upfrontPaidIds.contains(p.id)) {
          final upfront = (p.reward * tweak.upfrontRate).round();
          s = s.copyWith(
            money: s.money + upfront,
            totalEarned: s.totalEarned + upfront,
          );
          _upfrontPaidIds.add(p.id);
        }
      }
    }

    s = _autoAssign(s);

    final trustBefore = s.trust;
    s = TurnEngine.processTurnEnd(s);

    // 構造修正
    if (tweak.fatigueReduction > 0 || tweak.happinessBoost > 0) {
      s = s.copyWith(
        employees: s.employees.map((e) => e.copyWith(
          fatigue: (e.fatigue - tweak.fatigueReduction).clamp(0, 100),
          happiness: (e.happiness + tweak.happinessBoost).clamp(0, 100),
        )).toList(),
      );
    }
    if (tweak.overdueTrustRestore > 0 && s.trust < trustBefore) {
      final restore = (trustBefore - s.trust).clamp(0, tweak.overdueTrustRestore);
      s = s.copyWith(trust: (s.trust + restore).clamp(0, 100));
    }

    s = _tweakProjects(s);
    return s;
  }

  @override
  GameState doActions(GameState state) => inner.doActions(state);

  GameState _tweakProjects(GameState state) {
    var changed = false;
    final tweaked = state.contractProjects.map((p) {
      if (_modifiedIds.contains(p.id)) return p;
      _modifiedIds.add(p.id);
      changed = true;
      return p.copyWith(
        reward: (p.reward * tweak.rewardMultiplier).round(),
        totalWork: (p.totalWork * tweak.workMultiplier).round(),
      );
    }).toList();
    return changed ? state.copyWith(contractProjects: tweaked) : state;
  }

  GameState _resolveEvent(GameState state) {
    final event = state.pendingEvent!;
    if (event.choices.isEmpty) return state.copyWith(pendingEvent: () => null);
    final sorted = [...event.choices]..sort((a, b) => a.cost.compareTo(b.cost));
    final choice = (sorted.first.apCost > 0 && state.ap < sorted.first.apCost)
        ? sorted.firstWhere((c) => c.apCost == 0, orElse: () => sorted.last)
        : sorted.first;
    return EventEngine.applyEventChoice(state, event, choice);
  }

  GameState _autoAssign(GameState state) {
    var s = state;
    for (final emp in s.unassignedEmployees) {
      if (!emp.isEngineer) continue;
      final active = s.activeProjects;
      if (active.isEmpty) break;
      final sorted = [...active]..sort((a, b) =>
          a.assignedEmployeeIds.length.compareTo(b.assignedEmployeeIds.length));
      s = ContractEngine.assignEmployee(s, sorted.first.id, emp.id);
    }
    return s;
  }
}

class _Stats {
  int survived = 0;
  int bankrupt = 0;
  int quit = 0;
  int trustZero = 0;
  int totalTurns = 0;
  int totalRevenue = 0;
  int totalExpense = 0;
  int totalCompleted = 0;
  int count = 0;
}

_Stats _run(BotStrategy innerBot, StructuralTweak tweak, int n) {
  final stats = _Stats();
  for (var i = 0; i < n; i++) {
    final bot = StructuralBot(inner: innerBot, tweak: tweak);
    const cfg = GameConfig();
    var state = GameState.initial(cfg);
    state = state.copyWith(money: tweak.startingMoney);
    state = TurnEngine.initializeGame(state);

    var completed = 0;
    while (!state.isGameOver && state.currentTurn <= cfg.maxTurns) {
      final prev = state.contractProjects
          .where((p) => p.status == ProjectStatus.completed).length;
      state = bot.playTurn(state);
      completed += state.contractProjects
              .where((p) => p.status == ProjectStatus.completed).length -
          prev;
    }

    stats.count++;
    stats.totalTurns += state.currentTurn;
    stats.totalRevenue += state.totalEarned;
    stats.totalExpense += state.totalSpent;
    stats.totalCompleted += completed;
    if (state.currentTurn >= cfg.maxTurns) stats.survived++;
    if (state.totalDebtWithLoans >= 1000) stats.bankrupt++;
    if (state.gameOverReason?.contains('退職') ?? false) stats.quit++;
    if (state.gameOverReason?.contains('信頼度') ?? false) stats.trustZero++;
  }
  return stats;
}

void _printStats(String label, _Stats s) {
  final n = s.count;
  print('  ${label.padRight(24)}'
      '生存${(s.survived / n * 100).toStringAsFixed(0).padLeft(3)}%  '
      '破産${(s.bankrupt / n * 100).toStringAsFixed(0).padLeft(3)}%  '
      '退職${(s.quit / n * 100).toStringAsFixed(0).padLeft(3)}%  '
      '信頼${(s.trustZero / n * 100).toStringAsFixed(0).padLeft(3)}%  '
      '${(s.totalTurns / n).toStringAsFixed(0).padLeft(3)}T  '
      '損益${((s.totalRevenue - s.totalExpense) / n).toStringAsFixed(0).padLeft(7)}万');
}

void main() {
  const n = 300;

  test('Final comprehensive sweep', () {
    // ══════════════════════════════════════════
    // Step 1: 極端なパラメータで「生存可能な範囲」を特定
    // ══════════════════════════════════════════
    print('');
    print('═' * 90);
    print('  Step 1: 極端パラメータで生存可能範囲を特定 ($n回, GreedyBot)');
    print('═' * 90);

    final extremes = [
      const StructuralTweak(label: '現状ベースライン'),
      const StructuralTweak(
        label: '報酬×3 工数×0.5 資金500',
        rewardMultiplier: 3.0, workMultiplier: 0.5, startingMoney: 500,
      ),
      const StructuralTweak(
        label: '報酬×3 工数×0.5 資金1000',
        rewardMultiplier: 3.0, workMultiplier: 0.5, startingMoney: 1000,
      ),
      const StructuralTweak(
        label: '報酬×5 工数×0.33 資金1000',
        rewardMultiplier: 5.0, workMultiplier: 0.33, startingMoney: 1000,
      ),
      const StructuralTweak(
        label: '↑+疲労-5 幸福+3',
        rewardMultiplier: 5.0, workMultiplier: 0.33, startingMoney: 1000,
        fatigueReduction: 5, happinessBoost: 3,
      ),
      const StructuralTweak(
        label: '↑+前払50% 信頼軽減+4',
        rewardMultiplier: 5.0, workMultiplier: 0.33, startingMoney: 1000,
        fatigueReduction: 5, happinessBoost: 3,
        upfrontRate: 0.5, overdueTrustRestore: 4,
      ),
      const StructuralTweak(
        label: '報酬×3 工数×0.33 資金1000 全盛',
        rewardMultiplier: 3.0, workMultiplier: 0.33, startingMoney: 1000,
        fatigueReduction: 5, happinessBoost: 3,
        upfrontRate: 0.3, overdueTrustRestore: 4,
      ),
    ];

    for (final tweak in extremes) {
      _printStats(tweak.label, _run(GreedyBot(), tweak, n));
    }
    print('─' * 90);

    // ══════════════════════════════════════════
    // Step 2: 生存率が上がった条件を4bot比較
    // ══════════════════════════════════════════
    print('');
    print('═' * 90);
    print('  Step 2: ベスト条件の全bot比較 ($n回)');
    print('═' * 90);

    final best = [
      const StructuralTweak(
        label: 'フル修正(報酬×5)',
        rewardMultiplier: 5.0, workMultiplier: 0.33, startingMoney: 1000,
        fatigueReduction: 5, happinessBoost: 3,
        upfrontRate: 0.5, overdueTrustRestore: 4,
      ),
      const StructuralTweak(
        label: 'フル修正(報酬×3)',
        rewardMultiplier: 3.0, workMultiplier: 0.33, startingMoney: 1000,
        fatigueReduction: 5, happinessBoost: 3,
        upfrontRate: 0.3, overdueTrustRestore: 4,
      ),
    ];

    for (final tweak in best) {
      print('\n  ── ${tweak.label} ──');
      for (final (label, bot) in [
        ('Greedy', GreedyBot()),
        ('Safe', SafeBot()),
        ('Growth', GrowthBot()),
        ('SaaS', SaaSBot()),
      ]) {
        _printStats(label, _run(bot, tweak, n));
      }
    }
    print('─' * 90);

    // ══════════════════════════════════════════
    // Step 3: 「ゲームとして面白いバランス」を探る
    //         目標: 生存率 30-60%（上手いプレイで生存可能）
    // ══════════════════════════════════════════
    print('');
    print('═' * 90);
    print('  Step 3: ゲームバランス目標（生存率30-60%）を探索 ($n回, GreedyBot)');
    print('═' * 90);

    final gameBalance = [
      // 現実的な報酬 + 現実的な工数 + 構造修正
      const StructuralTweak(
        label: 'v1: 控えめ',
        rewardMultiplier: 2.5, workMultiplier: 0.4, startingMoney: 500,
        fatigueReduction: 4, happinessBoost: 2,
        upfrontRate: 0.2, overdueTrustRestore: 3,
      ),
      const StructuralTweak(
        label: 'v2: 中間',
        rewardMultiplier: 3.0, workMultiplier: 0.4, startingMoney: 600,
        fatigueReduction: 5, happinessBoost: 3,
        upfrontRate: 0.3, overdueTrustRestore: 3,
      ),
      const StructuralTweak(
        label: 'v3: 手厚い',
        rewardMultiplier: 3.0, workMultiplier: 0.33, startingMoney: 700,
        fatigueReduction: 5, happinessBoost: 3,
        upfrontRate: 0.3, overdueTrustRestore: 4,
      ),
      const StructuralTweak(
        label: 'v4: かなり手厚い',
        rewardMultiplier: 3.5, workMultiplier: 0.33, startingMoney: 800,
        fatigueReduction: 6, happinessBoost: 3,
        upfrontRate: 0.3, overdueTrustRestore: 4,
      ),
      const StructuralTweak(
        label: 'v5: 大盤振る舞い',
        rewardMultiplier: 4.0, workMultiplier: 0.33, startingMoney: 1000,
        fatigueReduction: 6, happinessBoost: 4,
        upfrontRate: 0.3, overdueTrustRestore: 4,
      ),
    ];

    for (final tweak in gameBalance) {
      _printStats(tweak.label, _run(GreedyBot(), tweak, n));
    }
    print('─' * 90);

    // ベストなバランスを全bot比較
    print('');
    print('═' * 90);
    print('  Step 4: ベストバランス候補 全bot比較 ($n回)');
    print('═' * 90);

    // Step 3で最も生存率が高かったものをピック
    for (final tweak in gameBalance) {
      print('\n  ── ${tweak.label} ──');
      for (final (label, bot) in [
        ('Greedy', GreedyBot()),
        ('Safe', SafeBot()),
        ('Growth', GrowthBot()),
      ]) {
        _printStats(label, _run(bot, tweak, n));
      }
    }

    print('');
    print('═' * 90);
  });
}
