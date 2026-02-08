import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/contract_project.dart';
import '../theme/app_colors.dart';
import 'progress_bar.dart';

class ProjectCard extends StatelessWidget {
  const ProjectCard({
    super.key,
    required this.project,
    required this.currentTurn,
    this.onAccept,
    this.onAssign,
    this.onWork,
    this.onAbandon,
  });

  final ContractProject project;
  final int currentTurn;
  final VoidCallback? onAccept;
  final VoidCallback? onAssign;
  final VoidCallback? onWork;
  final VoidCallback? onAbandon;

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat('#,###');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー
            Row(
              children: [
                _typeIcon(project.type),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        project.clientName,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                _statusBadge(project.status),
              ],
            ),

            const SizedBox(height: 8),

            // 報酬と情報
            Row(
              children: [
                Icon(Icons.currency_yen, size: 14, color: AppColors.money),
                const SizedBox(width: 2),
                Text(
                  '${formatter.format(project.reward)}万',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.money,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.star_outline, size: 14, color: AppColors.orange),
                const SizedBox(width: 2),
                Text(
                  '必要スキル: ${project.requiredSkill}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),

            if (project.status == ProjectStatus.inProgress ||
                project.status == ProjectStatus.overdue) ...[
              const SizedBox(height: 8),

              // 進捗バー
              GameProgressBar(
                value: project.progress,
                label: '進捗',
                showPercentage: true,
                color: AppColors.blue,
              ),

              const SizedBox(height: 4),

              // 納期
              Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 14,
                    color: project.remainingTurns(currentTurn) <= 2
                        ? AppColors.red
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '納期: あと${project.remainingTurns(currentTurn)}ターン',
                    style: TextStyle(
                      fontSize: 11,
                      color: project.remainingTurns(currentTurn) <= 2
                          ? AppColors.red
                          : AppColors.textSecondary,
                      fontWeight: project.remainingTurns(currentTurn) <= 2
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.people_outline, size: 14,
                      color: AppColors.textSecondary),
                  const SizedBox(width: 2),
                  Text(
                    'アサイン: ${project.assignedEmployeeIds.length}名',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '品質: ${project.qualityScore}',
                    style: TextStyle(
                      fontSize: 11,
                      color: project.qualityScore >= 80
                          ? AppColors.green
                          : project.qualityScore >= 50
                              ? AppColors.orange
                              : AppColors.red,
                    ),
                  ),
                ],
              ),
            ],

            // アクションボタン
            const SizedBox(height: 8),
            Row(
              children: [
                if (onAccept != null &&
                    project.status == ProjectStatus.available)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onAccept,
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('受注する', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                if (onAssign != null &&
                    (project.status == ProjectStatus.inProgress ||
                        project.status == ProjectStatus.overdue)) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onAssign,
                      icon: const Icon(Icons.person_add, size: 16),
                      label: const Text('アサイン', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
                if (onAbandon != null &&
                    (project.status == ProjectStatus.inProgress ||
                        project.status == ProjectStatus.overdue)) ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: onAbandon,
                    icon: const Icon(Icons.cancel_outlined, size: 16,
                        color: AppColors.red),
                    label: const Text('破棄',
                        style: TextStyle(fontSize: 12, color: AppColors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.red),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeIcon(ProjectType type) {
    final (icon, color) = switch (type) {
      ProjectType.corporateSite => (Icons.web, AppColors.blue),
      ProjectType.ecSite => (Icons.shopping_cart, AppColors.green),
      ProjectType.webApp => (Icons.apps, AppColors.purple),
      ProjectType.mobileApp => (Icons.phone_android, AppColors.cyan),
      ProjectType.systemIntegration => (Icons.integration_instructions, AppColors.orange),
      ProjectType.api => (Icons.api, AppColors.yellow),
      ProjectType.aiProject => (Icons.psychology, AppColors.red),
    };

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }

  Widget _statusBadge(ProjectStatus status) {
    final (label, color) = switch (status) {
      ProjectStatus.available => ('募集中', AppColors.blue),
      ProjectStatus.inProgress => ('開発中', AppColors.green),
      ProjectStatus.completed => ('完了', AppColors.cyan),
      ProjectStatus.failed => ('失敗', AppColors.red),
      ProjectStatus.overdue => ('納期超過', AppColors.red),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}
