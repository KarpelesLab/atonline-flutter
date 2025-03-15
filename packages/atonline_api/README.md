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

The package provides a command-line tool to explore the AtOnline API schema directly from your terminal. After installing the package, you can use the `atonline_describe` command:

```bash
# Install the package globally
dart pub global activate atonline_api

# Basic usage to explore the User API
atonline_describe User

# Show information about specific endpoints
atonline_describe User:get

# Generate Dart code for the endpoint
atonline_describe --code User

# Show detailed response information
atonline_describe --verbose User

# Use a custom base URL (for private AtOnline instances)
atonline_describe --base-url=https://yourdomain.atonline.com/_special/rest/ User

# Show help information
atonline_describe --help
```

The tool sends OPTIONS requests to the API to retrieve detailed schema information, including:
- Available HTTP methods
- Database table structure
- Field types, constraints, and validations
- Access permissions
- Key relationships

For developers, this provides an easy way to explore the API without reading through documentation or writing test code. The `--code` option will even generate Dart code templates for interacting with the endpoints.
