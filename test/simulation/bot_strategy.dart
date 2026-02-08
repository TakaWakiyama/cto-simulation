import 'package:cto_simulator/core/ap_cost_calculator.dart';
import 'package:cto_simulator/core/contract_engine.dart';
import 'package:cto_simulator/core/employee_engine.dart';
import 'package:cto_simulator/core/event_engine.dart';
import 'package:cto_simulator/core/game_state.dart';
import 'package:cto_simulator/core/infra_engine.dart';
import 'package:cto_simulator/core/models/ceo_background.dart';
import 'package:cto_simulator/core/models/contract_project.dart';
import 'package:cto_simulator/core/models/server.dart';
import 'package:cto_simulator/core/saas_engine.dart';
import 'package:cto_simulator/core/tech_tree_engine.dart';
import 'package:cto_simulator/core/turn_engine.dart';

/// Bot戦略の抽象インターフェース
abstract class BotStrategy {
  String get name;

  /// 1ターン分の行動を決定・実行して新しいGameStateを返す
  /// （ターン終了処理込み）
  GameState playTurn(GameState state) {
    var s = state;

    // 1. ペンディングイベントを自動解決
    s = _resolveEvent(s);

    // 2. 戦略固有のアクション実行
    s = doActions(s);

    // 3. 未アサイン社員を進行中プロジェクトに割り当て（AP不要）
    s = _autoAssignEmployees(s);

    // 4. ターン終了処理
    s = TurnEngine.processTurnEnd(s);

    return s;
  }

  /// 戦略固有のアクションを実行する（サブクラスで実装）
  GameState doActions(GameState state);

  // --- ユーティリティ ---

  /// AP消費コスト取得
  int apCost(GameState state, ActionCategory category) {
    return ApCostCalculator.cost(state.config, category);
  }

  /// AP足りるか
  bool canAfford(GameState state, ActionCategory category) {
    return state.ap >= apCost(state, category);
  }

  /// APを消費
  GameState consumeAp(GameState state, ActionCategory category) {
    return state.copyWith(ap: state.ap - apCost(state, category));
  }

  /// ペンディングイベントの自動解決（コスト最小の選択肢を選ぶ）
  GameState _resolveEvent(GameState state) {
    if (state.pendingEvent == null) return state;
    final event = state.pendingEvent!;
    if (event.choices.isEmpty) {
      return state.copyWith(pendingEvent: () => null);
    }

    // コストが最小の選択肢を選ぶ（無料優先）
    final sorted = [...event.choices]
      ..sort((a, b) => a.cost.compareTo(b.cost));
    final choice = sorted.first;

    // AP不足なら無料の選択肢を探す
    final effectiveChoice =
        (choice.apCost > 0 && state.ap < choice.apCost)
            ? sorted.firstWhere((c) => c.apCost == 0,
                orElse: () => sorted.last)
            : choice;

    return EventEngine.applyEventChoice(state, event, effectiveChoice);
  }

  /// 未アサイン社員を進行中プロジェクトに自動アサイン
  GameState _autoAssignEmployees(GameState state) {
    var s = state;
    final activeProjects = s.activeProjects;
    if (activeProjects.isEmpty) return s;

    for (final employee in s.unassignedEmployees) {
      if (!employee.isEngineer) continue;

      // アサインされている人数が少ないプロジェクトを優先
      final sortedProjects = [...activeProjects]
        ..sort((a, b) =>
            a.assignedEmployeeIds.length.compareTo(b.assignedEmployeeIds.length));

      if (sortedProjects.isNotEmpty) {
        s = ContractEngine.assignEmployee(
            s, sortedProjects.first.id, employee.id);
      }
    }
    return s;
  }

  /// 案件を受注する（AP消費）
  GameState acceptProject(GameState state, String projectId) {
    if (!canAfford(state, ActionCategory.sales)) return state;
    var s = ContractEngine.acceptProject(state, projectId);
    s = consumeAp(s, ActionCategory.sales);
    return s;
  }

  /// 社員を雇用する（AP消費）
  GameState hireFromCandidates(GameState state) {
    if (!canAfford(state, ActionCategory.hiring)) return state;
    if (state.employeeCount >= state.maxEmployees) return state;

    final candidates = EmployeeEngine.generateCandidates(3);
    if (candidates.isEmpty) return state;

    // 最もスキルの高い候補を選ぶ
    final best = candidates.reduce((a, b) => a.skill > b.skill ? a : b);

    final hiringCost = best.salary * 2;
    if (state.money < hiringCost) return state;

    var s = EmployeeEngine.hireEmployee(state, best);
    s = consumeAp(s, ActionCategory.hiring);
    return s;
  }

  /// 案件リフレッシュ（AP消費）
  GameState refreshProjects(GameState state) {
    if (!canAfford(state, ActionCategory.sales)) return state;

    final newProjects =
        ContractEngine.generateProjects(state.currentTurn, state.trust);
    final kept = state.contractProjects
        .where((p) => p.status != ProjectStatus.available)
        .toList();

    var s = state.copyWith(contractProjects: [...kept, ...newProjects]);
    s = consumeAp(s, ActionCategory.sales);
    return s;
  }
}

// ════════════════════════════════════════════════════════════════
// GreedyBot: 報酬最大の案件を受注、全員アサイン
// ════════════════════════════════════════════════════════════════
class GreedyBot extends BotStrategy {
  @override
  String get name => 'GreedyBot';

  @override
  GameState doActions(GameState state) {
    var s = state;

    // アクティブプロジェクトがなければ受注
    if (s.activeProjects.isEmpty) {
      final available = s.availableProjects;
      if (available.isNotEmpty) {
        // 報酬が最大の案件を受注
        final best =
            available.reduce((a, b) => a.reward > b.reward ? a : b);
        s = acceptProject(s, best.id);
      } else {
        // 案件がなければリフレッシュ
        s = refreshProjects(s);
      }
    }

    return s;
  }
}

// ════════════════════════════════════════════════════════════════
// SafeBot: 納期内に完了できる案件のみ受注
// ════════════════════════════════════════════════════════════════
class SafeBot extends BotStrategy {
  @override
  String get name => 'SafeBot';

  @override
  GameState doActions(GameState state) {
    var s = state;

    if (s.activeProjects.isEmpty) {
      final available = s.availableProjects;
      if (available.isNotEmpty) {
        // 現在の社員の総生産力を計算
        final totalProd = s.employees
            .where((e) => e.isEngineer && !e.isAssigned)
            .fold(0.0, (sum, e) => sum + e.productivity);
        final workPerTurn = (totalProd / 10).round();

        // 納期内に完了できる案件をフィルタ
        final feasible = available.where((p) {
          if (workPerTurn <= 0) return false;
          final turnsNeeded = (p.totalWork / workPerTurn).ceil();
          return turnsNeeded <= p.deadline;
        }).toList();

        if (feasible.isNotEmpty) {
          // 実行可能な案件の中で最も報酬が高いものを選ぶ
          final best =
              feasible.reduce((a, b) => a.reward > b.reward ? a : b);
          s = acceptProject(s, best.id);
        } else {
          // 案件リフレッシュ
          s = refreshProjects(s);
        }
      } else {
        s = refreshProjects(s);
      }
    }

    return s;
  }
}

// ════════════════════════════════════════════════════════════════
// GrowthBot: 計画的な採用 + 複数案件並行 + 技術投資
//   人を増やして案件スループットを最大化する成長戦略
// ════════════════════════════════════════════════════════════════
class GrowthBot extends BotStrategy {
  @override
  String get name => 'GrowthBot';

  @override
  GameState doActions(GameState state) {
    var s = state;

    // 1. 案件受注（未アサインのエンジニアがいれば複数案件を並行）
    final unassignedEngineers =
        s.employees.where((e) => e.isEngineer && !e.isAssigned).length;
    if (unassignedEngineers >= 1) {
      final available = s.availableProjects;
      if (available.isNotEmpty && canAfford(s, ActionCategory.sales)) {
        final best =
            available.reduce((a, b) => a.reward > b.reward ? a : b);
        s = acceptProject(s, best.id);
      } else if (available.isEmpty && canAfford(s, ActionCategory.sales)) {
        s = refreshProjects(s);
      }
    }

    // 2. 積極採用（runway 2ヶ月以上なら雇い続ける — ハイリスク）
    for (var i = 0; i < 3; i++) {
      final monthlySalary = s.totalSalary;
      final runway = monthlySalary > 0 ? s.money ~/ monthlySalary : 99;
      if (s.employeeCount < s.maxEmployees && runway >= 2) {
        s = hireFromCandidates(s);
      } else {
        break;
      }
    }

    // 3. 技術投資（採用後でも余裕がある場合）
    final monthlySalary = s.totalSalary;
    final runway = monthlySalary > 0 ? s.money ~/ monthlySalary : 99;
    if (runway >= 3 && canAfford(s, ActionCategory.tech)) {
      final researchable = s.technologies.where((t) =>
          !t.isUnlocked &&
          !t.isResearching &&
          t.canResearch(s.unlockedTechIds) &&
          s.money >= t.researchCost);
      if (researchable.isNotEmpty) {
        final cheapest =
            researchable.reduce((a, b) =>
                a.researchCost < b.researchCost ? a : b);
        s = TechTreeEngine.startResearch(s, cheapest.id);
        s = consumeAp(s, ActionCategory.tech);
      }
    }

    return s;
  }
}

// ════════════════════════════════════════════════════════════════
// SaaSBot: 受託を普通にこなしつつ、案件の合間にSaaS開発
//          → リリース後は複利成長で受託を凌駕する収益を狙う
// ════════════════════════════════════════════════════════════════
class SaaSBot extends BotStrategy {
  @override
  String get name => 'SaaSBot';

  bool _serverPurchased = false;
  bool _saasStarted = false;

  /// SaaSBotは信頼度を重視してイベントを解決する
  @override
  GameState playTurn(GameState state) {
    var s = state;

    // イベント解決（信頼度重視）
    if (s.pendingEvent != null) {
      final event = s.pendingEvent!;
      if (event.choices.isEmpty) {
        s = s.copyWith(pendingEvent: () => null);
      } else {
        // trust効果が最も良い選択肢を選ぶ（コスト払えるなら）
        final affordable = event.choices.where(
            (c) => c.apCost == 0 || s.ap >= c.apCost).toList();
        if (affordable.isNotEmpty) {
          final sorted = [...affordable]..sort((a, b) {
            final aTrust = (a.effects['trust'] as num?)?.toInt() ?? 0;
            final bTrust = (b.effects['trust'] as num?)?.toInt() ?? 0;
            return bTrust.compareTo(aTrust); // trust高い順
          });
          s = EventEngine.applyEventChoice(s, event, sorted.first);
        } else {
          s = EventEngine.applyEventChoice(s, event, event.choices.first);
        }
      }
    }

    s = doActions(s);
    s = _autoAssignEmployees(s);
    s = TurnEngine.processTurnEnd(s);
    return s;
  }

  @override
  GameState doActions(GameState state) {
    var s = state;

    final developingSaaS =
        s.saasProducts.where((p) => !p.isLaunched && !p.isDevelopmentComplete).toList();
    final launchedSaaS =
        s.saasProducts.where((p) => p.isLaunched).toList();
    final saasMonthlyRev = launchedSaaS.fold(0, (sum, p) => sum + p.monthlyRevenue);
    final saasCoversExpenses = saasMonthlyRev >= s.totalMonthlyCost;

    // === Phase 1: SaaS開発前（受託で稼いで資金確保） ===
    // === Phase 2: SaaS開発中（受託なし、全員でSaaS開発に集中→5ターンで完了） ===
    // === Phase 3: SaaS成長中（受託で食いつなぎつつSaaS成長を待つ） ===
    // === Phase 4: SaaS収益が経費を超えた（受託不要） ===

    // SaaS開発開始判定（資金に余裕があり、進行中案件がない隙を狙う）
    if (!_saasStarted && s.saasProducts.isEmpty &&
        s.activeProjects.isEmpty && s.money >= 300 &&
        canAfford(s, ActionCategory.tech)) {
      final taskFlow = SaaSEngine.getAvailableProducts()
          .firstWhere((p) => p.id == 'saas_pm');
      s = s.copyWith(
        saasProducts: [...s.saasProducts, taskFlow],
        money: s.money - taskFlow.developmentCost,
      );
      s = consumeAp(s, ActionCategory.tech);
      _saasStarted = true;
    }

    // SaaS開発中は全エンジニアをSaaS開発に投入（受託は取らない）
    if (developingSaaS.isNotEmpty) {
      final unassigned = s.unassignedEmployees.where((e) => e.isEngineer).toList();
      for (final emp in unassigned) {
        final saas = developingSaaS.first;
        s = s.copyWith(
          employees: s.employees.map((e) {
            if (e.id == emp.id) {
              return e.copyWith(assignedProjectId: () => saas.id);
            }
            return e;
          }).toList(),
        );
      }
      // 開発中は受託を取らない（全力開発）
    } else {
      // SaaS開発中でない場合は受託を回す
      if (!saasCoversExpenses && s.activeProjects.isEmpty) {
        final available = s.availableProjects;
        if (available.isNotEmpty) {
          // 工数が小さい案件を選ぶ（早く終わる→SaaS開発の隙を作る）
          final easiest =
              available.reduce((a, b) => a.totalWork < b.totalWork ? a : b);
          s = acceptProject(s, easiest.id);
        } else if (canAfford(s, ActionCategory.sales)) {
          s = refreshProjects(s);
        }
      }
    }

    // 開発完了したSaaSをリリース
    for (final product in s.saasProducts) {
      if (product.isDevelopmentComplete && !product.isLaunched &&
          canAfford(s, ActionCategory.tech)) {
        // SaaS開発完了→エンジニアをアサイン解除（受託に戻れるように）
        s = s.copyWith(
          employees: s.employees.map((e) {
            if (e.assignedProjectId == product.id) {
              return e.copyWith(assignedProjectId: () => null);
            }
            return e;
          }).toList(),
        );

        if (s.servers.isEmpty && !_serverPurchased) {
          final vps = InfraEngine.getAvailableServers()
              .firstWhere((sv) => sv.id == 'vps_1');
          final cost = vps.monthlyCost * 3;
          if (s.money >= cost) {
            s = InfraEngine.purchaseServer(s, vps);
            _serverPurchased = true;
          }
        }
        if (s.totalServerCapacity > 0) {
          s = SaaSEngine.launchProduct(s, product.id);
          s = consumeAp(s, ActionCategory.tech);
        }
      }
    }

    return s;
  }
}
