import 'dart:math';

import 'game_state.dart';
import 'models/employee_type.dart';

/// 非エンジニア社員のパッシブ効果を計算するエンジン
class StaffBonusEngine {
  /// 職種別の人数を取得
  static Map<EmployeeType, int> staffCounts(GameState state) {
    final counts = <EmployeeType, int>{};
    for (final emp in state.employees) {
      counts[emp.type] = (counts[emp.type] ?? 0) + 1;
    }
    return counts;
  }

  /// 営業による受託報酬ボーナス倍率（1人あたり+5%）
  static double salesRewardMultiplier(GameState state) {
    final count = staffCounts(state)[EmployeeType.sales] ?? 0;
    return 1.0 + count * 0.05;
  }

  /// 営業による信頼度ゲインボーナス（1人あたり+1）
  static int salesTrustBonus(GameState state) {
    return staffCounts(state)[EmployeeType.sales] ?? 0;
  }

  /// マーケターによるSaaS成長率ボーナス（1人あたり+2%）
  static double marketerGrowthBonus(GameState state) {
    final count = staffCounts(state)[EmployeeType.marketer] ?? 0;
    return count * 2.0;
  }

  /// マーケターによる解約率削減（1人あたり-0.5%）
  static double marketerChurnReduction(GameState state) {
    final count = staffCounts(state)[EmployeeType.marketer] ?? 0;
    return count * 0.5;
  }

  /// バックオフィスによる経費削減率（1人あたり-3%, max -15%）
  static double backOfficeExpenseReduction(GameState state) {
    final count = staffCounts(state)[EmployeeType.backOffice] ?? 0;
    return min(count * 0.03, 0.15);
  }

  /// バックオフィスによるAP追加（2人ごとに+1）
  static int backOfficeApBonus(GameState state) {
    final count = staffCounts(state)[EmployeeType.backOffice] ?? 0;
    return count ~/ 2;
  }

  /// 人事による採用コスト割引率（1人あたり-20%, max -60%）
  static double hrHiringDiscount(GameState state) {
    final count = staffCounts(state)[EmployeeType.hr] ?? 0;
    return min(count * 0.20, 0.60);
  }

  /// 人事による幸福度ボーナス（全社員に+3/ターン）
  static int hrHappinessBonus(GameState state) {
    final count = staffCounts(state)[EmployeeType.hr] ?? 0;
    return count * 3;
  }

  /// 人事による忠誠度ボーナス（全社員に+2/ターン）
  static int hrLoyaltyBonus(GameState state) {
    final count = staffCounts(state)[EmployeeType.hr] ?? 0;
    return count * 2;
  }
}
