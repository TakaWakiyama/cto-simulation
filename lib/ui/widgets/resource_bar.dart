import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../state/game_notifier.dart';
import '../theme/app_colors.dart';

class ResourceBar extends ConsumerWidget {
  const ResourceBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameProvider);
    final formatter = NumberFormat('#,###');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // メインリソース（大きめ）
            Row(
              children: [
                // 資金
                _BigResource(
                  icon: Icons.currency_yen,
                  value: '${formatter.format(state.money)}万',
                  color: AppColors.money,
                ),
                const SizedBox(width: 16),
                // 信頼度
                _BigResource(
                  icon: Icons.handshake_outlined,
                  value: '信頼 ${state.trust}',
                  color: state.trust < 20 ? AppColors.red : AppColors.trust,
                ),
                const Spacer(),
                // APインジケーター
                _ApIndicator(current: state.ap, max: state.config.apPerTurn),
              ],
            ),
            const SizedBox(height: 6),
            // サブ情報
            Row(
              children: [
                if (state.totalDebtWithLoans > 0) ...[
                  Icon(Icons.trending_down, size: 12, color: AppColors.red),
                  const SizedBox(width: 2),
                  Text(
                    '負債:${formatter.format(state.totalDebtWithLoans)}万',
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.red,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 12),
                ],
                if (state.hasEquity) ...[
                  Icon(Icons.show_chart, size: 12, color: AppColors.purple),
                  const SizedBox(width: 2),
                  Text(
                    '持株:${state.remainingEquity}%',
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.purple,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 12),
                ],
                Icon(Icons.people_outline, size: 12,
                    color: AppColors.textSecondary),
                const SizedBox(width: 2),
                Text(
                  '${state.employeeCount}/${state.maxEmployees}名',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
                const SizedBox(width: 12),
                if (state.totalMonthlyCost > 0) ...[
                  Icon(Icons.payments_outlined, size: 12,
                      color: AppColors.textSecondary),
                  const SizedBox(width: 2),
                  Text(
                    '支出:${state.totalMonthlyCost}万/月',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
                if (state.config.background != null) ...[
                  Icon(Icons.person, size: 12,
                      color: AppColors.textSecondary),
                  const SizedBox(width: 2),
                  Text(
                    state.config.background!.label,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: 12),
                ],
                const Spacer(),
                if (state.saasRevenue > 0) ...[
                  Icon(Icons.trending_up, size: 12, color: AppColors.cyan),
                  const SizedBox(width: 2),
                  Text(
                    'MRR:${formatter.format(state.saasRevenue)}万',
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.cyan,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BigResource extends StatelessWidget {
  const _BigResource({
    required this.icon,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _ApIndicator extends StatelessWidget {
  const _ApIndicator({required this.current, required this.max});

  final int current;
  final int max;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: current > 0
            ? AppColors.orange.withValues(alpha: 0.15)
            : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: current > 0
              ? AppColors.orange.withValues(alpha: 0.5)
              : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt,
              size: 14,
              color: current > 0 ? AppColors.orange : AppColors.textMuted),
          const SizedBox(width: 4),
          Text(
            'AP $current/$max',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: current > 0 ? AppColors.orange : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
