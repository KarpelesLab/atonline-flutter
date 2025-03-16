# atonline_api

AtOnline API tools for Flutter

## Purpose

This package allows simple access to AtOnline APIs, such as
user accounts (oauth2), and all the services provided by AtOnline.

## Features

- OAuth2 authentication with token refresh
- API request handling with automatic authentication
- File upload handling with progress tracking
- Deep link handling for authentication flow
- User profile management
- Command-line API explorer tool with recursive exploration and parameter discovery
- Comprehensive test suite with real API integration tests

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

### File Uploads

The package provides a convenient way to upload files to AtOnline APIs with progress tracking:

```dart
import 'dart:io';
import 'package:atonline_api/atonline_api.dart';

void main() async {
  // Initialize the API client
  final api = AtOnline('your_app_id');
  
  // Make sure the user is authenticated before uploading
  try {
    // Create a File object from a local file path
    final File fileToUpload = File('/path/to/your/file.jpg');
    
    // Set optional parameters
    final uploadParams = {
      'filename': 'custom_filename.jpg',  // Override the file name
      'type': 'image/jpeg',               // Specify MIME type (auto-detected if omitted)
      'put_only': true,                   // Use simplified upload flow (optional)
    };
    
    // Track upload progress (optional)
    void progressCallback(double progress) {
      print('Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
    }
    
    // Upload the file with progress tracking
    final result = await api.authReqUpload(
      'your/upload/endpoint',
      fileToUpload,
      body: uploadParams,
      progress: progressCallback,
    );
    
    // Handle the successful upload result
    print('Upload completed. File ID: ${result.data['Blob__']}');
  } catch (e) {
    print('Upload error: $e');
  }
}
```

The upload process follows these steps:
1. First API call to get a pre-signed upload URL
2. Direct upload to storage with progress tracking
3. Final API call to complete and register the upload

After a successful upload, you'll receive a Blob ID you can use to reference or download the file.

### Command-Line API Explorer

The package provides a command-line tool to explore the AtOnline API schema directly from your terminal. After installing the package, you can use the `atonline_describe` command:

```bash
# Install the package globally
dart pub global activate atonline_api

# Basic usage to explore the User API
atonline_describe User

# Show information about specific endpoints
atonline_describe User:get

# Generate Dart code for the endpoint (includes procedure parameters)
atonline_describe --code User

# Example of generated code for an endpoint with parameters
atonline_describe --code Misc/Debug:testUpload

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
- Procedure parameters and their types
- Database table structure
- Field types, constraints, and validations
- Access permissions
- Key relationships
- Sub-endpoints and their available methods

Example output showing procedure parameters:
```
API Endpoint: Misc/Debug:testUpload
Available Methods: OPTIONS, GET, POST

Access: public

Full Key: Misc/Debug

Path: Misc/Debug

Procedure: testUpload
Static: true

Arguments:
  put_only: bool (optional)
```

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

## Testing

The package includes a comprehensive test suite that verifies core functionality using both unit tests and real API integration tests. The test coverage includes:

### Unit Tests
- Query parameter handling in GET requests
- Context parameter merging
- Cookie header formatting and parsing
- AtOnlineApiResult data access and iteration
- Error handling and exception hierarchy

### Integration Tests
The package uses AtOnline's Misc/Debug endpoints to perform real API tests without requiring authentication:

- API connection with Misc/Debug:serverTime
- Parameter handling with Misc/Debug:params
- Error handling with Misc/Debug:error
- Various response formats (strings, arrays, objects)
- File upload testing with Misc/Debug:testUpload

These tests help ensure the package works correctly with the actual AtOnline API. You can run the tests with:

```bash
flutter test
```

To generate a coverage report:

```bash
flutter test --coverage
genhtml -o coverage_report coverage/lcov.info
```

The current test coverage is approximately 33% of the codebase, with api.dart having the highest coverage at over 50%.
