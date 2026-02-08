import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/ceo_background.dart';
import '../../core/models/game_config.dart';
import '../../state/game_notifier.dart';
import '../theme/app_colors.dart';
import 'main_dashboard.dart';

class TitleScreen extends ConsumerWidget {
  const TitleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0D1117),
              Color(0xFF161B22),
              Color(0xFF0D1117),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),

                  // タイトルロゴ
                  const Icon(
                    Icons.terminal,
                    size: 64,
                    color: AppColors.green,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'CTO',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: AppColors.green,
                      letterSpacing: 12,
                    ),
                  ),
                  const Text(
                    'SIMULATOR',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w300,
                      color: AppColors.textSecondary,
                      letterSpacing: 8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'システム開発企業 経営シミュレーション',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),

                  const SizedBox(height: 48),

                  // ターミナル風メニュー
                  _TerminalLine(
                    prefix: '\$ ',
                    text: 'start --new-game',
                    onTap: () => _showDifficultySelect(context, ref),
                  ),

                  const SizedBox(height: 64),

                  // バージョン情報
                  const Text(
                    'v0.2.0 - Phase 1: Reality Update',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textMuted,
                    ),
                  ),

                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDifficultySelect(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '難易度を選択',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...Difficulty.values.map((difficulty) {
                return _DifficultyOption(
                  difficulty: difficulty,
                  onTap: () {
                    Navigator.pop(ctx);
                    _showBackgroundSelect(context, ref, difficulty);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showBackgroundSelect(
    BuildContext context,
    WidgetRef ref,
    Difficulty difficulty,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (_, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CEOのバックグラウンドを選択',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '得意分野は1AP、不得意分野は2APを消費します',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: CeoBackground.values.map((bg) {
                        return _BackgroundOption(
                          background: bg,
                          onTap: () {
                            Navigator.pop(ctx);
                            _startGame(context, ref, difficulty, bg);
                          },
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

  void _startGame(
    BuildContext context,
    WidgetRef ref,
    Difficulty difficulty,
    CeoBackground background,
  ) {
    ref.read(gameProvider.notifier).startNewGame(
          GameConfig(difficulty: difficulty, background: background),
        );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainDashboard()),
    );
  }
}

class _TerminalLine extends StatelessWidget {
  const _TerminalLine({
    required this.prefix,
    required this.text,
    required this.onTap,
  });

  final String prefix;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Text(
              prefix,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.green,
                fontFamily: 'JetBrainsMono',
              ),
            ),
            Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textPrimary,
                fontFamily: 'JetBrainsMono',
              ),
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios,
                size: 14, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _DifficultyOption extends StatelessWidget {
  const _DifficultyOption({
    required this.difficulty,
    required this.onTap,
  });

  final Difficulty difficulty;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (color, desc) = switch (difficulty) {
      Difficulty.easy => (
          AppColors.green,
          '報酬1.5倍 / イベント軽減。初めてのプレイにおすすめ。'
        ),
      Difficulty.normal => (
          AppColors.blue,
          '標準的なバランス。プログラミング経験者向け。'
        ),
      Difficulty.hard => (
          AppColors.orange,
          '報酬0.7倍 / イベント過酷。シビアな経営判断が必要。'
        ),
      Difficulty.nightmare => (
          AppColors.red,
          '報酬0.5倍 / イベント極悪。デスマーチを生き延びろ。'
        ),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                difficulty.label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                desc,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackgroundOption extends StatelessWidget {
  const _BackgroundOption({
    required this.background,
    required this.onTap,
  });

  final CeoBackground background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final profile = BackgroundProfile.of(background);
    final proficient = profile.proficientCategories
        .map((c) => c.label)
        .join(', ');

    final (color, icon) = switch (background) {
      CeoBackground.engineer => (AppColors.green, Icons.code),
      CeoBackground.sales => (AppColors.blue, Icons.handshake),
      CeoBackground.marketer => (AppColors.purple, Icons.campaign),
      CeoBackground.backOffice => (AppColors.orange, Icons.account_balance),
      CeoBackground.studentEntrepreneur => (AppColors.cyan, Icons.school),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      background.label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      background.description,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.green.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '得意: $proficient',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.green,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.cyan.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            profile.specialEffect,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.cyan,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
