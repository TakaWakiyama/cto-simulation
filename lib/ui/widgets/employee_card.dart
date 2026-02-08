import 'package:flutter/material.dart';

import '../../core/models/employee.dart';
import '../theme/app_colors.dart';
import 'progress_bar.dart';

class EmployeeCard extends StatelessWidget {
  const EmployeeCard({
    super.key,
    required this.employee,
    this.onTap,
    this.onAssign,
    this.onUnassign,
    this.onOvertime,
    this.onFire,
    this.compact = false,
  });

  final Employee employee;
  final VoidCallback? onTap;
  final VoidCallback? onAssign;
  final VoidCallback? onUnassign;
  final VoidCallback? onOvertime;
  final VoidCallback? onFire;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ヘッダー
              Row(
                children: [
                  _roleIcon(employee.role),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          employee.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${employee.role.label} / ${employee.specialty.label}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${employee.salary}万/月',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.money,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              if (!compact) ...[
                const SizedBox(height: 8),

                // ステータスバー
                Row(
                  children: [
                    Expanded(
                      child: GameProgressBar(
                        value: employee.skill / 100,
                        label: 'スキル',
                        color: AppColors.blue,
                        height: 6,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GameProgressBar(
                        value: employee.fatigue / 100,
                        label: '疲労',
                        color: employee.fatigue > 70
                            ? AppColors.red
                            : employee.fatigue > 40
                                ? AppColors.orange
                                : AppColors.green,
                        height: 6,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: GameProgressBar(
                        value: employee.happiness / 100,
                        label: '幸福度',
                        color: employee.happiness < 30
                            ? AppColors.red
                            : AppColors.green,
                        height: 6,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '生産力',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            employee.productivity.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.cyan,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // アサイン状態
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: employee.isAssigned
                            ? AppColors.greenDark.withValues(alpha: 0.3)
                            : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: employee.isAssigned
                              ? AppColors.green
                              : AppColors.border,
                        ),
                      ),
                      child: Text(
                        employee.isAssigned ? 'アサイン中' : '待機中',
                        style: TextStyle(
                          fontSize: 10,
                          color: employee.isAssigned
                              ? AppColors.green
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    if (employee.quitRisk > 0.3) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.red.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.red),
                        ),
                        child: const Text(
                          '退職リスク',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.red,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (onAssign != null && !employee.isAssigned)
                      _ActionChip(
                        label: 'アサイン',
                        color: AppColors.blue,
                        onTap: onAssign!,
                      ),
                    if (onUnassign != null && employee.isAssigned)
                      _ActionChip(
                        label: '解除',
                        color: AppColors.orange,
                        onTap: onUnassign!,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _roleIcon(EmployeeRole role) {
    final (icon, color) = switch (role) {
      EmployeeRole.junior => (Icons.person_outline, AppColors.textSecondary),
      EmployeeRole.mid => (Icons.person, AppColors.blue),
      EmployeeRole.senior => (Icons.engineering, AppColors.purple),
      EmployeeRole.lead => (Icons.supervisor_account, AppColors.orange),
      EmployeeRole.architect => (Icons.architecture, AppColors.cyan),
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
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 11, color: color),
        ),
      ),
    );
  }
}
