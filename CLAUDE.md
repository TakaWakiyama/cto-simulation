# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CTO Simulator — Flutter + Riverpod経営シミュレーションゲーム。ITスタートアップのCTOとして、エンジニア採用・受託開発・SaaS事業・インフラ管理・技術投資を行いながら会社を成長させる。Phase 0（プロトタイプ）完了済み。

## Commands

```bash
flutter pub get              # 依存取得
flutter run                  # 実行（デフォルトデバイス）
flutter run -d chrome        # Web実行
flutter run -d macos         # macOS実行
flutter test                 # テスト実行
flutter test test/widget_test.dart  # 単体テスト指定実行
flutter analyze              # 静的解析
flutter build web            # Webビルド
flutter build ios            # iOSビルド
```

**注意:** build_runnerとriverpod_generatorは依存に入っているが未使用。コード生成（`flutter pub run build_runner build`）は不要。

## Architecture

### レイヤー分離

```
lib/core/     → ゲームロジック（純粋Dart、Flutter依存なし）
lib/state/    → Riverpod StateNotifier（UIとcoreの橋渡し）
lib/ui/       → Flutter UI（screens, widgets, theme）
```

`core/`はFlutterに依存しないため、単体テストが容易。UIロジックは`state/`経由でのみ`core/`を操作する。

### 状態管理

単一の`GameState`をSSoT（Single Source of Truth）とし、`StateNotifierProvider`で管理:

```dart
final gameProvider = StateNotifierProvider<GameNotifier, GameState>(...);
```

- `GameNotifier`がプレイヤーアクション（受注・採用・ターン進行等）をすべて処理
- UIは`ref.watch(gameProvider)`で状態を購読、`ref.read(gameProvider.notifier)`でアクション実行

### ターンエンジン（TurnEngine）

ターン進行は5+1フェーズで処理:
1. Economy — 月次経費・SaaS収益・債務処理
2. Contract — 受託プロジェクト進捗・完了判定
3. SaaS/Infra — ユーザー増減・サーバー故障
4. Employee — 疲労回復/蓄積・スキル成長・離職判定
5. Technology — 技術研究進捗
6. Event — 条件付き確率イベント発動

### データモデル規約

freezed不使用。手書きimmutableクラスで`copyWith`パターンを統一:

**通常のnullableフィールド:**
```dart
String? assignedProjectId,  // copyWithでそのまま渡せる
```

**nullを明示的にセットする必要があるフィールド（`Function()?`パターン）:**
```dart
Office? Function()? office,
GameEvent? Function()? pendingEvent,

// 使用例:
state.copyWith(office: () => newOffice)   // 値をセット
state.copyWith(pendingEvent: () => null)  // nullをセット
// copyWithに渡さない → 現在値を維持
```

このパターンは「未指定（現在値維持）」と「明示的にnullセット」を区別するために必須。

## UI Theme

ダークターミナル風（GitHub inspired）:
- 背景: `#0D1117` / Surface: `#161B22`
- Primary: Green `#3FB950` / Secondary: Blue `#58A6FF`
- フォント: JetBrains Mono（google_fontsパッケージ経由）
- 色定数は`lib/ui/theme/app_colors.dart`に集約

## Game Over条件

- 負債 > 1000万円
- 信頼度 = 0
- 120ターン到達（エンディング）

## Import規約

importは必ずファイル先頭に記述。途中でのimportは禁止。順序: `dart:` → `package:flutter/` → `package:` → relative imports。
