import 'package:flutter/foundation.dart';

/// アクションのカテゴリ（APコスト計算に使用）
enum ActionCategory {
  tech('技術'),
  hiring('採用'),
  sales('営業'),
  finance('財務'),
  marketing('マーケティング'),
  management('マネジメント');

  const ActionCategory(this.label);
  final String label;
}

/// CEOのバックグラウンド
enum CeoBackground {
  engineer('エンジニア出身', 'コードが書けるCTO。技術判断が速い。'),
  sales('営業出身', '顧客開拓が得意。案件獲得に強い。'),
  marketer('マーケター出身', 'SaaS成長の勘所を知っている。'),
  backOffice('バックオフィス出身', '堅実な経営管理ができる。'),
  studentEntrepreneur('学生起業家', '若さと情熱で突き進む。資金は少ないが伸びしろがある。');

  const CeoBackground(this.label, this.description);
  final String label;
  final String description;
}

/// 各バックグラウンドの得意/不得意定義
@immutable
class BackgroundProfile {
  const BackgroundProfile._({
    required this.background,
    required this.proficientCategories,
    required this.specialEffect,
    required this.specialEffectValue,
  });

  final CeoBackground background;
  final Set<ActionCategory> proficientCategories;
  final String specialEffect;
  final double specialEffectValue;

  /// 得意カテゴリなら true
  bool isProficient(ActionCategory category) =>
      proficientCategories.contains(category);

  /// APコスト: 得意=1, 不得意=2
  int apCost(ActionCategory category) => isProficient(category) ? 1 : 2;

  static const Map<CeoBackground, BackgroundProfile> profiles = {
    CeoBackground.engineer: BackgroundProfile._(
      background: CeoBackground.engineer,
      proficientCategories: {ActionCategory.tech},
      specialEffect: '技術研究速度+15%',
      specialEffectValue: 0.15,
    ),
    CeoBackground.sales: BackgroundProfile._(
      background: CeoBackground.sales,
      proficientCategories: {ActionCategory.sales},
      specialEffect: '案件報酬+15%',
      specialEffectValue: 0.15,
    ),
    CeoBackground.marketer: BackgroundProfile._(
      background: CeoBackground.marketer,
      proficientCategories: {ActionCategory.marketing, ActionCategory.sales},
      specialEffect: 'SaaS成長率+15%',
      specialEffectValue: 0.15,
    ),
    CeoBackground.backOffice: BackgroundProfile._(
      background: CeoBackground.backOffice,
      proficientCategories: {
        ActionCategory.finance,
        ActionCategory.hiring,
        ActionCategory.management,
      },
      specialEffect: '経費関連+15%',
      specialEffectValue: 0.15,
    ),
    CeoBackground.studentEntrepreneur: BackgroundProfile._(
      background: CeoBackground.studentEntrepreneur,
      proficientCategories: {ActionCategory.tech, ActionCategory.marketing},
      specialEffect: '初期資金60%・全カテゴリボーナス+10%',
      specialEffectValue: 0.10,
    ),
  };

  static BackgroundProfile of(CeoBackground bg) => profiles[bg]!;
}
