import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/event.dart';
import '../../state/game_notifier.dart';
import '../theme/app_colors.dart';

class EventDialog extends ConsumerWidget {
  const EventDialog({super.key, required this.event});

  final GameEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(gameProvider.notifier);

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // イベントタイプアイコン
            Row(
              children: [
                _typeIcon(event.type),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    event.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 説明
            Text(
              event.description,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            // 選択肢
            ...event.choices.map((choice) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        notifier.resolveEvent(choice);
                        Navigator.of(context).pop();
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(12),
                        alignment: Alignment.centerLeft,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            choice.text,
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (choice.cost > 0)
                                _EffectChip(
                                  text: '-${choice.cost}万円',
                                  color: AppColors.red,
                                ),
                              if (choice.apCost > 0)
                                _EffectChip(
                                  text: '-${choice.apCost}AP',
                                  color: AppColors.orange,
                                ),
                              ...choice.effects.entries.map((e) {
                                final value = e.value is int
                                    ? e.value as int
                                    : (e.value as num).toInt();
                                return _EffectChip(
                                  text:
                                      '${_effectLabel(e.key)}: ${value > 0 ? '+' : ''}$value',
                                  color: value > 0
                                      ? AppColors.green
                                      : AppColors.red,
                                );
                              }),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _typeIcon(EventType type) {
    final (icon, color) = switch (type) {
      EventType.opportunity => (Icons.star, AppColors.yellow),
      EventType.crisis => (Icons.warning, AppColors.red),
      EventType.market => (Icons.trending_up, AppColors.green),
      EventType.employee => (Icons.people, AppColors.purple),
      EventType.tech => (Icons.computer, AppColors.cyan),
    };

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  String _effectLabel(String key) => switch (key) {
        'money' => '資金',
        'trust' => '信頼度',
        'debt' => '負債',
        'allHappiness' => '全員幸福度',
        'allFatigue' => '全員疲労',
        _ => key,
      };
}

class _EffectChip extends StatelessWidget {
  const _EffectChip({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
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
