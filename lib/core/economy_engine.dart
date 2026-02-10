import 'contract_engine.dart';
import 'game_state.dart';
import 'staff_bonus_engine.dart';

/// 収入/支出/企業価値の計算エンジン
class EconomyEngine {
  /// 月次経費の計算と適用
  static GameState processMonthlyExpenses(GameState state) {
    final rawExpense = state.totalMonthlyCost;
    // バックオフィスによる経費削減
    final expenseReduction = StaffBonusEngine.backOfficeExpenseReduction(state);
    final totalExpense = (rawExpense * (1.0 - expenseReduction)).round();
    final saasRev = state.saasRevenue;
    final newMoney = state.money - totalExpense + saasRev;

    final log = <String>[];
    if (totalExpense > 0) {
      log.add(
        '月次経費: -${totalExpense}万円 (給与: ${state.totalSalary}, サーバー: ${state.totalServerCost}, オフィス: ${state.officeCost})',
      );
    }
    if (saasRev > 0) {
      log.add('SaaS売上: +${saasRev}万円');
    }

    var updatedState = state.copyWith(
      money: newMoney,
      monthlyRevenue: saasRev,
      monthlyExpense: totalExpense,
      totalEarned: state.totalEarned + saasRev,
      totalSpent: state.totalSpent + totalExpense,
      turnLog: [...state.turnLog, ...log],
    );

    // 資金がマイナスの場合、負債に変換
    if (updatedState.money < 0) {
      final newDebt = updatedState.debt - updatedState.money;
      updatedState = updatedState.copyWith(
        money: 0,
        debt: newDebt,
        turnLog: [...updatedState.turnLog, '資金不足! 負債が${newDebt}万円に増加'],
      );
    }

    return updatedState;
  }

  /// 受託案件完了時の報酬受け取り（着手金分を差し引いた残金）
  static GameState receiveContractReward(GameState state, String projectId) {
    final project = state.contractProjects.firstWhere((p) => p.id == projectId);
    final salesMultiplier = StaffBonusEngine.salesRewardMultiplier(state);
    final reward =
        (project.reward *
                state.config.difficulty.rewardMultiplier *
                salesMultiplier)
            .round();

    // 品質スコアに応じてボーナス/ペナルティ
    final qualityMultiplier = project.qualityScore >= 80
        ? 1.2
        : project.qualityScore >= 50
        ? 1.0
        : 0.8;
    final totalReward = (reward * qualityMultiplier).round();

    // 着手金（受注時に支払い済み）を差し引いた残金
    final upfrontPaid = (project.reward * ContractEngine.upfrontRate).round();
    final remainingReward = totalReward - upfrontPaid;

    // 信頼度への影響（営業ボーナス加算）
    final baseTrustDelta = project.qualityScore >= 80
        ? 5
        : project.qualityScore >= 50
        ? 2
        : -3;
    final trustDelta = baseTrustDelta > 0
        ? baseTrustDelta + StaffBonusEngine.salesTrustBonus(state)
        : baseTrustDelta;

    return state.copyWith(
      money: state.money + remainingReward,
      trust: (state.trust + trustDelta).clamp(0, 100),
      totalEarned: state.totalEarned + remainingReward,
      turnLog: [
        ...state.turnLog,
        '案件「${project.name}」完了! +${remainingReward}万円 (総額${totalReward}万円, 着手金${upfrontPaid}万円支払済, 品質: ${project.qualityScore})',
        if (trustDelta > 0) '信頼度 +$trustDelta' else '信頼度 $trustDelta',
      ],
    );
  }

  /// 借金の返済
  static GameState repayDebt(GameState state, int amount) {
    if (amount > state.money) return state;
    if (amount > state.debt) amount = state.debt;

    return state.copyWith(
      money: state.money - amount,
      debt: state.debt - amount,
      turnLog: [...state.turnLog, '負債返済: ${amount}万円'],
    );
  }

  /// ゲームオーバー判定
  static GameState checkGameOver(GameState state) {
    // キャッシュが尽きたら資金ショート
    if (state.money <= 0) {
      return state.copyWith(
        isGameOver: true,
        gameOverReason: () => 'キャッシュが尽き、資金ショートで倒産しました。',
      );
    }

    // 信頼度が0になったら
    if (state.trust <= 0) {
      return state.copyWith(
        isGameOver: true,
        gameOverReason: () => '信頼度が0になり、取引先を全て失いました。',
      );
    }

    // 社員が全員辞めて案件が残っている場合
    if (state.employees.isEmpty && state.activeProjects.isNotEmpty) {
      return state.copyWith(
        isGameOver: true,
        gameOverReason: () => '社員が全員退職し、進行中の案件を完了できません。',
      );
    }

    return state;
  }
}
