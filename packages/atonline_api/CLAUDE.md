# CLAUDE.md for atonline_api package

## Build Commands
- `flutter pub get`: Install dependencies
- `flutter test`: Run all tests 
- `flutter test test/atonline_api_test.dart`: Run a specific test file
- `flutter analyze`: Static code analysis
- `flutter pub publish --dry-run`: Verify package can be published

## Code Style Guidelines
- **Imports**: Order by dart, flutter, then third-party packages alphabetically
- **Naming**: Use camelCase for variables/methods, PascalCase for classes
- **Types**: Prefer explicit types where possible; use nullable types with `?` suffix
- **Error Handling**: Custom exceptions (AtOnlinePlatformException, AtOnlineNetworkException)
- **Formatting**: 2-space indentation, 80-character line limit
- **Documentation**: Use dartdoc comments for public APIs
- **State Management**: Use ChangeNotifier for state changes
- **Async**: Use async/await pattern with proper Future handling
- **Privacy**: Use underscore prefix for private members

Maintain backward compatibility when making changes. For authentication, use the existing token refresh flow.