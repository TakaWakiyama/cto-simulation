import 'dart:math';

import 'game_state.dart';
import 'models/saas_product.dart';
import 'staff_bonus_engine.dart';

/// SaaSユーザー増減/解約率計算エンジン
class SaaSEngine {
  static final _random = Random();

  /// ターン終了時のSaaS状態更新
  static GameState processSaaS(GameState state) {
    final log = <String>[];
    final updatedProducts = <SaaSProduct>[];
    var trustBonus = 0;

    for (final product in state.saasProducts) {
      var updated = product;

      if (product.isLaunched) {
        // マーケターボーナス適用
        final growthBonus = StaffBonusEngine.marketerGrowthBonus(state);
        final churnReduction = StaffBonusEngine.marketerChurnReduction(state);

        // 一時的に成長率/解約率を調整して計算
        var boosted = updated;
        if (growthBonus > 0 || churnReduction > 0) {
          boosted = boosted.copyWith(
            growthRate: boosted.growthRate + growthBonus,
            churnRate: (boosted.churnRate - churnReduction).clamp(0.5, 50.0),
          );
        }

        // ユーザー増減の計算
        final newUsers = boosted.calculateNewUsers();
        final randomVariation =
            (_random.nextInt(20) - 10); // ±10のランダム変動

        final totalNewUsers = newUsers + randomVariation;
        final nextUsers =
            (product.totalUsers + totalNewUsers).clamp(0, 999999);

        updated = updated.copyWith(totalUsers: nextUsers);

        if (totalNewUsers > 0) {
          log.add('${product.name}: ユーザー +$totalNewUsers (計${nextUsers}人)');
        } else if (totalNewUsers < 0) {
          log.add('${product.name}: ユーザー $totalNewUsers (計${nextUsers}人)');
        }

        // SaaSユーザー規模に応じた信頼度ボーナス（毎ターン）
        if (nextUsers >= 1000) {
          trustBonus += 1; // 1000人以上で毎ターン+1
        }

        // ユーザー数マイルストーンで追加信頼度ボーナス
        final milestones = [200, 500, 1000, 3000, 10000];
        for (final milestone in milestones) {
          if (nextUsers >= milestone && product.totalUsers < milestone) {
            trustBonus += 3;
            log.add('${product.name}がユーザー${milestone}人を突破！ 信頼度+3');
          }
        }

        // 品質が低いと解約率上昇
        if (updated.quality < 30) {
          updated = updated.copyWith(
            churnRate: (updated.churnRate + 1.0).clamp(0, 50),
          );
          log.add('${product.name}の品質が低く、解約率が上昇しています。');
        }
      } else if (!product.isDevelopmentComplete) {
        // 開発中の場合は進捗を計算
        final devEmployees = state.employees
            .where((e) => e.assignedProjectId == product.id);

        if (devEmployees.isNotEmpty) {
          final totalWork = devEmployees.fold(
              0.0, (sum, e) => sum + e.productivity);
          final workDone = (totalWork / 10).round();

          updated = updated.copyWith(
            developmentProgress:
                (updated.developmentProgress + workDone)
                    .clamp(0, updated.totalDevelopmentWork),
          );

          log.add(
              '${product.name} 開発進捗: ${(updated.developmentRate * 100).toStringAsFixed(0)}%');

          if (updated.isDevelopmentComplete) {
            log.add('${product.name}の開発が完了しました！リリース可能です。');
          }
        }
      }

      updatedProducts.add(updated);
    }

    return state.copyWith(
      saasProducts: updatedProducts,
      trust: (state.trust + trustBonus).clamp(0, 100),
      turnLog: [...state.turnLog, ...log],
    );
  }

  /// SaaS製品のリリース
  static GameState launchProduct(GameState state, String productId) {
    if (state.totalServerCapacity <= 0) {
      return state.copyWith(
        turnLog: [
          ...state.turnLog,
          'サーバーがありません。SaaSをリリースするにはサーバーが必要です。',
        ],
      );
    }

    final updatedProducts = state.saasProducts.map((p) {
      if (p.id == productId && p.isDevelopmentComplete) {
        return p.copyWith(
          isLaunched: true,
          growthRate: 10.0, // 初期成長率
          totalUsers: 50, // 初期ユーザー
        );
      }
      return p;
    }).toList();

    final product = updatedProducts.firstWhere((p) => p.id == productId);

    return state.copyWith(
      saasProducts: updatedProducts,
      trust: (state.trust + 5).clamp(0, 100),
      turnLog: [
        ...state.turnLog,
        '${product.name}をリリースしました！ 初期ユーザー: 100人 (信頼度+5)',
      ],
    );
  }

  /// SaaS製品の品質改善
  static GameState improveQuality(
    GameState state,
    String productId,
    int amount,
  ) {
    final updatedProducts = state.saasProducts.map((p) {
      if (p.id == productId) {
        return p.copyWith(
          quality: (p.quality + amount).clamp(0, 100),
          churnRate: (p.churnRate - amount * 0.5).clamp(1.0, 50.0),
        );
      }
      return p;
    }).toList();

    return state.copyWith(
      saasProducts: updatedProducts,
      turnLog: [
        ...state.turnLog,
        'SaaS品質を改善しました (+$amount)',
      ],
    );
  }

  /// 利用可能なSaaS製品テンプレート
  static List<SaaSProduct> getAvailableProducts() {
    return const [
      SaaSProduct(
        id: 'saas_pm',
        name: 'TaskFlow',
        category: SaaSCategory.projectManagement,
        monthlyPricePerUser: 1500,
        developmentCost: 400,
        requiredTechLevel: 1,
        totalDevelopmentWork: 80,
        monthlyMaintenanceCost: 5,
      ),
      SaaSProduct(
        id: 'saas_crm',
        name: 'CustLink',
        category: SaaSCategory.crm,
        monthlyPricePerUser: 2500,
        developmentCost: 250,
        requiredTechLevel: 2,
        totalDevelopmentWork: 50,
        monthlyMaintenanceCost: 10,
      ),
      SaaSProduct(
        id: 'saas_analytics',
        name: 'DataPulse',
        category: SaaSCategory.analytics,
        monthlyPricePerUser: 3500,
        developmentCost: 400,
        requiredTechLevel: 3,
        totalDevelopmentWork: 80,
        monthlyMaintenanceCost: 15,
      ),
      SaaSProduct(
        id: 'saas_comm',
        name: 'ChatSync',
        category: SaaSCategory.communication,
        monthlyPricePerUser: 800,
        developmentCost: 150,
        requiredTechLevel: 2,
        totalDevelopmentWork: 40,
        monthlyMaintenanceCost: 8,
      ),
      SaaSProduct(
        id: 'saas_erp',
        name: 'BizCore',
        category: SaaSCategory.erp,
        monthlyPricePerUser: 5000,
        developmentCost: 600,
        requiredTechLevel: 4,
        totalDevelopmentWork: 120,
        monthlyMaintenanceCost: 30,
      ),
      SaaSProduct(
        id: 'saas_security',
        name: 'ShieldGuard',
        category: SaaSCategory.security,
        monthlyPricePerUser: 4500,
        developmentCost: 500,
        requiredTechLevel: 4,
        totalDevelopmentWork: 100,
        monthlyMaintenanceCost: 20,
      ),
    ];
  }
}
