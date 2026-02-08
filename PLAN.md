# PLAN.md — CTO Simulator バグ修正・改善設計書

> **作成者:** agent-0-planner (Game Designer)
> **作成日:** 2026-02-09
> **ステータス:** implementer向け設計書

---

## 001: BUG-01 — イベントのコスト二重減算を修正

### 問題の根本原因

`event_engine.dart:applyEventChoice` メソッドで、イベント選択肢のコスト処理が2箇所で行われている:

1. **L50-54:** `choice.cost > 0` のとき `money -= cost` を実行
2. **L57-59:** `choice.effects` のループで `effects['money']` が負値の場合にさらに `money += effects['money']` を実行

例: `evt_talent_market` の `hire_bonus` 選択肢:
- `cost: 50` → 50万円減算
- `effects: {'money': -50}` → さらに50万円減算
- **結果: -100万円**（本来は-50万円のはず）

同様のパターンが `evt_server_attack`, `evt_tech_conference`, `evt_market_boom`, `evt_employee_burnout`, `evt_board_direction` の選択肢にも存在する。

### 修正方針

**方針: `effects['money']` を削除し、`cost` フィールドに一本化する**

理由:
- `cost` フィールドは「選択肢を選ぶのに必要なコスト」という明確なセマンティクス
- `effects['money']` は正値（報酬）のケースもあるため、正の `money` effect は残す
- 二重課金を防ぐためには、負の `money` effect を全て削除し、`cost` に統一するのが最もクリーン

**変更対象:** `lib/core/event_engine.dart`

**具体的な変更内容:**

以下のイベント選択肢から `effects` の `'money': -XX` エントリを削除する:

| イベント | 選択肢ID | 現在の effects['money'] | cost | 修正後 effects |
|---|---|---|---|---|
| evt_talent_market | hire_bonus | -50 | 50 | `effects: {}` |
| evt_server_attack | invest_security | -30 | 30 | `effects: {'trust': 5}` |
| evt_tech_conference | attend | -20 | 20 | `effects: {'allHappiness': 10}` |
| evt_market_boom | aggressive | -10 | 10 | `effects: {'trust': 5}` |
| evt_employee_burnout | team_building | -15 | 15 | `effects: {'allHappiness': 15, 'allFatigue': -20}` |
| evt_employee_burnout | bonus | -30 | 30 | `effects: {'allHappiness': 20}` |
| evt_board_direction | accept_change | -50 | 50 | `effects: {'trust': 3}` |

**注意:** 以下の選択肢は `effects['money']` が正値（報酬）なので変更しない:
- `evt_big_client` の `accept_big`: `effects: {'trust': 10, 'money': 100}` — これは報酬なので正しい
- `evt_investor_referral` の `accept_referral`: `effects: {'money': 80, 'trust': 5}` — 正しい

### 期待される結果

- イベント選択時のコスト減算が1回のみになる
- 例: `hire_bonus` で所持金が -50万円（現在の -100万円ではなく）

### テスト方法

```dart
test('イベント選択肢のコストが二重減算されない', () {
  final state = GameState.initial(const GameConfig()).copyWith(money: 500);
  final event = GameEvent(/* evt_talent_market */);
  final choice = event.choices[0]; // hire_bonus: cost=50
  final result = EventEngine.applyEventChoice(state, event, choice);
  expect(result.money, 450); // 500 - 50 = 450 (not 400)
});
```

---

## 002: BUG-03 — 納期超過ペナルティの無限ループを修正

### 問題の根本原因

`contract_engine.dart:processProjects` (L196-207) で:

1. `status == ProjectStatus.overdue` の案件に**毎ターン** `trust -= 2` を適用
2. overdue案件を終了させる手段（自動失敗、手動破棄）が存在しない
3. overdue案件のアサイン社員はそのまま拘束され続ける
4. trust が 0 になるまで減り続け、確実にゲームオーバーになる

### 修正方針

**2段階の修正を行う:**

#### A. overdue案件の自動失敗（3ターン超過で強制失敗）

**変更対象:** `lib/core/contract_engine.dart:processProjects`

**変更内容:**

L172-178 の納期超過判定部分を拡張し、以下のロジックを追加:

```
// 現在のロジック: status を overdue にセットするだけ
// 追加するロジック:
// 1. overdue になってからのターン数を追跡する
//    → ContractProject モデルに `overdueSinceTurn: int?` フィールドを追加
// 2. overdue開始時に overdueSinceTurn を現在ターンにセット
// 3. overdueSinceTurn から3ターン経過で ProjectStatus.failed にセット
// 4. failed 時: 着手金の返還不要だが、信頼度 -5 のペナルティ
// 5. failed 案件のアサイン社員を自動解放
```

**ContractProject モデル変更:** `lib/core/models/contract_project.dart`

```dart
// 追加フィールド
final int? overdueSinceTurn;  // nullable（通常のcopyWithで渡せる）
```

**processProjects の変更ロジック:**

```
for each overdue project:
  if overdueSinceTurn == null:
    set overdueSinceTurn = currentTurn
  if currentTurn - overdueSinceTurn >= 3:
    set status = ProjectStatus.failed
    trust -= 5
    log: '案件「{name}」が失敗しました（納期超過3ターン）'
    unassign all employees
  else:
    trust -= 2  // 従来通りの毎ターンペナルティ
    log: '納期超過ペナルティ: 信頼度 -2 (あと{残りターン}ターンで失敗)'
```

**ProjectStatus に `failed` を追加:**

```dart
enum ProjectStatus { available, inProgress, completed, overdue, failed }
```

#### B. プレイヤーによる案件破棄機能（オプション）

**変更対象:** `lib/core/contract_engine.dart`, `lib/state/game_notifier.dart`, `lib/ui/screens/contract_tab.dart`

```dart
// ContractEngine に追加
static GameState abandonProject(GameState state, String projectId) {
  // 1. 案件を failed に変更
  // 2. 着手金分の信頼度ペナルティ（trust -5）
  // 3. アサイン社員を解放
  // 4. ログ出力
}

// GameNotifier に追加
void abandonProject(String projectId) {
  state = ContractEngine.abandonProject(state, projectId);
}
```

UIでは overdue / inProgress の案件に「破棄」ボタンを追加。

### 期待される結果

- overdue案件が3ターン後に自動失敗し、社員が解放される
- プレイヤーが自主的に案件を破棄できる
- trust=0 の無限降下が防止される

### テスト方法

```dart
test('overdue案件は3ターン後に自動失敗する', () {
  // overdue状態のプロジェクト(overdueSinceTurn=10)をセット
  // currentTurn=13でprocessProjects実行
  // → status == ProjectStatus.failed になること
  // → アサイン社員が解放されること
});
```

---

## 003: BUG-12 — サーバー購入・研究開始時のAP無条件消費を修正

### 問題の根本原因

`game_notifier.dart` の以下メソッドで、アクションが失敗してもAPが消費される:

1. **`purchaseServer` (L87-90):** `InfraEngine.purchaseServer` が資金不足でログだけ出して失敗しても、次行で `ap -= cost` が実行される
2. **`startResearch` (L133-137):** `TechTreeEngine.startResearch` が前提技術未解禁や資金不足で失敗しても、AP消費される

対比: `hireEmployee` (L64-71) は正しく「採用成功した場合のみAP消費」パターンを実装済み。

### 修正方針

**変更対象:** `lib/state/game_notifier.dart`

#### purchaseServer の修正 (L87-90)

```dart
void purchaseServer(Server server) {
  if (!_canAfford(ActionCategory.tech)) return;
  final prevServerCount = state.servers.length;
  state = InfraEngine.purchaseServer(state, server);
  // 購入が成功した場合のみAPを消費
  if (state.servers.length > prevServerCount) {
    state = state.copyWith(ap: state.ap - _apCost(ActionCategory.tech));
  }
}
```

#### startResearch の修正 (L133-137)

```dart
void startResearch(String techId) {
  if (!_canAfford(ActionCategory.tech)) return;
  final prevMoney = state.money;
  state = TechTreeEngine.startResearch(state, techId);
  // 研究が開始された場合のみAPを消費（資金が減っていれば成功）
  if (state.money < prevMoney) {
    state = state.copyWith(ap: state.ap - _apCost(ActionCategory.tech));
  }
}
```

#### 同様のパターンで要確認の他メソッド

- `startSaaSDevelopment` (L99-123): 内部で資金チェックして早期returnしているが、AP消費は成功時のみ処理される（L117で一括処理）。ただし、`SaaSEngine` がすでに状態にある製品の重複チェックをしていない点は別課題。→ 現状はOK
- `launchSaaS` (L126-130): `SaaSEngine.launchProduct` が失敗（サーバーなし）してもAP消費される → **これも修正が必要**

```dart
void launchSaaS(String productId) {
  if (!_canAfford(ActionCategory.tech)) return;
  final prevProduct = state.saasProducts.firstWhere((p) => p.id == productId);
  state = SaaSEngine.launchProduct(state, productId);
  final updatedProduct = state.saasProducts.firstWhere((p) => p.id == productId);
  // リリースが成功した場合のみAPを消費
  if (updatedProduct.isLaunched && !prevProduct.isLaunched) {
    state = state.copyWith(ap: state.ap - _apCost(ActionCategory.tech));
  }
}
```

### 期待される結果

- 資金不足でサーバー購入失敗 → AP消費なし
- 前提未解禁で研究失敗 → AP消費なし
- サーバーなしでSaaSリリース失敗 → AP消費なし

### テスト方法

```dart
test('サーバー購入失敗時にAPが消費されない', () {
  // money=0, ap=3 の状態でサーバー購入
  // → ap == 3 のまま
});

test('研究開始失敗時にAPが消費されない', () {
  // 前提技術が未解禁の状態で研究開始
  // → ap が変わらない
});
```

---

## 004: BUG-04 — SaaSリリース時のユーザー数ログ不一致を修正

### 問題の根本原因

`saas_engine.dart:launchProduct` (L108-139):

- L123: `totalUsers: 50` — 実際のユーザー数を50に設定
- L136: ログで `'初期ユーザー: 100人'` と表示 — ハードコードされた文字列

50人と100人の不整合。

### 修正方針

**変更対象:** `lib/core/saas_engine.dart:launchProduct` L136

**変更内容:** ログの文字列を実際の値に合わせる

```dart
// 修正前:
'${product.name}をリリースしました！ 初期ユーザー: 100人 (信頼度+5)',

// 修正後:
'${product.name}をリリースしました！ 初期ユーザー: ${product.totalUsers}人 (信頼度+5)',
```

初期ユーザー数は50人が適切（SaaSの初期リリースとしてリアリスティック）。ログを50に合わせる。

### 期待される結果

- リリースログに「初期ユーザー: 50人」と正しく表示される

### テスト方法

```dart
test('SaaSリリース時のログに正しいユーザー数が表示される', () {
  // 開発完了済みSaaS製品をリリース
  // → turnLog に '初期ユーザー: 50人' が含まれること
});
```

---

## 005: BUG-10 — qualityBonusをプロジェクト品質計算に反映

### 問題の根本原因

`contract_engine.dart:processProjects` (L148-158):

品質スコアの計算式:
```dart
final qualityDelta = ((avgSkill - 50) / 10 - avgFatigue / 20).round();
```

`Technology.qualityBonus` が計算に含まれていない。テクノロジー研究で品質ボーナスを得ても、受託案件の品質に影響しない。

一方、`productivityBonus` は L128-140 で正しく適用されている（`bonusMultiplier`）。

### 修正方針

**変更対象:** `lib/core/contract_engine.dart:processProjects` L148-159 付近

**変更内容:**

```dart
// テクノロジー品質ボーナスの計算（productivityBonusと同様のパターン）
final techQualityBonus = state.technologies
    .where((t) => t.isUnlocked)
    .fold(0, (sum, t) => sum + t.qualityBonus);

// 品質スコアの計算（スキル・疲労・テクノロジーに基づく）
final qualityDelta =
    ((avgSkill - 50) / 10 - avgFatigue / 20 + techQualityBonus / 10).round();
```

**設計根拠:**
- `productivityBonus` は `bonusMultiplier = 1.0 + bonus/100.0` として倍率に変換
- `qualityBonus` も同様にパーセント値 → 品質スコアへの加算に変換
- `qualityBonus / 10` は 10%ボーナスあたり +1 品質デルタ（バランス重視）
- 例: Git(5%) + Docker(8%) + React(10%) = 23% → +2.3 → +2/ターン

### 期待される結果

- テクノロジー研究の品質ボーナスが受託案件の品質スコアに反映される
- 高い品質ボーナスを持つ技術を研究するインセンティブが生まれる

### テスト方法

```dart
test('テクノロジーの品質ボーナスが案件品質に反映される', () {
  // qualityBonus合計20%のテクノロジーが解禁された状態
  // 案件にエンジニアをアサインしてターン処理
  // → qualityScore の増加量がボーナスなしの場合より大きいこと
});
```

---

## 006: BUG-13 — SaaS保守費用を月次経費に含める

### 問題の根本原因

`game_state.dart:totalMonthlyCost` (L77):

```dart
int get totalMonthlyCost => totalSalary + totalServerCost + officeCost;
```

`SaaSProduct.monthlyMaintenanceCost` が計算に含まれていない。

- 各SaaS製品には `monthlyMaintenanceCost` フィールドがある（5〜30万円）
- しかし `totalMonthlyCost` に加算されていない
- 経費表示UIで保守費用が見えず、プレイヤーが実際のコスト構造を把握できない

### 修正方針

**変更対象:** `lib/core/game_state.dart`

**変更内容:**

```dart
// 追加: SaaS保守費用の合計プロパティ
int get totalSaaSMaintenanceCost =>
    saasProducts.where((p) => p.isLaunched).fold(0, (sum, p) => sum + p.monthlyMaintenanceCost);

// 修正: totalMonthlyCost に保守費用を含める
int get totalMonthlyCost =>
    totalSalary + totalServerCost + officeCost + totalSaaSMaintenanceCost;
```

**注意:** `isLaunched` なSaaS製品のみ保守費用を計上。開発中は保守不要。

### 期待される結果

- SaaS製品リリース後、月次経費にメンテナンスコストが反映される
- UIの経費表示が実態と一致する

### 補足: 経費ログの更新

`economy_engine.dart:processMonthlyExpenses` L18 のログ行:
```dart
'月次経費: -${totalExpense}万円 (給与: ${state.totalSalary}, サーバー: ${state.totalServerCost}, オフィス: ${state.officeCost})'
```

SaaS保守費用を含めるため、以下に更新:
```dart
'月次経費: -${totalExpense}万円 (給与: ${state.totalSalary}, サーバー: ${state.totalServerCost}, オフィス: ${state.officeCost}, SaaS保守: ${state.totalSaaSMaintenanceCost})'
```

### テスト方法

```dart
test('SaaS保守費用がtotalMonthlyCostに含まれる', () {
  final state = GameState.initial(const GameConfig()).copyWith(
    saasProducts: [
      SaaSProduct(/* isLaunched: true, monthlyMaintenanceCost: 10 */),
    ],
  );
  expect(state.totalMonthlyCost, /* 基本コスト + 10 */);
});
```

---

## 007: BAL-02 — ローン月利を現実的な水準に調整

### 問題の根本原因

`models/loan.dart:LoanSize` (L4-7):

```dart
small('小口融資', 100, 0.05, 12),   // 月利5% = 年利60%
medium('中口融資', 300, 0.07, 24),   // 月利7% = 年利84%
large('大口融資', 500, 0.10, 36);    // 月利10% = 年利120%
```

現実のビジネスローンと比較:
- 銀行融資: 年利1-5% → 月利0.08-0.42%
- ノンバンク: 年利5-15% → 月利0.42-1.25%
- カードローン: 年利15-18% → 月利1.25-1.5%

現在の設定は闇金レベルであり、ゲームバランスとしてもローンが全く使い物にならない。

### 修正方針

**変更対象:** `lib/core/models/loan.dart:LoanSize`

**ゲームバランスを考慮した新しい利率設計:**

ゲームは1ターン=1ヶ月相当。リアリスティックすぎると利息が微小で意味がないため、ゲーム性を加味して以下に設定:

```dart
small('小口融資', 100, 0.01, 12),   // 月利1% = 年利12% — 低リスク短期
medium('中口融資', 300, 0.015, 24),  // 月利1.5% = 年利18% — 中リスク中期
large('大口融資', 500, 0.02, 36);    // 月利2% = 年利24% — 高リスク長期
```

**設計根拠:**
- 月利1-2% は「ゲーム世界のビジネスローン」として十分リアリスティック
- 小口100万を12ターンで返済 → 月額返済: 元本8.3万 + 利息1万 ≈ 9.3万円/月（現実的）
- 大口500万を36ターンで返済 → 月額返済: 元本13.9万 + 利息10万 ≈ 23.9万円/月（重いが払える）
- 現在の設定: 大口月額返済 = 13.9万 + 50万 = 63.9万円/月（ほぼ破産確定）

**月額返済額の比較（大口融資・初月）:**

| 月利 | 月額利息 | 月額元本 | 月額合計 |
|---|---|---|---|
| 現在(10%) | 50万 | 13.9万 | 63.9万 |
| 修正後(2%) | 10万 | 13.9万 | 23.9万 |

### 期待される結果

- ローンが実用的な資金調達手段になる
- 利息負担が現実的で、返済計画が立てられる

### テスト方法

```dart
test('ローン月利が適切な水準', () {
  expect(LoanSize.small.monthlyRate, 0.01);
  expect(LoanSize.medium.monthlyRate, 0.015);
  expect(LoanSize.large.monthlyRate, 0.02);
});

test('ローン月額返済額が妥当', () {
  final loan = Loan.create(LoanSize.large, 1);
  // 初月: 元本500/36≈14 + 利息500*0.02=10 ≈ 24万円
  expect(loan.monthlyPayment, lessThan(30));
});
```

---

## 008: UI改善 — サーバー購入時の資金チェック + アサインのエンジニアフィルター

### 問題の根本原因

#### A. サーバー購入の資金チェック不足

`infra_tab.dart`: サーバー購入ボタンが資金不足でも押せてしまい、エラーログが表示されるだけ。UXが悪い。

#### B. アサインダイアログのフィルタリング不足

`contract_tab.dart`, `saas_tab.dart`: エンジニアのアサインダイアログで全社員（マーケター、バックオフィスなど非エンジニア含む）が表示される。

### 修正方針

#### A. サーバー購入ボタンの資金チェック

**変更対象:** `lib/ui/screens/infra_tab.dart`

```dart
// 各サーバー購入ボタンで:
// purchaseCost = server.monthlyCost * 3
// state.money < purchaseCost の場合:
//   - ボタンをdisabledにする
//   - ツールチップで「資金不足: {purchaseCost}万円必要」と表示
```

#### B. アサインダイアログでエンジニアのみ表示

**変更対象:** `lib/ui/screens/contract_tab.dart`, `lib/ui/screens/saas_tab.dart`

```dart
// アサインダイアログの社員リストフィルタ:
// unassignedEmployees.where((e) => e.type == EmployeeType.engineer)
```

エンジニア以外（marketer, backOffice）はコード開発に参加できないため、アサイン候補から除外。

### 期待される結果

- 資金不足時にサーバー購入ボタンがグレーアウト
- アサインダイアログにエンジニアのみ表示

### テスト方法

- UIテスト: 資金不足状態でサーバー購入ボタンが disabled であること
- UIテスト: アサインダイアログに EmployeeType.engineer のみ表示されること

---

## 009: FUN — オフィスアップグレード機能の実装

### 問題の根本原因

現在のゲームでは `Office` モデルが存在するが、初期の「ガレージオフィス」のみでアップグレード手段がない。`Office` クラスには `maxEmployees`, `monthlyCost`, `happinessBonus`, `productivityBonus` が定義済みだが使われていない。

### 修正方針

#### オフィスグレード定義

| ID | 名前 | 社員上限 | 月額 | 幸福度Bonus | 生産性Bonus | 必要資金 | 説明 |
|---|---|---|---|---|---|---|---|
| office_garage | ガレージオフィス | 5 | 5万 | 0 | 0 | - | 初期オフィス |
| office_coworking | コワーキングスペース | 8 | 15万 | 5 | 5 | 50万 | 他社との交流あり |
| office_small | 小規模オフィス | 15 | 30万 | 10 | 8 | 150万 | 自社専用空間 |
| office_medium | 中規模オフィス | 30 | 60万 | 15 | 12 | 400万 | フロア単位 |
| office_large | 大規模オフィス | 50 | 100万 | 20 | 15 | 800万 | ビル1棟 |

#### 必要な変更

**1. オフィスマスターデータ定義**

`lib/core/models/office.dart` に静的メソッドまたは定数を追加:

```dart
static const List<Office> allOffices = [
  Office(id: 'office_garage', name: 'ガレージオフィス', maxEmployees: 5, monthlyCost: 5, description: 'スタートアップの原点'),
  Office(id: 'office_coworking', name: 'コワーキングスペース', maxEmployees: 8, monthlyCost: 15, happinessBonus: 5, productivityBonus: 5, description: '他社との交流あり'),
  // ... 他のオフィス
];

static int upgradeCost(String officeId) {
  // マップで管理
}
```

`Office` にアップグレード費用フィールドは不要。別途管理する。

**2. アップグレードロジック**

`lib/state/game_notifier.dart` に追加:

```dart
void upgradeOffice(String newOfficeId) {
  if (!_canAfford(ActionCategory.management)) return;
  // 1. 新オフィスのデータ取得
  // 2. アップグレード費用チェック
  // 3. 現在のオフィスより上位かチェック
  // 4. state更新: office, money, ap, turnLog
}
```

**3. UIコンポーネント**

`lib/ui/screens/infra_tab.dart` にオフィスセクション追加:
- 現在のオフィス情報表示
- アップグレード可能なオフィスの一覧
- アップグレードボタン（資金・グレードチェック付き）

### 期待される結果

- 会社の成長に応じてオフィスをアップグレード可能
- 社員上限が増加し、大規模チーム運営が可能に
- 幸福度・生産性ボーナスが戦略的な投資として機能

### テスト方法

```dart
test('オフィスアップグレードが正しく適用される', () {
  // ガレージ → コワーキングへアップグレード
  // maxEmployees, monthlyCost, bonus が更新されること
  // money が upgradeCost 分減少すること
});
```

---

## 横断的な注意事項

### アーキテクチャ規約の遵守

- **copyWithパターン:** Office の nullable パターン (`Office? Function()? office`) を維持
- **レイヤー分離:** ロジックは `lib/core/`, 状態管理は `lib/state/`, UIは `lib/ui/`
- **import順序:** `dart:` → `package:flutter/` → `package:` → relative imports

### 実装優先度

1. **Critical (P1):** 001, 002, 003 — ゲーム進行に致命的なバグ
2. **High (P2):** 004, 005, 006 — ゲームバランスに影響
3. **Medium (P3):** 007, 008, 009 — バランス改善・UX向上

---

## 追加発見事項（今回のスコープ外）

コードレビュー中に発見した追加の改善候補。将来タスクとして参照。

### A. 残業指示の効果が不完全

`employee_engine.dart:orderOvertime` (L159-183):
- 疲労増加と幸福度低下は行うが、プロジェクトの作業進捗に反映されていない
- APを消費するがプロジェクトの `currentWork` は増えない
- `contract_engine.dart:workOnProject` (L213-231) も同様にAPだけ消費して何もしない

### B. イベント抽選の順序依存性

`event_engine.dart:rollEvent` (L22-29):
- `eligibleEvents` をリスト順に走査し、最初に確率をパスしたイベントを返す
- リスト先頭のイベント（`evt_talent_market`, probability: 0.3）が最も発火しやすい
- よりフェアな抽選にするには、確率に基づく重み付き抽選が望ましい

### C. SaaS開発中社員の判定がproject.idベース

`saas_engine.dart:processSaaS` (L74-75):
- `e.assignedProjectId == product.id` で開発社員を判定
- しかし `assignedProjectId` は受託案件のアサインで使用される前提のフィールド
- SaaS専用のアサイン機構が未実装の可能性がある（UIで確認必要）

### D. 案件生成の擬似ランダム

`contract_engine.dart:generateProjects` (L283):
- `DateTime.now().millisecondsSinceEpoch` を直接使っており、テスト時に結果が不安定
- `Random` インスタンスを注入可能にすべき
