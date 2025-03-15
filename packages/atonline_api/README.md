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
- Command-line API explorer tool with recursive exploration

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

# Use a custom base URL
atonline_describe --base-url=https://ws.atonline.com/_special/rest/ User

# Get a list of all top-level endpoints (explore the root)
atonline_describe --base-url=https://ws.atonline.com/_special/rest/ /

# Recursive exploration of endpoints and their sub-endpoints
atonline_describe --recursive --depth=2 --base-url=https://ws.atonline.com/_special/rest/ User

# Shorthand form for recursive exploration with depth 1
atonline_describe -r -d 1 --base-url=https://ws.atonline.com/_special/rest/ /

# Show help information
atonline_describe --help
```

The tool sends OPTIONS requests to the API to retrieve detailed schema information, including:
- Available HTTP methods
- Database table structure
- Field types, constraints, and validations
- Access permissions
- Key relationships
- Sub-endpoints and their available methods

#### Recursive Exploration

The `--recursive` (or `-r`) flag enables recursive exploration of endpoints, traversing through sub-endpoints automatically. This is especially useful for:

1. Discovering the full API structure starting from the root (`/`)
2. Automatically documenting a large section of the API
3. Finding all available operations within a specific domain (e.g., all User-related endpoints)

The `--depth` parameter controls how many levels deep the recursive exploration goes:
- Depth 1: Only immediate sub-endpoints
- Depth 2: Sub-endpoints and their sub-endpoints
- And so on...

Example output of recursive exploration:
```
Exploring API endpoint: /
...
Sub-Endpoints:
  User [SUB, OPTIONS, GET, POST, PATCH]
  Order [SUB, OPTIONS, GET, POST]
  ...

=================>  Exploring: /User (Depth: 1 of 1)
...
Sub-Endpoints:
  Profile [OPTIONS, GET, PATCH]
  Wallet [SUB, OPTIONS, GET]
  ...
```

For developers, this provides an easy way to explore the API without reading through documentation or writing test code. The `--code` option will even generate Dart code templates for interacting with the endpoints.
