import 'package:flutter/foundation.dart';

import 'api.dart';

/// API information response from an OPTIONS request
class ApiInfo {
  /// API endpoint path
  final String path;
  /// Available HTTP methods
  final List<String> methods;
  /// Parameters description
  final Map<String, dynamic>? parameters;
  /// Response description
  final Map<String, dynamic>? response;
  /// Additional documentation
  final String? documentation;
  /// Raw response data
  final Map<String, dynamic> rawData;

  ApiInfo({
    required this.path,
    required this.methods,
    this.parameters,
    this.response,
    this.documentation,
    required this.rawData,
  });

  @override
  String toString() {
    final buffer = StringBuffer();
    
    buffer.writeln('API Endpoint: $path');
    buffer.writeln('Available Methods: ${methods.join(', ')}');
    
    if (documentation != null && documentation!.isNotEmpty) {
      buffer.writeln('\nDocumentation:');
      buffer.writeln(documentation);
    }
    
    if (parameters != null && parameters!.isNotEmpty) {
      buffer.writeln('\nParameters:');
      _writeMapRecursively(buffer, parameters!, '  ');
    }
    
    if (response != null && response!.isNotEmpty) {
      buffer.writeln('\nResponse:');
      _writeMapRecursively(buffer, response!, '  ');
    }
    
    return buffer.toString();
  }

  /// Helper method to recursively output nested maps
  void _writeMapRecursively(StringBuffer buffer, Map<String, dynamic> map, String indent) {
    map.forEach((key, value) {
      if (value is Map) {
        buffer.writeln('$indent$key:');
        _writeMapRecursively(buffer, value.cast<String, dynamic>(), '$indent  ');
      } else if (value is List) {
        buffer.writeln('$indent$key: [${value.join(', ')}]');
      } else {
        buffer.writeln('$indent$key: $value');
      }
    });
  }
}

/// API Explorer utility for discovering available endpoints and their documentation
class ApiExplorer {
  final AtOnline api;

  ApiExplorer(this.api);

  /// Get information about an API endpoint using an OPTIONS request
  /// 
  /// @param path The API endpoint path to explore
  /// @param authenticated Whether to make an authenticated request (if true)
  /// @return ApiInfo object containing details about the endpoint
  Future<ApiInfo> getEndpointInfo(String path, {bool authenticated = false}) async {
    try {
      final result = authenticated 
          ? await api.authReq(path, method: 'OPTIONS')
          : await api.req(path, method: 'OPTIONS');
      
      final methods = <String>[];
      if (result.containsKey('methods')) {
        if (result['methods'] is List) {
          methods.addAll((result['methods'] as List).cast<String>());
        } else if (result['methods'] is String) {
          methods.addAll((result['methods'] as String).split(',').map((m) => m.trim()));
        }
      }
      
      return ApiInfo(
        path: path,
        methods: methods,
        parameters: result['parameters'] as Map<String, dynamic>?,
        response: result['response'] as Map<String, dynamic>?,
        documentation: result['documentation'] as String?,
        rawData: result,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error exploring API endpoint $path: $e');
      }
      rethrow;
    }
  }

  /// Print detailed information about an API endpoint to the console
  /// 
  /// @param path The API endpoint path to explore
  /// @param authenticated Whether to make an authenticated request (if true)
  Future<void> exploreEndpoint(String path, {bool authenticated = false}) async {
    try {
      final info = await getEndpointInfo(path, authenticated: authenticated);
      print(info.toString());
    } catch (e) {
      print('Error exploring API endpoint $path: $e');
    }
  }

  /// Generate Dart code for interacting with the specified endpoint
  /// 
  /// @param path The API endpoint path to generate code for
  /// @param authenticated Whether the endpoint requires authentication
  /// @return String containing Dart code for calling the endpoint
  Future<String> generateEndpointCode(String path, {bool authenticated = false}) async {
    final info = await getEndpointInfo(path, authenticated: authenticated);
    final buffer = StringBuffer();
    
    // Generate code for GET method
    if (info.methods.contains('GET')) {
      buffer.writeln('/// Fetch data from $path');
      buffer.writeln('Future<dynamic> get${_endpointToMethodName(path)}(AtOnline api) async {');
      if (authenticated) {
        buffer.writeln('  return await api.authReq(\'$path\');');
      } else {
        buffer.writeln('  return await api.req(\'$path\');');
      }
      buffer.writeln('}');
      buffer.writeln();
    }
    
    // Generate code for POST method
    if (info.methods.contains('POST')) {
      buffer.writeln('/// Create/submit data to $path');
      buffer.writeln('Future<dynamic> create${_endpointToMethodName(path)}(AtOnline api, Map<String, dynamic> data) async {');
      if (authenticated) {
        buffer.writeln('  return await api.authReq(\'$path\', method: \'POST\', body: data);');
      } else {
        buffer.writeln('  return await api.req(\'$path\', method: \'POST\', body: data);');
      }
      buffer.writeln('}');
      buffer.writeln();
    }
    
    return buffer.toString();
  }
  
  /// Convert an API endpoint path to a valid method name
  String _endpointToMethodName(String path) {
    // Remove leading/trailing slashes and split by slashes or colons
    final parts = path.trim().replaceAll(RegExp(r'^\/+|\/+$'), '').split(RegExp(r'[\/:]'));
    
    // Convert each part to PascalCase
    final pascalCaseParts = parts.map((part) {
      if (part.isEmpty) return '';
      return part[0].toUpperCase() + part.substring(1);
    }).where((part) => part.isNotEmpty);
    
    return pascalCaseParts.join();
  }
}