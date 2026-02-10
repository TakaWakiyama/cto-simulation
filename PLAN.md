# PLAN.md v3 — CTO Simulator バグ修正・改善設計書

> **作成者:** agent-0-planner (Game Designer)
> **更新日:** 2026-02-09 Session 3
> **ステータス:** implementer向け設計書（v3: コードレビュー反映版）

---

## 変更履歴

| Version | 内容 |
|---------|------|
| v1 | 全9タスク(001-009)の設計書作成 |
| v2 | 実装レビュー + 追加バグ6件発見 + 新タスク011-015起票 |
| **v3** | **Session 3 コードレビュー。多数のバグが修正済みであることを確認。残存バグの設計を精密化** |

---

## 修正済みタスク一覧（v3で確認）

以下のタスクは mainブランチのコードで修正が確認された。設計書は参考として残すが、**追加作業は不要**。

| 旧タスク | 修正内容 | 確認箇所 |
|----------|----------|----------|
| 001 BUG-01 | イベントコスト二重減算 → effects['money']負値を全7選択肢から削除済み | event_engine.dart L111-327 |
| 002 BUG-03 | 納期超過無限ループ → overdueGraceTurns=3, _failProject(), abandonProject() 実装済み | contract_engine.dart L114,227-273 |
| 003 BUG-12 | purchaseServer/startResearch AP修正 → 成功ベースAP消費パターン実装済み | game_notifier.dart L87-94, L137-145 |
| 005 BUG-10 | qualityBonus未反映 → processProjectsのqualityDelta計算にtechQualityBonus追加済み | contract_engine.dart L171-175 |
| 006 BUG-13 | SaaS保守費用 → totalSaasMaintenanceCost + totalMonthlyCostに含む | game_state.dart L77-80 |
| 007 BAL-02 | ローン月利 → 0.008/0.012/0.018に調整済み（設計の0.01/0.015/0.02より良い） | loan.dart L5-7 |
| 014-C | Office.productivityBonus → processProjectsで使用済み | contract_engine.dart L150 |

---

## 残存タスク一覧（要修正）

| # | タスク | 優先度 | 影響ファイル |
|---|--------|--------|-------------|
| 011 | orderOvertime / workOnProject が no-op | P1 | employee_engine.dart, contract_engine.dart, game_notifier.dart |
| 012-B | launchSaaS が失敗時もAP消費 | P1 | game_notifier.dart |
| 013-C | SaaSリリースログがハードコード "50人" | P3 | saas_engine.dart |
| 013-B | 経費ログにSaaS保守費用が未表示 | P3 | economy_engine.dart |
| 014-A | イベント抽選の順序バイアス | P2 | event_engine.dart |
| 014-B | 研究の重複チェック不足 | P2 | tech_tree_engine.dart |
| 015-A | UI改善（サーバー購入disabled, アサインフィルター） | P3 | infra_tab.dart, contract_tab.dart, saas_tab.dart |
| 015-B | オフィスアップグレード機能 | P3 | office.dart, game_notifier.dart, infra_tab.dart |

---

## 011: orderOvertime / workOnProject が no-op — P1

### 問題の根本原因

**2つの独立した問題がある:**

#### A. `orderOvertime` — 疲労/幸福度のみ変更、プロジェクト進捗なし

**場所:** `employee_engine.dart:159-183` + `game_notifier.dart:80-84`

**現在の動作:**
1. `GameNotifier.orderOvertime(employeeId, projectId)` が呼ばれる
2. `EmployeeEngine.orderOvertime()` が社員の fatigue+20, happiness-10 を適用し、新stateを返す
3. `GameNotifier` がAPを消費

**問題:** `EmployeeEngine.orderOvertime()` は社員の疲労/幸福度のみ変更し、`projectId` パラメータを使わない。プロジェクトの `currentWork` は一切増加しない。

**結論:** プレイヤーはAPと社員の体力を消費して、何のリターンもない。

#### B. `workOnProject` — APだけ消費して何もしない

**場所:** `contract_engine.dart:317-336`

```dart
static GameState workOnProject(GameState state, String projectId, {
  int apCost = 1, bool isOvertime = false,
}) {
  if (state.ap < apCost) {
    return state.copyWith(turnLog: [...state.turnLog, 'APが不足しています。']);
  }
  return state.copyWith(ap: state.ap - apCost);  // ← AP消費のみ！
}
```

**問題:** AP消費後に `currentWork` を増加させるロジックが完全に欠落している。さらに、このメソッドは `GameNotifier` から呼ばれていない（dead code）。

### 修正方針

**方針: orderOvertime をメインの「手動作業加速」アクションとして実装する**

`workOnProject` は現在呼ばれておらず、`orderOvertime` はUIから呼ばれているため、`orderOvertime` を正しく実装し、`workOnProject` は内部ヘルパーとして活用する設計にする。

#### Step 1: `ContractEngine.workOnProject` を実装する

**変更対象:** `lib/core/contract_engine.dart:317-336`

```dart
/// 案件の開発を手動で進める
static GameState workOnProject(
  GameState state,
  String projectId,
  String employeeId, {
  bool isOvertime = false,
}) {
  final project = state.contractProjects.firstWhere(
    (p) => p.id == projectId,
    orElse: () => throw StateError('Project not found: $projectId'),
  );

  if (project.status != ProjectStatus.inProgress &&
      project.status != ProjectStatus.overdue) {
    return state;
  }

  final employee = state.employees.firstWhere(
    (e) => e.id == employeeId,
    orElse: () => throw StateError('Employee not found: $employeeId'),
  );

  // テクノロジーボーナス
  final techBonus = state.technologies
      .where((t) => t.isUnlocked)
      .fold(0, (sum, t) => sum + t.productivityBonus);
  final officeBonus = state.office?.productivityBonus ?? 0;
  final bonusMultiplier = 1.0 + (techBonus + officeBonus) / 100.0;

  // 個人の生産性に基づく作業量
  // processProjects は全員の合計/10 だが、手動は1人の即時作業なので /5 で高めに
  final baseWork = employee.productivity * bonusMultiplier;
  final overtimeMultiplier = isOvertime ? 1.5 : 1.0;
  final workDone = (baseWork * overtimeMultiplier / 5).round().clamp(1, 999);

  // プロジェクト進捗を更新
  final updatedProjects = state.contractProjects.map((p) {
    if (p.id == projectId) {
      return p.copyWith(
        currentWork: (p.currentWork + workDone).clamp(0, p.totalWork),
      );
    }
    return p;
  }).toList();

  final updated = updatedProjects.firstWhere((p) => p.id == projectId);
  final logSuffix = isOvertime ? '（残業）' : '';

  return state.copyWith(
    contractProjects: updatedProjects,
    turnLog: [
      ...state.turnLog,
      '${employee.name}が「${project.name}」を作業$logSuffix: +$workDone工数 (${(updated.progress * 100).toStringAsFixed(0)}%)',
    ],
  );
}
```

**設計根拠:**
- `processProjects`（ターン終了時自動）: 全社員の合計生産性 × bonus / 10
- `workOnProject`（手動）: 1人の生産性 × bonus / 5（手動はターン内即時なのでやや効率高め）
- 残業時は 1.5倍の作業量
- 最低1工数を保証（`clamp(1, 999)`）

#### Step 2: `EmployeeEngine.orderOvertime` を拡張する

**変更対象:** `lib/core/employee_engine.dart:158-183`

```dart
/// 残業指示（社員状態の変更 + プロジェクト作業進捗）
static GameState orderOvertime(
  GameState state,
  String employeeId,
  String projectId,
) {
  final empIndex = state.employees.indexWhere((e) => e.id == employeeId);
  if (empIndex < 0) return state;

  final employee = state.employees[empIndex];

  // 1. プロジェクト進捗を追加（ContractEngine経由）
  var updatedState = ContractEngine.workOnProject(
    state, projectId, employeeId, isOvertime: true,
  );

  // 2. 社員の疲労増加・幸福度低下
  final updatedEmployee = employee.copyWith(
    fatigue: (employee.fatigue + 20).clamp(0, 100),
    happiness: (employee.happiness - 10).clamp(0, 100),
  );

  final employees = List<Employee>.from(updatedState.employees);
  // empIndex は state.employees から取得したので、updatedState でも同じインデックス
  // ただし workOnProject が employees を変更しないため安全
  final newEmpIndex = employees.indexWhere((e) => e.id == employeeId);
  employees[newEmpIndex] = updatedEmployee;

  return updatedState.copyWith(
    employees: employees,
  );
  // ログは workOnProject 内で出力済み + 疲労情報はログに含めない（UIで確認可能）
}
```

**注意:** `workOnProject` のログとは別に疲労情報を表示したい場合は、追加のturnLog行を入れてもよい。

#### Step 3: GameNotifier.orderOvertime はそのまま

現在の実装:
```dart
void orderOvertime(String employeeId, String projectId) {
  if (!_canAfford(ActionCategory.management)) return;
  state = EmployeeEngine.orderOvertime(state, employeeId, projectId);
  state = state.copyWith(ap: state.ap - _apCost(ActionCategory.management));
}
```

**これはそのまま正しく動作する。** `EmployeeEngine.orderOvertime` が正しいstateを返すようになれば、AP消費行がそのstateを上書きしても、copyWithは指定したフィールド(ap)のみ変更し、他のフィールド(employees, contractProjects, turnLog)は前行のstateを維持する。

### 期待される結果

- `orderOvertime`: AP消費 + 社員疲労+20/幸福度-10 + プロジェクト進捗（通常の1.5倍）
- 残業によるプロジェクト加速と社員のコンディション悪化のトレードオフが機能する
- ログに作業量が表示される

### テスト方法

```dart
test('orderOvertime がプロジェクト進捗を増加させる', () {
  // 1. employee(productivity: 50) を project(totalWork: 100) にアサイン
  // 2. orderOvertime(employeeId, projectId) を実行
  // 3. project.currentWork > 0 であること
  // 4. employee.fatigue が +20 されていること
  // 5. employee.happiness が -10 されていること
});

test('workOnProject が進捗を増加させる', () {
  // 1. project(currentWork: 0, totalWork: 100)
  // 2. ContractEngine.workOnProject(state, projectId, employeeId) を実行
  // 3. currentWork > 0 であること
});
```

---

## 012-B: launchSaaS が失敗時もAP消費 — P1

### 問題の根本原因

**場所:** `game_notifier.dart:130-134`

```dart
void launchSaaS(String productId) {
  if (!_canAfford(ActionCategory.tech)) return;
  state = SaaSEngine.launchProduct(state, productId);
  state = state.copyWith(ap: state.ap - _apCost(ActionCategory.tech));
}
```

`SaaSEngine.launchProduct` は以下のケースで失敗する:
- `state.totalServerCapacity <= 0`（サーバーがない）
- 該当製品の `isDevelopmentComplete` が false（開発未完了）

失敗時はログだけ出してstateを返すが、`launchSaaS` はその後無条件にAPを消費する。

**対比:** `purchaseServer`（L87-94）と `startResearch`（L137-145）は成功ベースAP消費が実装済み。

### 修正方針

**変更対象:** `lib/state/game_notifier.dart:130-134`

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

**設計根拠:**
- `isLaunched` が false → true に変わっていれば成功
- `purchaseServer` の `servers.length` チェックと同じパターン

### 期待される結果

- サーバーなしでSaaSリリース試行 → AP消費なし
- 開発未完了でリリース試行 → AP消費なし
- 正常リリース → AP消費あり

### テスト方法

```dart
test('launchSaaS 失敗時にAPが消費されない', () {
  // サーバーなし、SaaS開発完了済みの状態
  // launchSaaS 実行 → AP変化なし
});
```

---

## 013-C: SaaSリリースログのハードコード — P3

### 問題の根本原因

**場所:** `saas_engine.dart:136`

```dart
'${product.name}をリリースしました！ 初期ユーザー: 50人 (信頼度+5)',
```

実際の初期ユーザー数は L123 の `totalUsers: 50` だが、ログ文字列が数値をハードコードしている。将来初期ユーザー数を変更した場合にログとの不整合が発生する。

### 修正方針

**変更対象:** `lib/core/saas_engine.dart:136`

```dart
// 修正前:
'${product.name}をリリースしました！ 初期ユーザー: 50人 (信頼度+5)',

// 修正後:
'${product.name}をリリースしました！ 初期ユーザー: ${product.totalUsers}人 (信頼度+5)',
```

**注意:** `product` は L129 の `updatedProducts.firstWhere` で取得した更新後のオブジェクト。`totalUsers` は50にセット済みなので正しい値が表示される。

### テスト方法

```dart
test('リリースログに実際のユーザー数が表示される', () {
  // 開発完了済みSaaS + サーバーあり
  // launchProduct 実行
  // turnLog に '初期ユーザー: 50人' が含まれる（テンプレートリテラルから生成）
});
```

---

## 013-B: 経費ログにSaaS保守費用が未表示 — P3

### 問題の根本原因

**場所:** `economy_engine.dart:18`

```dart
log.add('月次経費: -${totalExpense}万円 (給与: ${state.totalSalary}, サーバー: ${state.totalServerCost}, オフィス: ${state.officeCost})');
```

`totalMonthlyCost` の計算自体は SaaS保守費用を含むようになった（game_state.dart L80）が、ログの内訳表示にSaaS保守が含まれていない。

プレイヤーは経費の内訳が合わない（表示の合計 < 実際の引き落とし）ことに混乱する可能性がある。

### 修正方針

**変更対象:** `lib/core/economy_engine.dart:18`

```dart
// 修正前:
log.add('月次経費: -${totalExpense}万円 (給与: ${state.totalSalary}, サーバー: ${state.totalServerCost}, オフィス: ${state.officeCost})');

// 修正後:
final saasMaintenanceStr = state.totalSaasMaintenanceCost > 0
    ? ', SaaS保守: ${state.totalSaasMaintenanceCost}'
    : '';
log.add('月次経費: -${totalExpense}万円 (給与: ${state.totalSalary}, サーバー: ${state.totalServerCost}, オフィス: ${state.officeCost}$saasMaintenanceStr)');
```

**設計根拠:** SaaS保守費用がゼロの場合（SaaS未リリース時）は表示を省略して、ログの見やすさを維持。

### テスト方法

```dart
test('SaaS保守費用が経費ログに表示される', () {
  // isLaunched=true のSaaS製品がある状態
  // processMonthlyExpenses 実行
  // turnLog に 'SaaS保守:' が含まれること
});
```

---

## 014-A: イベント抽選の順序バイアス — P2

### 問題の根本原因

**場所:** `event_engine.dart:21-31`

```dart
for (final event in eligibleEvents) {
  final roll = _random.nextDouble();
  final adjustedProb = event.probability * state.config.difficulty.eventSeverity;
  if (roll < adjustedProb) {
    return event;
  }
}
```

リスト先頭のイベントから順に独立した確率チェックを行い、最初にパスしたものを返す。

**問題:** リスト先頭のイベントが統計的に選ばれやすい。

**具体例:** eventSeverity=1.0、2つのイベント A(prob=0.3), B(prob=0.3) の場合:
- P(A選択) = 0.3 = 30%
- P(B選択) = P(A不選択) × P(B選択) = 0.7 × 0.3 = 21%
- P(どちらも選択されない) = 0.7 × 0.7 = 49%

Aは Bより 43% 高い確率で選ばれる（30% vs 21%）。

### 修正方針

**方針: 重み付きルーレット選択（Weighted Roulette Selection）に変更**

**変更対象:** `lib/core/event_engine.dart:rollEvent`

```dart
static GameEvent? rollEvent(GameState state, List<GameEvent> allEvents) {
  final eligibleEvents = allEvents.where((event) {
    if (state.triggeredEventIds.contains(event.id) && event.isOneTime) {
      return false;
    }
    return event.canTrigger(state.currentTurn, state.toConditionMap());
  }).toList();

  if (eligibleEvents.isEmpty) return null;

  // Step 1: 各イベントの調整済み確率を計算
  final adjustedProbs = eligibleEvents.map((e) =>
    e.probability * state.config.difficulty.eventSeverity
  ).toList();

  // Step 2: 「イベントが1つも発生しない」確率を計算
  // 全イベントの発生確率の最大値を「このターンでイベントが起きる確率」として使う
  final maxProb = adjustedProbs.reduce((a, b) => a > b ? a : b);

  // Step 3: まず「今回イベントが発生するか」を判定
  final occurRoll = _random.nextDouble();
  if (occurRoll >= maxProb) {
    return null;  // イベントなし
  }

  // Step 4: イベントが発生する場合、重みに基づいて公平に1つ選択
  final totalWeight = adjustedProbs.fold(0.0, (sum, p) => sum + p);
  final selectRoll = _random.nextDouble() * totalWeight;

  var cumulative = 0.0;
  for (var i = 0; i < eligibleEvents.length; i++) {
    cumulative += adjustedProbs[i];
    if (selectRoll < cumulative) {
      return eligibleEvents[i];
    }
  }

  return eligibleEvents.last;  // 浮動小数点の丸め対策
}
```

**設計根拠:**
- Step 3: 元のコードでは「全体的にイベントが起きやすさ」が確率の合計値ではなく個別の確率で制御されていた。`maxProb` を使うことで、「最も起きやすいイベント」の確率でイベント発生を判定する（ゲームの難易度感を維持）
- Step 4: イベントが発生する場合、確率の比率で公平に選択。prob=0.3のイベントは prob=0.15のイベントの2倍選ばれやすい
- 結果: リスト順序による統計的バイアスが解消される

**注意:** 「イベント発生頻度」が元のロジックと大きく変わらないよう、maxProbを使ってイベント発生判定を行う。sumProbを使うとイベントが起きすぎる可能性がある。

### 代替案（よりシンプルだが発生頻度が変わる）

元のロジックとの互換性を最重視する場合:

```dart
// 元のロジックと同じ「合計発生確率」を維持しつつ、順序バイアスを除去
// P(少なくとも1つ発生) = 1 - Π(1 - p_i)
final noEventProb = adjustedProbs.fold(1.0, (prod, p) => prod * (1 - p));
final eventProb = 1 - noEventProb;

if (_random.nextDouble() >= eventProb) return null;

// 発生する場合、確率比で選択
// ... (Step 4 と同じ)
```

**推奨は最初の案**（maxProb方式）。理由: 元のロジックでもリスト1番目しかほぼ評価されないため、体感的なイベント発生頻度は maxProb に近い。

### テスト方法

```dart
test('イベント抽選がリスト順序に依存しない', () {
  // 同一確率の2イベントを用意
  // 1000回抽選して各イベントの選択回数を記録
  // 選択回数の差が10%以内（統計的に公平）
  // 注: _random をテスト用に固定seedで注入する必要あり → 015-Random注入と併せて対応
});
```

---

## 014-B: 研究の重複チェック不足 — P2

### 問題の根本原因

**場所:** `tech_tree_engine.dart:7-43`

`startResearch` メソッドは以下のチェックを行う:
1. `canResearch(state.unlockedTechIds)` — 前提技術が解禁済みか
2. `state.money < tech.researchCost` — 資金が足りるか

**不足しているチェック:**
- 既に `isUnlocked == true`（研究完了済み）の技術を再度研究開始できてしまう
- 既に `isResearching == true`（研究中）の技術を再度研究開始できてしまう

いずれの場合も `currentResearchProgress` が1にリセットされ、研究費用が二重に請求される。

### 修正方針

**変更対象:** `lib/core/tech_tree_engine.dart:startResearch` L7-43

`canResearch` チェックの前に追加:

```dart
static GameState startResearch(GameState state, String techId) {
  final tech = state.technologies.firstWhere((t) => t.id == techId);

  // 既に解禁済み
  if (tech.isUnlocked) {
    return state.copyWith(
      turnLog: [
        ...state.turnLog,
        '${tech.name}は既に研究完了しています。',
      ],
    );
  }

  // 既に研究中
  if (tech.isResearching) {
    return state.copyWith(
      turnLog: [
        ...state.turnLog,
        '${tech.name}は既に研究中です。',
      ],
    );
  }

  // 前提技術チェック（既存）
  if (!tech.canResearch(state.unlockedTechIds)) {
    return state.copyWith(
      turnLog: [
        ...state.turnLog,
        '前提技術が未解禁のため、研究を開始できません。',
      ],
    );
  }

  // 資金チェック（既存）
  if (state.money < tech.researchCost) {
    // ... 既存のまま
  }

  // ... 残りは既存のまま
}
```

**game_notifier.dart側の注意:**

`startResearch` メソッド（L137-145）は「資金が減ったらAP消費」パターンを使っている:

```dart
final prevMoney = state.money;
state = TechTreeEngine.startResearch(state, techId);
if (state.money < prevMoney) {
  state = state.copyWith(ap: state.ap - _apCost(ActionCategory.tech));
}
```

重複チェックで弾かれた場合は `money` が変わらないため、AP消費されない。**game_notifier側の変更は不要。**

### テスト方法

```dart
test('解禁済み技術の再研究ができない', () {
  // isUnlocked=true の技術に対して startResearch
  // → money が変わらない
  // → turnLog に '既に研究完了' メッセージ
});

test('研究中技術の再研究ができない', () {
  // currentResearchProgress > 0 の技術に対して startResearch
  // → money が変わらない
  // → turnLog に '既に研究中' メッセージ
});
```

---

## 015-A: UI改善 — P3

### A. サーバー購入ボタンの資金チェック

**変更対象:** `lib/ui/screens/infra_tab.dart`

サーバー購入ボタンの条件:
```dart
// サーバー購入の初期費用はサーバーの種類によって異なる
// InfraEngine.purchaseServer 内で money チェックしている
// UI側では money < purchaseCost のときボタンを disabled にする

ElevatedButton(
  onPressed: state.money >= server.purchaseCost
    ? () => ref.read(gameProvider.notifier).purchaseServer(server)
    : null,  // null = disabled
  child: Text('購入 (${server.purchaseCost}万円)'),
)
```

**注意:** `server.purchaseCost` プロパティの有無を確認する必要あり。`InfraEngine.purchaseServer` 内のコスト計算ロジックを参照して、UI側でも同じ値を使う。

### B. アサインダイアログのエンジニアフィルター

**変更対象:** `lib/ui/screens/contract_tab.dart`, `lib/ui/screens/saas_tab.dart`

アサイン候補のフィルタリング:
```dart
// 修正前（推定）:
final candidates = state.unassignedEmployees;

// 修正後:
final candidates = state.unassignedEmployees
    .where((e) => e.type == EmployeeType.engineer)
    .toList();
```

**設計根拠:** マーケター、バックオフィスはコード開発に参加できないため、プロジェクトアサイン候補から除外。StaffBonusEngine による間接効果は別途反映されている。

### テスト方法

UI widget テスト:
```dart
testWidgets('サーバー購入ボタンが資金不足時にdisabled', (tester) async {
  // money=0 の状態でinfra_tabを描画
  // サーバー購入ボタンがタップ不可であること
});

testWidgets('アサインダイアログにエンジニアのみ表示', (tester) async {
  // engineer + marketer の社員がいる状態
  // アサインダイアログを開く
  // マーケターが表示されないこと
});
```

---

## 015-B: オフィスアップグレード機能 — P3

### 問題の根本原因

`Office` モデルが存在し、`maxEmployees`, `monthlyCost`, `happinessBonus`, `productivityBonus` フィールドがあるが、初期オフィスのみでアップグレード手段がない。

### オフィスグレード定義

| ID | 名前 | 社員上限 | 月額(万円) | 幸福度Bonus | 生産性Bonus | 購入費(万円) |
|---|---|---|---|---|---|---|
| office_garage | ガレージオフィス | 5 | 5 | 0 | 0 | 0 (初期) |
| office_coworking | コワーキングスペース | 8 | 15 | 5 | 5 | 50 |
| office_small | 小規模オフィス | 15 | 30 | 10 | 8 | 150 |
| office_medium | 中規模オフィス | 30 | 60 | 15 | 12 | 400 |
| office_large | 大規模オフィス | 50 | 100 | 20 | 15 | 800 |

**ゲームバランス考察:**
- ガレージ→コワーキング: 序盤の50万は投資判断として適切（月15万の固定費増に見合うか）
- 最上位の大規模オフィスは800万の投資 + 月100万のランニングコスト。中盤以降のSaaS収益が安定してから検討するレベル
- `productivityBonus` は processProjects の `bonusMultiplier` に反映される（既に実装済み）
- `happinessBonus` は EmployeeEngine.processEmployeeTurn 等で社員の幸福度維持に使う（要追加実装）

### 修正方針

#### 1. オフィスマスターデータ

**変更対象:** `lib/core/models/office.dart`

```dart
class Office {
  // ... 既存フィールド ...

  /// 全オフィスの一覧（アップグレード順）
  static const List<Office> allGrades = [
    Office(id: 'office_garage', name: 'ガレージオフィス', maxEmployees: 5, monthlyCost: 5, description: 'スタートアップの原点'),
    Office(id: 'office_coworking', name: 'コワーキングスペース', maxEmployees: 8, monthlyCost: 15, happinessBonus: 5, productivityBonus: 5, description: '他社との交流でモチベUP'),
    Office(id: 'office_small', name: '小規模オフィス', maxEmployees: 15, monthlyCost: 30, happinessBonus: 10, productivityBonus: 8, description: '自社専用の開発空間'),
    Office(id: 'office_medium', name: '中規模オフィス', maxEmployees: 30, monthlyCost: 60, happinessBonus: 15, productivityBonus: 12, description: 'ワンフロアの広々空間'),
    Office(id: 'office_large', name: '大規模オフィス', maxEmployees: 50, monthlyCost: 100, happinessBonus: 20, productivityBonus: 15, description: '自社ビルで圧倒的存在感'),
  ];

  /// アップグレード費用マップ
  static const Map<String, int> upgradeCosts = {
    'office_garage': 0,
    'office_coworking': 50,
    'office_small': 150,
    'office_medium': 400,
    'office_large': 800,
  };

  /// このオフィスのグレードインデックス（0=最低）
  int get gradeIndex => allGrades.indexWhere((o) => o.id == id);

  /// 次のアップグレード先
  Office? get nextUpgrade {
    final idx = gradeIndex;
    if (idx < 0 || idx >= allGrades.length - 1) return null;
    return allGrades[idx + 1];
  }
}
```

#### 2. アップグレードロジック

**変更対象:** `lib/state/game_notifier.dart`

```dart
void upgradeOffice(String newOfficeId) {
  if (!_canAfford(ActionCategory.management)) return;

  final newOffice = Office.allGrades.firstWhere((o) => o.id == newOfficeId);
  final cost = Office.upgradeCosts[newOfficeId] ?? 0;

  // 資金チェック
  if (state.money < cost) {
    state = state.copyWith(
      turnLog: [...state.turnLog, 'オフィスアップグレードの費用（${cost}万円）が不足しています。'],
    );
    return;
  }

  // 現在のオフィスよりグレードが上かチェック
  final currentIndex = state.office?.gradeIndex ?? -1;
  final newIndex = newOffice.gradeIndex;
  if (newIndex <= currentIndex) {
    state = state.copyWith(
      turnLog: [...state.turnLog, '現在のオフィス以下のグレードにはダウングレードできません。'],
    );
    return;
  }

  state = state.copyWith(
    office: () => newOffice,
    money: state.money - cost,
    ap: state.ap - _apCost(ActionCategory.management),
    turnLog: [
      ...state.turnLog,
      'オフィスを「${newOffice.name}」にアップグレードしました！ -${cost}万円 (社員上限: ${newOffice.maxEmployees}人)',
    ],
  );
}
```

#### 3. happinessBonus の反映

**変更対象:** `lib/core/employee_engine.dart` の processEmployeeTurn（ターン終了時）

幸福度回復処理にオフィスボーナスを加算:

```dart
// 既存の幸福度変動ロジックに追加:
final officeHappinessBonus = state.office?.happinessBonus ?? 0;
// ターンごとに officeHappinessBonus/10 程度の幸福度回復ボーナス
// （大きすぎるとバランスが崩れるので控えめに）
```

**注意:** `happinessBonus` が具体的にどう反映されるかは processEmployeeTurn の既存ロジックを確認してから決定する必要がある。

#### 4. UIコンポーネント

**変更対象:** `lib/ui/screens/infra_tab.dart`

```
[現在のオフィス情報カード]
  名前: コワーキングスペース
  社員上限: 8人 / 月額: 15万円
  生産性+5% / 幸福度+5

[アップグレードボタン]
  → 小規模オフィス (150万円)
    社員上限15人 / 月額30万円 / 生産性+8% / 幸福度+10
```

### テスト方法

```dart
test('オフィスアップグレードが正しく適用される', () {
  // 初期状態（ガレージ）
  // upgradeOffice('office_coworking') 実行
  // state.office.id == 'office_coworking'
  // state.money が 50万円減少
  // state.maxEmployees == 8
});

test('資金不足でアップグレードできない', () {
  // money=10 でアップグレード試行
  // → office が変わらない
});

test('ダウングレードできない', () {
  // 現在 office_small → office_coworking にアップグレード試行
  // → office が変わらない
});
```

---

## 追加発見事項（今回のスコープ外・将来タスク）

### A. `startSaaSDevelopment` の重複チェック不足

**場所:** `game_notifier.dart:103-127`

同じSaaS製品を複数回開発開始できてしまう。`state.saasProducts` に同じIDの製品が重複して追加される可能性がある。

```dart
// 追加すべきチェック:
if (state.saasProducts.any((p) => p.id == productId)) {
  state = state.copyWith(
    turnLog: [...state.turnLog, 'この製品は既に開発中/リリース済みです。'],
  );
  return;
}
```

### B. `DateTime.now()` の使用によるテスト不安定性

**場所:**
- `contract_engine.dart:388` — `DateTime.now().millisecondsSinceEpoch` でRandom seed
- `loan.dart:53` — `DateTime.now().millisecondsSinceEpoch` でローンID生成

テスト時に結果が不安定になる。将来的に `Random` インスタンスを外部から注入可能にするリファクタリングが望ましい。

### C. `happinessBonus` のターン処理への反映（015-Bと連携）

`Office.happinessBonus` はオフィスアップグレード実装時に併せて反映する必要がある。`processEmployeeTurn` 内での幸福度回復ロジックにボーナスを加算する。

### D. acceptProject の AP消費パターン不整合

**場所:** `game_notifier.dart:47-51`

```dart
void acceptProject(String projectId) {
  if (!_canAfford(ActionCategory.sales)) return;
  state = ContractEngine.acceptProject(state, projectId);
  state = state.copyWith(ap: state.ap - _apCost(ActionCategory.sales));
}
```

`acceptProject` は成功チェックなしにAPを消費する。ただし `ContractEngine.acceptProject` は受注可能な案件がある限り失敗しないため、実質問題ない。低優先度。
