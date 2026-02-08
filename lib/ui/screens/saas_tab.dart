import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/ap_cost_calculator.dart';
import '../../core/models/ceo_background.dart';
import '../../core/models/saas_product.dart';
import '../../core/saas_engine.dart';
import '../../state/game_notifier.dart';
import '../theme/app_colors.dart';
import '../widgets/progress_bar.dart';

class SaaSTab extends ConsumerWidget {
  const SaaSTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameProvider);
    final notifier = ref.read(gameProvider.notifier);
    final formatter = NumberFormat('#,###');

    final launchedProducts =
        state.saasProducts.where((p) => p.isLaunched).toList();
    final developingProducts =
        state.saasProducts.where((p) => !p.isLaunched).toList();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // SaaSサマリー
        if (launchedProducts.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SaaS事業サマリー',
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
                        label: '総ユーザー',
                        value: formatter.format(state.totalSaasUsers),
                        color: AppColors.purple,
                      ),
                      _StatItem(
                        label: 'MRR',
                        value: '${formatter.format(state.saasRevenue)}万',
                        color: AppColors.money,
                      ),
                      _StatItem(
                        label: '製品数',
                        value: '${launchedProducts.length}',
                        color: AppColors.cyan,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 12),

        // 新規SaaS開発ボタン
        ElevatedButton.icon(
          onPressed: ApCostCalculator.canAfford(
                  state.ap, state.config, ActionCategory.tech)
              ? () => _showNewProductDialog(context, ref)
              : null,
          icon: const Icon(Icons.rocket_launch, size: 18),
          label: Text(
            '新しいSaaS製品を開発する (AP${ApCostCalculator.cost(state.config, ActionCategory.tech)})',
          ),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(44),
            backgroundColor: AppColors.purple.withValues(alpha: 0.8),
          ),
        ),

        const SizedBox(height: 12),

        // リリース済み製品
        if (launchedProducts.isNotEmpty) ...[
          _sectionTitle('リリース済み', AppColors.green),
          ...launchedProducts.map((product) => _SaaSCard(
                product: product,
                formatter: formatter,
              )),
        ],

        // 開発中の製品
        if (developingProducts.isNotEmpty) ...[
          const SizedBox(height: 12),
          _sectionTitle('開発中', AppColors.orange),
          ...developingProducts.map((product) => _DevelopingSaaSCard(
                product: product,
                canLaunch: product.isDevelopmentComplete &&
                    ApCostCalculator.canAfford(
                        state.ap, state.config, ActionCategory.tech),
                onLaunch: () => notifier.launchSaaS(product.id),
                onAssign: () => _showAssignDialog(context, ref, product),
              )),
        ],

        if (state.saasProducts.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.cloud_outlined, size: 48,
                      color: AppColors.textMuted),
                  SizedBox(height: 8),
                  Text(
                    'SaaS製品がありません\n新しい製品の開発を始めましょう',
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

  Widget _sectionTitle(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showNewProductDialog(BuildContext context, WidgetRef ref) {
    final state = ref.read(gameProvider);
    final notifier = ref.read(gameProvider.notifier);
    final available = SaaSEngine.getAvailableProducts()
        .where((p) => !state.saasProducts.any((sp) => sp.id == p.id))
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
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
                    'SaaS製品を選択',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (available.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        '開発可能な製品がありません',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        children: available.map((product) {
                          return Card(
                            child: ListTile(
                              leading: Icon(
                                _categoryIcon(product.category),
                                color: AppColors.purple,
                              ),
                              title: Text(product.name),
                              subtitle: Text(
                                '${product.category.label} / ¥${product.monthlyPricePerUser}/user/月\n開発費: ${product.developmentCost}万円 / 保守: ${product.monthlyMaintenanceCost}万/月',
                                style: const TextStyle(fontSize: 11),
                              ),
                              isThreeLine: true,
                              trailing: ElevatedButton(
                                onPressed: state.money >=
                                        product.developmentCost
                                    ? () {
                                        notifier.startSaaSDevelopment(
                                            product.id);
                                        Navigator.pop(ctx);
                                      }
                                    : null,
                                child: const Text('開発',
                                    style: TextStyle(fontSize: 12)),
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

  void _showAssignDialog(
      BuildContext context, WidgetRef ref, SaaSProduct product) {
    final state = ref.read(gameProvider);
    final notifier = ref.read(gameProvider.notifier);
    final unassigned = state.unassignedEmployees
        .where((e) => e.isEngineer)
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${product.name}の開発にアサイン',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              if (unassigned.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    '待機中のエンジニアがいません',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              else
                ...unassigned.map((emp) => ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text(emp.name),
                      subtitle: Text(
                        '${emp.role.label} / スキル: ${emp.skill}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      onTap: () {
                        // SaaS開発にアサイン（プロジェクトIDとしてSaaS IDを使用）
                        notifier.assignEmployee(product.id, emp.id);
                        Navigator.pop(ctx);
                      },
                    )),
            ],
          ),
        );
      },
    );
  }

  IconData _categoryIcon(SaaSCategory category) => switch (category) {
        SaaSCategory.crm => Icons.people,
        SaaSCategory.erp => Icons.business,
        SaaSCategory.projectManagement => Icons.task_alt,
        SaaSCategory.communication => Icons.chat,
        SaaSCategory.analytics => Icons.analytics,
        SaaSCategory.security => Icons.security,
      };
}

class _SaaSCard extends StatelessWidget {
  const _SaaSCard({
    required this.product,
    required this.formatter,
  });

  final SaaSProduct product;
  final NumberFormat formatter;

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
                Icon(Icons.cloud, color: AppColors.green, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${formatter.format(product.monthlyRevenue)}万/月',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.money,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ユーザー: ${formatter.format(product.totalUsers)}人',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  '成長率: ${product.growthRate.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 11,
                    color: product.growthRate > 0
                        ? AppColors.green
                        : AppColors.red,
                  ),
                ),
                Text(
                  '解約率: ${product.churnRate.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            GameProgressBar(
              value: product.quality / 100,
              label: '品質',
              showPercentage: true,
              color: AppColors.blue,
              height: 6,
            ),
          ],
        ),
      ),
    );
  }
}

class _DevelopingSaaSCard extends StatelessWidget {
  const _DevelopingSaaSCard({
    required this.product,
    required this.canLaunch,
    required this.onLaunch,
    required this.onAssign,
  });

  final SaaSProduct product;
  final bool canLaunch;
  final VoidCallback onLaunch;
  final VoidCallback onAssign;

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
                Icon(Icons.code, color: AppColors.orange, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (product.isDevelopmentComplete)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.green),
                    ),
                    child: const Text(
                      '開発完了',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.green,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            GameProgressBar(
              value: product.developmentRate,
              label: '開発進捗',
              showPercentage: true,
              color: AppColors.orange,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (product.isDevelopmentComplete)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: canLaunch ? onLaunch : null,
                      icon: const Icon(Icons.rocket_launch, size: 16),
                      label: const Text('リリース',
                          style: TextStyle(fontSize: 12)),
                    ),
                  )
                else
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onAssign,
                      icon: const Icon(Icons.person_add, size: 16),
                      label: const Text('開発者をアサイン',
                          style: TextStyle(fontSize: 12)),
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
