import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/contract_project.dart';
import '../../state/game_notifier.dart';
import '../theme/app_colors.dart';
import '../widgets/project_card.dart';

class ContractTab extends ConsumerWidget {
  const ContractTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameProvider);
    final notifier = ref.read(gameProvider.notifier);

    final availableProjects = state.availableProjects;
    final activeProjects = state.activeProjects;
    final completedProjects = state.contractProjects
        .where((p) =>
            p.status == ProjectStatus.completed ||
            p.status == ProjectStatus.failed ||
            p.status == ProjectStatus.overdue)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // 進行中の案件
        if (activeProjects.isNotEmpty) ...[
          _SectionHeader(
            title: '進行中の案件',
            count: activeProjects.length,
            color: AppColors.green,
          ),
          ...activeProjects.map((project) => ProjectCard(
                project: project,
                currentTurn: state.currentTurn,
                onAssign: () => _showAssignDialog(context, ref, project),
              )),
          const SizedBox(height: 16),
        ],

        // 募集中の案件
        _SectionHeader(
          title: '募集中の案件',
          count: availableProjects.length,
          color: AppColors.blue,
          trailing: TextButton.icon(
            onPressed: state.ap > 0 ? () => notifier.refreshProjects() : null,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('更新', style: TextStyle(fontSize: 12)),
          ),
        ),
        if (availableProjects.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text(
                '現在募集中の案件はありません\n案件を更新してください',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          )
        else
          ...availableProjects.map((project) => ProjectCard(
                project: project,
                currentTurn: state.currentTurn,
                onAccept: state.ap > 0
                    ? () => notifier.acceptProject(project.id)
                    : null,
              )),

        // 完了済み
        if (completedProjects.isNotEmpty) ...[
          const SizedBox(height: 16),
          _SectionHeader(
            title: '完了済み',
            count: completedProjects.length,
            color: AppColors.textSecondary,
          ),
          ...completedProjects.map((project) => ProjectCard(
                project: project,
                currentTurn: state.currentTurn,
              )),
        ],
      ],
    );
  }

  void _showAssignDialog(
    BuildContext context,
    WidgetRef ref,
    ContractProject project,
  ) {
    final state = ref.read(gameProvider);
    final notifier = ref.read(gameProvider.notifier);
    final unassigned = state.unassignedEmployees;

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
                '${project.name}にアサイン',
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
                    '待機中の社員がいません',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              else
                ...unassigned.map((emp) => ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text(emp.name),
                      subtitle: Text(
                        '${emp.role.label} / スキル: ${emp.skill} / 生産力: ${emp.productivity.toStringAsFixed(1)}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      onTap: () {
                        notifier.assignEmployee(project.id, emp.id);
                        Navigator.pop(ctx);
                      },
                    )),
              // アサイン済み社員の解除
              if (project.assignedEmployeeIds.isNotEmpty) ...[
                const Divider(),
                const Text(
                  'アサイン済み（タップで解除）',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                ...project.assignedEmployeeIds.map((empId) {
                  final emp =
                      state.employees.where((e) => e.id == empId).firstOrNull;
                  if (emp == null) return const SizedBox.shrink();
                  return ListTile(
                    leading:
                        const Icon(Icons.person, color: AppColors.green),
                    title: Text(emp.name),
                    trailing: const Icon(Icons.close, size: 16,
                        color: AppColors.red),
                    onTap: () {
                      notifier.unassignEmployee(empId);
                      Navigator.pop(ctx);
                    },
                  );
                }),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
    required this.color,
    this.trailing,
  });

  final String title;
  final int count;
  final Color color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
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
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: TextStyle(fontSize: 10, color: color),
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
