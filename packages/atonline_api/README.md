# atonline_api

AtOnline API tools for Flutter

## Purpose

This package allows simple access to AtOnline APIs, such as
user accounts (oauth2), and all the services provided by AtOnline.

## Features

- OAuth2 authentication with token refresh
- API request handling with automatic authentication
- Deep link handling for authentication flow
- User profile management
- API discovery and documentation

## Usage

### Basic API requests

```dart
import 'package:atonline_api/atonline_api.dart';

void main() async {
  // Initialize the API client
  final api = AtOnline('your_app_id');
  
  // Make an unauthenticated request
  try {
    final result = await api.req('some/endpoint');
    print('Result: ${result.data}');
  } catch (e) {
    print('Error: $e');
  }
  
  // Make an authenticated request (requires login)
  try {
    final result = await api.authReq('user/profile');
    print('Profile: ${result.data}');
  } catch (e) {
    print('Error: $e');
  }
}
```

### API Explorer

The package includes an API Explorer tool that allows you to discover available endpoints and their documentation:

```dart
import 'package:atonline_api/atonline_api.dart';

void main() async {
  final api = AtOnline('your_app_id');
  final explorer = ApiExplorer(api);
  
  // Explore an API endpoint
  await explorer.exploreEndpoint('User:get', authenticated: true);
  
  // Generate code for interacting with an endpoint
  final code = await explorer.generateEndpointCode('User:get', authenticated: true);
  print(code);
}
```

### Command-Line API Explorer

The package also provides a command-line tool to explore APIs directly from your terminal. After installing the package, you can use the `atonline_describe` command:

```bash
# Basic usage
atonline_describe --app-id=your_app_id User

# Authenticated request with code generation
atonline_describe --app-id=your_app_id --auth --code User:get

# Show help information
atonline_describe --help
```

You can also set the `ATONLINE_APP_ID` environment variable instead of using the `--app-id` option:

```bash
export ATONLINE_APP_ID=your_app_id
atonline_describe User
```

This tool helps developers quickly explore the API structure and understand available endpoints without writing any code.
