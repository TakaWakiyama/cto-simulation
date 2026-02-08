import 'game_state.dart';
import 'models/technology.dart';

/// テクノロジーツリー解禁判定エンジン
class TechTreeEngine {
  /// 技術研究の開始
  static GameState startResearch(GameState state, String techId) {
    final tech = state.technologies.firstWhere((t) => t.id == techId);

    if (!tech.canResearch(state.unlockedTechIds)) {
      return state.copyWith(
        turnLog: [
          ...state.turnLog,
          '前提技術が未解禁のため、研究を開始できません。',
        ],
      );
    }

    if (state.money < tech.researchCost) {
      return state.copyWith(
        turnLog: [
          ...state.turnLog,
          '研究費用（${tech.researchCost}万円）が不足しています。',
        ],
      );
    }

    final updatedTechs = state.technologies.map((t) {
      if (t.id == techId) {
        return t.copyWith(currentResearchProgress: 1);
      }
      return t;
    }).toList();

    return state.copyWith(
      technologies: updatedTechs,
      money: state.money - tech.researchCost,
      turnLog: [
        ...state.turnLog,
        '${tech.name}の研究を開始しました。 -${tech.researchCost}万円',
      ],
    );
  }

  /// ターン終了時の研究進捗
  static GameState processResearch(GameState state) {
    final log = <String>[];

    final updatedTechs = state.technologies.map((tech) {
      if (!tech.isResearching) return tech;

      var updated = tech.copyWith(
        currentResearchProgress: tech.currentResearchProgress + 1,
      );

      if (updated.isResearchComplete) {
        updated = updated.copyWith(isUnlocked: true);
        log.add('${tech.name}の研究が完了しました！');
        if (tech.productivityBonus > 0) {
          log.add('生産性 +${tech.productivityBonus}%');
        }
        if (tech.qualityBonus > 0) {
          log.add('品質 +${tech.qualityBonus}%');
        }
      } else {
        log.add(
            '${tech.name} 研究中... (${updated.currentResearchProgress}/${tech.researchTurns})');
      }

      return updated;
    }).toList();

    return state.copyWith(
      technologies: updatedTechs,
      turnLog: [...state.turnLog, ...log],
    );
  }

  /// 初期テクノロジーツリー
  static List<Technology> getDefaultTechTree() {
    return const [
      // Tier 1 - 基礎
      Technology(
        id: 'tech_html_css',
        name: 'HTML/CSS',
        category: TechCategory.language,
        description: 'Web開発の基礎。フロントエンド開発が可能になる。',
        researchCost: 10,
        researchTurns: 2,
        isUnlocked: true, // 初期解禁
        productivityBonus: 5,
      ),
      Technology(
        id: 'tech_javascript',
        name: 'JavaScript',
        category: TechCategory.language,
        description: 'Webアプリに動的な機能を追加できる。',
        researchCost: 20,
        researchTurns: 3,
        prerequisites: ['tech_html_css'],
        productivityBonus: 10,
      ),
      Technology(
        id: 'tech_git',
        name: 'Git/バージョン管理',
        category: TechCategory.devops,
        description: 'コードのバージョン管理。チーム開発の効率が向上。',
        researchCost: 15,
        researchTurns: 2,
        isUnlocked: true, // 初期解禁
        productivityBonus: 8,
        qualityBonus: 5,
      ),

      // Tier 2 - 中級
      Technology(
        id: 'tech_react',
        name: 'React',
        category: TechCategory.framework,
        description: 'モダンなフロントエンドフレームワーク。',
        researchCost: 40,
        researchTurns: 4,
        prerequisites: ['tech_javascript'],
        productivityBonus: 15,
        qualityBonus: 10,
      ),
      Technology(
        id: 'tech_nodejs',
        name: 'Node.js',
        category: TechCategory.framework,
        description: 'サーバーサイドJavaScript。フルスタック開発が可能に。',
        researchCost: 35,
        researchTurns: 4,
        prerequisites: ['tech_javascript'],
        productivityBonus: 12,
      ),
      Technology(
        id: 'tech_docker',
        name: 'Docker',
        category: TechCategory.devops,
        description: 'コンテナ技術。開発環境の統一とデプロイの効率化。',
        researchCost: 30,
        researchTurns: 3,
        prerequisites: ['tech_git'],
        productivityBonus: 10,
        qualityBonus: 8,
      ),
      Technology(
        id: 'tech_database',
        name: 'データベース設計',
        category: TechCategory.infrastructure,
        description: 'RDB/NoSQLの適切な設計ができるようになる。',
        researchCost: 25,
        researchTurns: 3,
        prerequisites: ['tech_git'],
        productivityBonus: 8,
        qualityBonus: 10,
      ),

      // Tier 3 - 上級
      Technology(
        id: 'tech_typescript',
        name: 'TypeScript',
        category: TechCategory.language,
        description: '型安全なJavaScript。大規模開発での品質向上。',
        researchCost: 50,
        researchTurns: 4,
        prerequisites: ['tech_react', 'tech_nodejs'],
        productivityBonus: 10,
        qualityBonus: 20,
      ),
      Technology(
        id: 'tech_cicd',
        name: 'CI/CD パイプライン',
        category: TechCategory.devops,
        description: '自動テスト/自動デプロイ。リリース品質の大幅改善。',
        researchCost: 60,
        researchTurns: 5,
        prerequisites: ['tech_docker'],
        productivityBonus: 15,
        qualityBonus: 15,
      ),
      Technology(
        id: 'tech_cloud_arch',
        name: 'クラウドアーキテクチャ',
        category: TechCategory.infrastructure,
        description: 'AWS/GCPを活用した高可用性設計。',
        researchCost: 70,
        researchTurns: 5,
        prerequisites: ['tech_docker', 'tech_database'],
        productivityBonus: 12,
        qualityBonus: 15,
      ),
      Technology(
        id: 'tech_security_basic',
        name: 'セキュリティ基礎',
        category: TechCategory.security,
        description: 'OWASP Top 10対策。セキュアな開発の基盤。',
        researchCost: 40,
        researchTurns: 4,
        prerequisites: ['tech_database'],
        qualityBonus: 20,
      ),

      // Tier 4 - エキスパート
      Technology(
        id: 'tech_microservices',
        name: 'マイクロサービス',
        category: TechCategory.infrastructure,
        description: '大規模システムのスケーラブルなアーキテクチャ。',
        researchCost: 100,
        researchTurns: 6,
        prerequisites: ['tech_cloud_arch', 'tech_cicd'],
        productivityBonus: 20,
        qualityBonus: 15,
      ),
      Technology(
        id: 'tech_ai_ml',
        name: 'AI/機械学習',
        category: TechCategory.ai,
        description: 'AI機能の実装。高付加価値な製品開発が可能に。',
        researchCost: 120,
        researchTurns: 8,
        prerequisites: ['tech_typescript', 'tech_cloud_arch'],
        productivityBonus: 15,
        qualityBonus: 10,
        unlocksSaaSIds: ['saas_analytics'],
      ),
      Technology(
        id: 'tech_zero_trust',
        name: 'ゼロトラストセキュリティ',
        category: TechCategory.security,
        description: '最先端のセキュリティアーキテクチャ。',
        researchCost: 90,
        researchTurns: 6,
        prerequisites: ['tech_security_basic', 'tech_cloud_arch'],
        qualityBonus: 25,
        unlocksSaaSIds: ['saas_security'],
      ),
    ];
  }
}
