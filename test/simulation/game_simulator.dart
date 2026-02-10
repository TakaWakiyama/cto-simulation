import 'package:cto_simulator/core/game_state.dart';
import 'package:cto_simulator/core/models/contract_project.dart';
import 'package:cto_simulator/core/models/game_config.dart';
import 'package:cto_simulator/core/turn_engine.dart';

import 'bot_strategy.dart';

/// 1回のシミュレーション結果
class SimulationResult {
  const SimulationResult({
    required this.survivalTurns,
    required this.finalMoney,
    required this.totalDebt,
    required this.projectsCompleted,
    required this.projectsFailed,
    required this.survived120Turns,
    required this.peakEmployees,
    required this.totalRevenueEarned,
    required this.totalExpensesPaid,
    required this.gameOverReason,
  });

  final int survivalTurns;
  final int finalMoney;
  final int totalDebt;
  final int projectsCompleted;
  final int projectsFailed;
  final bool survived120Turns;
  final int peakEmployees;
  final int totalRevenueEarned;
  final int totalExpensesPaid;
  final String? gameOverReason;
}

/// モンテカルロシミュレーション実行エンジン
class GameSimulator {
  /// 1ゲームをシミュレーション
  static SimulationResult runSingle(BotStrategy bot, {GameConfig? config}) {
    final cfg = config ?? const GameConfig();
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

      final nowCompleted = state.contractProjects
          .where((p) => p.status == ProjectStatus.completed)
          .length;
      final nowFailed = state.contractProjects
          .where((p) =>
              p.status == ProjectStatus.failed ||
              p.status == ProjectStatus.overdue)
          .length;

      projectsCompleted += nowCompleted - prevCompleted;
      projectsFailed += nowFailed - prevFailed;

      if (state.employeeCount > peakEmployees) {
        peakEmployees = state.employeeCount;
      }
    }

    return SimulationResult(
      survivalTurns: state.currentTurn,
      finalMoney: state.money,
      totalDebt: state.totalDebtWithLoans,
      projectsCompleted: projectsCompleted,
      projectsFailed: projectsFailed,
      survived120Turns: state.currentTurn >= cfg.maxTurns,
      peakEmployees: peakEmployees,
      totalRevenueEarned: state.totalEarned,
      totalExpensesPaid: state.totalSpent,
      gameOverReason: state.gameOverReason,
    );
  }

  /// N回モンテカルロシミュレーションを実行
  static List<SimulationResult> runMonteCarlo(
    BotStrategy bot,
    int iterations, {
    GameConfig? config,
  }) {
    final results = <SimulationResult>[];
    for (var i = 0; i < iterations; i++) {
      results.add(runSingle(bot, config: config));
    }
    return results;
  }

  /// 統計を出力
  static void printStats(String botName, List<SimulationResult> results) {
    final n = results.length;
    if (n == 0) return;

    final survived = results.where((r) => r.survived120Turns).length;
    final bankrupted = results.where((r) => r.totalDebt >= 1000).length;
    final avgTurns = results.map((r) => r.survivalTurns).reduce((a, b) => a + b) / n;
    final avgMoney = results.map((r) => r.finalMoney).reduce((a, b) => a + b) / n;
    final avgDebt = results.map((r) => r.totalDebt).reduce((a, b) => a + b) / n;
    final avgCompleted =
        results.map((r) => r.projectsCompleted).reduce((a, b) => a + b) / n;
    final avgFailed =
        results.map((r) => r.projectsFailed).reduce((a, b) => a + b) / n;
    final avgRevenue =
        results.map((r) => r.totalRevenueEarned).reduce((a, b) => a + b) / n;
    final avgExpense =
        results.map((r) => r.totalExpensesPaid).reduce((a, b) => a + b) / n;
    final avgPeakEmp =
        results.map((r) => r.peakEmployees).reduce((a, b) => a + b) / n;

    // ゲームオーバー理由の集計
    final reasons = <String, int>{};
    for (final r in results) {
      if (r.gameOverReason != null) {
        final key = r.gameOverReason!.length > 30
            ? r.gameOverReason!.substring(0, 30)
            : r.gameOverReason!;
        reasons[key] = (reasons[key] ?? 0) + 1;
      }
    }

    print('');
    print('═' * 56);
    print('  $botName ($n回実行)');
    print('═' * 56);
    print('  生存率(120T):     ${(survived / n * 100).toStringAsFixed(1)}%');
    print('  破産率:           ${(bankrupted / n * 100).toStringAsFixed(1)}%');
    print('  平均生存ターン:   ${avgTurns.toStringAsFixed(1)}T');
    print('  平均最終資金:     ${avgMoney.toStringAsFixed(0)}万円');
    print('  平均負債:         ${avgDebt.toStringAsFixed(0)}万円');
    print('  案件完了(平均):   ${avgCompleted.toStringAsFixed(1)}件');
    print('  案件失敗(平均):   ${avgFailed.toStringAsFixed(1)}件');
    print('  総収入(平均):     ${avgRevenue.toStringAsFixed(0)}万円');
    print('  総支出(平均):     ${avgExpense.toStringAsFixed(0)}万円');
    print('  損益(平均):       ${(avgRevenue - avgExpense).toStringAsFixed(0)}万円');
    print('  最大社員数(平均): ${avgPeakEmp.toStringAsFixed(1)}人');
    if (reasons.isNotEmpty) {
      print('  ── ゲームオーバー理由 ──');
      for (final entry in reasons.entries) {
        print('    ${entry.key}: ${entry.value}回');
      }
    }
    print('─' * 56);
  }

  /// 全botの比較テーブルを出力
  static void printComparison(Map<String, List<SimulationResult>> allResults) {
    print('');
    print('═' * 70);
    print('  全Bot比較サマリー');
    print('═' * 70);
    print('  ${'Bot名'.padRight(12)}'
        '${'生存率'.padRight(10)}'
        '${'破産率'.padRight(10)}'
        '${'平均ターン'.padRight(12)}'
        '${'平均損益'.padRight(12)}');
    print('─' * 70);

    for (final entry in allResults.entries) {
      final results = entry.value;
      final n = results.length;
      final survived = results.where((r) => r.survived120Turns).length;
      final bankrupted = results.where((r) => r.totalDebt >= 1000).length;
      final avgTurns =
          results.map((r) => r.survivalTurns).reduce((a, b) => a + b) / n;
      final avgRevenue =
          results.map((r) => r.totalRevenueEarned).reduce((a, b) => a + b) / n;
      final avgExpense =
          results.map((r) => r.totalExpensesPaid).reduce((a, b) => a + b) / n;

      print('  ${entry.key.padRight(12)}'
          '${('${(survived / n * 100).toStringAsFixed(0)}%').padRight(10)}'
          '${('${(bankrupted / n * 100).toStringAsFixed(0)}%').padRight(10)}'
          '${('${avgTurns.toStringAsFixed(1)}T').padRight(12)}'
          '${('${(avgRevenue - avgExpense).toStringAsFixed(0)}万円').padRight(12)}');
    }
    print('═' * 70);
  }
}
