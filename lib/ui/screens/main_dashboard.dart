import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/game_state.dart';
import '../../state/game_notifier.dart';
import '../theme/app_colors.dart';
import '../widgets/resource_bar.dart';
import 'contract_tab.dart';
import 'employee_tab.dart';
import 'event_dialog.dart';
import 'finance_sheet.dart';
import 'infra_tab.dart';
import 'saas_tab.dart';
import 'tech_tree_screen.dart';
import 'turn_log_sheet.dart';
import 'tutorial_dialog.dart';

class MainDashboard extends ConsumerStatefulWidget {
  const MainDashboard({super.key});

  @override
  ConsumerState<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends ConsumerState<MainDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _showGuide = true;
  bool _tutorialShown = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    // 初回チュートリアル表示
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(gameProvider);
      if (state.currentTurn == 1 && !_tutorialShown) {
        _tutorialShown = true;
        _showGuide = false;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const TutorialDialog(),
        );
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gameProvider);
    final notifier = ref.read(gameProvider.notifier);

    // イベント発生時にダイアログを表示
    ref.listen(gameProvider, (prev, next) {
      if (next.pendingEvent != null &&
          (prev == null || prev.pendingEvent == null)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => EventDialog(event: next.pendingEvent!),
            );
          }
        });
      }

      if (next.isGameOver && (prev == null || !prev.isGameOver)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showGameOverDialog(context, next.gameOverReason ?? 'ゲーム終了');
          }
        });
      }
    });

    return Scaffold(
      body: Column(
        children: [
          const ResourceBar(),

          // ヒントバナー
          _HintBanner(
            state: state,
            showGuide: _showGuide,
            onDismissGuide: () => setState(() => _showGuide = false),
            onGoToTab: (index) => _tabController.animateTo(index),
          ),

          // タブバー
          Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(
                bottom: BorderSide(color: AppColors.border),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              tabs: [
                _buildTab(Icons.work_outline, '受託',
                    badge: state.availableProjects.length),
                _buildTab(Icons.cloud_outlined, 'SaaS',
                    badge: state.saasProducts
                        .where((p) => p.isDevelopmentComplete && !p.isLaunched)
                        .length),
                _buildTab(Icons.dns_outlined, 'インフラ',
                    badge: state.servers.where((s) => s.isDown).length,
                    badgeColor: AppColors.red),
                _buildTab(Icons.people_outline, '社員',
                    badge: state.employees
                        .where((e) => e.quitRisk > 0.3)
                        .length,
                    badgeColor: AppColors.orange),
              ],
              labelStyle: const TextStyle(fontSize: 11),
            ),
          ),

          // タブコンテンツ
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                ContractTab(),
                SaaSTab(),
                InfraTab(),
                EmployeeTab(),
              ],
            ),
          ),
        ],
      ),

      // 固定フッター
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          top: 8,
          bottom: MediaQuery.of(context).padding.bottom + 8,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(color: AppColors.border),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: state.isGameOver ? null : () => notifier.endTurn(),
                icon: const Icon(Icons.skip_next, size: 20),
                label: Text(
                  'ターン終了 (${state.currentTurn}/${state.config.maxTurns})',
                  style: const TextStyle(fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: AppColors.greenDark,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const TechTreeScreen()),
                  );
                },
                icon: const Icon(Icons.account_tree, size: 16),
                label: const Text('技術', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true,
                    builder: (_) => const FinanceSheet(),
                  );
                },
                icon: const Icon(Icons.account_balance_wallet, size: 16),
                label: const Text('資金', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true,
                    builder: (_) => const TurnLogSheet(),
                  );
                },
                icon: const Icon(Icons.terminal, size: 16),
                label: const Text('ログ', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(IconData icon, String label,
      {int badge = 0, Color badgeColor = AppColors.green}) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 4),
          Text(label),
          if (badge > 0) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$badge',
                style: const TextStyle(
                    fontSize: 9,
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showGameOverDialog(BuildContext context, String reason) {
    final state = ref.read(gameProvider);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              state.companyValue > 500 ? Icons.emoji_events : Icons.close,
              color: state.companyValue > 500
                  ? AppColors.yellow
                  : AppColors.red,
            ),
            const SizedBox(width: 8),
            const Text('ゲーム終了'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(reason),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            _resultRow('企業価値', '${state.companyValue}万円'),
            _resultRow('最終資金', '${state.money}万円'),
            _resultRow('負債', '${state.debt}万円'),
            _resultRow('信頼度', '${state.trust}'),
            _resultRow('社員数', '${state.employeeCount}名'),
            _resultRow('SaaSユーザー', '${state.totalSaasUsers}人'),
            _resultRow('総収入', '${state.totalEarned}万円'),
            _resultRow('総支出', '${state.totalSpent}万円'),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('タイトルに戻る'),
          ),
        ],
      ),
    );
  }

  Widget _resultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          Text(value,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

/// 状況に応じたヒントを表示するバナー
class _HintBanner extends StatelessWidget {
  const _HintBanner({
    required this.state,
    required this.showGuide,
    required this.onDismissGuide,
    required this.onGoToTab,
  });

  final GameState state;
  final bool showGuide;
  final VoidCallback onDismissGuide;
  final ValueChanged<int> onGoToTab;

  @override
  Widget build(BuildContext context) {
    // 状況に応じた警告ヒント
    final hint = _getContextualHint();
    if (hint == null) return const SizedBox.shrink();

    return _buildBanner(
      icon: hint.icon,
      color: hint.color,
      title: hint.title,
      subtitle: hint.subtitle,
      action: hint.tabIndex != null
          ? TextButton(
              onPressed: () => onGoToTab(hint.tabIndex!),
              child: Text(hint.actionLabel ?? '確認',
                  style: const TextStyle(fontSize: 12)),
            )
          : null,
    );
  }

  _HintData? _getContextualHint() {
    // サーバー障害
    if (state.servers.any((s) => s.isDown)) {
      return _HintData(
        icon: Icons.warning_amber_rounded,
        color: AppColors.red,
        title: 'サーバー障害が発生中！',
        subtitle: 'SaaSユーザーの信頼が低下しています',
        tabIndex: 2,
        actionLabel: 'インフラを確認',
      );
    }

    // 退職リスクの社員
    final atRisk = state.employees.where((e) => e.quitRisk > 0.3).length;
    if (atRisk > 0) {
      return _HintData(
        icon: Icons.sentiment_dissatisfied,
        color: AppColors.orange,
        title: '$atRisk名の社員が退職を検討中',
        subtitle: '幸福度を上げるか、負担を減らしましょう',
        tabIndex: 3,
        actionLabel: '社員を確認',
      );
    }

    // 案件がアサインされていない
    final unassigned = state.activeProjects
        .where((p) => p.assignedEmployeeIds.isEmpty)
        .length;
    if (unassigned > 0) {
      return _HintData(
        icon: Icons.person_add_alt,
        color: AppColors.blue,
        title: '$unassigned件の案件に社員がアサインされていません',
        subtitle: 'アサインしないと案件が進みません',
        tabIndex: 0,
        actionLabel: '受託を確認',
      );
    }

    // 案件の納期が近い
    final urgent = state.activeProjects
        .where((p) => p.remainingTurns(state.currentTurn) <= 2)
        .length;
    if (urgent > 0) {
      return _HintData(
        icon: Icons.timer_outlined,
        color: AppColors.red,
        title: '$urgent件の案件の納期が迫っています！',
        subtitle: '残り2ターン以内。社員を追加アサインしましょう',
        tabIndex: 0,
        actionLabel: '受託を確認',
      );
    }

    // 全員待機中なのに案件がある
    if (state.unassignedEmployees.length == state.employees.length &&
        state.activeProjects.isNotEmpty) {
      return _HintData(
        icon: Icons.coffee,
        color: AppColors.orange,
        title: '全員が待機中です',
        subtitle: '案件に社員をアサインして開発を進めましょう',
        tabIndex: 0,
        actionLabel: '受託を確認',
      );
    }

    // APが残っている
    if (state.ap == state.config.apPerTurn &&
        state.currentTurn > 1) {
      return _HintData(
        icon: Icons.bolt,
        color: AppColors.orange,
        title: 'APを使い切っていません',
        subtitle: '案件の受注、採用、サーバー購入などにAPを使えます',
      );
    }

    return null;
  }

  Widget _buildBanner({
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    Widget? action,
    VoidCallback? onDismiss,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(color: color.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: color),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
          if (action != null) action,
          if (onDismiss != null)
            GestureDetector(
              onTap: onDismiss,
              child: Icon(Icons.close, size: 16, color: color),
            ),
        ],
      ),
    );
  }
}

class _HintData {
  const _HintData({
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    this.tabIndex,
    this.actionLabel,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final int? tabIndex;
  final String? actionLabel;
}
