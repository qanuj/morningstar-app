# Repository Guidelines

## Project Structure & Module Organization
- `lib/` holds production code: `screens/` for views, `providers/` for state, `services/` for API access, and `widgets/` for shared UI. Mirror this layout for new features.
- `config/`, `models/`, and `utils/` store app-wide constants, data contracts, and helpers; update them only when behavior is reused.
- `assets/` keeps images referenced from `pubspec.yaml`, while platform folders (`android/`, `ios/`, `web/`, desktop targets) change only for native integrations. Keep `test/` aligned with the structure under `lib/`.

## Build, Test, and Development Commands
- `flutter pub get` syncs dependencies after editing `pubspec.yaml` or pulling new branches.
- `./scripts/run-dev.sh` points the app at the localhost API; `./scripts/run-prod.sh` enables the production endpoint via `--dart-define`.
- `flutter run` remains useful for quick device checks, but prefer the scripts to avoid stale flags.
- `flutter test` runs unit and widget suites, and `flutter analyze` surfaces lints that block CI.

## Coding Style & Naming Conventions
- Follow Dart defaults: two-space indentation, trailing commas inside multiline widget trees, and sorted imports (`dart`, `package`, local).
- Use `UpperCamelCase` for classes and widgets, `lowerCamelCase` for members, and `snake_case.dart` for files. Providers and services should end with `Provider` or `Service` to match existing types.
- Format patches with `dart format lib test` (or `flutter format`) before submitting reviews.

## Testing Guidelines
- Place new specs beside the feature they exercise and name files `<feature>_test.dart`.
- Use widget tests for UI behavior, stubbing HTTP or Firebase calls through the abstractions in `services/` to keep runs deterministic.
- Aim for at least one happy-path and one edge-case test per feature, and report coverage gaps in the pull request body.

## Commit & Pull Request Guidelines
- Write imperative, concise commit subjects (e.g., `Add match selector`) and limit each commit to a single concern.
- Pull requests should include a summary, testing checklist (`flutter test`, `flutter analyze`, relevant run script), linked issues, and screenshots or GIFs for UI tweaks.
- Rebase on `main` before requesting review and ensure local commands match the expected CI pipeline.

## Configuration Tips
- Review `API_CONFIG.md` before adjusting endpoints, and keep secrets out of source control by relying on `--dart-define` flags.
- Update `pubspec.yaml` whenever assets or fonts change, then rerun `flutter pub get` to refresh the lockfile.
