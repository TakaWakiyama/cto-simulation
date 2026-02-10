import 'package:cto_simulator/core/contract_engine.dart';
import 'package:cto_simulator/core/event_engine.dart';
import 'package:cto_simulator/core/game_state.dart';
import 'package:cto_simulator/core/models/ceo_background.dart';
import 'package:cto_simulator/core/models/contract_project.dart';
import 'package:cto_simulator/core/turn_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'bot_strategy.dart';
import 'game_simulator.dart';

/// パラメータ調整ラッパー（改良版）
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
  String get name => inner.name;

  @override
  GameState playTurn(GameState state) {
    var s = _tweakNewProjects(state);
    if (s.pendingEvent != null) {
      s = _resolveEvent(s);
    }
    s = inner.doActions(s);
    s = _tweakNewProjects(s); // doActions内でrefreshされた案件にも適用
    s = _autoAssign(s);
    s = TurnEngine.processTurnEnd(s);
    s = _tweakNewProjects(s);
    return s;
  }

  @override
  GameState doActions(GameState state) => inner.doActions(state);

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

  GameState _resolveEvent(GameState state) {
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
      final sorted = [...activeProjects]
        ..sort((a, b) => a.assignedEmployeeIds.length
            .compareTo(b.assignedEmployeeIds.length));
      if (sorted.isNotEmpty) {
        s = ContractEngine.assignEmployee(s, sorted.first.id, employee.id);
      }
    }
    return s;
  }
}

/// 改良型GreedyBot: 複数案件を同時受注 + 案件がなければリフレッシュ
class MultiProjectBot extends BotStrategy {
  @override
  String get name => 'MultiProjBot';

  @override
  GameState doActions(GameState state) {
    var s = state;

    // 空きエンジニアがいる限り案件を受注
    while (canAfford(s, ActionCategory.sales)) {
      final unassigned = s.employees.where((e) => e.isEngineer && !e.isAssigned);
      if (unassigned.isEmpty) break;

      final available = s.availableProjects;
      if (available.isEmpty) {
        // リフレッシュして再チャレンジ
        s = refreshProjects(s);
        break;
      }

      final best = available.reduce((a, b) => a.reward > b.reward ? a : b);
      s = acceptProject(s, best.id);
    }

    return s;
  }
}

void main() {
  const iterations = 100;

  test('Extended parameter sweep with wider range', () {
    final rewardMultipliers = [3.0, 5.0, 7.0, 10.0];
    final workMultipliers = [0.5, 0.33, 0.25];

    print('');
    print('═' * 80);
    print('  拡張パラメータスイープ: GreedyBot ($iterations回/条件)');
    print('═' * 80);

    final header = StringBuffer('  ${'報酬＼工数'.padRight(14)}');
    for (final wm in workMultipliers) {
      header.write('工数×${wm.toStringAsFixed(2).padRight(12)}');
    }
    print(header);
    print('─' * 80);

    for (final rm in rewardMultipliers) {
      final row = StringBuffer('  報酬×${rm.toStringAsFixed(0).padLeft(2).padRight(10)}');
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
            '${survRate.padLeft(3)}% ${avgTurns.toStringAsFixed(0).padLeft(3)}T     ');
      }
      print(row);
    }
    print('═' * 80);

    // MultiProjectBot（複数案件同時受注）も比較
    print('');
    print('═' * 80);
    print('  MultiProjectBot（複数案件同時受注） ($iterations回/条件)');
    print('═' * 80);

    final header2 = StringBuffer('  ${'報酬＼工数'.padRight(14)}');
    for (final wm in workMultipliers) {
      header2.write('工数×${wm.toStringAsFixed(2).padRight(12)}');
    }
    print(header2);
    print('─' * 80);

    for (final rm in rewardMultipliers) {
      final row = StringBuffer('  報酬×${rm.toStringAsFixed(0).padLeft(2).padRight(10)}');
      for (final wm in workMultipliers) {
        final bot = TweakedBot(
          inner: MultiProjectBot(),
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
            '${survRate.padLeft(3)}% ${avgTurns.toStringAsFixed(0).padLeft(3)}T     ');
      }
      print(row);
    }
    print('═' * 80);

    // ベストな組み合わせの詳細
    print('');
    print('═' * 80);
    print('  有望パラメータ 詳細比較（全bot）');
    print('═' * 80);

    final promising = [
      (5.0, 0.33),
      (7.0, 0.33),
      (10.0, 0.33),
      (7.0, 0.25),
      (10.0, 0.25),
    ];

    for (final (rm, wm) in promising) {
      print('\n  ── 報酬×${rm.toStringAsFixed(0)} / 工数×$wm ──');

      final bots = <(String, BotStrategy)>[
        ('Greedy', GreedyBot()),
        ('Safe', SafeBot()),
        ('Growth', GrowthBot()),
        ('MultiProj', MultiProjectBot()),
      ];

      for (final (label, innerBot) in bots) {
        final bot = TweakedBot(
            inner: innerBot, rewardMultiplier: rm, workMultiplier: wm);
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

        print('    ${label.padRight(12)}'
            '生存${(survived / n * 100).toStringAsFixed(0).padLeft(3)}%  '
            '破産${(bankrupted / n * 100).toStringAsFixed(0).padLeft(3)}%  '
            '${avgTurns.toStringAsFixed(0).padLeft(3)}T  '
            '損益${(avgRevenue - avgExpense).toStringAsFixed(0).padLeft(7)}万  '
            '完了${avgCompleted.toStringAsFixed(1).padLeft(4)}件');
      }
    }

    // 死因分析
    print('');
    print('═' * 80);
    print('  死因分析 (報酬×7 / 工数×0.33 / GreedyBot)');
    print('═' * 80);
    {
      final bot = TweakedBot(
          inner: GreedyBot(), rewardMultiplier: 7, workMultiplier: 0.33);
      final results = GameSimulator.runMonteCarlo(bot, 200);
      final reasons = <String, int>{};
      for (final r in results) {
        if (r.gameOverReason != null) {
          reasons[r.gameOverReason!] =
              (reasons[r.gameOverReason!] ?? 0) + 1;
        }
      }
      final survived = results.where((r) => r.survived120Turns).length;
      print('  生存: $survived / ${results.length}');
      for (final e in reasons.entries) {
        print('  ${e.value}回: ${e.key}');
      }
    }

    print('');
    print('═' * 80);
  });
}
