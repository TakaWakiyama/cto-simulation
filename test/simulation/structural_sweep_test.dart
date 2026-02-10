import 'package:cto_simulator/core/contract_engine.dart';
import 'package:cto_simulator/core/event_engine.dart';
import 'package:cto_simulator/core/game_state.dart';
import 'package:cto_simulator/core/models/ceo_background.dart';
import 'package:cto_simulator/core/models/contract_project.dart';
import 'package:cto_simulator/core/models/game_config.dart';
import 'package:cto_simulator/core/turn_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'bot_strategy.dart';
import 'game_simulator.dart';

/// ゲーム構造パラメータの調整セット
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
    this.hiringCostRefund = 0.0,
  });

  final String label;
  final double rewardMultiplier;
  final double workMultiplier;
  final int startingMoney;
  final double upfrontRate; // 受注時に前払い（報酬の%）
  final int fatigueReduction; // ターン後に疲労をN追加回復
  final int happinessBoost; // ターン後に幸福度をN追加
  final int overdueTrustRestore; // 納期超過ペナルティをN回復
  final double hiringCostRefund; // 採用費用のN%を還元
}

/// 構造調整付きBot
class StructuralBot extends BotStrategy {
  StructuralBot({
    required this.inner,
    required this.tweak,
  });

  final BotStrategy inner;
  final StructuralTweak tweak;
  final Set<String> _modifiedProjectIds = {};
  final Set<String> _upfrontPaidIds = {};

  @override
  String get name => tweak.label.isNotEmpty ? tweak.label : inner.name;

  @override
  GameState playTurn(GameState state) {
    var s = _tweakProjects(state);

    // イベント解決
    if (s.pendingEvent != null) {
      s = _resolveEvent(s);
    }

    // 戦略アクション（案件受注時に前払い処理を含む）
    final beforeProjects = s.contractProjects
        .where((p) => p.status == ProjectStatus.inProgress)
        .map((p) => p.id)
        .toSet();

    s = inner.doActions(s);
    s = _tweakProjects(s); // refresh後の新案件にも適用

    // 新たに受注された案件に前払い
    if (tweak.upfrontRate > 0) {
      for (final p in s.contractProjects) {
        if (p.status == ProjectStatus.inProgress &&
            !beforeProjects.contains(p.id) &&
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

    // 自動アサイン
    s = _autoAssign(s);

    // ターン進行
    final trustBefore = s.trust;
    s = TurnEngine.processTurnEnd(s);

    // 構造調整: 疲労回復・幸福度ブースト
    if (tweak.fatigueReduction > 0 || tweak.happinessBoost > 0) {
      s = s.copyWith(
        employees: s.employees.map((e) {
          return e.copyWith(
            fatigue:
                (e.fatigue - tweak.fatigueReduction).clamp(0, 100),
            happiness:
                (e.happiness + tweak.happinessBoost).clamp(0, 100),
          );
        }).toList(),
      );
    }

    // 構造調整: 納期超過ペナルティの軽減
    if (tweak.overdueTrustRestore > 0 && s.trust < trustBefore) {
      final lost = trustBefore - s.trust;
      final restore = lost.clamp(0, tweak.overdueTrustRestore);
      s = s.copyWith(trust: (s.trust + restore).clamp(0, 100));
    }

    // 新ターンの案件にも適用
    s = _tweakProjects(s);

    return s;
  }

  @override
  GameState doActions(GameState state) => inner.doActions(state);

  GameState _tweakProjects(GameState state) {
    var changed = false;
    final tweaked = state.contractProjects.map((p) {
      if (_modifiedProjectIds.contains(p.id)) return p;
      _modifiedProjectIds.add(p.id);
      changed = true;
      return p.copyWith(
        reward: (p.reward * tweak.rewardMultiplier).round(),
        totalWork: (p.totalWork * tweak.workMultiplier).round(),
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
    for (final employee in s.unassignedEmployees) {
      if (!employee.isEngineer) continue;
      final active = s.activeProjects;
      if (active.isEmpty) break;
      final sorted = [...active]
        ..sort((a, b) => a.assignedEmployeeIds.length
            .compareTo(b.assignedEmployeeIds.length));
      s = ContractEngine.assignEmployee(s, sorted.first.id, employee.id);
    }
    return s;
  }
}

/// カスタム初期資金でシミュレーション実行
List<SimulationResult> runWithTweak(
  BotStrategy innerBot,
  StructuralTweak tweak,
  int iterations,
) {
  final bot = StructuralBot(inner: innerBot, tweak: tweak);
  final results = <SimulationResult>[];

  for (var i = 0; i < iterations; i++) {
    const cfg = GameConfig();
    var state = GameState.initial(cfg);
    // 初期資金を差し替え
    state = state.copyWith(money: tweak.startingMoney);
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
    }

    results.add(SimulationResult(
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
    ));
  }

  return results;
}

void _printRow(String label, List<SimulationResult> results) {
  final n = results.length;
  final survived = results.where((r) => r.survived120Turns).length;
  final bankrupted = results.where((r) => r.totalDebt >= 1000).length;
  final quit = results
      .where((r) => r.gameOverReason?.contains('退職') ?? false)
      .length;
  final trustZero = results
      .where((r) => r.gameOverReason?.contains('信頼度') ?? false)
      .length;
  final avgTurns =
      results.map((r) => r.survivalTurns).reduce((a, b) => a + b) / n;
  final avgRevenue =
      results.map((r) => r.totalRevenueEarned).reduce((a, b) => a + b) / n;
  final avgExpense =
      results.map((r) => r.totalExpensesPaid).reduce((a, b) => a + b) / n;
  final avgCompleted =
      results.map((r) => r.projectsCompleted).reduce((a, b) => a + b) / n;

  print('  ${label.padRight(22)}'
      '生存${(survived / n * 100).toStringAsFixed(0).padLeft(3)}%  '
      '破産${(bankrupted / n * 100).toStringAsFixed(0).padLeft(3)}%  '
      '退職${(quit / n * 100).toStringAsFixed(0).padLeft(3)}%  '
      '信頼${(trustZero / n * 100).toStringAsFixed(0).padLeft(3)}%  '
      '${avgTurns.toStringAsFixed(0).padLeft(3)}T  '
      '完了${avgCompleted.toStringAsFixed(1).padLeft(4)}件');
}

void main() {
  const n = 200;

  test('Structural parameter sweep', () {
    // ════════════════════════════════════════════════
    // Phase 1: 個別パラメータの影響度測定
    // ════════════════════════════════════════════════
    print('');
    print('═' * 90);
    print('  Phase 1: 個別パラメータの影響度 (GreedyBot, $n回/条件)');
    print('═' * 90);

    final baseline = const StructuralTweak(label: '現状(ベースライン)');
    final singles = [
      baseline,
      const StructuralTweak(
          label: '報酬×3のみ', rewardMultiplier: 3.0),
      const StructuralTweak(
          label: '工数×0.5のみ', workMultiplier: 0.5),
      const StructuralTweak(
          label: '初期資金500万', startingMoney: 500),
      const StructuralTweak(
          label: '初期資金1000万', startingMoney: 1000),
      const StructuralTweak(
          label: '前払い30%', upfrontRate: 0.3),
      const StructuralTweak(
          label: '前払い50%', upfrontRate: 0.5),
      const StructuralTweak(
          label: '疲労軽減(+3回復)', fatigueReduction: 3),
      const StructuralTweak(
          label: '疲労軽減(+5回復)', fatigueReduction: 5),
      const StructuralTweak(
          label: '幸福度+3/T', happinessBoost: 3),
      const StructuralTweak(
          label: '信頼ペナ軽減(+3)', overdueTrustRestore: 3),
    ];

    for (final tweak in singles) {
      final results = runWithTweak(GreedyBot(), tweak, n);
      _printRow(tweak.label, results);
    }
    print('─' * 90);

    // ════════════════════════════════════════════════
    // Phase 2: 修正パッケージの比較
    // ════════════════════════════════════════════════
    print('');
    print('═' * 90);
    print('  Phase 2: 修正パッケージ比較 (GreedyBot, $n回)');
    print('═' * 90);

    final packages = [
      const StructuralTweak(
        label: 'A: 経済のみ',
        rewardMultiplier: 3.0,
        workMultiplier: 0.5,
        startingMoney: 500,
      ),
      const StructuralTweak(
        label: 'B: A+社員ケア',
        rewardMultiplier: 3.0,
        workMultiplier: 0.5,
        startingMoney: 500,
        fatigueReduction: 3,
        happinessBoost: 2,
      ),
      const StructuralTweak(
        label: 'C: A+キャッシュフロー',
        rewardMultiplier: 3.0,
        workMultiplier: 0.5,
        startingMoney: 500,
        upfrontRate: 0.3,
      ),
      const StructuralTweak(
        label: 'D: A+B+C',
        rewardMultiplier: 3.0,
        workMultiplier: 0.5,
        startingMoney: 500,
        fatigueReduction: 3,
        happinessBoost: 2,
        upfrontRate: 0.3,
      ),
      const StructuralTweak(
        label: 'E: D+信頼軽減',
        rewardMultiplier: 3.0,
        workMultiplier: 0.5,
        startingMoney: 500,
        fatigueReduction: 3,
        happinessBoost: 2,
        upfrontRate: 0.3,
        overdueTrustRestore: 3,
      ),
      const StructuralTweak(
        label: 'F: フル修正',
        rewardMultiplier: 3.0,
        workMultiplier: 0.5,
        startingMoney: 700,
        fatigueReduction: 4,
        happinessBoost: 3,
        upfrontRate: 0.3,
        overdueTrustRestore: 3,
      ),
      const StructuralTweak(
        label: 'G: 現実寄り',
        rewardMultiplier: 2.5,
        workMultiplier: 0.4,
        startingMoney: 500,
        fatigueReduction: 3,
        happinessBoost: 2,
        upfrontRate: 0.3,
        overdueTrustRestore: 2,
      ),
    ];

    for (final pkg in packages) {
      final results = runWithTweak(GreedyBot(), pkg, n);
      _printRow(pkg.label, results);
    }
    print('─' * 90);

    // ════════════════════════════════════════════════
    // Phase 3: ベスト候補を全bot比較
    // ════════════════════════════════════════════════
    print('');
    print('═' * 90);
    print('  Phase 3: ベスト候補の全bot比較 ($n回)');
    print('═' * 90);

    // Phase 2で良さそうなパッケージをピックアップ
    final bestCandidates = [
      const StructuralTweak(
        label: 'E: D+信頼軽減',
        rewardMultiplier: 3.0,
        workMultiplier: 0.5,
        startingMoney: 500,
        fatigueReduction: 3,
        happinessBoost: 2,
        upfrontRate: 0.3,
        overdueTrustRestore: 3,
      ),
      const StructuralTweak(
        label: 'F: フル修正',
        rewardMultiplier: 3.0,
        workMultiplier: 0.5,
        startingMoney: 700,
        fatigueReduction: 4,
        happinessBoost: 3,
        upfrontRate: 0.3,
        overdueTrustRestore: 3,
      ),
    ];

    for (final pkg in bestCandidates) {
      print('\n  ── ${pkg.label} ──');
      final bots = [
        ('Greedy', GreedyBot()),
        ('Safe', SafeBot()),
        ('Growth', GrowthBot()),
        ('SaaS', SaaSBot()),
      ];
      for (final (label, bot) in bots) {
        final results = runWithTweak(bot, pkg, n);
        _printRow(label, results);
      }
    }

    print('');
    print('═' * 90);
  });
}
