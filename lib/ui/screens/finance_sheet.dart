import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/ceo_background.dart';
import '../../core/models/equity_round.dart';
import '../../core/models/loan.dart';
import '../../state/game_notifier.dart';
import '../theme/app_colors.dart';

class FinanceSheet extends ConsumerWidget {
  const FinanceSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameProvider);
    final notifier = ref.read(gameProvider.notifier);
    final financeApCost =
        notifier.getActionApCost(ActionCategory.finance);
    final canAfford = state.ap >= financeApCost;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              controller: scrollController,
              children: [
                const Text(
                  '資金調達',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'AP消費: ${financeApCost}AP',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 20),

                // --- ローンセクション ---
                const _SectionHeader(
                  icon: Icons.account_balance,
                  title: 'ローン（デットファイナンス）',
                  color: AppColors.orange,
                ),
                const SizedBox(height: 8),

                // アクティブローン一覧
                if (state.activeLoans.isNotEmpty) ...[
                  ...state.activeLoans.map((loan) => _LoanCard(
                        loan: loan,
                        onEarlyRepay: () =>
                            notifier.earlyRepayLoan(loan.id),
                      )),
                  const SizedBox(height: 8),
                ],

                // 新規借入
                if (state.activeLoans.length < 3) ...[
                  const Text(
                    '新規借入',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...LoanSize.values.map((size) => _LoanOption(
                        size: size,
                        canAfford: canAfford,
                        onTap: () => notifier.takeLoan(size),
                      )),
                ] else
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '同時に3件までしか借入できません',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textMuted),
                    ),
                  ),

                const SizedBox(height: 24),

                // --- エクイティセクション ---
                const _SectionHeader(
                  icon: Icons.show_chart,
                  title: 'エクイティ（株式調達）',
                  color: AppColors.purple,
                ),
                const SizedBox(height: 8),

                // 持株比率ビジュアル
                _EquityBar(
                  ownedPercent: state.remainingEquity,
                  soldPercent: state.totalEquitySold,
                ),

                const SizedBox(height: 12),

                // エクイティラウンド一覧
                ...EquityRoundType.values.map((type) {
                  final completed =
                      state.equityRounds.any((r) => r.type == type);
                  final prerequisiteMet = type.prerequisite == null ||
                      state.equityRounds
                          .any((r) => r.type == type.prerequisite);
                  final wouldExceedLimit =
                      state.totalEquitySold + type.equityPercent > 70;

                  return _EquityOption(
                    type: type,
                    completed: completed,
                    prerequisiteMet: prerequisiteMet,
                    wouldExceedLimit: wouldExceedLimit,
                    canAfford: canAfford,
                    onTap: () => notifier.raiseEquity(type),
                  );
                }),

                const SizedBox(height: 16),

                // サマリー
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'サマリー',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _SummaryRow(
                          label: '通常負債',
                          value: '${state.debt}万円',
                          color: state.debt > 0
                              ? AppColors.red
                              : AppColors.textSecondary,
                        ),
                        _SummaryRow(
                          label: 'ローン残高',
                          value: '${state.totalLoanDebt}万円',
                          color: state.totalLoanDebt > 0
                              ? AppColors.orange
                              : AppColors.textSecondary,
                        ),
                        _SummaryRow(
                          label: '月次ローン返済',
                          value: '${state.monthlyLoanPayment}万円/月',
                          color: AppColors.textSecondary,
                        ),
                        const Divider(),
                        _SummaryRow(
                          label: '総負債',
                          value: '${state.totalDebtWithLoans}万円',
                          color: state.totalDebtWithLoans >= 800
                              ? AppColors.red
                              : AppColors.textPrimary,
                          bold: true,
                        ),
                        _SummaryRow(
                          label: '持株比率',
                          value: '${state.remainingEquity}%',
                          color: AppColors.green,
                          bold: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.color,
  });

  final IconData icon;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _LoanCard extends StatelessWidget {
  const _LoanCard({required this.loan, required this.onEarlyRepay});

  final Loan loan;
  final VoidCallback onEarlyRepay;

  @override
  Widget build(BuildContext context) {
    final progress = 1.0 -
        (loan.remainingPrincipal / loan.principal);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  loan.size.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '残${loan.remainingMonths}ターン',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // 返済プログレスバー
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: AppColors.progressBg,
                color: AppColors.green,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '残高: ${loan.remainingPrincipal}万円 / 月額: ${loan.monthlyPayment}万円',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                TextButton(
                  onPressed: onEarlyRepay,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    '繰上返済(${loan.earlyRepayAmount}万)',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LoanOption extends StatelessWidget {
  const _LoanOption({
    required this.size,
    required this.canAfford,
    required this.onTap,
  });

  final LoanSize size;
  final bool canAfford;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: canAfford ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: canAfford
                  ? AppColors.orange.withValues(alpha: 0.5)
                  : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${size.label} - ${size.amount}万円',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: canAfford
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                      ),
                    ),
                    Text(
                      '月利${(size.monthlyRate * 100).toStringAsFixed(0)}% / ${size.termMonths}ターン返済',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: canAfford ? AppColors.orange : AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EquityOption extends StatelessWidget {
  const _EquityOption({
    required this.type,
    required this.completed,
    required this.prerequisiteMet,
    required this.wouldExceedLimit,
    required this.canAfford,
    required this.onTap,
  });

  final EquityRoundType type;
  final bool completed;
  final bool prerequisiteMet;
  final bool wouldExceedLimit;
  final bool canAfford;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final enabled =
        !completed && prerequisiteMet && !wouldExceedLimit && canAfford;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: completed
                  ? AppColors.green.withValues(alpha: 0.5)
                  : enabled
                      ? AppColors.purple.withValues(alpha: 0.5)
                      : AppColors.border,
            ),
            color: completed
                ? AppColors.green.withValues(alpha: 0.05)
                : null,
          ),
          child: Row(
            children: [
              Icon(
                completed ? Icons.check_circle : Icons.circle_outlined,
                size: 20,
                color: completed
                    ? AppColors.green
                    : enabled
                        ? AppColors.purple
                        : AppColors.textMuted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${type.label} - ${type.amount}万円',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: completed
                            ? AppColors.green
                            : enabled
                                ? AppColors.textPrimary
                                : AppColors.textMuted,
                      ),
                    ),
                    Text(
                      '株式${type.equityPercent}%譲渡${completed ? '（実施済み）' : ''}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (!prerequisiteMet && !completed)
                      Text(
                        '${type.prerequisite!.label}を先に完了してください',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.red,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EquityBar extends StatelessWidget {
  const _EquityBar({
    required this.ownedPercent,
    required this.soldPercent,
  });

  final int ownedPercent;
  final int soldPercent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '自社保有: $ownedPercent%',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (soldPercent > 0)
              Text(
                '投資家: $soldPercent%',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.purple,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 12,
            child: Row(
              children: [
                Expanded(
                  flex: ownedPercent,
                  child: Container(color: AppColors.green),
                ),
                if (soldPercent > 0)
                  Expanded(
                    flex: soldPercent,
                    child: Container(color: AppColors.purple),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.color,
    this.bold = false,
  });

  final String label;
  final String value;
  final Color color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
