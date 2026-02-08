import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ap_cost_calculator.dart';
import '../../core/employee_engine.dart';
import '../../core/models/ceo_background.dart';
import '../../core/models/employee.dart';
import '../../core/models/employee_type.dart';
import '../../core/staff_bonus_engine.dart';
import '../../state/game_notifier.dart';
import '../theme/app_colors.dart';
import '../widgets/employee_card.dart';

class EmployeeTab extends ConsumerStatefulWidget {
  const EmployeeTab({super.key});

  @override
  ConsumerState<EmployeeTab> createState() => _EmployeeTabState();
}

class _EmployeeTabState extends ConsumerState<EmployeeTab> {
  bool _showStaff = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gameProvider);
    final notifier = ref.read(gameProvider.notifier);

    final engineers = state.employees.where((e) => e.isEngineer).toList();
    final staff = state.employees.where((e) => !e.isEngineer).toList();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // チームサマリー
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                  label: '社員数',
                  value: '${state.employeeCount}/${state.maxEmployees}',
                  color: AppColors.purple,
                ),
                _StatItem(
                  label: '平均幸福度',
                  value: '${state.averageHappiness.toStringAsFixed(0)}%',
                  color: state.averageHappiness > 50
                      ? AppColors.green
                      : AppColors.red,
                ),
                _StatItem(
                  label: '平均疲労',
                  value: '${state.averageFatigue.toStringAsFixed(0)}%',
                  color: state.averageFatigue < 50
                      ? AppColors.green
                      : AppColors.red,
                ),
                _StatItem(
                  label: '月給合計',
                  value: '${state.totalSalary}万',
                  color: AppColors.money,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // エンジニア/スタッフ切替タブ
        Row(
          children: [
            Expanded(
              child: _SegmentButton(
                label: 'エンジニア (${engineers.length})',
                isSelected: !_showStaff,
                onTap: () => setState(() => _showStaff = false),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SegmentButton(
                label: 'スタッフ (${staff.length})',
                isSelected: _showStaff,
                onTap: () => setState(() => _showStaff = true),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        if (!_showStaff) ...[
          // エンジニア採用ボタン
          if (state.employeeCount < state.maxEmployees)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ElevatedButton.icon(
                onPressed: ApCostCalculator.canAfford(
                        state.ap, state.config, ActionCategory.hiring)
                    ? () => _showHiringDialog(context, ref)
                    : null,
                icon: const Icon(Icons.person_add, size: 18),
                label: Text(
                  'エンジニアを採用する (AP${ApCostCalculator.cost(state.config, ActionCategory.hiring)})',
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                ),
              ),
            ),

          // エンジニア一覧
          ...engineers.map((emp) => EmployeeCard(
                employee: emp,
                onUnassign: emp.isAssigned
                    ? () => notifier.unassignEmployee(emp.id)
                    : null,
                onFire: () => _confirmFire(context, ref, emp),
                onTap: () => _showEmployeeDetail(context, ref, emp),
              )),

          if (engineers.isEmpty)
            const _EmptyState(
              icon: Icons.code,
              text: 'エンジニアがいません\nエンジニアを採用しましょう',
            ),
        ] else ...[
          // スタッフ効果サマリー
          if (staff.isNotEmpty) _StaffEffectSummary(state: state),

          // スタッフ採用ボタン
          if (state.employeeCount < state.maxEmployees)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ElevatedButton.icon(
                onPressed: ApCostCalculator.canAfford(
                        state.ap, state.config, ActionCategory.hiring)
                    ? () => _showStaffHiringDialog(context, ref)
                    : null,
                icon: const Icon(Icons.person_add, size: 18),
                label: Text(
                  'スタッフを採用する (AP${ApCostCalculator.cost(state.config, ActionCategory.hiring)})',
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  backgroundColor: AppColors.purple,
                ),
              ),
            ),

          // スタッフ一覧
          ...staff.map((emp) => EmployeeCard(
                employee: emp,
                onFire: () => _confirmFire(context, ref, emp),
                onTap: () => _showEmployeeDetail(context, ref, emp),
              )),

          if (staff.isEmpty)
            const _EmptyState(
              icon: Icons.people_outline,
              text: 'スタッフがいません\n営業・マーケター・バックオフィス・人事を\n採用してパッシブ効果を得ましょう',
            ),
        ],
      ],
    );
  }

  void _showHiringDialog(BuildContext context, WidgetRef ref) {
    final state = ref.read(gameProvider);
    final notifier = ref.read(gameProvider.notifier);
    final candidates = EmployeeEngine.generateCandidates(3);
    final hrDiscount = StaffBonusEngine.hrHiringDiscount(state);

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
          minChildSize: 0.5,
          expand: false,
          builder: (_, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '採用候補',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        '所持金: ${state.money}万円',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.money,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hrDiscount > 0
                        ? '採用費用: 月給の2ヶ月分（HR割引 ${(hrDiscount * 100).toStringAsFixed(0)}% OFF）'
                        : '採用費用: 月給の2ヶ月分',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: candidates.map((candidate) {
                        final hiringCost =
                            (candidate.salary * 2 * (1.0 - hrDiscount))
                                .round();
                        final canAfford = state.money >= hiringCost;
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                EmployeeCard(
                                  employee: candidate,
                                  compact: true,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '採用費用: ${hiringCost}万円',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: canAfford
                                              ? AppColors.orange
                                              : AppColors.red,
                                        ),
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: canAfford
                                          ? () {
                                              notifier
                                                  .hireEmployee(candidate);
                                              Navigator.pop(ctx);
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                      '${candidate.name}を採用しました！'),
                                                  backgroundColor:
                                                      AppColors.greenDark,
                                                  duration: const Duration(
                                                      seconds: 2),
                                                ),
                                              );
                                            }
                                          : null,
                                      child: Text(
                                        canAfford ? '採用' : '資金不足',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
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

  void _showStaffHiringDialog(BuildContext context, WidgetRef ref) {
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
          minChildSize: 0.5,
          expand: false,
          builder: (_, scrollController) {
            return _StaffHiringContent(scrollController: scrollController);
          },
        );
      },
    );
  }

  void _confirmFire(BuildContext context, WidgetRef ref, Employee emp) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('解雇確認'),
        content: Text(
          '${emp.name}を解雇しますか？\n退職金として${emp.salary}万円が必要です。\n信頼度が-2されます。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              ref.read(gameProvider.notifier).fireEmployee(emp.id);
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: const Text('解雇する'),
          ),
        ],
      ),
    );
  }

  void _showEmployeeDetail(
      BuildContext context, WidgetRef ref, Employee emp) {
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
              EmployeeCard(employee: emp),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (emp.isAssigned)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          ref
                              .read(gameProvider.notifier)
                              .unassignEmployee(emp.id);
                          Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('アサイン解除'),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _confirmFire(context, ref, emp);
                      },
                      icon: const Icon(Icons.person_remove, size: 16),
                      label: const Text('解雇'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.red,
                        side: const BorderSide(color: AppColors.red),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// スタッフ職種選択 → 候補表示
class _StaffHiringContent extends ConsumerStatefulWidget {
  const _StaffHiringContent({required this.scrollController});

  final ScrollController scrollController;

  @override
  ConsumerState<_StaffHiringContent> createState() =>
      _StaffHiringContentState();
}

class _StaffHiringContentState extends ConsumerState<_StaffHiringContent> {
  EmployeeType? _selectedType;
  List<Employee> _candidates = [];

  static const _staffTypes = [
    EmployeeType.sales,
    EmployeeType.marketer,
    EmployeeType.backOffice,
    EmployeeType.hr,
  ];

  void _selectType(EmployeeType type) {
    setState(() {
      _selectedType = type;
      _candidates =
          ref.read(gameProvider.notifier).getStaffCandidates(type);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gameProvider);
    final notifier = ref.read(gameProvider.notifier);
    final hrDiscount = StaffBonusEngine.hrHiringDiscount(state);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'スタッフ採用',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                '所持金: ${state.money}万円',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.money,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '職種を選んで候補を確認',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),

          // 職種選択チップ
          Wrap(
            spacing: 8,
            children: _staffTypes.map((type) {
              final isSelected = _selectedType == type;
              final (color, effectDesc) = switch (type) {
                EmployeeType.sales => (
                    AppColors.blue,
                    '報酬+5%/人, 信頼度+1/人'
                  ),
                EmployeeType.marketer => (
                    AppColors.purple,
                    'SaaS成長+2%/人, 解約-0.5%/人'
                  ),
                EmployeeType.backOffice => (
                    AppColors.orange,
                    '経費-3%/人, 2人でAP+1'
                  ),
                EmployeeType.hr => (
                    AppColors.cyan,
                    '採用費-20%/人, 幸福+3, 忠誠+2'
                  ),
                _ => (AppColors.textSecondary, ''),
              };
              return ActionChip(
                label: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(type.label),
                    Text(effectDesc,
                        style: TextStyle(
                            fontSize: 9,
                            color: isSelected ? Colors.white : color)),
                  ],
                ),
                backgroundColor:
                    isSelected ? color : color.withValues(alpha: 0.15),
                side: BorderSide(color: color.withValues(alpha: 0.5)),
                onPressed: () => _selectType(type),
              );
            }).toList(),
          ),

          const SizedBox(height: 12),

          // 候補一覧
          if (_candidates.isNotEmpty)
            Expanded(
              child: ListView(
                controller: widget.scrollController,
                children: _candidates.map((candidate) {
                  final hiringCost =
                      (candidate.salary * 2 * (1.0 - hrDiscount)).round();
                  final canAfford = state.money >= hiringCost;
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${candidate.name} (${candidate.type.label})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '月給: ${candidate.salary}万円 / 採用費: ${hiringCost}万円',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: canAfford
                                        ? AppColors.textSecondary
                                        : AppColors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: canAfford
                                ? () {
                                    notifier.hireStaff(candidate);
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            '${candidate.name}を採用しました！'),
                                        backgroundColor: AppColors.greenDark,
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                : null,
                            child: Text(
                              canAfford ? '採用' : '資金不足',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            )
          else if (_selectedType == null)
            const Expanded(
              child: Center(
                child: Text(
                  '職種を選択してください',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// スタッフ効果サマリーカード
class _StaffEffectSummary extends StatelessWidget {
  const _StaffEffectSummary({required this.state});

  final dynamic state;

  @override
  Widget build(BuildContext context) {
    final counts = StaffBonusEngine.staffCounts(state);
    final effects = <String>[];

    final salesCount = counts[EmployeeType.sales] ?? 0;
    if (salesCount > 0) {
      effects.add('営業x$salesCount: 報酬+${salesCount * 5}%, 信頼度+$salesCount/完了');
    }

    final marketerCount = counts[EmployeeType.marketer] ?? 0;
    if (marketerCount > 0) {
      effects.add(
          'マーケターx$marketerCount: SaaS成長+${marketerCount * 2}%, 解約-${(marketerCount * 0.5).toStringAsFixed(1)}%');
    }

    final boCount = counts[EmployeeType.backOffice] ?? 0;
    if (boCount > 0) {
      final expRed = (boCount * 3).clamp(0, 15);
      final apBonus = boCount ~/ 2;
      effects.add(
          'バックオフィスx$boCount: 経費-$expRed%${apBonus > 0 ? ', AP+$apBonus' : ''}');
    }

    final hrCount = counts[EmployeeType.hr] ?? 0;
    if (hrCount > 0) {
      final discount = (hrCount * 20).clamp(0, 60);
      effects.add(
          '人事x$hrCount: 採用費-$discount%, 幸福+${hrCount * 3}, 忠誠+${hrCount * 2}/ターン');
    }

    if (effects.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        color: AppColors.purple.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_awesome, size: 16, color: AppColors.purple),
                  SizedBox(width: 4),
                  Text(
                    'パッシブ効果',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.purple,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ...effects.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      e,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.green.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.green : AppColors.border,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? AppColors.green : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
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
