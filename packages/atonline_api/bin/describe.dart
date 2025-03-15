#!/usr/bin/env dart

import 'dart:convert';
import 'dart:io';
import 'package:args/args.dart';
import 'package:http/http.dart' as http;

/// Command-line tool to explore AtOnline APIs using OPTIONS requests
void main(List<String> args) async {
  final parser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage information')
    ..addFlag('code', abbr: 'c', negatable: false, help: 'Generate sample code')
    ..addOption('base-url', abbr: 'u', 
        help: 'Base URL for API requests',
        defaultsTo: 'https://hub.atonline.com/_special/rest/')
    ..addOption('app-id', abbr: 'i', help: 'Optional AtOnline application ID');

  try {
    final results = parser.parse(args);

    if (results['help'] || results.rest.isEmpty) {
      _printUsage(parser);
      exit(0);
    }

    final endpoint = results.rest[0];
    final generateCode = results['code'];
    final baseUrl = results['base-url'];
    final appId = results['app-id'] ?? Platform.environment['ATONLINE_APP_ID'];

    try {
      // Make direct OPTIONS request to the API
      print('Exploring API endpoint: $endpoint');
      print('API Base URL: $baseUrl');
      print('');
      
      final url = Uri.parse('$baseUrl$endpoint');
      final headers = <String, String>{};
      
      if (appId != null) {
        headers['Sec-ClientId'] = appId;
      }
      
      // The http package doesn't have a direct options method, so create a custom request
      final request = http.Request('OPTIONS', url);
      request.headers.addAll(headers);
      
      final streamedResponse = await http.Client().send(request);
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode >= 300) {
        print('Error: Server returned status code ${response.statusCode}');
        if (response.body.isNotEmpty) {
          print(response.body);
        }
        exit(2);
      }
      
      // Parse and display the response
      final dynamic data;
      try {
        data = json.decode(response.body);
      } catch (e) {
        print('Error: Failed to parse response as JSON');
        print('Response body: ${response.body}');
        exit(3);
      }
      
      print('API Endpoint: $endpoint');
      
      // Extract methods
      final methods = <String>[];
      if (data.containsKey('methods')) {
        if (data['methods'] is List) {
          methods.addAll((data['methods'] as List).cast<String>());
        } else if (data['methods'] is String) {
          methods.addAll((data['methods'] as String).split(',').map((m) => m.trim()));
        }
      }
      
      if (methods.isNotEmpty) {
        print('Available Methods: ${methods.join(', ')}');
      }
      
      if (data.containsKey('documentation') && data['documentation'] != null) {
        print('\nDocumentation:');
        print(data['documentation']);
      }
      
      if (data.containsKey('parameters') && data['parameters'] != null) {
        print('\nParameters:');
        _printMap(data['parameters'], '  ');
      }
      
      if (data.containsKey('response') && data['response'] != null) {
        print('\nResponse:');
        _printMap(data['response'], '  ');
      }

      // Generate and print code if requested
      if (generateCode) {
        final code = _generateEndpointCode(endpoint, methods, appId);
        print('\nGenerated Code:');
        print('---------------');
        print(code);
      }
    } catch (e) {
      print('Error: $e');
      exit(2);
    }
  } catch (e) {
    print('Error parsing arguments: $e');
    _printUsage(parser);
    exit(1);
  }
}

/// Generate sample code for the endpoint
String _generateEndpointCode(String path, List<String> methods, String? appId) {
  final buffer = StringBuffer();
  final methodName = _endpointToMethodName(path);
  
  buffer.writeln('import \'package:atonline_api/atonline_api.dart\';');
  buffer.writeln('');
  
  // Generate code for GET method
  if (methods.contains('GET')) {
    buffer.writeln('/// Fetch data from $path');
    buffer.writeln('Future<dynamic> get$methodName() async {');
    buffer.writeln('  final api = AtOnline(${appId != null ? "'$appId'" : 'YOUR_APP_ID'});');
    buffer.writeln('  return await api.req(\'$path\');');
    buffer.writeln('}');
    buffer.writeln('');
  }
  
  // Generate code for POST method
  if (methods.contains('POST')) {
    buffer.writeln('/// Create/submit data to $path');
    buffer.writeln('Future<dynamic> create$methodName(Map<String, dynamic> data) async {');
    buffer.writeln('  final api = AtOnline(${appId != null ? "'$appId'" : 'YOUR_APP_ID'});');
    buffer.writeln('  return await api.req(\'$path\', method: \'POST\', body: data);');
    buffer.writeln('}');
    buffer.writeln('');
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

/// Print usage information
void _printUsage(ArgParser parser) {
  print('AtOnline API Explorer');
  print('');
  print('Usage: atonline_describe [options] <endpoint>');
  print('');
  print('Options:');
  print(parser.usage);
  print('');
  print('Examples:');
  print('  atonline_describe User');
  print('  atonline_describe --code User:get');
  print('  atonline_describe --base-url=https://yourdomain.atonline.com/_special/rest/ User');
  print('');
}

/// Recursively print a map with proper indentation
void _printMap(dynamic map, String indent) {
  if (map is! Map) return;
  
  map.forEach((key, value) {
    if (value is Map) {
      print('$indent$key:');
      _printMap(value, '$indent  ');
    } else if (value is List) {
      print('$indent$key: [${value.join(', ')}]');
    } else {
      print('$indent$key: $value');
    }
  });
}