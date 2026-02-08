import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ap_cost_calculator.dart';
import '../../core/infra_engine.dart';
import '../../core/models/ceo_background.dart';
import '../../core/models/server.dart';
import '../../state/game_notifier.dart';
import '../theme/app_colors.dart';
import '../widgets/progress_bar.dart';

class InfraTab extends ConsumerWidget {
  const InfraTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameProvider);
    final notifier = ref.read(gameProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // インフラサマリー
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'サーバーステータス',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatItem(
                      label: 'サーバー数',
                      value: '${state.servers.length}',
                      color: AppColors.blue,
                    ),
                    _StatItem(
                      label: '総容量',
                      value: '${state.totalServerCapacity}',
                      color: AppColors.cyan,
                    ),
                    _StatItem(
                      label: 'SaaSユーザー',
                      value: '${state.totalSaasUsers}',
                      color: AppColors.purple,
                    ),
                    _StatItem(
                      label: '月額費用',
                      value: '${state.totalServerCost}万',
                      color: AppColors.money,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // サーバー購入ボタン
        ElevatedButton.icon(
          onPressed: ApCostCalculator.canAfford(
                  state.ap, state.config, ActionCategory.tech)
              ? () => _showPurchaseDialog(context, ref)
              : null,
          icon: const Icon(Icons.add_circle_outline, size: 18),
          label: Text(
            'サーバーを購入する (AP${ApCostCalculator.cost(state.config, ActionCategory.tech)})',
          ),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(44),
          ),
        ),

        const SizedBox(height: 12),

        // 所有サーバー一覧
        ...state.servers.map((server) => _ServerCard(
              server: server,
              onRemove: () => _confirmRemove(context, notifier, server),
            )),

        if (state.servers.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.dns_outlined, size: 48,
                      color: AppColors.textMuted),
                  SizedBox(height: 8),
                  Text(
                    'サーバーがありません\nSaaSを運用するにはサーバーが必要です',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _showPurchaseDialog(BuildContext context, WidgetRef ref) {
    final state = ref.read(gameProvider);
    final notifier = ref.read(gameProvider.notifier);
    final available = InfraEngine.getAvailableServers();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (_, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'サーバー購入',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '初期費用: 月額の3ヶ月分 / 所持金: ${state.money}万円',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: available.map((server) {
                        final purchaseCost = server.monthlyCost * 3;
                        final canBuy = state.money >= purchaseCost;
                        return Card(
                          child: ListTile(
                            leading: Icon(
                              _tierIcon(server.tier),
                              color: _tierColor(server.tier),
                            ),
                            title: Text(server.name),
                            subtitle: Text(
                              '容量: ${server.capacity}人 / 信頼性: ${server.reliability}% / 月額: ${server.monthlyCost}万円',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: ElevatedButton(
                              onPressed: canBuy
                                  ? () {
                                      notifier.purchaseServer(server.copyWith(
                                        id: 'srv_${DateTime.now().millisecondsSinceEpoch}',
                                      ));
                                      Navigator.pop(ctx);
                                    }
                                  : null,
                              child: Text('${purchaseCost}万',
                                  style: const TextStyle(fontSize: 12)),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _confirmRemove(
      BuildContext context, GameNotifier notifier, Server server) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('サーバー撤去'),
        content: Text('${server.name}を撤去しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              notifier.removeServer(server.id);
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: const Text('撤去する'),
          ),
        ],
      ),
    );
  }

  IconData _tierIcon(ServerTier tier) => switch (tier) {
        ServerTier.shared => Icons.cloud_outlined,
        ServerTier.vps => Icons.dns_outlined,
        ServerTier.dedicated => Icons.dns,
        ServerTier.cloud => Icons.cloud,
        ServerTier.enterprise => Icons.cloud_circle,
      };

  Color _tierColor(ServerTier tier) => switch (tier) {
        ServerTier.shared => AppColors.textSecondary,
        ServerTier.vps => AppColors.blue,
        ServerTier.dedicated => AppColors.purple,
        ServerTier.cloud => AppColors.cyan,
        ServerTier.enterprise => AppColors.orange,
      };
}

class _ServerCard extends StatelessWidget {
  const _ServerCard({required this.server, required this.onRemove});

  final Server server;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  server.isDown
                      ? Icons.error_outline
                      : Icons.dns_outlined,
                  color: server.isDown ? AppColors.red : AppColors.blue,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        server.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${server.tier.label} / 月額: ${server.monthlyCost}万円',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (server.isDown)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.red),
                    ),
                    child: const Text(
                      '障害発生中',
                      style: TextStyle(fontSize: 10, color: AppColors.red),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  color: AppColors.textSecondary,
                  onPressed: onRemove,
                ),
              ],
            ),
            const SizedBox(height: 8),
            GameProgressBar(
              value: server.loadRate,
              label: '負荷率',
              showPercentage: true,
              color: AppColors.serverLoadColor(server.loadRate),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '容量: ${server.capacity}人',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '現在: ${server.currentLoad}人',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '信頼性: ${server.reliability}%',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
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

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
