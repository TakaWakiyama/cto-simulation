import 'models/ceo_background.dart';
import 'models/game_config.dart';

/// アクションのAPコストを動的に計算するユーティリティ
class ApCostCalculator {
  /// アクションのAPコストを返す（1 or 2）
  static int cost(GameConfig config, ActionCategory action) {
    if (config.background == null) return 1;
    return BackgroundProfile.of(config.background!).apCost(action);
  }

  /// 現在のAPで実行可能かどうか
  static bool canAfford(int ap, GameConfig config, ActionCategory action) {
    return ap >= cost(config, action);
  }

  /// 得意カテゴリの場合の効果倍率（1.0 or 1.10~1.15）
  static double proficiencyMultiplier(
      GameConfig config, ActionCategory action) {
    if (config.background == null) return 1.0;
    final profile = BackgroundProfile.of(config.background!);
    if (profile.isProficient(action)) {
      return 1.0 + profile.specialEffectValue;
    }
    return 1.0;
  }
}
