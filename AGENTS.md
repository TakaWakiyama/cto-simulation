# Repository Guidelines

## Project Structure & Module Organization
- `lib/main.dart` is the Flutter entry point.
- `lib/core/` contains simulation engines (`*_engine.dart`) and domain models in `lib/core/models/`.
- `lib/state/` holds Riverpod notifiers and state orchestration.
- `lib/ui/screens/`, `lib/ui/widgets/`, and `lib/ui/theme/` contain presentation code.
- `assets/` stores static resources (`assets/fonts/`, `assets/images/`); `assets/data/` is present for game data.
- Tests live in `test/`: `test/regression_test.dart` for bug regressions, `test/widget_test.dart` for UI smoke checks, and `test/simulation/` for balance/sweep simulations.

## Build, Test, and Development Commands
- `flutter pub get`: install/update Dart and Flutter dependencies.
- `flutter analyze`: run static analysis using `flutter_lints` from `analysis_options.yaml`.
- `flutter test`: run the full test suite.
- `flutter test test/regression_test.dart`: run targeted regression checks.
- `flutter test test/simulation/final_sweep_test.dart`: run a specific simulation sweep.
- `flutter run -d macos` (or another device): launch locally.
- `dart run build_runner build --delete-conflicting-outputs`: regenerate Riverpod/build-runner outputs when annotations are added.

## Coding Style & Naming Conventions
- Follow Dart defaults: 2-space indentation, trailing commas for multi-line widgets/constructors, and formatter-friendly structure.
- File names use `snake_case.dart`; classes/enums use `PascalCase`; members/variables use `camelCase`.
- Keep game logic deterministic and concentrated in `lib/core/`; keep UI-only behavior in `lib/ui/`.
- Favor immutable state patterns (`const` constructors, `copyWith`) as used in `GameState`.

## Testing Guidelines
- Use `flutter_test` with clear `group()` and `test()` descriptions.
- Name test files `*_test.dart`; place high-level behavioral regressions in `test/regression_test.dart`.
- For balance changes, update/add simulation tests in `test/simulation/` and verify generated artifacts in `test/simulation/output/` when relevant.
- No enforced coverage threshold is configured; logic changes should still ship with focused tests.

## Commit & Pull Request Guidelines
- Recent history favors short, imperative commit subjects, with optional scoped prefixes (examples: `agent(implementer): fix BUG-12 ...`, `Fix remaining bugs: ...`).
- Reference bug IDs (for example `BUG-03`) when fixing tracked issues.
- PRs should include: purpose, key files changed, test commands run, and screenshots for UI changes (`lib/ui/screens/*`) when behavior is visual.
- Avoid unrelated platform-file churn in a single PR unless the platform change is intentional.
