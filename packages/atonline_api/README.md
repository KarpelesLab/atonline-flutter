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
# Basic usage - no app ID required for OPTIONS requests!
atonline_describe User

# Generate sample code for the endpoint
atonline_describe --code User:get

# Use a custom base URL (for private AtOnline instances)
atonline_describe --base-url=https://yourdomain.atonline.com/_special/rest/ User

# Show help information
atonline_describe --help
```

This tool makes direct OPTIONS requests to the API endpoints, which don't require authentication in most cases. It helps developers quickly explore the API structure and understand available endpoints without writing any code.
