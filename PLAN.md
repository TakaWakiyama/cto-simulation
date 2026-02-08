# PLAN.md — CTO Simulator バグ修正・改善設計書 (v2)

> **作成者:** agent-0-planner (Game Designer)
> **初版:** 2026-02-09
> **更新:** 2026-02-09 (Session 2 — 実装レビュー・追加バグ発見)
> **ステータス:** implementer向け設計書 (v2)

---

## 実装進捗サマリー

### 実装完了 (implementer branch)

| タスク | 状態 | レビュー結果 |
|---|---|---|
| 002 BUG-03 納期超過無限ループ | 実装済 | OK — `remainingTurns` ベースで猶予3ターン判定。`overdueSinceTurn` フィールド追加せず `remainingTurns()` を活用した簡潔な実装。 |
| 003 BUG-12 AP無条件消費 (purchaseServer, startResearch) | 実装済 | OK — 設計書通りの実装 |
| 004 BUG-04 SaaSログ不一致 | 部分実装 | 要修正 — ログを `50人` に修正したがハードコード。`${updatedProduct.totalUsers}` にすべき |
| 002追加 案件破棄機能 | 実装済 | OK — abandonProject + UI破棄ボタン実装済み |
| 008 activeProjects にoverdue含める | 実装済 | OK — game_state.dart の activeProjects getter 修正済み |

### 未実装 (要対応)

| タスク | 優先度 | 備考 |
|---|---|---|
| 001 BUG-01 イベントコスト二重減算 | P1 | **最重要** — 全く手付かず |
| 003追加 launchSaaS AP修正 | P1 | 設計書に記載済みだが未実装 |
| 005 BUG-10 qualityBonus未反映 | P2 | 全く手付かず |
| 006 BUG-13 SaaS保守費用 | P2 | 全く手付かず |
| 007 BAL-02 ローン月利 | P3 | 全く手付かず |
| 008 サーバー購入disable + エンジニアフィルター | P3 | 全く手付かず |
| 009 オフィスアップグレード | P3 | 全く手付かず |

### 実装差分メモ (002について)

implementerは `overdueSinceTurn` フィールドを追加せず、`remainingTurns()` の値で判定する方式を採用:
- `-(p.remainingTurns(currentTurn)) >= overdueGraceTurns` で3ターン超過を判定
- これは設計書のアプローチより簡潔で、モデル変更が不要という利点がある
- **評価: 問題なし。** `remainingTurns` は `deadline - (currentTurn - startTurn)` なので、等価な判定。

ただし毎ターンの信頼度ペナルティ(-2)は **新たにoverdueになったターンのみ** に限定されている。これは設計書の「毎ターン -2」とは異なるが、自動失敗(3ターン後)があるため、ゲームバランスとしてはこちらの方が良い。

---

## 未実装タスク (詳細設計 — 前回から変更なし)

以下のタスクは設計書の内容に変更なし。implementerは前回の設計書を参照すること。

### 001: BUG-01 — イベントのコスト二重減算を修正 (P1)

**状態: 未実装**

前回の設計内容をそのまま適用。要点:
- `event_engine.dart:getDefaultEvents()` 内の7つの選択肢から `effects['money']` の負値エントリを削除
- `cost` フィールドに一本化
- 正値の `effects['money']`（報酬）は変更しない

**影響を受けるイベント:**
| イベント | 選択肢ID | 削除する effects | 残す cost |
|---|---|---|---|
| evt_talent_market | hire_bonus | `'money': -50` 削除 | cost: 50 |
| evt_server_attack | invest_security | `'money': -30` 削除 | cost: 30 |
| evt_tech_conference | attend | `'money': -20` 削除 | cost: 20 |
| evt_market_boom | aggressive | `'money': -10` 削除 | cost: 10 |
| evt_employee_burnout | team_building | `'money': -15` 削除 | cost: 15 |
| evt_employee_burnout | bonus | `'money': -30` 削除 | cost: 30 |
| evt_board_direction | accept_change | `'money': -50` 削除 | cost: 50 |

---

### 003追加: BUG-12拡張 — launchSaaS のAP無条件消費修正 (P1)

**状態: 未実装**

`game_notifier.dart:launchSaaS` (現在L126-130):

```dart
// 修正前:
void launchSaaS(String productId) {
  if (!_canAfford(ActionCategory.tech)) return;
  state = SaaSEngine.launchProduct(state, productId);
  state = state.copyWith(ap: state.ap - _apCost(ActionCategory.tech));
}

// 修正後:
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

---

### 004修正: BUG-04 — SaaSログのハードコード修正 (P2)

**状態: 部分実装（要修正）**

implementerはログを `'50人'` に修正したが、ハードコードのまま。
動的な値を使うべき:

```dart
// 現在の実装 (implementer branch):
'${product.name}をリリースしました！ 初期ユーザー: 50人 (信頼度+5)',

// 正しい修正:
// launchProduct内でupdatedProductを取得して:
'${updatedProduct.name}をリリースしました！ 初期ユーザー: ${updatedProduct.totalUsers}人 (信頼度+5)',
```

**注意:** `launchProduct` メソッド内の構造上、`updatedProducts.map()` の中でログを出力しているため、更新後の `totalUsers` を参照する必要がある。リファクタリングとして、map処理とログ出力を分離するのが望ましい。

---

### 005: BUG-10 — qualityBonusをプロジェクト品質計算に反映 (P2)

**状態: 未実装**

設計内容に変更なし。`contract_engine.dart:processProjects` の品質デルタ計算に `techQualityBonus` を加算。

---

### 006: BUG-13 — SaaS保守費用を月次経費に含める (P2)

**状態: 未実装**

設計内容に変更なし。`game_state.dart:totalMonthlyCost` に `totalSaaSMaintenanceCost` を追加。

---

### 007: BAL-02 — ローン月利を現実的な水準に調整 (P3)

**状態: 未実装**

設計内容に変更なし。月利 5-10% → 1-2% に変更。

---

### 008: UI改善 — サーバー購入disable + エンジニアフィルター (P3)

**状態: 未実装**

設計内容に変更なし。

---

### 009: FUN — オフィスアップグレード機能の実装 (P3)

**状態: 未実装**

設計内容に変更なし。

---

## 新規発見バグ・改善 (Session 2)

コードレビューで追加発見した問題。新規タスクとして起票する。

---

### 011: BUG-NEW — orderOvertime / workOnProject がプロジェクトを進捗させない (P1)

### 問題の根本原因

**2つのメソッドが完全なno-op（何もしない）:**

#### A. `employee_engine.dart:orderOvertime` (L159-183)

残業指示は社員の疲労+20・幸福度-10を適用するが、プロジェクトの `currentWork` を一切増加させない。APを消費して社員を消耗させるだけの罠アクション。

```dart
static GameState orderOvertime(GameState state, String employeeId, String projectId) {
  // 社員の疲労・幸福度のみ変更
  // projectの進捗: 変更なし！
  return state.copyWith(employees: employees, turnLog: [...]);
}
```

#### B. `contract_engine.dart:workOnProject` (L212-231)

案件の手動作業はAPだけ消費して文字通り何もしない:

```dart
static GameState workOnProject(GameState state, String projectId, {int apCost = 1, bool isOvertime = false}) {
  if (state.ap < apCost) { return state.copyWith(turnLog: [...]); }
  return state.copyWith(ap: state.ap - apCost);
  // currentWork 増加: なし！ ログ出力: なし！
}
```

### 修正方針

#### A. orderOvertime の修正

**変更対象:** `lib/core/employee_engine.dart:orderOvertime`

残業の効果:
1. 社員の疲労+20、幸福度-10（既存）
2. **追加:** アサインされたプロジェクトの `currentWork` に即時ボーナスを加算

```dart
static GameState orderOvertime(GameState state, String employeeId, String projectId) {
  final employee = state.employees.firstWhere((e) => e.id == employeeId);

  // 1. 社員状態を更新（疲労+20, 幸福度-10）
  // （既存コードのまま）

  // 2. プロジェクト進捗を追加
  final project = state.contractProjects.firstWhere((p) => p.id == projectId);
  final overtimeWork = (employee.productivity * 0.5).round(); // 通常作業の50%分
  final updatedProjects = state.contractProjects.map((p) {
    if (p.id == projectId) {
      return p.copyWith(currentWork: p.currentWork + overtimeWork);
    }
    return p;
  }).toList();

  return state.copyWith(
    employees: updatedEmployees,
    contractProjects: updatedProjects,
    turnLog: [...state.turnLog,
      '${employee.name}に残業を指示（疲労+20, 幸福度-10, 進捗+$overtimeWork）'],
  );
}
```

**設計根拠:**
- 残業は通常ターン進行時の作業の約50%の効果
- APコスト(1) + 社員消耗(疲労+20, 幸福度-10)の対価として妥当
- 納期に追われる案件への「最後の手段」として機能

#### B. workOnProject の修正

**変更対象:** `lib/core/contract_engine.dart:workOnProject`

CTO自身の手動作業（APを消費して直接開発する概念）:

```dart
static GameState workOnProject(GameState state, String projectId, {int apCost = 1, bool isOvertime = false}) {
  if (state.ap < apCost) {
    return state.copyWith(turnLog: [...state.turnLog, 'APが不足しています。']);
  }

  final project = state.contractProjects.firstWhere((p) => p.id == projectId);
  // CTOの手動作業: 固定値 + テクノロジーボーナス
  final techBonus = state.technologies
      .where((t) => t.isUnlocked)
      .fold(0, (sum, t) => sum + t.productivityBonus);
  final workDone = 3 + (techBonus ~/ 10); // 基本3 + テクノロジー補正

  final updatedProjects = state.contractProjects.map((p) {
    if (p.id == projectId) {
      return p.copyWith(currentWork: p.currentWork + workDone);
    }
    return p;
  }).toList();

  return state.copyWith(
    ap: state.ap - apCost,
    contractProjects: updatedProjects,
    turnLog: [...state.turnLog, 'CTOが「${project.name}」の開発を手伝いました (+$workDone)'],
  );
}
```

**設計根拠:**
- CTOの手動作業は基本値3（ジュニアエンジニア相当）
- テクノロジー研究による底上げ（10%ボーナスあたり+1）
- APが限られるため、社員がいない序盤の救済手段として機能

### 期待される結果

- 残業指示がプロジェクトを実際に進捗させる
- CTO手動作業がプロジェクトを実際に進捗させる
- 序盤（社員0-1人）でも受託案件を少しずつ進められる

### テスト方法

```dart
test('残業指示がプロジェクトを進捗させる', () {
  // プロジェクトにエンジニアをアサイン
  // orderOvertime 実行
  // → project.currentWork が増加していること
  // → 社員の疲労が+20、幸福度が-10されていること
});

test('workOnProjectがプロジェクトを進捗させる', () {
  // ap=3, プロジェクトあり
  // workOnProject 実行
  // → project.currentWork が増加していること
  // → ap が減少していること
});
```

---

### 012: BUG-NEW — イベント抽選の順序バイアス (P2)

### 問題の根本原因

`event_engine.dart:rollEvent` (L11-32) のイベント抽選が順序依存:

```dart
for (final event in eligibleEvents) {
  final roll = _random.nextDouble();
  final adjustedProb = event.probability * state.config.difficulty.eventSeverity;
  if (roll < adjustedProb) {
    return event; // 最初にヒットしたイベントを即座に返す
  }
}
```

**問題:**
- リスト先頭のイベント（`evt_talent_market`, probability: 0.3）は毎回30%の確率で選ばれる
- 2番目のイベントは「1番目が選ばれなかった場合に」判定されるため、実効確率が下がる
- 例: 2番目のイベント(prob=0.3)の実効確率 = 0.7 * 0.3 = 0.21（21%）
- リスト末尾のイベントはほぼ選ばれない

### 修正方針

**変更対象:** `lib/core/event_engine.dart:rollEvent`

**方式: 重み付きルーレット選択**

```dart
static GameEvent? rollEvent(GameState state) {
  final eligibleEvents = state.events.where((e) => e.canTrigger(state)).toList();
  if (eligibleEvents.isEmpty) return null;

  // 各イベントの調整済み確率を計算
  final weights = eligibleEvents.map((e) =>
    e.probability * state.config.difficulty.eventSeverity
  ).toList();

  // まず「イベントが発生するかどうか」を判定
  final totalWeight = weights.reduce((a, b) => a + b);
  final maxProbability = totalWeight.clamp(0.0, 0.6); // 最大60%でイベント発生
  if (_random.nextDouble() >= maxProbability) return null; // イベントなし

  // 重み付きルーレットで選択
  final roll = _random.nextDouble() * totalWeight;
  double cumulative = 0;
  for (var i = 0; i < eligibleEvents.length; i++) {
    cumulative += weights[i];
    if (roll < cumulative) return eligibleEvents[i];
  }
  return eligibleEvents.last;
}
```

**設計根拠:**
- 全イベントが定義された確率に比例した公平な選択確率を持つ
- `maxProbability` でイベント発生率の上限を設定（多くの条件が満たされても60%上限）
- リスト順序に依存しないフェアな抽選

### 期待される結果

- 全イベントが確率に比例して公平に発生
- リスト順序の影響がなくなる
- ゲーム体験の多様性が向上

### テスト方法

```dart
test('イベント抽選が確率に比例する', () {
  // 2つのイベント(prob=0.3, prob=0.3)で1000回ロール
  // → 両者の選択回数がほぼ同数（±5%以内）
});
```

---

### 013: BUG-NEW — TechTree研究の重複チェック不足 (P2)

### 問題の根本原因

`tech_tree_engine.dart:startResearch` (L6-43):
- 既に解禁済み(`isUnlocked`)の技術を再度研究できてしまう → 資金の無駄遣い
- 既に研究中(`currentResearchProgress > 0`)の技術をリスタートできる → 進捗リセット

### 修正方針

**変更対象:** `lib/core/tech_tree_engine.dart:startResearch`

```dart
static GameState startResearch(GameState state, String techId) {
  final tech = state.technologies.firstWhere((t) => t.id == techId);

  // 既に解禁済み
  if (tech.isUnlocked) {
    return state.copyWith(turnLog: [...state.turnLog, '${tech.name}は既に解禁済みです。']);
  }

  // 既に研究中
  if (tech.currentResearchProgress > 0) {
    return state.copyWith(turnLog: [...state.turnLog, '${tech.name}は既に研究中です。']);
  }

  // 前提技術チェック（既存）
  if (!tech.canResearch(state.unlockedTechIds)) { ... }

  // 資金チェック（既存）
  if (state.money < tech.researchCost) { ... }

  // 研究開始（既存）
  ...
}
```

### 期待される結果

- 解禁済み技術の再研究が不可能になる
- 研究中の技術を再スタートして進捗をリセットする事故を防止
- APと資金の無駄遣いを防止

### テスト方法

```dart
test('解禁済み技術は研究開始できない', () {
  // isUnlocked=true の技術で startResearch
  // → money が変化しないこと
});

test('研究中の技術は再開始できない', () {
  // currentResearchProgress > 0 の技術で startResearch
  // → progressがリセットされないこと
});
```

---

### 014: BUG-NEW — Office.productivityBonus が計算に未反映 (P2)

### 問題の根本原因

`Office` モデルに `productivityBonus` フィールドが定義されているが、エンジン層のどこでも使われていない:

- `contract_engine.dart:processProjects` — テクノロジーの `productivityBonus` のみ参照
- `employee.dart:productivity` — オフィスボーナスを考慮しない
- `saas_engine.dart:processSaaS` — オフィスボーナスを考慮しない

`happinessBonus` は `employee_engine.dart:50` で `/ 4` して使われている（ただし効果が弱い）。

### 修正方針

**変更対象:** `lib/core/contract_engine.dart:processProjects` のボーナス計算部分

テクノロジーボーナスの計算に並列して、オフィスボーナスを追加:

```dart
// 既存: テクノロジーボーナス
final techBonus = state.technologies
    .where((t) => t.isUnlocked)
    .fold(0, (sum, t) => sum + t.productivityBonus);

// 追加: オフィスボーナス
final officeBonus = state.office?.productivityBonus ?? 0;

// ボーナス倍率にオフィスを加算
final bonusMultiplier = 1.0 + (techBonus + officeBonus) / 100.0;
```

同様に `saas_engine.dart:processSaaS` の生産性計算にもオフィスボーナスを反映。

### 期待される結果

- オフィスアップグレード(009)の生産性ボーナスが実際に機能する
- 009の実装と連動してゲームプレイに影響

### テスト方法

```dart
test('オフィス生産性ボーナスが案件進捗に反映される', () {
  // productivityBonus=10 のオフィスで案件処理
  // → ボーナスなしの場合より進捗が大きいこと
});
```

---

### 015: DESIGN — 案件生成のRandom注入化 (P3)

### 問題の根本原因

`contract_engine.dart:generateProjects` (L283):
```dart
final random = DateTime.now().millisecondsSinceEpoch;
```

`loan.dart:Loan.create` (L53):
```dart
id: 'loan_${DateTime.now().millisecondsSinceEpoch}',
```

`DateTime.now()` の使用により:
- テスト時に結果が不安定（非決定的）
- 同一ミリ秒内の呼び出しで同一結果
- シード再現（リプレイ機能）が不可能

### 修正方針

**変更対象:** `lib/core/contract_engine.dart`, `lib/core/models/loan.dart`

1. `generateProjects` に `Random` パラメータを追加（デフォルトは `Random()`）
2. `Loan.create` のID生成を `uuid` パッケージまたはカウンター方式に変更
3. 将来的には `GameConfig` にマスターシードを持たせ、全Randomを統一管理

### 期待される結果

- テスト時に決定的な案件生成が可能
- 同一シードで再現可能なゲームプレイ

---

### 016: DESIGN — SaaS社員アサインの分離 (P3)

### 問題の根本原因

`saas_engine.dart:processSaaS` (L72-75):
```dart
final devEmployees = state.employees
    .where((e) => e.assignedProjectId == product.id);
```

`assignedProjectId` フィールドを受託案件とSaaS製品で共用しており、IDが衝突する可能性がある。

### 修正方針

短期的な対応として、SaaS製品IDに明示的なプレフィックス（例: `saas_`）を付与し、受託案件ID（例: `project_`）との衝突を防止。

長期的には `Employee` モデルに `assignedSaasProductId` フィールドを追加するのが望ましいが、モデル変更の影響が大きいため Phase 1 では見送り。

---

## 横断的な注意事項

### アーキテクチャ規約の遵守

- **copyWithパターン:** Office の nullable パターン (`Office? Function()? office`) を維持
- **レイヤー分離:** ロジックは `lib/core/`, 状態管理は `lib/state/`, UIは `lib/ui/`
- **import順序:** `dart:` → `package:flutter/` → `package:` → relative imports

### 実装優先度 (v2)

**Wave 1 — Critical (P1): ゲーム進行に致命的**
1. 001 イベントコスト二重減算
2. 003追加 launchSaaS AP修正
3. 011 orderOvertime / workOnProject no-op修正

**Wave 2 — High (P2): ゲームバランス・正確性**
4. 004修正 SaaSログ動的化
5. 005 qualityBonus反映
6. 006 SaaS保守費用
7. 012 イベント抽選バイアス
8. 013 研究重複チェック
9. 014 Office.productivityBonus反映

**Wave 3 — Medium (P3): バランス改善・UX・機能追加**
10. 007 ローン月利調整
11. 008 UI改善（サーバー購入disable + エンジニアフィルター）
12. 009 オフィスアップグレード
13. 015 Random注入化
14. 016 SaaS社員アサイン分離
