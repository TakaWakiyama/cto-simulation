import 'package:cto_simulator/core/contract_engine.dart';
import 'package:cto_simulator/core/event_engine.dart';
import 'package:cto_simulator/core/game_state.dart';
import 'package:cto_simulator/core/turn_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'bot_strategy.dart';
import 'game_simulator.dart';

/// パラメータ調整ラッパー: 報酬と工数に倍率を適用
class TweakedBot extends BotStrategy {
  TweakedBot({
    required this.inner,
    this.rewardMultiplier = 1.0,
    this.workMultiplier = 1.0,
  });

  final BotStrategy inner;
  final double rewardMultiplier;
  final double workMultiplier;
  final Set<String> _modifiedIds = {};

  @override
  String get name =>
      '${inner.name}(報酬×${rewardMultiplier},工数×${workMultiplier})';

  @override
  GameState playTurn(GameState state) {
    var s = _tweakNewProjects(state);

    // ペンディングイベント解決
    if (s.pendingEvent != null) {
      s = _resolveEventPublic(s);
    }

    // 戦略アクション
    s = inner.doActions(s);

    // 自動アサイン
    s = _autoAssign(s);

    // ターン進行
    s = TurnEngine.processTurnEnd(s);

    // 新しく生成された案件にも倍率適用
    s = _tweakNewProjects(s);

    return s;
  }

  @override
  GameState doActions(GameState state) => inner.doActions(state);

  /// 新規プロジェクトにパラメータ調整を適用
  GameState _tweakNewProjects(GameState state) {
    var changed = false;
    final tweaked = state.contractProjects.map((p) {
      if (_modifiedIds.contains(p.id)) return p;
      _modifiedIds.add(p.id);
      changed = true;
      return p.copyWith(
        reward: (p.reward * rewardMultiplier).round(),
        totalWork: (p.totalWork * workMultiplier).round(),
      );
    }).toList();

    return changed ? state.copyWith(contractProjects: tweaked) : state;
  }

  GameState _resolveEventPublic(GameState state) {
    if (state.pendingEvent == null) return state;
    final event = state.pendingEvent!;
    if (event.choices.isEmpty) {
      return state.copyWith(pendingEvent: () => null);
    }
    final sorted = [...event.choices]
      ..sort((a, b) => a.cost.compareTo(b.cost));
    final choice = sorted.first;
    final effectiveChoice =
        (choice.apCost > 0 && state.ap < choice.apCost)
            ? sorted.firstWhere((c) => c.apCost == 0,
                orElse: () => sorted.last)
            : choice;
    return EventEngine.applyEventChoice(state, event, effectiveChoice);
  }

  GameState _autoAssign(GameState state) {
    var s = state;
    final activeProjects = s.activeProjects;
    if (activeProjects.isEmpty) return s;

    for (final employee in s.unassignedEmployees) {
      if (!employee.isEngineer) continue;
      final sortedProjects = [...activeProjects]
        ..sort((a, b) => a.assignedEmployeeIds.length
            .compareTo(b.assignedEmployeeIds.length));
      if (sortedProjects.isNotEmpty) {
        s = ContractEngine.assignEmployee(
            s, sortedProjects.first.id, employee.id);
      }
    }
    return s;
  }
}

void main() {
  const iterations = 50;

  test('Parameter sweep: reward × work multiplier grid', () {
    final rewardMultipliers = [1.0, 2.0, 3.0, 4.0, 5.0];
    final workMultipliers = [1.0, 0.5, 0.33];

    print('');
    print('${'═' * 80}');
    print('  パラメータスイープ: GreedyBot ($iterations回/条件)');
    print('${'═' * 80}');

    // ヘッダー
    final header = StringBuffer('  ${'報酬＼工数'.padRight(14)}');
    for (final wm in workMultipliers) {
      header.write('工数×${wm.toStringAsFixed(2).padRight(10)}');
    }
    print(header);
    print('${'─' * 80}');

    // グリッド
    for (final rm in rewardMultipliers) {
      final row = StringBuffer('  報酬×${rm.toStringAsFixed(1).padRight(9)}');

      for (final wm in workMultipliers) {
        final bot = TweakedBot(
          inner: GreedyBot(),
          rewardMultiplier: rm,
          workMultiplier: wm,
        );
        final results = GameSimulator.runMonteCarlo(bot, iterations);
        final n = results.length;
        final survived = results.where((r) => r.survived120Turns).length;
        final survRate = (survived / n * 100).toStringAsFixed(0);
        final avgTurns =
            results.map((r) => r.survivalTurns).reduce((a, b) => a + b) / n;

        row.write(
            '${survRate.padLeft(3)}% ${avgTurns.toStringAsFixed(0).padLeft(3)}T   ');
      }

      print(row);
    }

    print('${'═' * 80}');
    print('  (生存率% / 平均生存ターン)');
    print('');

    // 有望な組み合わせの詳細表示
    print('');
    print('${'═' * 80}');
    print('  有望パラメータの詳細（全4bot比較）');
    print('${'═' * 80}');

    final promising = [
      (3.0, 0.5),
      (4.0, 0.5),
      (3.0, 0.33),
      (2.0, 0.33),
    ];

    for (final (rm, wm) in promising) {
      print('\n  ── 報酬×$rm / 工数×$wm ──');

      final bots = <BotStrategy>[
        TweakedBot(
            inner: GreedyBot(),
            rewardMultiplier: rm,
            workMultiplier: wm),
        TweakedBot(
            inner: SafeBot(),
            rewardMultiplier: rm,
            workMultiplier: wm),
        TweakedBot(
            inner: GrowthBot(),
            rewardMultiplier: rm,
            workMultiplier: wm),
        TweakedBot(
            inner: SaaSBot(),
            rewardMultiplier: rm,
            workMultiplier: wm),
      ];

      for (final bot in bots) {
        final results = GameSimulator.runMonteCarlo(bot, iterations);
        final n = results.length;
        final survived = results.where((r) => r.survived120Turns).length;
        final bankrupted = results.where((r) => r.totalDebt >= 1000).length;
        final avgTurns = results
                .map((r) => r.survivalTurns)
                .reduce((a, b) => a + b) /
            n;
        final avgRevenue = results
                .map((r) => r.totalRevenueEarned)
                .reduce((a, b) => a + b) /
            n;
        final avgExpense = results
                .map((r) => r.totalExpensesPaid)
                .reduce((a, b) => a + b) /
            n;
        final avgCompleted = results
                .map((r) => r.projectsCompleted)
                .reduce((a, b) => a + b) /
            n;

        final botLabel = bot.name.contains('(')
            ? bot.name.substring(0, bot.name.indexOf('('))
            : bot.name;

        print('    ${botLabel.padRight(12)}'
            '生存${(survived / n * 100).toStringAsFixed(0).padLeft(3)}%  '
            '破産${(bankrupted / n * 100).toStringAsFixed(0).padLeft(3)}%  '
            '${avgTurns.toStringAsFixed(0).padLeft(3)}T  '
            '損益${(avgRevenue - avgExpense).toStringAsFixed(0).padLeft(6)}万  '
            '完了${avgCompleted.toStringAsFixed(1)}件');
      }
    }

    print('');
    print('${'═' * 80}');
  });
}
