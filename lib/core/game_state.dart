import 'package:flutter/foundation.dart';

import 'models/contract_project.dart';
import 'models/employee.dart';
import 'models/equity_round.dart';
import 'models/event.dart';
import 'models/game_config.dart';
import 'models/loan.dart';
import 'models/office.dart';
import 'models/saas_product.dart';
import 'models/server.dart';
import 'models/technology.dart';

@immutable
class GameState {
  const GameState({
    required this.config,
    this.currentTurn = 1,
    this.money = 300,
    this.debt = 0,
    this.trust = 30,
    this.ap = 3,
    this.employees = const [],
    this.servers = const [],
    this.contractProjects = const [],
    this.saasProducts = const [],
    this.technologies = const [],
    this.office,
    this.triggeredEventIds = const [],
    this.pendingEvent,
    this.monthlyRevenue = 0,
    this.monthlyExpense = 0,
    this.totalEarned = 0,
    this.totalSpent = 0,
    this.turnLog = const [],
    this.isGameOver = false,
    this.gameOverReason,
    this.loans = const [],
    this.equityRounds = const [],
  });

  final GameConfig config;
  final int currentTurn;
  final int money; // 所持金（万円）
  final int debt; // 負債（万円）
  final int trust; // 信頼度 0-100
  final int ap; // アクションポイント

  final List<Employee> employees;
  final List<Server> servers;
  final List<ContractProject> contractProjects;
  final List<SaaSProduct> saasProducts;
  final List<Technology> technologies;
  final Office? office;

  final List<String> triggeredEventIds;
  final GameEvent? pendingEvent;

  final int monthlyRevenue;
  final int monthlyExpense;
  final int totalEarned;
  final int totalSpent;

  final List<String> turnLog;
  final bool isGameOver;
  final String? gameOverReason;

  // 資金調達
  final List<Loan> loans;
  final List<EquityRound> equityRounds;

  // 計算プロパティ
  int get totalSalary => employees.fold(0, (sum, e) => sum + e.salary);
  int get totalServerCost => servers.fold(0, (sum, s) => sum + s.monthlyCost);
  int get officeCost => office?.monthlyCost ?? 0;

  int get saasMaintenanceCost =>
      saasProducts.where((p) => p.isLaunched).fold(0, (sum, p) => sum + p.monthlyMaintenanceCost);

  int get totalMonthlyCost =>
      totalSalary + totalServerCost + officeCost + saasMaintenanceCost;

  int get saasRevenue =>
      saasProducts.fold(0, (sum, p) => sum + p.monthlyRevenue);

  int get totalSaasUsers =>
      saasProducts.fold(0, (sum, p) => sum + p.totalUsers);

  int get employeeCount => employees.length;
  int get maxEmployees => office?.maxEmployees ?? 3;

  double get averageHappiness => employees.isEmpty
      ? 100.0
      : employees.fold(0.0, (sum, e) => sum + e.happiness) / employees.length;

  double get averageFatigue => employees.isEmpty
      ? 0.0
      : employees.fold(0.0, (sum, e) => sum + e.fatigue) / employees.length;

  List<ContractProject> get activeProjects => contractProjects
      .where((p) =>
          p.status == ProjectStatus.inProgress ||
          p.status == ProjectStatus.overdue)
      .toList();

  List<ContractProject> get availableProjects => contractProjects
      .where((p) => p.status == ProjectStatus.available)
      .toList();

  List<Employee> get unassignedEmployees =>
      employees.where((e) => !e.isAssigned).toList();

  List<String> get unlockedTechIds =>
      technologies.where((t) => t.isUnlocked).map((t) => t.id).toList();

  int get totalServerCapacity =>
      servers.where((s) => !s.isDown).fold(0, (sum, s) => sum + s.capacity);

  bool get isLastTurn => currentTurn >= config.maxTurns;

  // ローン関連プロパティ
  int get totalLoanDebt =>
      loans.fold(0, (sum, l) => sum + l.remainingPrincipal);

  int get totalDebtWithLoans => debt + totalLoanDebt;

  int get monthlyLoanPayment =>
      loans.where((l) => !l.isPaidOff).fold(0, (sum, l) => sum + l.monthlyPayment);

  List<Loan> get activeLoans => loans.where((l) => !l.isPaidOff).toList();

  // エクイティ関連プロパティ
  int get totalEquitySold =>
      equityRounds.fold(0, (sum, r) => sum + r.equityPercent);

  int get remainingEquity => 100 - totalEquitySold;

  bool get hasEquity => equityRounds.isNotEmpty;

  /// 企業価値の計算
  int get companyValue {
    final assetValue = money - debt - totalLoanDebt;
    final saasValue = saasProducts.fold(
        0, (sum, p) => sum + (p.monthlyRevenue * 24)); // MRR × 24ヶ月
    final techValue = technologies
        .where((t) => t.isUnlocked)
        .fold(0, (sum, t) => sum + t.researchCost);
    final trustValue = trust * 10;
    return assetValue + saasValue + techValue + trustValue;
  }

  /// ゲーム状態を条件判定用のMapに変換
  Map<String, dynamic> toConditionMap() => {
        'money': money,
        'debt': debt,
        'trust': trust,
        'turn': currentTurn,
        'employeeCount': employeeCount,
        'saasUsers': totalSaasUsers,
        'hasDebt': debt > 0,
        'hasSaaS': saasProducts.any((p) => p.isLaunched),
        'hasEquity': hasEquity,
        'totalEquitySold': totalEquitySold,
        'totalDebtWithLoans': totalDebtWithLoans,
      };

  factory GameState.initial(GameConfig config) => GameState(
        config: config,
        money: config.effectiveStartingMoney,
        trust: config.startingTrust,
        ap: config.apPerTurn,
      );

  GameState copyWith({
    GameConfig? config,
    int? currentTurn,
    int? money,
    int? debt,
    int? trust,
    int? ap,
    List<Employee>? employees,
    List<Server>? servers,
    List<ContractProject>? contractProjects,
    List<SaaSProduct>? saasProducts,
    List<Technology>? technologies,
    Office? Function()? office,
    List<String>? triggeredEventIds,
    GameEvent? Function()? pendingEvent,
    int? monthlyRevenue,
    int? monthlyExpense,
    int? totalEarned,
    int? totalSpent,
    List<String>? turnLog,
    bool? isGameOver,
    String? Function()? gameOverReason,
    List<Loan>? loans,
    List<EquityRound>? equityRounds,
  }) {
    return GameState(
      config: config ?? this.config,
      currentTurn: currentTurn ?? this.currentTurn,
      money: money ?? this.money,
      debt: debt ?? this.debt,
      trust: trust ?? this.trust,
      ap: ap ?? this.ap,
      employees: employees ?? this.employees,
      servers: servers ?? this.servers,
      contractProjects: contractProjects ?? this.contractProjects,
      saasProducts: saasProducts ?? this.saasProducts,
      technologies: technologies ?? this.technologies,
      office: office != null ? office() : this.office,
      triggeredEventIds: triggeredEventIds ?? this.triggeredEventIds,
      pendingEvent: pendingEvent != null ? pendingEvent() : this.pendingEvent,
      monthlyRevenue: monthlyRevenue ?? this.monthlyRevenue,
      monthlyExpense: monthlyExpense ?? this.monthlyExpense,
      totalEarned: totalEarned ?? this.totalEarned,
      totalSpent: totalSpent ?? this.totalSpent,
      turnLog: turnLog ?? this.turnLog,
      isGameOver: isGameOver ?? this.isGameOver,
      gameOverReason:
          gameOverReason != null ? gameOverReason() : this.gameOverReason,
      loans: loans ?? this.loans,
      equityRounds: equityRounds ?? this.equityRounds,
    );
  }

  Map<String, dynamic> toJson() => {
        'config': config.toJson(),
        'currentTurn': currentTurn,
        'money': money,
        'debt': debt,
        'trust': trust,
        'ap': ap,
        'employees': employees.map((e) => e.toJson()).toList(),
        'servers': servers.map((s) => s.toJson()).toList(),
        'contractProjects': contractProjects.map((p) => p.toJson()).toList(),
        'saasProducts': saasProducts.map((p) => p.toJson()).toList(),
        'technologies': technologies.map((t) => t.toJson()).toList(),
        'office': office?.toJson(),
        'triggeredEventIds': triggeredEventIds,
        'monthlyRevenue': monthlyRevenue,
        'monthlyExpense': monthlyExpense,
        'totalEarned': totalEarned,
        'totalSpent': totalSpent,
        'isGameOver': isGameOver,
        'gameOverReason': gameOverReason,
        'loans': loans.map((l) => l.toJson()).toList(),
        'equityRounds': equityRounds.map((r) => r.toJson()).toList(),
      };

  factory GameState.fromJson(Map<String, dynamic> json) => GameState(
        config: GameConfig.fromJson(json['config'] as Map<String, dynamic>),
        currentTurn: json['currentTurn'] as int,
        money: json['money'] as int,
        debt: json['debt'] as int? ?? 0,
        trust: json['trust'] as int,
        ap: json['ap'] as int,
        employees: (json['employees'] as List<dynamic>)
            .map((e) => Employee.fromJson(e as Map<String, dynamic>))
            .toList(),
        servers: (json['servers'] as List<dynamic>)
            .map((s) => Server.fromJson(s as Map<String, dynamic>))
            .toList(),
        contractProjects: (json['contractProjects'] as List<dynamic>)
            .map((p) => ContractProject.fromJson(p as Map<String, dynamic>))
            .toList(),
        saasProducts: (json['saasProducts'] as List<dynamic>)
            .map((p) => SaaSProduct.fromJson(p as Map<String, dynamic>))
            .toList(),
        technologies: (json['technologies'] as List<dynamic>)
            .map((t) => Technology.fromJson(t as Map<String, dynamic>))
            .toList(),
        office: json['office'] != null
            ? Office.fromJson(json['office'] as Map<String, dynamic>)
            : null,
        triggeredEventIds:
            (json['triggeredEventIds'] as List<dynamic>?)?.cast<String>() ??
                const [],
        monthlyRevenue: json['monthlyRevenue'] as int? ?? 0,
        monthlyExpense: json['monthlyExpense'] as int? ?? 0,
        totalEarned: json['totalEarned'] as int? ?? 0,
        totalSpent: json['totalSpent'] as int? ?? 0,
        isGameOver: json['isGameOver'] as bool? ?? false,
        gameOverReason: json['gameOverReason'] as String?,
        loans: (json['loans'] as List<dynamic>?)
                ?.map((l) => Loan.fromJson(l as Map<String, dynamic>))
                .toList() ??
            const [],
        equityRounds: (json['equityRounds'] as List<dynamic>?)
                ?.map(
                    (r) => EquityRound.fromJson(r as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}
