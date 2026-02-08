import 'dart:math';

import 'game_state.dart';
import 'models/server.dart';

/// サーバー負荷/障害判定エンジン
class InfraEngine {
  static final _random = Random();

  /// ターン終了時のサーバー状態更新
  static GameState processServers(GameState state) {
    final log = <String>[];
    final updatedServers = <Server>[];

    // SaaSユーザーに基づく負荷を分配
    final totalUsers = state.totalSaasUsers;
    final activeServers =
        state.servers.where((s) => !s.isDown).toList();
    final userPerServer = activeServers.isEmpty
        ? 0
        : totalUsers ~/ activeServers.length;

    for (final server in state.servers) {
      var updated = server;

      if (server.isDown) {
        // 障害復旧判定（30%の確率で復旧）
        if (_random.nextDouble() < 0.3) {
          updated = updated.copyWith(isDown: false, currentLoad: 0);
          log.add('${server.name}が復旧しました。');
        } else {
          updatedServers.add(updated);
          continue;
        }
      }

      // 負荷更新
      updated = updated.copyWith(currentLoad: userPerServer);

      // 障害発生判定
      if (_random.nextDouble() < updated.failureProbability) {
        updated = updated.copyWith(isDown: true);
        log.add('${server.name}で障害が発生しました！');

        // SaaSユーザーの信頼低下
        if (state.totalSaasUsers > 0) {
          log.add('サーバー障害によりユーザーの信頼が低下しています。');
        }
      } else if (updated.isHighLoad) {
        log.add('${server.name}の負荷が高くなっています (${(updated.loadRate * 100).toStringAsFixed(0)}%)');
      }

      updatedServers.add(updated);
    }

    // サーバー障害中のSaaSへの影響
    final anyDown = updatedServers.any((s) => s.isDown);
    var trustDelta = 0;
    if (anyDown && state.totalSaasUsers > 0) {
      trustDelta = -3;
    }

    return state.copyWith(
      servers: updatedServers,
      trust: (state.trust + trustDelta).clamp(0, 100),
      turnLog: [...state.turnLog, ...log],
    );
  }

  /// サーバー購入
  static GameState purchaseServer(GameState state, Server server) {
    // 初期費用は月額の3ヶ月分
    final purchaseCost = server.monthlyCost * 3;
    if (state.money < purchaseCost) {
      return state.copyWith(
        turnLog: [
          ...state.turnLog,
          'サーバー購入費用（${purchaseCost}万円）が不足しています。',
        ],
      );
    }

    return state.copyWith(
      servers: [...state.servers, server],
      money: state.money - purchaseCost,
      turnLog: [
        ...state.turnLog,
        '${server.name}を導入しました！ -${purchaseCost}万円 (月額: ${server.monthlyCost}万円)',
      ],
    );
  }

  /// サーバー撤去
  static GameState removeServer(GameState state, String serverId) {
    return state.copyWith(
      servers: state.servers.where((s) => s.id != serverId).toList(),
      turnLog: [
        ...state.turnLog,
        'サーバーを撤去しました。',
      ],
    );
  }

  /// 購入可能なサーバー一覧
  static List<Server> getAvailableServers() {
    return const [
      Server(
        id: 'shared_1',
        name: '共有レンタルサーバー',
        tier: ServerTier.shared,
        capacity: 100,
        monthlyCost: 1,
        reliability: 90.0,
      ),
      Server(
        id: 'vps_1',
        name: 'VPS スタンダード',
        tier: ServerTier.vps,
        capacity: 500,
        monthlyCost: 3,
        reliability: 95.0,
      ),
      Server(
        id: 'vps_2',
        name: 'VPS プレミアム',
        tier: ServerTier.vps,
        capacity: 1000,
        monthlyCost: 5,
        reliability: 97.0,
      ),
      Server(
        id: 'dedicated_1',
        name: '専用サーバー',
        tier: ServerTier.dedicated,
        capacity: 3000,
        monthlyCost: 15,
        reliability: 98.0,
      ),
      Server(
        id: 'cloud_1',
        name: 'クラウド (AWS)',
        tier: ServerTier.cloud,
        capacity: 10000,
        monthlyCost: 30,
        reliability: 99.5,
      ),
      Server(
        id: 'enterprise_1',
        name: 'エンタープライズクラウド',
        tier: ServerTier.enterprise,
        capacity: 50000,
        monthlyCost: 100,
        reliability: 99.9,
      ),
    ];
  }
}
