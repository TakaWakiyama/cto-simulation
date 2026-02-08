import 'contract_engine.dart';
import 'economy_engine.dart';
import 'employee_engine.dart';
import 'event_engine.dart';
import 'finance_engine.dart';
import 'game_state.dart';
import 'infra_engine.dart';
import 'models/event.dart';
import 'models/office.dart';
import 'saas_engine.dart';
import 'staff_bonus_engine.dart';
import 'tech_tree_engine.dart';

/// ターン進行の5フェーズ処理を統括するエンジン
///
/// Phase 1: 収入/支出処理
/// Phase 2: 案件進捗処理
/// Phase 3: SaaS/インフラ処理
/// Phase 4: 社員状態更新
/// Phase 5: イベント抽選
class TurnEngine {
  /// ターン終了処理を実行
  static GameState processTurnEnd(
    GameState state, {
    List<GameEvent>? customEvents,
  }) {
    if (state.isGameOver) return state;

    var newState = state.copyWith(
      turnLog: ['═══ ターン ${state.currentTurn} 終了 ═══'],
    );

    // Phase 1: 収入/支出処理
    newState = EconomyEngine.processMonthlyExpenses(newState);

    // Phase 1.5: ローン返済処理
    newState = FinanceEngine.processLoanPayments(newState);

    // Phase 2: 案件進捗処理
    newState = ContractEngine.processProjects(newState);

    // 完了した案件の報酬受け取り
    for (final project in newState.contractProjects) {
      if (project.status.name == 'completed' &&
          !state.contractProjects
              .any((p) => p.id == project.id && p.status.name == 'completed')) {
        newState = EconomyEngine.receiveContractReward(newState, project.id);
      }
    }

    // Phase 3: SaaS/インフラ処理
    newState = SaaSEngine.processSaaS(newState);
    newState = InfraEngine.processServers(newState);

    // Phase 4: 社員状態更新
    newState = EmployeeEngine.processEmployees(newState);

    // Phase 5: テクノロジー研究進捗
    newState = TechTreeEngine.processResearch(newState);

    // Phase 6: イベント抽選
    final events = customEvents ?? EventEngine.getDefaultEvents();
    final event = EventEngine.rollEvent(newState, events);
    if (event != null) {
      newState = newState.copyWith(
        pendingEvent: () => event,
        turnLog: [
          ...newState.turnLog,
          '【イベント発生】${event.title}',
        ],
      );
    }

    // ゲームオーバー判定
    newState = EconomyEngine.checkGameOver(newState);

    // 最終ターン判定
    if (newState.currentTurn >= newState.config.maxTurns && !newState.isGameOver) {
      newState = newState.copyWith(
        isGameOver: true,
        gameOverReason: () => 'ゲーム終了！ ${newState.config.maxTurns}ターンが経過しました。',
      );
    }

    // ターン進行（バックオフィスAPボーナス加算）
    if (!newState.isGameOver) {
      final apBonus = StaffBonusEngine.backOfficeApBonus(newState);
      newState = newState.copyWith(
        currentTurn: newState.currentTurn + 1,
        ap: newState.config.apPerTurn + apBonus,
      );
    }

    return newState;
  }

  /// 新しいゲームの初期化
  static GameState initializeGame(GameState state) {
    const startingOffice = Office(
      id: 'office_garage',
      name: 'ガレージオフィス',
      maxEmployees: 5,
      monthlyCost: 5,
      description: 'スタートアップの原点。狭いが家賃は安い。',
    );

    final startingEmployees = EmployeeEngine.generateCandidates(2);
    final startingProjects = ContractEngine.generateProjects(1, state.trust);
    final techTree = TechTreeEngine.getDefaultTechTree();

    return state.copyWith(
      office: () => startingOffice,
      employees: startingEmployees,
      contractProjects: startingProjects,
      technologies: techTree,
      turnLog: [
        'ゲーム開始！ あなたはシステム開発企業のCTOです。',
        '所持金: ${state.money}万円 / 信頼度: ${state.trust}',
        '${startingEmployees.length}名のエンジニアと共にスタートします。',
        '${startingProjects.length}件の案件が募集中です。',
      ],
    );
  }
}
