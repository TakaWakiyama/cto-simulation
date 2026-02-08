import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class TutorialDialog extends StatefulWidget {
  const TutorialDialog({super.key});

  @override
  State<TutorialDialog> createState() => _TutorialDialogState();
}

class _TutorialDialogState extends State<TutorialDialog> {
  int _currentStep = 0;

  static const _steps = [
    _TutorialStep(
      icon: Icons.terminal,
      color: AppColors.green,
      title: 'CTO Simulatorへようこそ',
      description: 'あなたはITスタートアップのCTOです。\n'
          'エンジニアの採用、受託開発、SaaS事業、インフラ管理を通じて会社を成長させましょう。',
      details: [
        _DetailItem(
          icon: Icons.bolt,
          label: 'AP（行動ポイント）',
          text: '毎ターン3AP。採用・受注などのアクションに消費します。\n'
              'CEOの得意分野は1AP、不得意は2AP消費。',
        ),
        _DetailItem(
          icon: Icons.skip_next,
          label: 'ターン制',
          text: '全120ターン（10年）。ターン終了で開発進行・給与支払い・イベント発生。',
        ),
        _DetailItem(
          icon: Icons.warning_amber,
          label: 'ゲームオーバー',
          text: '負債1000万超 or 信頼度0 で即ゲームオーバー。資金管理が重要！',
        ),
      ],
    ),
    _TutorialStep(
      icon: Icons.work_outline,
      color: AppColors.blue,
      title: '受託タブ',
      description: '受託開発で資金を稼ぎましょう。\n案件を受注 → 社員をアサイン → ターン終了で開発が進みます。',
      details: [
        _DetailItem(
          icon: Icons.assignment,
          label: '案件の受注',
          text: '報酬・難易度・納期を確認して案件を選びましょう。'
              '信頼度が高いほど良い案件が来ます。',
        ),
        _DetailItem(
          icon: Icons.person_add,
          label: '社員のアサイン',
          text: '受注した案件にエンジニアをアサインすると開発が進みます。'
              '複数人アサインで加速！',
        ),
        _DetailItem(
          icon: Icons.timer,
          label: '納期に注意',
          text: '期限内に完了しないと信頼度が下がります。'
              '無理な案件は受けないことも大切。',
        ),
      ],
    ),
    _TutorialStep(
      icon: Icons.cloud_outlined,
      color: AppColors.purple,
      title: 'SaaSタブ',
      description: 'SaaS製品を開発してサブスク収入を得ましょう。\n開発 → ローンチ → ユーザー獲得で安定収入に。',
      details: [
        _DetailItem(
          icon: Icons.code,
          label: '製品開発',
          text: '開発費を投じてSaaS製品を作成。'
              '開発完了まで数ターンかかります。',
        ),
        _DetailItem(
          icon: Icons.rocket_launch,
          label: 'ローンチ',
          text: '開発完了後にローンチするとユーザー獲得開始。'
              'MRR（月額収入）が発生します。',
        ),
        _DetailItem(
          icon: Icons.dns,
          label: 'サーバー必須',
          text: 'ユーザーが増えるとサーバー負荷が上昇。'
              'インフラタブでサーバーを確保しましょう。',
        ),
      ],
    ),
    _TutorialStep(
      icon: Icons.dns_outlined,
      color: AppColors.cyan,
      title: 'インフラタブ',
      description: 'サーバーを購入・管理してSaaSを安定稼働させましょう。\n障害発生時は速やかに復旧を。',
      details: [
        _DetailItem(
          icon: Icons.shopping_cart,
          label: 'サーバー購入',
          text: 'スペックや月額費用を比較して購入。'
              'SaaSユーザー数に合わせて拡張が必要。',
        ),
        _DetailItem(
          icon: Icons.warning,
          label: '障害対応',
          text: 'サーバーは確率で故障します。'
              '障害中はSaaS収入が減少し、信頼度も低下。',
        ),
      ],
    ),
    _TutorialStep(
      icon: Icons.people_outline,
      color: AppColors.orange,
      title: '社員タブ',
      description: 'エンジニアとスタッフを採用してチームを強化しましょう。',
      details: [
        _DetailItem(
          icon: Icons.code,
          label: 'エンジニア',
          text: '案件開発の主力。スキルが高いほど開発速度UP。'
              '疲労管理と幸福度に注意。',
        ),
        _DetailItem(
          icon: Icons.support_agent,
          label: 'スタッフ',
          text: '営業（報酬UP）・マーケター（SaaS成長）・バックオフィス（経費削減）・'
              '人事（採用費DOWN）の4職種。パッシブ効果で経営を支えます。',
        ),
        _DetailItem(
          icon: Icons.mood_bad,
          label: '退職リスク',
          text: '幸福度が低いと退職してしまいます。'
              '給与・疲労・オフィス環境に気を配りましょう。',
        ),
      ],
    ),
  ];

  void _next() {
    if (_currentStep < _steps.length - 1) {
      setState(() => _currentStep++);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _prev() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentStep];
    final isLast = _currentStep == _steps.length - 1;

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ステッパーインジケーター
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: List.generate(_steps.length, (i) {
                final s = _steps[i];
                final isActive = i == _currentStep;
                final isDone = i < _currentStep;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _currentStep = i),
                    child: Column(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isActive
                                ? s.color
                                : isDone
                                    ? s.color.withValues(alpha: 0.3)
                                    : Colors.transparent,
                            border: Border.all(
                              color: isActive || isDone
                                  ? s.color
                                  : AppColors.border,
                              width: isActive ? 2 : 1,
                            ),
                          ),
                          child: Icon(
                            isDone ? Icons.check : s.icon,
                            size: 16,
                            color: isActive
                                ? Colors.white
                                : isDone
                                    ? s.color
                                    : AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (i < _steps.length - 1)
                          Container()
                        else
                          const SizedBox.shrink(),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),

          // プログレスバー
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: (_currentStep + 1) / _steps.length,
                backgroundColor: AppColors.border,
                valueColor: AlwaysStoppedAnimation(step.color),
                minHeight: 3,
              ),
            ),
          ),

          // コンテンツ
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // タイトル
                  Row(
                    children: [
                      Icon(step.icon, color: step.color, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          step.title,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: step.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 説明
                  Text(
                    step.description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 詳細項目
                  ...step.details.map((detail) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: step.color.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: step.color.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(detail.icon,
                                  size: 18, color: step.color),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      detail.label,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: step.color,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      detail.text,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )),
                ],
              ),
            ),
          ),

          // ナビゲーションボタン
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // スキップ / 戻る
                if (_currentStep == 0)
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'スキップ',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  )
                else
                  TextButton.icon(
                    onPressed: _prev,
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text('戻る', style: TextStyle(fontSize: 13)),
                  ),

                const Spacer(),

                // ステップ表示
                Text(
                  '${_currentStep + 1} / ${_steps.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),

                const Spacer(),

                // 次へ / 始める
                ElevatedButton.icon(
                  onPressed: _next,
                  icon: Icon(
                    isLast ? Icons.play_arrow : Icons.arrow_forward,
                    size: 18,
                  ),
                  label: Text(
                    isLast ? 'ゲームを始める' : '次へ',
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: step.color,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TutorialStep {
  const _TutorialStep({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.details,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final List<_DetailItem> details;
}

class _DetailItem {
  const _DetailItem({
    required this.icon,
    required this.label,
    required this.text,
  });

  final IconData icon;
  final String label;
  final String text;
}
