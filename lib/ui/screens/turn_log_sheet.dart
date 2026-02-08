import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/game_notifier.dart';
import '../theme/app_colors.dart';

class TurnLogSheet extends ConsumerWidget {
  const TurnLogSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      maxChildSize: 0.8,
      minChildSize: 0.3,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // ハンドル
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.terminal, size: 16, color: AppColors.green),
                    SizedBox(width: 8),
                    Text(
                      'ターンログ',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.green,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 16),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: state.turnLog.length,
                  itemBuilder: (_, index) {
                    final log = state.turnLog[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '> $log',
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'JetBrainsMono',
                          color: _logColor(log),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _logColor(String log) {
    if (log.contains('═══')) return AppColors.cyan;
    if (log.contains('完了') || log.contains('+')) return AppColors.green;
    if (log.contains('障害') || log.contains('退職') || log.contains('超過')) {
      return AppColors.red;
    }
    if (log.contains('イベント')) return AppColors.yellow;
    if (log.contains('警告') || log.contains('負荷')) return AppColors.orange;
    return AppColors.textSecondary;
  }
}
