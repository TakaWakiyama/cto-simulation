import 'dart:math';

import 'game_state.dart';
import 'models/employee.dart';
import 'models/employee_type.dart';
import 'staff_bonus_engine.dart';

/// 社員管理エンジン：疲労/幸福度/退職判定
class EmployeeEngine {
  static final _random = Random();

  /// ターン終了時の社員状態更新
  static GameState processEmployees(GameState state) {
    final log = <String>[];
    final updatedEmployees = <Employee>[];
    final retiredIds = <String>[];

    // HRボーナス計算
    final hrHappiness = StaffBonusEngine.hrHappinessBonus(state);
    final hrLoyalty = StaffBonusEngine.hrLoyaltyBonus(state);

    for (final employee in state.employees) {
      var updated = employee;

      // 疲労度の自然回復（働いていない場合）
      if (!employee.isAssigned) {
        updated = updated.copyWith(
          fatigue: (updated.fatigue - 10).clamp(0, 100),
          happiness: (updated.happiness + 2).clamp(0, 100),
        );
      } else {
        // 働いている場合は疲労増加（+5）& 働く充実感で幸福度微増（+2）
        updated = updated.copyWith(
          fatigue: (updated.fatigue + 5).clamp(0, 100),
          happiness: (updated.happiness + 2).clamp(0, 100),
        );

        // 疲労が高すぎると幸福度低下
        if (updated.fatigue > 70) {
          updated = updated.copyWith(
            happiness: (updated.happiness - 5).clamp(0, 100),
          );
        }
      }

      // オフィスボーナス
      if (state.office != null) {
        updated = updated.copyWith(
          happiness:
              (updated.happiness + state.office!.happinessBonus ~/ 4)
                  .clamp(0, 100),
        );
      }

      // HRボーナス適用
      if (hrHappiness > 0 || hrLoyalty > 0) {
        updated = updated.copyWith(
          happiness: (updated.happiness + hrHappiness).clamp(0, 100),
          loyalty: (updated.loyalty + hrLoyalty).clamp(0, 100),
        );
      }

      // 退職判定
      final quitChance = updated.quitRisk;
      if (quitChance > 0 && _random.nextDouble() < quitChance * 0.3) {
        log.add('${updated.name}(${updated.role.label})が退職しました！');
        retiredIds.add(updated.id);
        continue;
      }

      // スキル成長（微量）— エンジニアのみ
      if (updated.isAssigned && updated.isEngineer) {
        updated = updated.copyWith(
          skill: (updated.skill + 1).clamp(0, 100),
        );
      }

      updatedEmployees.add(updated);
    }

    // 退職者がいたプロジェクトからアサインを解除
    var updatedProjects = state.contractProjects;
    if (retiredIds.isNotEmpty) {
      updatedProjects = state.contractProjects.map((p) {
        final newIds = p.assignedEmployeeIds
            .where((id) => !retiredIds.contains(id))
            .toList();
        if (newIds.length != p.assignedEmployeeIds.length) {
          return p.copyWith(assignedEmployeeIds: newIds);
        }
        return p;
      }).toList();
    }

    return state.copyWith(
      employees: updatedEmployees,
      contractProjects: updatedProjects,
      turnLog: [...state.turnLog, ...log],
    );
  }

  /// 社員を雇用
  static GameState hireEmployee(GameState state, Employee employee) {
    if (state.employeeCount >= state.maxEmployees) {
      return state.copyWith(
        turnLog: [
          ...state.turnLog,
          'オフィスの定員に達しています。雇用できません。',
        ],
      );
    }

    // 採用費用（月給の2ヶ月分、HR割引適用）
    final hrDiscount = StaffBonusEngine.hrHiringDiscount(state);
    final hiringCost = (employee.salary * 2 * (1.0 - hrDiscount)).round();
    if (state.money < hiringCost) {
      return state.copyWith(
        turnLog: [
          ...state.turnLog,
          '採用費用（${hiringCost}万円）が不足しています。',
        ],
      );
    }

    return state.copyWith(
      employees: [...state.employees, employee],
      money: state.money - hiringCost,
      turnLog: [
        ...state.turnLog,
        '${employee.name}(${employee.type.label})を雇用しました！ -${hiringCost}万円',
      ],
    );
  }

  /// 社員を解雇
  static GameState fireEmployee(GameState state, String employeeId) {
    final employee = state.employees.firstWhere((e) => e.id == employeeId);
    // 解雇費用（月給の1ヶ月分）
    final severancePay = employee.salary;

    return state.copyWith(
      employees: state.employees.where((e) => e.id != employeeId).toList(),
      money: state.money - severancePay,
      trust: (state.trust - 2).clamp(0, 100),
      contractProjects: state.contractProjects.map((p) {
        return p.copyWith(
          assignedEmployeeIds:
              p.assignedEmployeeIds.where((id) => id != employeeId).toList(),
        );
      }).toList(),
      turnLog: [
        ...state.turnLog,
        '${employee.name}を解雇しました。退職金: -${severancePay}万円',
      ],
    );
  }

  /// 残業指示
  static GameState orderOvertime(
    GameState state,
    String employeeId,
    String projectId,
  ) {
    final empIndex = state.employees.indexWhere((e) => e.id == employeeId);
    if (empIndex < 0) return state;

    final employee = state.employees[empIndex];
    final updatedEmployee = employee.copyWith(
      fatigue: (employee.fatigue + 20).clamp(0, 100),
      happiness: (employee.happiness - 10).clamp(0, 100),
    );

    final employees = List<Employee>.from(state.employees);
    employees[empIndex] = updatedEmployee;

    return state.copyWith(
      employees: employees,
      turnLog: [
        ...state.turnLog,
        '${employee.name}に残業を指示しました（疲労+20, 幸福度-10）',
      ],
    );
  }

  /// エンジニア採用候補の生成
  static List<Employee> generateCandidates(int count) {
    final names = [
      '田中太郎', '鈴木花子', '佐藤一郎', '山田美咲', '高橋健太',
      '渡辺あかり', '伊藤大介', '中村さくら', '小林拓也', '加藤梨花',
      '山本隼人', '吉田愛', '松本翔', '井上由美', '木村雄太',
    ];

    final candidates = <Employee>[];
    for (var i = 0; i < count; i++) {
      final role = EmployeeRole.values[_random.nextInt(3)]; // junior〜senior
      final specialty =
          EmployeeSpecialty.values[_random.nextInt(EmployeeSpecialty.values.length)];
      final baseSalary = switch (role) {
        EmployeeRole.junior => 25 + _random.nextInt(10),
        EmployeeRole.mid => 35 + _random.nextInt(15),
        EmployeeRole.senior => 50 + _random.nextInt(20),
        EmployeeRole.lead => 65 + _random.nextInt(20),
        EmployeeRole.architect => 80 + _random.nextInt(30),
      };

      candidates.add(Employee(
        id: 'emp_${DateTime.now().millisecondsSinceEpoch}_$i',
        name: names[_random.nextInt(names.length)],
        role: role,
        specialty: specialty,
        salary: baseSalary,
        type: EmployeeType.engineer,
        skill: 20 + role.skillLevel * 15 + _random.nextInt(10),
      ));
    }
    return candidates;
  }

  /// 非エンジニアスタッフ候補の生成
  static List<Employee> generateStaffCandidates(EmployeeType type, int count) {
    final names = [
      '斎藤健一', '橋本真由', '藤田浩二', '岡田美紀', '三浦拓郎',
      '前田麻衣', '石田翔太', '小川桃子', '後藤大輔', '長谷川葵',
    ];

    final (minSalary, maxSalary) = switch (type) {
      EmployeeType.sales => (30, 45),
      EmployeeType.marketer => (28, 40),
      EmployeeType.backOffice => (22, 30),
      EmployeeType.hr => (25, 35),
      EmployeeType.engineer => (25, 35), // fallback
    };

    final candidates = <Employee>[];
    for (var i = 0; i < count; i++) {
      final salary = minSalary + _random.nextInt(maxSalary - minSalary + 1);
      candidates.add(Employee(
        id: 'staff_${DateTime.now().millisecondsSinceEpoch}_$i',
        name: names[_random.nextInt(names.length)],
        role: EmployeeRole.mid, // 非エンジニアはロール固定
        specialty: EmployeeSpecialty.fullstack, // 非エンジニアは専門不要
        salary: salary,
        type: type,
        skill: 40 + _random.nextInt(30),
      ));
    }
    return candidates;
  }
}
