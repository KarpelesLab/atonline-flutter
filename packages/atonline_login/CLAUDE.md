# CLAUDE.md - Development Guide for AtOnline Login

## Build Commands
- Run all tests: `flutter test`
- Run single test: `flutter test test/atonline_login_test.dart`
- Format code: `dart format lib test`
- Analyze code: `flutter analyze`
- Run example: `cd example && flutter run`

## Code Style Guidelines
- **Imports**: Group in order: dart:core, packages, relative imports
- **Formatting**: 2-space indentation, ~80 char line length
- **Types**: Use strong typing and Dart null safety
- **Naming**:
  - Classes: PascalCase (AtOnlineLogin)
  - Variables/functions: camelCase
  - Private members: _prefixUnderscore
- **Error handling**: Use try/catch with consistent error presentation
- **Widget structure**: Required params first, then named optional params
- **Documentation**: Add comments for public APIs
- **Testing**: Add unit tests for all new functionality

This package integrates with AtOnline APIs for authentication flows.
Follow existing patterns in the codebase when adding new features.