import 'package:flutter_test/flutter_test.dart';

import 'bot_strategy.dart';
import 'game_simulator.dart';

void main() {
  const iterations = 100;

  test('Monte Carlo balance simulation', () {
    final bots = <BotStrategy>[
      GreedyBot(),
      SafeBot(),
      GrowthBot(),
      SaaSBot(),
    ];

    final allResults = <String, List<SimulationResult>>{};

    for (final bot in bots) {
      final results = GameSimulator.runMonteCarlo(bot, iterations);
      GameSimulator.printStats(bot.name, results);
      allResults[bot.name] = results;
    }

    // 全bot比較テーブル
    GameSimulator.printComparison(allResults);
  });
}
