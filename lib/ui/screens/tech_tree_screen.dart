import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ap_cost_calculator.dart';
import '../../core/models/ceo_background.dart';
import '../../core/models/technology.dart';
import '../../state/game_notifier.dart';
import '../theme/app_colors.dart';
import '../widgets/progress_bar.dart';

class TechTreeScreen extends ConsumerWidget {
  const TechTreeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameProvider);
    final notifier = ref.read(gameProvider.notifier);

    final categories = TechCategory.values;

    return Scaffold(
      appBar: AppBar(
        title: const Text('テクノロジーツリー'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                'AP: ${state.ap}',
                style: const TextStyle(
                  color: AppColors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // 解禁済みボーナスサマリー
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _BonusStat(
                    label: '生産性ボーナス',
                    value: '+${state.technologies.where((t) => t.isUnlocked).fold(0, (sum, t) => sum + t.productivityBonus)}%',
                    color: AppColors.green,
                  ),
                  _BonusStat(
                    label: '品質ボーナス',
                    value: '+${state.technologies.where((t) => t.isUnlocked).fold(0, (sum, t) => sum + t.qualityBonus)}%',
                    color: AppColors.blue,
                  ),
                  _BonusStat(
                    label: '解禁済み',
                    value: '${state.technologies.where((t) => t.isUnlocked).length}/${state.technologies.length}',
                    color: AppColors.purple,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // カテゴリ別表示
          ...categories.map((category) {
            final techs = state.technologies
                .where((t) => t.category == category)
                .toList();
            if (techs.isEmpty) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        _categoryIcon(category),
                        size: 16,
                        color: _categoryColor(category),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        category.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _categoryColor(category),
                        ),
                      ),
                    ],
                  ),
                ),
                ...techs.map((tech) => _TechCard(
                      tech: tech,
                      canResearch: tech.canResearch(state.unlockedTechIds) &&
                          ApCostCalculator.canAfford(
                              state.ap, state.config, ActionCategory.tech) &&
                          state.money >= tech.researchCost,
                      onResearch: () => notifier.startResearch(tech.id),
                      allTechs: state.technologies,
                    )),
              ],
            );
          }),
        ],
      ),
    );
  }

  IconData _categoryIcon(TechCategory category) => switch (category) {
        TechCategory.language => Icons.code,
        TechCategory.framework => Icons.widgets,
        TechCategory.infrastructure => Icons.dns,
        TechCategory.devops => Icons.settings,
        TechCategory.security => Icons.shield,
        TechCategory.ai => Icons.psychology,
      };

  Color _categoryColor(TechCategory category) => switch (category) {
        TechCategory.language => AppColors.blue,
        TechCategory.framework => AppColors.purple,
        TechCategory.infrastructure => AppColors.cyan,
        TechCategory.devops => AppColors.orange,
        TechCategory.security => AppColors.red,
        TechCategory.ai => AppColors.yellow,
      };
}

class _TechCard extends StatelessWidget {
  const _TechCard({
    required this.tech,
    required this.canResearch,
    required this.onResearch,
    required this.allTechs,
  });

  final Technology tech;
  final bool canResearch;
  final VoidCallback onResearch;
  final List<Technology> allTechs;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Opacity(
        opacity: tech.isUnlocked || tech.isResearching || canResearch
            ? 1.0
            : 0.5,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // ステータスアイコン
                  _statusIcon(),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tech.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (tech.description.isNotEmpty)
                          Text(
                            tech.description,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (!tech.isUnlocked && !tech.isResearching && canResearch)
                    ElevatedButton(
                      onPressed: onResearch,
                      child: Text('${tech.researchCost}万',
                          style: const TextStyle(fontSize: 11)),
                    ),
                ],
              ),

              // 研究中のプログレス
              if (tech.isResearching) ...[
                const SizedBox(height: 8),
                GameProgressBar(
                  value: tech.researchRate,
                  label: '研究進捗',
                  showPercentage: true,
                  color: AppColors.orange,
                ),
              ],

              // ボーナス表示
              if (tech.isUnlocked) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [
                    if (tech.productivityBonus > 0)
                      _BonusChip(
                        text: '生産性 +${tech.productivityBonus}%',
                        color: AppColors.green,
                      ),
                    if (tech.qualityBonus > 0)
                      _BonusChip(
                        text: '品質 +${tech.qualityBonus}%',
                        color: AppColors.blue,
                      ),
                  ],
                ),
              ],

              // 前提技術
              if (tech.prerequisites.isNotEmpty &&
                  !tech.isUnlocked) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  children: [
                    const Text(
                      '前提: ',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textMuted,
                      ),
                    ),
                    ...tech.prerequisites.map((prereqId) {
                      final prereq = allTechs
                          .where((t) => t.id == prereqId)
                          .firstOrNull;
                      return Text(
                        prereq?.name ?? prereqId,
                        style: TextStyle(
                          fontSize: 10,
                          color: prereq?.isUnlocked == true
                              ? AppColors.green
                              : AppColors.red,
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusIcon() {
    if (tech.isUnlocked) {
      return const Icon(Icons.check_circle, color: AppColors.green, size: 20);
    }
    if (tech.isResearching) {
      return const Icon(Icons.hourglass_top, color: AppColors.orange, size: 20);
    }
    if (canResearch) {
      return const Icon(Icons.lock_open, color: AppColors.blue, size: 20);
    }
    return const Icon(Icons.lock, color: AppColors.textMuted, size: 20);
  }
}

class _BonusChip extends StatelessWidget {
  const _BonusChip({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, color: color),
      ),
    );
  }
}

class _BonusStat extends StatelessWidget {
  const _BonusStat({
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
