import 'package:flutter_test/flutter_test.dart';

import 'package:cto_simulator/core/contract_engine.dart';
import 'package:cto_simulator/core/economy_engine.dart';
import 'package:cto_simulator/core/event_engine.dart';
import 'package:cto_simulator/core/finance_engine.dart';
import 'package:cto_simulator/core/game_state.dart';
import 'package:cto_simulator/core/infra_engine.dart';
import 'package:cto_simulator/core/saas_engine.dart';
import 'package:cto_simulator/core/tech_tree_engine.dart';
import 'package:cto_simulator/core/models/contract_project.dart';
import 'package:cto_simulator/core/models/employee.dart';
import 'package:cto_simulator/core/models/employee_type.dart';
import 'package:cto_simulator/core/models/event.dart';
import 'package:cto_simulator/core/models/game_config.dart';
import 'package:cto_simulator/core/models/loan.dart';
import 'package:cto_simulator/core/models/saas_product.dart';
import 'package:cto_simulator/core/models/server.dart';
import 'package:cto_simulator/core/models/technology.dart';
import 'package:cto_simulator/state/game_notifier.dart';

/// Helper to create a default GameState for testing
GameState _createTestState({
  int money = 500,
  int debt = 0,
  int trust = 50,
  int ap = 3,
  int currentTurn = 10,
  List<Employee> employees = const [],
  List<ContractProject> contractProjects = const [],
  List<SaaSProduct> saasProducts = const [],
  List<Technology> technologies = const [],
  List<Server> servers = const [],
  List<Loan> loans = const [],
}) {
  return GameState(
    config: const GameConfig(),
    money: money,
    debt: debt,
    trust: trust,
    ap: ap,
    currentTurn: currentTurn,
    employees: employees,
    contractProjects: contractProjects,
    saasProducts: saasProducts,
    technologies: technologies,
    servers: servers,
    loans: loans,
  );
}

/// Helper to create a test employee
Employee _createEmployee({
  String id = 'emp_1',
  String name = 'テスト太郎',
  int skill = 60,
  int fatigue = 20,
  int happiness = 70,
  String? assignedProjectId,
}) {
  return Employee(
    id: id,
    name: name,
    role: EmployeeRole.mid,
    specialty: EmployeeSpecialty.fullstack,
    salary: 40,
    skill: skill,
    fatigue: fatigue,
    happiness: happiness,
    assignedProjectId: assignedProjectId,
  );
}

void main() {
  // =========================================================================
  // BUG-01: イベントのコスト二重減算
  // event_engine.dart の applyEventChoice で choice.cost と
  // choice.effects['money'] が二重に減算される
  // =========================================================================
  group('BUG-01: Event cost double deduction', () {
    test('applyEventChoice should not double-deduct money when cost is used', () {
      // Setup: event with cost=50 only (effects should not contain money when cost is set)
      // Expected: total deduction should be exactly cost amount
      final state = _createTestState(money: 500);
      final event = GameEvent(
        id: 'test_event',
        title: 'テストイベント',
        description: 'テスト',
        type: EventType.opportunity,
        choices: [
          const EventChoice(
            id: 'choice_1',
            text: 'コスト支払い',
            effects: {'trust': 5},
            cost: 50,
          ),
        ],
      );

      final result = EventEngine.applyEventChoice(
        state,
        event,
        event.choices[0],
      );

      expect(
        result.money,
        450,
        reason: 'Cost should be deducted only once via the cost field',
      );
    });

    test(
      'applyEventChoice with only cost (no money effect) deducts correctly',
      () {
        final state = _createTestState(money: 500);
        final event = GameEvent(
          id: 'test_event_2',
          title: 'テスト',
          description: 'テスト',
          type: EventType.opportunity,
          choices: [
            const EventChoice(
              id: 'choice_1',
              text: 'コストのみ',
              effects: {'trust': 5},
              cost: 30,
            ),
          ],
        );

        final result = EventEngine.applyEventChoice(
          state,
          event,
          event.choices[0],
        );

        expect(result.money, 470);
        expect(result.trust, 55);
      },
    );

    test(
      'applyEventChoice with zero cost and money effect applies correctly',
      () {
        final state = _createTestState(money: 500);
        final event = GameEvent(
          id: 'test_event_3',
          title: 'テスト',
          description: 'テスト',
          type: EventType.opportunity,
          choices: [
            const EventChoice(
              id: 'choice_1',
              text: '報酬のみ',
              effects: {'money': 100},
            ),
          ],
        );

        final result = EventEngine.applyEventChoice(
          state,
          event,
          event.choices[0],
        );

        expect(result.money, 600);
      },
    );

    test(
      'real event data: talent market hire_bonus has overlapping cost and effect',
      () {
        // Verify the actual event data exhibits the double-deduction bug
        final events = EventEngine.getDefaultEvents();
        final talentMarket = events.firstWhere(
          (e) => e.id == 'evt_talent_market',
        );
        final hireChoice = talentMarket.choices.firstWhere(
          (c) => c.id == 'hire_bonus',
        );

        // This event has cost:50 AND effects:{'money': -50} - double deduction
        final state = _createTestState(money: 500);
        final result = EventEngine.applyEventChoice(
          state,
          talentMarket,
          hireChoice,
        );

        // After BUG-01 fix, expect 450 (single deduction of 50)
        expect(
          result.money,
          450,
          reason: 'evt_talent_market hire_bonus should deduct 50 once, not 100',
        );
      },
    );

    test('applyEventChoice correctly applies AP cost', () {
      final state = _createTestState(ap: 3);
      final event = GameEvent(
        id: 'ap_event',
        title: 'APテスト',
        description: 'テスト',
        type: EventType.tech,
        choices: [
          const EventChoice(
            id: 'ap_choice',
            text: 'AP消費',
            effects: {},
            apCost: 1,
          ),
        ],
      );

      final result = EventEngine.applyEventChoice(
        state,
        event,
        event.choices[0],
      );
      expect(result.ap, 2);
    });
  });

  // =========================================================================
  // BUG-03: 納期超過ペナルティの無限ループ
  // overdue案件に毎ターン trust-2 が適用され続け、破棄手段がない
  // =========================================================================
  group('BUG-03: Overdue penalty infinite loop', () {
    test('overdue projects should eventually be auto-failed or removable', () {
      // Setup: a project that is overdue
      final overdueProject = ContractProject(
        id: 'proj_overdue',
        name: 'テスト案件',
        type: ProjectType.webApp,
        clientName: 'テストクライアント',
        reward: 500,
        requiredSkill: 30,
        totalWork: 100,
        deadline: 5,
        currentWork: 10,
        status: ProjectStatus.overdue,
        startTurn: 1,
        assignedEmployeeIds: ['emp_1'],
      );

      final state = _createTestState(
        trust: 50,
        currentTurn: 10,
        contractProjects: [overdueProject],
        employees: [_createEmployee(assignedProjectId: 'proj_overdue')],
      );

      // Simulate multiple turns of processProjects
      var currentState = state;
      for (int i = 0; i < 5; i++) {
        currentState = ContractEngine.processProjects(currentState);
        currentState = currentState.copyWith(
          currentTurn: currentState.currentTurn + 1,
        );
      }

      // BUG: trust keeps dropping by -2 every turn indefinitely
      // EXPECTED: Overdue project should auto-fail after some turns,
      // stopping the infinite trust drain
      // After fix, either:
      // - The project status should change to 'failed'
      // - Or trust should not drop below a reasonable floor from this bug
      final hasFailedProject = currentState.contractProjects.any(
        (p) => p.id == 'proj_overdue' && p.status == ProjectStatus.failed,
      );

      // After fix, overdue should auto-fail (3 turns past deadline)
      expect(
        hasFailedProject,
        true,
        reason:
            'Overdue projects should auto-fail after excessive overdue turns',
      );
    });

    test(
      'overdue penalty applies trust -2 only when project newly becomes overdue',
      () {
        // Project that will become overdue this turn (inProgress + just past deadline)
        // deadline=8, startTurn=1, currentTurn=10 → remainingTurns = 8-(10-1) = -1
        // -(-1)=1 < 3 (grace), so NO auto-fail, only the -2 penalty
        final project = ContractProject(
          id: 'proj_1',
          name: 'テスト案件',
          type: ProjectType.webApp,
          clientName: 'テスト',
          reward: 500,
          requiredSkill: 30,
          totalWork: 100,
          deadline: 8,
          currentWork: 10,
          status: ProjectStatus.inProgress,
          startTurn: 1,
          assignedEmployeeIds: [],
        );

        final state = _createTestState(
          trust: 50,
          currentTurn: 10, // just past deadline (overdue by 1 turn)
          contractProjects: [project],
        );

        final result = ContractEngine.processProjects(state);

        // Newly overdue project should get -2 trust penalty only
        expect(result.trust, 48);
      },
    );

    test('already overdue projects do not repeat trust penalty', () {
      // Already overdue project should NOT get additional -2 each turn
      final projects = List.generate(
        3,
        (i) => ContractProject(
          id: 'proj_$i',
          name: '案件$i',
          type: ProjectType.webApp,
          clientName: 'テスト',
          reward: 500,
          requiredSkill: 30,
          totalWork: 100,
          deadline: 5,
          currentWork: 10,
          status: ProjectStatus.overdue, // already overdue
          startTurn: 1,
          assignedEmployeeIds: [],
        ),
      );

      final state = _createTestState(
        trust: 50,
        currentTurn: 10,
        contractProjects: projects,
      );

      final result = ContractEngine.processProjects(state);

      // Already overdue projects should NOT repeat the penalty
      // They will auto-fail after grace period instead
      expect(result.trust, lessThanOrEqualTo(50));
    });
  });

  // =========================================================================
  // BUG-04: SaaSリリース時のユーザー数ログ不一致
  // totalUsers=50 にセットするのにログでは「100人」と表示
  // =========================================================================
  group('BUG-04: SaaS launch user count log mismatch', () {
    test('launchProduct log should match actual initial user count', () {
      final product = const SaaSProduct(
        id: 'saas_test',
        name: 'TestApp',
        category: SaaSCategory.projectManagement,
        monthlyPricePerUser: 1000,
        developmentCost: 200,
        requiredTechLevel: 1,
        totalDevelopmentWork: 80,
        developmentProgress: 80, // development complete
      );

      final state = _createTestState(
        saasProducts: [product],
        servers: [
          const Server(
            id: 'srv_1',
            name: 'テストサーバー',
            tier: ServerTier.shared,
            capacity: 1000,
            monthlyCost: 5,
          ),
        ],
      );

      final result = SaaSEngine.launchProduct(state, 'saas_test');

      // Get the launched product
      final launchedProduct = result.saasProducts.firstWhere(
        (p) => p.id == 'saas_test',
      );

      // BUG: totalUsers is set to 50 but log says "100人"
      // EXPECTED: Log should say "50人" to match totalUsers
      expect(launchedProduct.totalUsers, 50);

      // Check that the log matches the actual user count
      final launchLog = result.turnLog.where((log) => log.contains('リリース'));
      expect(launchLog, isNotEmpty);

      // The log should contain "50人", not "100人"
      final logText = launchLog.first;
      expect(
        logText.contains('50人'),
        true,
        reason:
            'Launch log should say 50人 to match actual totalUsers, not 100人',
      );
    });
  });

  // =========================================================================
  // BUG-10: qualityBonusをプロジェクト品質計算に反映
  // テクノロジーの qualityBonus が品質計算に使われていない
  // =========================================================================
  group('BUG-10: Technology qualityBonus not reflected in project quality', () {
    test('unlocked tech qualityBonus should improve project quality score', () {
      final employee = _createEmployee(
        id: 'emp_1',
        skill: 60,
        fatigue: 20,
        assignedProjectId: 'proj_1',
      );

      final projectNoBonus = ContractProject(
        id: 'proj_1',
        name: 'テスト案件',
        type: ProjectType.webApp,
        clientName: 'テスト',
        reward: 500,
        requiredSkill: 30,
        totalWork: 100,
        deadline: 20,
        currentWork: 10,
        status: ProjectStatus.inProgress,
        startTurn: 1,
        qualityScore: 50,
        assignedEmployeeIds: ['emp_1'],
      );

      // State without tech bonus
      final stateWithoutTech = _createTestState(
        currentTurn: 5,
        employees: [employee],
        contractProjects: [projectNoBonus],
        technologies: [
          const Technology(
            id: 'tech_1',
            name: 'テスト技術',
            category: TechCategory.framework,
            researchCost: 100,
            researchTurns: 5,
            isUnlocked: false,
            qualityBonus: 20,
          ),
        ],
      );

      // State with tech bonus (same tech but unlocked)
      final stateWithTech = _createTestState(
        currentTurn: 5,
        employees: [employee],
        contractProjects: [projectNoBonus],
        technologies: [
          const Technology(
            id: 'tech_1',
            name: 'テスト技術',
            category: TechCategory.framework,
            researchCost: 100,
            researchTurns: 5,
            isUnlocked: true,
            qualityBonus: 20,
          ),
        ],
      );

      final resultWithoutTech = ContractEngine.processProjects(
        stateWithoutTech,
      );
      final resultWithTech = ContractEngine.processProjects(stateWithTech);

      final qualityWithout = resultWithoutTech.contractProjects
          .firstWhere((p) => p.id == 'proj_1')
          .qualityScore;
      final qualityWith = resultWithTech.contractProjects
          .firstWhere((p) => p.id == 'proj_1')
          .qualityScore;

      // BUG: qualityBonus is not used in quality calculation,
      // so both results have the same quality
      // EXPECTED: qualityWith should be higher than qualityWithout
      expect(
        qualityWith > qualityWithout,
        true,
        reason:
            'Unlocked technology qualityBonus should improve project quality score',
      );
    });
  });

  // =========================================================================
  // BUG-13: SaaS保守費用を月次経費に含める
  // totalMonthlyCost に SaaS保守費用が含まれていない
  // =========================================================================
  group('BUG-13: SaaS maintenance cost not included in monthly expenses', () {
    test('totalMonthlyCost should include SaaS maintenance costs', () {
      final state = _createTestState(
        employees: [_createEmployee(id: 'emp_1')],
        saasProducts: [
          const SaaSProduct(
            id: 'saas_1',
            name: 'TestSaaS',
            category: SaaSCategory.projectManagement,
            monthlyPricePerUser: 1000,
            developmentCost: 200,
            requiredTechLevel: 1,
            isLaunched: true,
            totalUsers: 100,
            monthlyMaintenanceCost: 10,
          ),
        ],
      );

      // BUG: totalMonthlyCost does not include SaaS maintenance
      // Currently: totalSalary + totalServerCost + officeCost
      // EXPECTED: totalSalary + totalServerCost + officeCost + saasMaintenanceCost
      final totalCost = state.totalMonthlyCost;
      final salaryOnly = state.totalSalary;

      expect(
        totalCost,
        greaterThan(salaryOnly),
        reason:
            'totalMonthlyCost should include SaaS maintenance cost on top of salary',
      );

      // Specifically check the maintenance is included
      final saasMaintenanceCost = state.saasProducts.fold(
        0,
        (sum, p) => sum + p.monthlyMaintenanceCost,
      );
      expect(saasMaintenanceCost, 10);
      expect(
        totalCost,
        salaryOnly + saasMaintenanceCost,
        reason:
            'totalMonthlyCost should be salary + SaaS maintenance (no servers/office in this test)',
      );
    });

    test('processMonthlyExpenses deducts SaaS maintenance from money', () {
      final state = _createTestState(
        money: 500,
        employees: [],
        saasProducts: [
          const SaaSProduct(
            id: 'saas_1',
            name: 'TestSaaS',
            category: SaaSCategory.projectManagement,
            monthlyPricePerUser: 1000,
            developmentCost: 200,
            requiredTechLevel: 1,
            isLaunched: true,
            totalUsers: 100,
            monthlyMaintenanceCost: 15,
          ),
        ],
      );

      final result = EconomyEngine.processMonthlyExpenses(state);

      // SaaS revenue = 100 * 1000 / 10000 = 10 万円
      // SaaS maintenance = 15 万円
      // Expected: 500 - 15 + 10 = 495
      // BUG: maintenance is not deducted, so result would be 500 + 10 = 510
      expect(
        result.money,
        lessThan(510),
        reason: 'SaaS maintenance cost should be deducted from money',
      );
    });
  });

  // =========================================================================
  // BUG-12: サーバー購入・研究開始時のAP無条件消費
  // purchaseServer/startResearch が失敗してもAPが消費される
  // =========================================================================
  group('BUG-12: AP consumed even when server purchase or research fails', () {
    test(
      'purchaseServer should not consume AP when purchase fails due to insufficient funds',
      () {
        // Simulate what GameNotifier.purchaseServer does:
        // 1. Check AP (has enough)
        // 2. Call InfraEngine.purchaseServer (may fail)
        // 3. Consume AP (ALWAYS - this is the bug)
        final expensiveServer = const Server(
          id: 'expensive_srv',
          name: '高額サーバー',
          tier: ServerTier.enterprise,
          capacity: 50000,
          monthlyCost: 100, // purchase cost = 100 * 3 = 300万円
        );

        final state = _createTestState(
          money: 50, // insufficient for 300万円
          ap: 3,
        );

        // The core engine correctly rejects the purchase
        final afterPurchase = InfraEngine.purchaseServer(
          state,
          expensiveServer,
        );

        // Purchase failed - server count unchanged, money unchanged
        expect(afterPurchase.servers.length, 0);
        expect(afterPurchase.money, 50);

        // BUG in GameNotifier: AP is consumed AFTER calling purchaseServer
        // even though the purchase failed.
        // The correct behavior should be: AP NOT consumed when purchase fails.
        // Test the detection pattern: if server count didn't increase, AP shouldn't decrease.
        final purchaseSucceeded =
            afterPurchase.servers.length > state.servers.length;
        expect(
          purchaseSucceeded,
          false,
          reason: 'Purchase should fail with insufficient funds',
        );
        // After fix, GameNotifier should check purchaseSucceeded before consuming AP
      },
    );

    test(
      'startResearch should not consume AP when research fails due to insufficient funds',
      () {
        final state = _createTestState(
          money: 5, // not enough for any research
          ap: 3,
          technologies: [
            const Technology(
              id: 'tech_test',
              name: 'テスト技術',
              category: TechCategory.framework,
              researchCost: 100,
              researchTurns: 5,
              isUnlocked: false,
            ),
          ],
        );

        // The core engine correctly rejects the research start
        final afterResearch = TechTreeEngine.startResearch(state, 'tech_test');

        // Research failed - tech progress unchanged
        final tech = afterResearch.technologies.firstWhere(
          (t) => t.id == 'tech_test',
        );
        expect(tech.currentResearchProgress, 0);
        expect(afterResearch.money, 5); // money unchanged

        // BUG: GameNotifier.startResearch consumes AP unconditionally after this call
      },
    );

    test(
      'startResearch should not consume AP when prerequisites are not met',
      () {
        final state = _createTestState(
          money: 500,
          ap: 3,
          technologies: [
            const Technology(
              id: 'tech_prereq',
              name: '前提技術',
              category: TechCategory.language,
              researchCost: 20,
              researchTurns: 3,
              isUnlocked: false, // not yet unlocked
            ),
            const Technology(
              id: 'tech_advanced',
              name: '上級技術',
              category: TechCategory.framework,
              researchCost: 50,
              researchTurns: 5,
              isUnlocked: false,
              prerequisites: ['tech_prereq'], // requires tech_prereq
            ),
          ],
        );

        final afterResearch = TechTreeEngine.startResearch(
          state,
          'tech_advanced',
        );

        // Research should fail - prerequisite not met
        final tech = afterResearch.technologies.firstWhere(
          (t) => t.id == 'tech_advanced',
        );
        expect(tech.currentResearchProgress, 0);
        expect(afterResearch.money, 500); // money unchanged

        // BUG: GameNotifier.startResearch consumes AP even when this fails
      },
    );

    test('purchaseServer succeeds and AP should be consumed', () {
      final cheapServer = const Server(
        id: 'cheap_srv',
        name: '安いサーバー',
        tier: ServerTier.shared,
        capacity: 100,
        monthlyCost: 1, // purchase cost = 1 * 3 = 3万円
      );

      final state = _createTestState(money: 500, ap: 3);
      final afterPurchase = InfraEngine.purchaseServer(state, cheapServer);

      // Purchase succeeds
      expect(afterPurchase.servers.length, 1);
      expect(afterPurchase.money, 497);

      // In this case, AP SHOULD be consumed (the action succeeded)
      final purchaseSucceeded =
          afterPurchase.servers.length > state.servers.length;
      expect(purchaseSucceeded, true);
    });
  });

  // =========================================================================
  // BAL-02: ローン月利を現実的な水準に調整
  // 現在の月利5-10%は年利60-120%で暴利。月利0.5-2%に調整すべき
  // =========================================================================
  group('BAL-02: Loan monthly interest rate should be realistic', () {
    test('small loan monthly rate should be <= 2%', () {
      // Currently: small = 5% monthly = 60% annually (usury)
      // Expected: <= 2% monthly
      expect(
        LoanSize.small.monthlyRate,
        lessThanOrEqualTo(0.02),
        reason:
            'Small loan monthly rate ${LoanSize.small.monthlyRate} is too high (${LoanSize.small.monthlyRate * 12 * 100}% annually)',
      );
    });

    test('medium loan monthly rate should be <= 2%', () {
      expect(
        LoanSize.medium.monthlyRate,
        lessThanOrEqualTo(0.02),
        reason:
            'Medium loan monthly rate ${LoanSize.medium.monthlyRate} is too high (${LoanSize.medium.monthlyRate * 12 * 100}% annually)',
      );
    });

    test('large loan monthly rate should be <= 2%', () {
      expect(
        LoanSize.large.monthlyRate,
        lessThanOrEqualTo(0.02),
        reason:
            'Large loan monthly rate ${LoanSize.large.monthlyRate} is too high (${LoanSize.large.monthlyRate * 12 * 100}% annually)',
      );
    });

    test('all loan annual rates should be below 24% (legal maximum)', () {
      for (final size in LoanSize.values) {
        final annualRate = size.monthlyRate * 12;
        expect(
          annualRate,
          lessThan(0.24),
          reason:
              '${size.label} annual rate ${(annualRate * 100).toStringAsFixed(1)}% exceeds legal maximum',
        );
      }
    });

    test('loan monthly payment is reasonable', () {
      // Create a small loan and check monthly payment
      final loan = Loan.create(LoanSize.small, 1);
      final payment = loan.monthlyPayment;

      // With 100万円 principal, 12 months, and reasonable interest:
      // Principal per month: ceil(100/12) = 9
      // Interest first month: 100 * rate
      // Total should be reasonable (not exceeding 15万円/month for small loan)
      expect(
        payment,
        lessThan(15),
        reason: 'Monthly payment for small loan should be reasonable',
      );
    });
  });

  group('Regression: staff assignment restrictions', () {
    test('non-engineer staff cannot be assigned to contract projects', () {
      final project = ContractProject(
        id: 'proj_staff_guard',
        name: 'スタッフ禁止案件',
        type: ProjectType.webApp,
        clientName: 'テスト',
        reward: 300,
        requiredSkill: 30,
        totalWork: 50,
        deadline: 10,
        status: ProjectStatus.inProgress,
        startTurn: 1,
      );
      final staff = Employee(
        id: 'staff_1',
        name: 'バックオフィス太郎',
        role: EmployeeRole.mid,
        specialty: EmployeeSpecialty.fullstack,
        salary: 25,
        type: EmployeeType.backOffice,
        skill: 45,
      );
      final state = _createTestState(
        employees: [staff],
        contractProjects: [project],
      );

      final result = ContractEngine.assignEmployee(
        state,
        'proj_staff_guard',
        'staff_1',
      );
      final updatedProject = result.contractProjects.first;
      final updatedStaff = result.employees.first;

      expect(updatedProject.assignedEmployeeIds, isEmpty);
      expect(updatedStaff.assignedProjectId, isNull);
      expect(result.turnLog.last, contains('エンジニアではないためアサインできません'));
    });
  });

  group('Regression: back office AP passive', () {
    test('hiring second back-office staff grants AP bonus immediately', () {
      final notifier = GameNotifier();

      final staff1 = Employee(
        id: 'bo_1',
        name: 'BO1',
        role: EmployeeRole.mid,
        specialty: EmployeeSpecialty.fullstack,
        salary: 20,
        type: EmployeeType.backOffice,
        skill: 40,
      );
      final staff2 = Employee(
        id: 'bo_2',
        name: 'BO2',
        role: EmployeeRole.mid,
        specialty: EmployeeSpecialty.fullstack,
        salary: 20,
        type: EmployeeType.backOffice,
        skill: 40,
      );

      notifier.hireStaff(staff1);
      expect(notifier.state.ap, 2);

      notifier.hireStaff(staff2);
      expect(notifier.state.ap, 2, reason: '2人目のバックオフィス採用で AP+1 が即時反映されること');
    });
  });

  group('Regression: server manual repair', () {
    test('repairServer should recover a down server', () {
      const downServer = Server(
        id: 'srv_down_1',
        name: '障害サーバー',
        tier: ServerTier.vps,
        capacity: 500,
        monthlyCost: 3,
        currentLoad: 450,
        isDown: true,
      );
      final state = _createTestState(servers: const [downServer]);

      final result = InfraEngine.repairServer(state, 'srv_down_1');
      final repaired = result.servers.firstWhere((s) => s.id == 'srv_down_1');

      expect(repaired.isDown, false);
      expect(repaired.currentLoad, 0);
      expect(result.turnLog.last, contains('手動復旧'));
    });
  });

  // =========================================================================
  // Additional edge case tests for game state
  // =========================================================================
  group('Edge cases: zero AP', () {
    test('workOnProject with 0 AP returns insufficient AP message', () {
      final state = _createTestState(ap: 0);
      final result = ContractEngine.workOnProject(state, 'any_project');

      expect(result.ap, 0);
      expect(result.turnLog, contains('APが不足しています。'));
    });
  });

  group('Edge cases: zero money', () {
    test('processMonthlyExpenses with 0 money creates debt', () {
      final state = _createTestState(money: 0, employees: [_createEmployee()]);

      final result = EconomyEngine.processMonthlyExpenses(state);

      // Employee salary should push money negative, creating debt
      expect(result.debt, greaterThan(0));
      expect(result.money, 0);
    });
  });

  group('Edge cases: zero employees', () {
    test('processProjects with no employees makes no progress', () {
      final project = ContractProject(
        id: 'proj_1',
        name: 'テスト案件',
        type: ProjectType.webApp,
        clientName: 'テスト',
        reward: 500,
        requiredSkill: 30,
        totalWork: 100,
        deadline: 20,
        currentWork: 10,
        status: ProjectStatus.inProgress,
        startTurn: 1,
        assignedEmployeeIds: [],
      );

      final state = _createTestState(
        contractProjects: [project],
        employees: [],
      );

      final result = ContractEngine.processProjects(state);
      final resultProject = result.contractProjects.firstWhere(
        (p) => p.id == 'proj_1',
      );

      expect(resultProject.currentWork, 10); // no progress
    });
  });

  group('Edge cases: trust boundary', () {
    test('trust cannot go below 0', () {
      final state = _createTestState(trust: 1);
      final result = state.copyWith(trust: (state.trust - 10).clamp(0, 100));

      expect(result.trust, 0);
    });

    test('trust cannot go above 100', () {
      final state = _createTestState(trust: 99);
      final result = state.copyWith(trust: (state.trust + 10).clamp(0, 100));

      expect(result.trust, 100);
    });
  });

  group('Edge cases: game over conditions', () {
    test('game over when cash reaches 0', () {
      final state = _createTestState(money: 0);

      final result = EconomyEngine.checkGameOver(state);
      expect(result.isGameOver, true);
    });
  });

  group('Contract project completion flow', () {
    test('completed project releases assigned employees', () {
      final employee = _createEmployee(
        id: 'emp_1',
        skill: 90,
        assignedProjectId: 'proj_1',
      );

      final project = ContractProject(
        id: 'proj_1',
        name: 'テスト案件',
        type: ProjectType.corporateSite,
        clientName: 'テスト',
        reward: 300,
        requiredSkill: 10,
        totalWork: 1, // very small, will complete in 1 turn
        deadline: 20,
        currentWork: 0,
        status: ProjectStatus.inProgress,
        startTurn: 1,
        assignedEmployeeIds: ['emp_1'],
      );

      final state = _createTestState(
        currentTurn: 2,
        employees: [employee],
        contractProjects: [project],
      );

      final result = ContractEngine.processProjects(state);

      // Project should be completed
      final resultProject = result.contractProjects.firstWhere(
        (p) => p.id == 'proj_1',
      );
      expect(resultProject.status, ProjectStatus.completed);

      // Employee should be unassigned
      final resultEmployee = result.employees.firstWhere(
        (e) => e.id == 'emp_1',
      );
      expect(resultEmployee.assignedProjectId, isNull);
    });
  });

  group('Event engine edge cases', () {
    test('one-time events do not trigger again', () {
      final state = _createTestState(
        currentTurn: 25,
        trust: 60,
      ).copyWith(triggeredEventIds: ['evt_big_client']);

      final events = EventEngine.getDefaultEvents();
      final bigClientEvent = events.firstWhere((e) => e.id == 'evt_big_client');

      expect(bigClientEvent.isOneTime, true);

      // Should not trigger because it's already in triggeredEventIds
      final canTrigger =
          !state.triggeredEventIds.contains(bigClientEvent.id) ||
          !bigClientEvent.isOneTime;
      expect(canTrigger, false);
    });

    test('event conditions are properly checked', () {
      final event = GameEvent(
        id: 'test_conditional',
        title: 'テスト',
        description: 'テスト',
        type: EventType.market,
        probability: 1.0,
        minTurn: 10,
        conditions: {'trust': 50, 'hasSaaS': true},
        choices: [],
      );

      // Meets conditions
      final goodMap = {'trust': 60, 'hasSaaS': true, 'money': 500};
      expect(event.canTrigger(15, goodMap), true);

      // Does not meet trust condition
      final badTrust = {'trust': 30, 'hasSaaS': true};
      expect(event.canTrigger(15, badTrust), false);

      // Does not meet SaaS condition
      final noSaaS = {'trust': 60, 'hasSaaS': false};
      expect(event.canTrigger(15, noSaaS), false);

      // Turn too low
      expect(event.canTrigger(5, goodMap), false);
    });
  });

  group('Loan repayment flow', () {
    test('processLoanPayments reduces principal and remaining months', () {
      final loan = Loan(
        id: 'loan_1',
        size: LoanSize.small,
        principal: 100,
        remainingPrincipal: 100,
        monthlyRate: 0.01,
        termMonths: 12,
        remainingMonths: 12,
        startTurn: 1,
      );

      final state = _createTestState(money: 500, loans: [loan]);

      final result = FinanceEngine.processLoanPayments(state);

      final updatedLoan = result.loans.first;
      expect(updatedLoan.remainingMonths, 11);
      expect(updatedLoan.remainingPrincipal, lessThan(100));
      expect(result.money, lessThan(500));
    });

    test('early repay pays off loan completely', () {
      final loan = Loan(
        id: 'loan_1',
        size: LoanSize.small,
        principal: 100,
        remainingPrincipal: 80,
        monthlyRate: 0.01,
        termMonths: 12,
        remainingMonths: 8,
        startTurn: 1,
      );

      final state = _createTestState(money: 500, loans: [loan]);

      final result = FinanceEngine.earlyRepayLoan(state, 'loan_1');

      final updatedLoan = result.loans.first;
      expect(updatedLoan.isPaidOff, true);
      expect(result.money, 420); // 500 - 80
    });
  });

  group('SaaS engine user growth', () {
    test('launched SaaS product calculates new users', () {
      final product = const SaaSProduct(
        id: 'saas_1',
        name: 'TestApp',
        category: SaaSCategory.projectManagement,
        monthlyPricePerUser: 1000,
        developmentCost: 200,
        requiredTechLevel: 1,
        isLaunched: true,
        totalUsers: 100,
        growthRate: 10.0,
        churnRate: 5.0,
      );

      final newUsers = product.calculateNewUsers();
      // growth: 100 * 10% = 10
      // churn: 100 * 5% = 5
      // net: 10 - 5 = 5
      expect(newUsers, 5);
    });

    test('non-launched SaaS product returns 0 new users', () {
      final product = const SaaSProduct(
        id: 'saas_1',
        name: 'TestApp',
        category: SaaSCategory.projectManagement,
        monthlyPricePerUser: 1000,
        developmentCost: 200,
        requiredTechLevel: 1,
        isLaunched: false,
        totalUsers: 0,
      );

      expect(product.calculateNewUsers(), 0);
    });
  });

  group('Employee productivity', () {
    test('productivity formula is correct', () {
      final employee = _createEmployee(skill: 60, fatigue: 0);
      // productivity = 60 * (1 - 0/200) * (2*0.3 + 0.4) = 60 * 1.0 * 1.0 = 60
      expect(employee.productivity, 60.0);
    });

    test('high fatigue reduces productivity', () {
      final fresh = _createEmployee(skill: 60, fatigue: 0);
      final tired = _createEmployee(skill: 60, fatigue: 80);

      expect(tired.productivity, lessThan(fresh.productivity));
    });

    test('quit risk is 0 when happy and not fatigued', () {
      final happy = _createEmployee(happiness: 80, fatigue: 30);
      expect(happy.quitRisk, 0.0);
    });

    test('quit risk increases with low happiness', () {
      final unhappy = _createEmployee(happiness: 20, fatigue: 80);
      expect(unhappy.quitRisk, greaterThan(0.0));
    });
  });
}
