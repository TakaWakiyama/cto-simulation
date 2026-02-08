import 'game_state.dart';
import 'models/equity_round.dart';
import 'models/loan.dart';

/// ローン・エクイティ資金調達エンジン
class FinanceEngine {
  static const int maxLoans = 3;
  static const int maxEquityPercent = 70;

  /// ローンを借り入れる
  static GameState takeLoan(GameState state, LoanSize size) {
    if (state.loans.where((l) => !l.isPaidOff).length >= maxLoans) {
      return state.copyWith(
        turnLog: [
          ...state.turnLog,
          '同時に${maxLoans}件までしか借入できません。',
        ],
      );
    }

    final loan = Loan.create(size, state.currentTurn);

    return state.copyWith(
      loans: [...state.loans, loan],
      money: state.money + size.amount,
      turnLog: [
        ...state.turnLog,
        '${size.label}で${size.amount}万円を借入しました（月利${(size.monthlyRate * 100).toStringAsFixed(0)}%、${size.termMonths}ターン返済）',
      ],
    );
  }

  /// 毎ターンのローン返済処理
  static GameState processLoanPayments(GameState state) {
    if (state.loans.isEmpty) return state;

    final log = <String>[];
    var totalPayment = 0;
    final updatedLoans = <Loan>[];

    for (final loan in state.loans) {
      if (loan.isPaidOff) {
        updatedLoans.add(loan);
        continue;
      }

      final payment = loan.monthlyPayment;
      totalPayment += payment;

      final principalPart = (loan.principal / loan.termMonths).ceil();
      final newRemaining =
          (loan.remainingPrincipal - principalPart).clamp(0, loan.principal);

      updatedLoans.add(loan.copyWith(
        remainingPrincipal: newRemaining,
        remainingMonths: loan.remainingMonths - 1,
      ));

      if (newRemaining <= 0) {
        log.add('${loan.size.label}を完済しました！');
      }
    }

    if (totalPayment > 0) {
      log.insert(0, 'ローン返済: -${totalPayment}万円');
    }

    return state.copyWith(
      loans: updatedLoans,
      money: state.money - totalPayment,
      totalSpent: state.totalSpent + totalPayment,
      turnLog: [...state.turnLog, ...log],
    );
  }

  /// 繰上返済
  static GameState earlyRepayLoan(GameState state, String loanId) {
    final loanIndex = state.loans.indexWhere((l) => l.id == loanId);
    if (loanIndex < 0) return state;

    final loan = state.loans[loanIndex];
    if (loan.isPaidOff) return state;

    final repayAmount = loan.earlyRepayAmount;
    if (state.money < repayAmount) {
      return state.copyWith(
        turnLog: [
          ...state.turnLog,
          '繰上返済に${repayAmount}万円が必要ですが、資金が不足しています。',
        ],
      );
    }

    final updatedLoans = List<Loan>.from(state.loans);
    updatedLoans[loanIndex] = loan.copyWith(
      remainingPrincipal: 0,
      remainingMonths: 0,
    );

    return state.copyWith(
      loans: updatedLoans,
      money: state.money - repayAmount,
      turnLog: [
        ...state.turnLog,
        '${loan.size.label}を繰上返済しました！ -${repayAmount}万円',
      ],
    );
  }

  /// エクイティ調達
  static GameState raiseEquity(GameState state, EquityRoundType type) {
    // 前提条件チェック
    if (type.prerequisite != null) {
      final hasPrerequisite =
          state.equityRounds.any((r) => r.type == type.prerequisite);
      if (!hasPrerequisite) {
        return state.copyWith(
          turnLog: [
            ...state.turnLog,
            '${type.prerequisite!.label}を先に完了する必要があります。',
          ],
        );
      }
    }

    // 重複チェック
    if (state.equityRounds.any((r) => r.type == type)) {
      return state.copyWith(
        turnLog: [
          ...state.turnLog,
          '${type.label}は既に実施済みです。',
        ],
      );
    }

    // 上限チェック
    if (state.totalEquitySold + type.equityPercent > maxEquityPercent) {
      return state.copyWith(
        turnLog: [
          ...state.turnLog,
          '株式譲渡上限（${maxEquityPercent}%）を超えるため実施できません。',
        ],
      );
    }

    final round = EquityRound.create(type, state.currentTurn);

    return state.copyWith(
      equityRounds: [...state.equityRounds, round],
      money: state.money + type.amount,
      trust: (state.trust + 5).clamp(0, 100),
      turnLog: [
        ...state.turnLog,
        '${type.label}で${type.amount}万円を調達しました！（株式${type.equityPercent}%譲渡）',
        '信頼度 +5',
      ],
    );
  }
}
