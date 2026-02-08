import 'game_state.dart';
import 'models/contract_project.dart';

/// 受託案件の進捗/納期管理エンジン
class ContractEngine {
  /// 着手金の割合（報酬の30%を受注時に前払い）
  static const double upfrontRate = 0.3;

  /// 案件の受注
  static GameState acceptProject(GameState state, String projectId) {
    final projects = state.contractProjects.map((p) {
      if (p.id == projectId && p.status == ProjectStatus.available) {
        return p.copyWith(
          status: ProjectStatus.inProgress,
          startTurn: () => state.currentTurn,
        );
      }
      return p;
    }).toList();

    final project = projects.firstWhere((p) => p.id == projectId);

    // 着手金（報酬の30%を前払い）
    final upfront = (project.reward * upfrontRate).round();

    return state.copyWith(
      contractProjects: projects,
      money: state.money + upfront,
      totalEarned: state.totalEarned + upfront,
      turnLog: [
        ...state.turnLog,
        '案件「${project.name}」を受注しました！ (納期: ${project.deadline}ターン, 着手金: +${upfront}万円)',
      ],
    );
  }

  /// 社員をプロジェクトにアサイン
  static GameState assignEmployee(
    GameState state,
    String projectId,
    String employeeId,
  ) {
    final employee = state.employees.firstWhere((e) => e.id == employeeId);
    if (employee.isAssigned) {
      return state.copyWith(
        turnLog: [
          ...state.turnLog,
          '${employee.name}は既に別の案件にアサインされています。',
        ],
      );
    }

    final updatedProjects = state.contractProjects.map((p) {
      if (p.id == projectId) {
        return p.copyWith(
          assignedEmployeeIds: [...p.assignedEmployeeIds, employeeId],
        );
      }
      return p;
    }).toList();

    final updatedEmployees = state.employees.map((e) {
      if (e.id == employeeId) {
        return e.copyWith(assignedProjectId: () => projectId);
      }
      return e;
    }).toList();

    return state.copyWith(
      contractProjects: updatedProjects,
      employees: updatedEmployees,
      turnLog: [
        ...state.turnLog,
        '${employee.name}を案件にアサインしました。',
      ],
    );
  }

  /// 社員のアサイン解除
  static GameState unassignEmployee(
    GameState state,
    String employeeId,
  ) {
    final employee = state.employees.firstWhere((e) => e.id == employeeId);

    final updatedProjects = state.contractProjects.map((p) {
      if (p.assignedEmployeeIds.contains(employeeId)) {
        return p.copyWith(
          assignedEmployeeIds:
              p.assignedEmployeeIds.where((id) => id != employeeId).toList(),
        );
      }
      return p;
    }).toList();

    final updatedEmployees = state.employees.map((e) {
      if (e.id == employeeId) {
        return e.copyWith(assignedProjectId: () => null);
      }
      return e;
    }).toList();

    return state.copyWith(
      contractProjects: updatedProjects,
      employees: updatedEmployees,
      turnLog: [
        ...state.turnLog,
        '${employee.name}のアサインを解除しました。',
      ],
    );
  }

  /// 案件の進捗処理（ターン終了時）
  static GameState processProjects(GameState state) {
    final log = <String>[];
    final completedProjectIds = <String>[];

    var updatedProjects = state.contractProjects.map((project) {
      if (project.status != ProjectStatus.inProgress) return project;

      // アサイン中の社員の生産力を合計
      final assignedEmployees = state.employees
          .where((e) => project.assignedEmployeeIds.contains(e.id));

      if (assignedEmployees.isEmpty) return project;

      // テクノロジーボーナスの計算
      final techBonus = state.technologies
          .where((t) => t.isUnlocked)
          .fold(0, (sum, t) => sum + t.productivityBonus);

      // オフィスボーナス
      final officeBonus = state.office?.productivityBonus ?? 0;

      final totalProductivity = assignedEmployees.fold(
        0.0,
        (sum, e) => sum + e.productivity,
      );

      final bonusMultiplier = 1.0 + (techBonus + officeBonus) / 100.0;
      final workDone = (totalProductivity * bonusMultiplier / 10).round();

      var updated = project.copyWith(
        currentWork: (project.currentWork + workDone)
            .clamp(0, project.totalWork),
      );

      // 品質スコアの計算（スキルと疲労に基づく）
      final avgSkill = assignedEmployees.fold(0, (sum, e) => sum + e.skill) /
          assignedEmployees.length;
      final avgFatigue =
          assignedEmployees.fold(0, (sum, e) => sum + e.fatigue) /
              assignedEmployees.length;
      final qualityDelta =
          ((avgSkill - 50) / 10 - avgFatigue / 20).round();
      updated = updated.copyWith(
        qualityScore:
            (updated.qualityScore + qualityDelta).clamp(0, 100),
      );

      log.add(
          '「${project.name}」進捗: +$workDone (${updated.progress * 100 ~/ 1}%)');

      // 完了判定
      if (updated.isCompleted) {
        updated = updated.copyWith(status: ProjectStatus.completed);
        completedProjectIds.add(updated.id);
        log.add('案件「${project.name}」が完了しました！');
      }

      // 納期超過判定
      if (updated.isOverdue(state.currentTurn) &&
          !updated.isCompleted) {
        updated = updated.copyWith(status: ProjectStatus.overdue);
        log.add('案件「${project.name}」が納期を超過しました！');
      }

      return updated;
    }).toList();

    var updatedState = state.copyWith(
      contractProjects: updatedProjects,
      turnLog: [...state.turnLog, ...log],
    );

    // 完了した案件の報酬処理とアサイン解除
    for (final projectId in completedProjectIds) {
      // アサインされた社員を解放
      final project =
          updatedState.contractProjects.firstWhere((p) => p.id == projectId);
      for (final empId in project.assignedEmployeeIds) {
        updatedState = ContractEngine.unassignEmployee(updatedState, empId);
      }
    }

    // 納期超過のペナルティ
    for (final project in updatedState.contractProjects) {
      if (project.status == ProjectStatus.overdue) {
        updatedState = updatedState.copyWith(
          trust: (updatedState.trust - 2).clamp(0, 100),
          turnLog: [
            ...updatedState.turnLog,
            '納期超過ペナルティ: 信頼度 -2',
          ],
        );
      }
    }

    return updatedState;
  }

  /// 案件の開発を進める（APを消費）
  static GameState workOnProject(
    GameState state,
    String projectId, {
    int apCost = 1,
    bool isOvertime = false,
  }) {
    if (state.ap < apCost) {
      return state.copyWith(
        turnLog: [
          ...state.turnLog,
          'APが不足しています。',
        ],
      );
    }

    return state.copyWith(
      ap: state.ap - apCost,
    );
  }

  /// 新しい受託案件の生成
  static List<ContractProject> generateProjects(int turn, int trust) {
    final templates = [
      (
        name: 'コーポレートサイト制作',
        type: ProjectType.corporateSite,
        clients: ['ABC商事', '日本テクノ', 'グローバル物産'],
        reward: (240, 450),
        skill: (10, 30),
        work: (12, 24),
        deadline: (4, 8),
      ),
      (
        name: 'ECサイト構築',
        type: ProjectType.ecSite,
        clients: ['ファッションモール', 'グルメマート', 'ホビーショップ'],
        reward: (450, 900),
        skill: (20, 50),
        work: (20, 40),
        deadline: (6, 12),
      ),
      (
        name: 'Webアプリケーション開発',
        type: ProjectType.webApp,
        clients: ['スタートアップX', 'メディアY', 'フィンテックZ'],
        reward: (600, 1500),
        skill: (30, 60),
        work: (32, 60),
        deadline: (8, 16),
      ),
      (
        name: 'モバイルアプリ開発',
        type: ProjectType.mobileApp,
        clients: ['ヘルスケアCo.', 'エデュテック', 'ゲームスタジオ'],
        reward: (750, 1800),
        skill: (40, 70),
        work: (40, 80),
        deadline: (10, 20),
      ),
      (
        name: '基幹システム刷新',
        type: ProjectType.systemIntegration,
        clients: ['大手製造業', '金融グループ', '行政機関'],
        reward: (1500, 3000),
        skill: (60, 90),
        work: (80, 160),
        deadline: (15, 30),
      ),
    ];

    final random = DateTime.now().millisecondsSinceEpoch;
    final projects = <ContractProject>[];

    // 信頼度に応じて案件数を調整
    final maxProjects = trust >= 60
        ? 3
        : trust >= 30
            ? 2
            : 1;

    for (var i = 0; i < maxProjects; i++) {
      // ターンに応じて難易度を上げる
      final maxTemplateIndex =
          (turn / 30).floor().clamp(0, templates.length - 1);
      final templateIndex =
          (random + i * 7) % (maxTemplateIndex + 1);
      final t = templates[templateIndex];

      final clientIndex = (random + i * 3) % t.clients.length;
      final rewardRange = t.reward.$2 - t.reward.$1;
      final reward = t.reward.$1 + ((random + i * 13) % rewardRange);
      final workRange = t.work.$2 - t.work.$1;
      final work = t.work.$1 + ((random + i * 11) % workRange);
      final deadlineRange = t.deadline.$2 - t.deadline.$1;
      final deadline = t.deadline.$1 + ((random + i * 17) % deadlineRange);

      projects.add(ContractProject(
        id: 'proj_${turn}_$i',
        name: t.name,
        type: t.type,
        clientName: t.clients[clientIndex],
        reward: reward,
        requiredSkill: t.skill.$1 +
            ((random + i * 19) % (t.skill.$2 - t.skill.$1)),
        totalWork: work,
        deadline: deadline,
      ));
    }

    return projects;
  }
}
