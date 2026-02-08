import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/ap_cost_calculator.dart';
import '../core/contract_engine.dart';
import '../core/economy_engine.dart';
import '../core/employee_engine.dart';
import '../core/event_engine.dart';
import '../core/finance_engine.dart';
import '../core/game_state.dart';
import '../core/infra_engine.dart';
import '../core/models/ceo_background.dart';
import '../core/models/contract_project.dart';
import '../core/models/employee.dart';
import '../core/models/employee_type.dart';
import '../core/models/equity_round.dart';
import '../core/models/event.dart';
import '../core/models/game_config.dart';
import '../core/models/loan.dart';
import '../core/models/server.dart';
import '../core/saas_engine.dart';
import '../core/tech_tree_engine.dart';
import '../core/turn_engine.dart';

class GameNotifier extends StateNotifier<GameState> {
  GameNotifier()
      : super(GameState.initial(const GameConfig()));

  /// ゲーム開始
  void startNewGame(GameConfig config) {
    final initial = GameState.initial(config);
    state = TurnEngine.initializeGame(initial);
  }

  /// ターン終了
  void endTurn() {
    state = TurnEngine.processTurnEnd(state);
  }

  // --- AP消費ヘルパー ---
  int _apCost(ActionCategory category) =>
      ApCostCalculator.cost(state.config, category);

  bool _canAfford(ActionCategory category) =>
      ApCostCalculator.canAfford(state.ap, state.config, category);

  /// 案件を受注
  void acceptProject(String projectId) {
    if (!_canAfford(ActionCategory.sales)) return;
    state = ContractEngine.acceptProject(state, projectId);
    state = state.copyWith(ap: state.ap - _apCost(ActionCategory.sales));
  }

  /// 社員をプロジェクトにアサイン
  void assignEmployee(String projectId, String employeeId) {
    state = ContractEngine.assignEmployee(state, projectId, employeeId);
  }

  /// 社員のアサイン解除
  void unassignEmployee(String employeeId) {
    state = ContractEngine.unassignEmployee(state, employeeId);
  }

  /// 社員を雇用
  void hireEmployee(Employee employee) {
    if (!_canAfford(ActionCategory.hiring)) return;
    state = EmployeeEngine.hireEmployee(state, employee);
    state = state.copyWith(ap: state.ap - _apCost(ActionCategory.hiring));
  }

  /// 社員を解雇
  void fireEmployee(String employeeId) {
    state = EmployeeEngine.fireEmployee(state, employeeId);
  }

  /// 残業指示
  void orderOvertime(String employeeId, String projectId) {
    if (!_canAfford(ActionCategory.management)) return;
    state = EmployeeEngine.orderOvertime(state, employeeId, projectId);
    state = state.copyWith(ap: state.ap - _apCost(ActionCategory.management));
  }

  /// サーバー購入
  void purchaseServer(Server server) {
    if (!_canAfford(ActionCategory.tech)) return;
    state = InfraEngine.purchaseServer(state, server);
    state = state.copyWith(ap: state.ap - _apCost(ActionCategory.tech));
  }

  /// サーバー撤去
  void removeServer(String serverId) {
    state = InfraEngine.removeServer(state, serverId);
  }

  /// SaaS製品の開発開始
  void startSaaSDevelopment(String productId) {
    if (!_canAfford(ActionCategory.tech)) return;
    final product = SaaSEngine.getAvailableProducts()
        .firstWhere((p) => p.id == productId);

    if (state.money < product.developmentCost) {
      state = state.copyWith(
        turnLog: [
          ...state.turnLog,
          '開発費用（${product.developmentCost}万円）が不足しています。',
        ],
      );
      return;
    }

    state = state.copyWith(
      saasProducts: [...state.saasProducts, product],
      money: state.money - product.developmentCost,
      ap: state.ap - _apCost(ActionCategory.tech),
      turnLog: [
        ...state.turnLog,
        '${product.name}の開発を開始しました！ -${product.developmentCost}万円',
      ],
    );
  }

  /// SaaS製品のリリース
  void launchSaaS(String productId) {
    if (!_canAfford(ActionCategory.tech)) return;
    state = SaaSEngine.launchProduct(state, productId);
    state = state.copyWith(ap: state.ap - _apCost(ActionCategory.tech));
  }

  /// 技術研究開始
  void startResearch(String techId) {
    if (!_canAfford(ActionCategory.tech)) return;
    state = TechTreeEngine.startResearch(state, techId);
    state = state.copyWith(ap: state.ap - _apCost(ActionCategory.tech));
  }

  /// イベント選択肢の決定
  void resolveEvent(EventChoice choice) {
    if (state.pendingEvent == null) return;
    state = EventEngine.applyEventChoice(state, state.pendingEvent!, choice);
  }

  /// 負債返済
  void repayDebt(int amount) {
    state = EconomyEngine.repayDebt(state, amount);
  }

  /// 新しい案件を生成（リフレッシュ）
  void refreshProjects() {
    if (!_canAfford(ActionCategory.sales)) return;
    final newProjects =
        ContractEngine.generateProjects(state.currentTurn, state.trust);
    // 進行中の案件は維持し、募集中の案件だけ更新
    final activeProjects = state.contractProjects
        .where((p) => p.status != ProjectStatus.available)
        .toList();
    state = state.copyWith(
      contractProjects: [...activeProjects, ...newProjects],
      ap: state.ap - _apCost(ActionCategory.sales),
      turnLog: [
        ...state.turnLog,
        '新しい案件情報を取得しました。',
      ],
    );
  }

  /// 採用候補を生成
  List<Employee> getHiringCandidates() {
    return EmployeeEngine.generateCandidates(3);
  }

  /// 非エンジニアスタッフの採用候補を生成
  List<Employee> getStaffCandidates(EmployeeType type) {
    return EmployeeEngine.generateStaffCandidates(type, 3);
  }

  /// 非エンジニアスタッフを雇用
  void hireStaff(Employee employee) {
    if (!_canAfford(ActionCategory.hiring)) return;
    state = EmployeeEngine.hireEmployee(state, employee);
    state = state.copyWith(ap: state.ap - _apCost(ActionCategory.hiring));
  }

  /// ローン借入
  void takeLoan(LoanSize size) {
    if (!_canAfford(ActionCategory.finance)) return;
    state = FinanceEngine.takeLoan(state, size);
    state = state.copyWith(ap: state.ap - _apCost(ActionCategory.finance));
  }

  /// エクイティ調達
  void raiseEquity(EquityRoundType type) {
    if (!_canAfford(ActionCategory.finance)) return;
    state = FinanceEngine.raiseEquity(state, type);
    state = state.copyWith(ap: state.ap - _apCost(ActionCategory.finance));
  }

  /// ローン繰上返済
  void earlyRepayLoan(String loanId) {
    state = FinanceEngine.earlyRepayLoan(state, loanId);
  }

  /// 特定アクションのAPコストを取得（UI表示用）
  int getActionApCost(ActionCategory category) => _apCost(category);

  /// ログをクリア
  void clearLog() {
    state = state.copyWith(turnLog: const []);
  }
}

final gameProvider =
    StateNotifierProvider<GameNotifier, GameState>((ref) => GameNotifier());
