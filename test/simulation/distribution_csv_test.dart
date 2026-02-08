import 'dart:io';

import 'package:cto_simulator/core/game_state.dart';
import 'package:cto_simulator/core/models/contract_project.dart';
import 'package:cto_simulator/core/models/game_config.dart';
import 'package:cto_simulator/core/turn_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'bot_strategy.dart';

/// 各ターンの経済データを記録
class TurnSnapshot {
  TurnSnapshot({
    required this.bot,
    required this.run,
    required this.turn,
    required this.money,
    required this.debt,
    required this.revenue,
    required this.expense,
    required this.employees,
    required this.activeProjects,
    required this.completedProjects,
    required this.trust,
    required this.saasRevenue,
  });

  final String bot;
  final int run;
  final int turn;
  final int money;
  final int debt;
  final int revenue;
  final int expense;
  final int employees;
  final int activeProjects;
  final int completedProjects;
  final int trust;
  final int saasRevenue;
}

/// 1ゲーム完了時のサマリー
class RunSummary {
  RunSummary({
    required this.bot,
    required this.run,
    required this.survivalTurns,
    required this.survived,
    required this.totalRevenue,
    required this.totalExpense,
    required this.profit,
    required this.finalMoney,
    required this.totalDebt,
    required this.projectsCompleted,
    required this.projectsFailed,
    required this.peakEmployees,
    required this.gameOverReason,
  });

  final String bot;
  final int run;
  final int survivalTurns;
  final bool survived;
  final int totalRevenue;
  final int totalExpense;
  final int profit;
  final int finalMoney;
  final int totalDebt;
  final int projectsCompleted;
  final int projectsFailed;
  final int peakEmployees;
  final String gameOverReason;
}

void main() {
  const n = 200;
  const cfg = GameConfig();

  test('Export distribution CSV', () {
    final summaries = <RunSummary>[];
    final turnSnapshots = <TurnSnapshot>[];

    final bots = <String, BotStrategy Function()>{
      'Greedy': () => GreedyBot(),
      'Safe': () => SafeBot(),
      'Growth': () => GrowthBot(),
      'SaaS': () => SaaSBot(),
    };

    for (final entry in bots.entries) {
      final botName = entry.key;
      print('Running $botName x $n ...');

      for (var i = 0; i < n; i++) {
        final bot = entry.value();
        var state = GameState.initial(cfg);
        state = TurnEngine.initializeGame(state);

        var peakEmployees = state.employeeCount;
        var projectsCompleted = 0;
        var projectsFailed = 0;

        while (!state.isGameOver && state.currentTurn <= cfg.maxTurns) {
          final prevCompleted = state.contractProjects
              .where((p) => p.status == ProjectStatus.completed)
              .length;
          final prevFailed = state.contractProjects
              .where((p) =>
                  p.status == ProjectStatus.failed ||
                  p.status == ProjectStatus.overdue)
              .length;

          state = bot.playTurn(state);

          projectsCompleted += state.contractProjects
                  .where((p) => p.status == ProjectStatus.completed)
                  .length -
              prevCompleted;
          projectsFailed += state.contractProjects
                  .where((p) =>
                      p.status == ProjectStatus.failed ||
                      p.status == ProjectStatus.overdue)
                  .length -
              prevFailed;

          if (state.employeeCount > peakEmployees) {
            peakEmployees = state.employeeCount;
          }

          // 10ターンごとにスナップショット記録（データ量抑制）
          if (state.currentTurn % 10 == 0 || state.isGameOver) {
            turnSnapshots.add(TurnSnapshot(
              bot: botName,
              run: i,
              turn: state.currentTurn,
              money: state.money,
              debt: state.totalDebtWithLoans,
              revenue: state.totalEarned,
              expense: state.totalSpent,
              employees: state.employeeCount,
              activeProjects: state.activeProjects.length,
              completedProjects: projectsCompleted,
              trust: state.trust,
              saasRevenue: state.saasRevenue,
            ));
          }
        }

        summaries.add(RunSummary(
          bot: botName,
          run: i,
          survivalTurns: state.currentTurn,
          survived: state.currentTurn >= cfg.maxTurns,
          totalRevenue: state.totalEarned,
          totalExpense: state.totalSpent,
          profit: state.totalEarned - state.totalSpent,
          finalMoney: state.money,
          totalDebt: state.totalDebtWithLoans,
          projectsCompleted: projectsCompleted,
          projectsFailed: projectsFailed,
          peakEmployees: peakEmployees,
          gameOverReason: state.gameOverReason ?? '120T生存',
        ));
      }
    }

    // サマリーCSV出力
    final summaryFile = File('test/simulation/output/summary.csv');
    summaryFile.parent.createSync(recursive: true);
    final summaryBuf = StringBuffer();
    summaryBuf.writeln(
        'bot,run,survival_turns,survived,total_revenue,total_expense,profit,final_money,total_debt,projects_completed,projects_failed,peak_employees,game_over_reason');
    for (final s in summaries) {
      summaryBuf.writeln(
          '${s.bot},${s.run},${s.survivalTurns},${s.survived},${s.totalRevenue},${s.totalExpense},${s.profit},${s.finalMoney},${s.totalDebt},${s.projectsCompleted},${s.projectsFailed},${s.peakEmployees},"${s.gameOverReason}"');
    }
    summaryFile.writeAsStringSync(summaryBuf.toString());
    print('Wrote ${summaryFile.path}');

    // ターンスナップショットCSV出力
    final turnFile = File('test/simulation/output/turn_snapshots.csv');
    final turnBuf = StringBuffer();
    turnBuf.writeln(
        'bot,run,turn,money,debt,revenue,expense,employees,active_projects,completed_projects,trust,saas_revenue');
    for (final t in turnSnapshots) {
      turnBuf.writeln(
          '${t.bot},${t.run},${t.turn},${t.money},${t.debt},${t.revenue},${t.expense},${t.employees},${t.activeProjects},${t.completedProjects},${t.trust},${t.saasRevenue}');
    }
    turnFile.writeAsStringSync(turnBuf.toString());
    print('Wrote ${turnFile.path}');

    print('Done! $n runs x ${bots.length} bots = ${summaries.length} results');
  });
}
