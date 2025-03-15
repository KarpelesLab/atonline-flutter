#!/usr/bin/env dart

import 'dart:convert';
import 'dart:io';
import 'package:args/args.dart';
import 'package:http/http.dart' as http;

/// Command-line tool to explore AtOnline APIs
void main(List<String> args) async {
  final parser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage information')
    ..addFlag('code', abbr: 'c', negatable: false, help: 'Generate sample code')
    ..addFlag('verbose', abbr: 'v', negatable: false, help: 'Show detailed response information')
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
    final verbose = results['verbose'];
    final baseUrl = results['base-url'];
    final appId = results['app-id'] ?? Platform.environment['ATONLINE_APP_ID'];

    try {
      // Make request to the API
      print('Exploring API endpoint: $endpoint');
      print('API Base URL: $baseUrl');
      print('');
      
      final url = Uri.parse('$baseUrl$endpoint');
      final headers = <String, String>{};
      
      if (appId != null) {
        headers['Sec-ClientId'] = appId;
      }
      
      // Get detailed information with OPTIONS request or just do a GET
      final method = 'OPTIONS';
      final request = http.Request(method, url);
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
      
      // Print raw response for debugging if verbose
      if (verbose) {
        print('Status code: ${response.statusCode}');
        print('Headers: ${response.headers}');
        print('Body length: ${response.body.length}');
        print('Response body:');
        print('---');
        print(response.body.substring(0, response.body.length.clamp(0, 5000)));
        if (response.body.length > 5000) print('...(truncated)');
        print('---\n');
      }
      
      // Parse the response
      final dynamic data;
      try {
        if (response.body.isNotEmpty) {
          data = json.decode(response.body);
        } else {
          data = {};
        }
      } catch (e) {
        print('Error: Failed to parse response as JSON: $e');
        exit(3);
      }
      
      // Extract API info from AtOnline's response format
      if (data is Map && data.containsKey('result') && data['result'] == 'success' && data.containsKey('data')) {
        final apiData = data['data'];
        
        print('API Endpoint: $endpoint');
        
        // Extract allowed methods
        final List<String> methods = [];
        if (apiData is Map) {
          if (apiData.containsKey('allowed_methods') && apiData['allowed_methods'] is List) {
            methods.addAll((apiData['allowed_methods'] as List).map((m) => m.toString()));
          }
          
          print('Available Methods: ${methods.join(', ')}');
          
          // Print table structure if available
          if (apiData.containsKey('table') && apiData['table'] is Map) {
            final table = apiData['table'];
            if (table.containsKey('Name')) {
              print('\nTable: ${table['Name']}');
            }
            
            if (table.containsKey('Struct') && table['Struct'] is Map) {
              print('\nFields:');
              _printStructure(table['Struct'], '  ');
            }
          }

          // Print object structure if available
          if (apiData.containsKey('object') && apiData['object'] is Map) {
            print('\nObject Structure:');
            _printMap(apiData['object'], '  ');
          }
          
          // Print access information
          if (apiData.containsKey('access')) {
            print('\nAccess: ${apiData['access']}');
          }
          
          // Show any other interesting properties
          final keysToShow = {
            'Description': 'Description',
            'Full_Key': 'Full Key',
          };
          
          keysToShow.forEach((key, label) {
            if (apiData.containsKey(key)) {
              print('\n$label: ${apiData[key]}');
            }
          });
        }

        // Generate and print code if requested
        if (generateCode) {
          final code = _generateEndpointCode(endpoint, methods, appId);
          print('\nGenerated Code:');
          print('---------------');
          print(code);
        }
      } else {
        // Handle non-standard response
        print('Warning: Unexpected response format');
        print('API Endpoint: $endpoint');
        _printMap(data, '  ');
        
        // Try to generate code even with limited information
        if (generateCode) {
          print('\nGenerated Code:');
          print('---------------');
          print(_generateEndpointCode(endpoint, ['GET', 'POST'], appId));
        }
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

/// Special printing for database structure information
void _printStructure(Map<String, dynamic> struct, String indent) {
  struct.forEach((field, props) {
    if (props is Map) {
      final type = props['type'] ?? 'unknown';
      final key = props.containsKey('key') ? ' (${props['key']} KEY)' : '';
      final nullable = props.containsKey('null') ? (props['null'] == true ? ' NULL' : ' NOT NULL') : '';
      final size = props.containsKey('size') ? ' (${props['size']})' : '';
      final defaultVal = props.containsKey('default') ? ' DEFAULT: ${props['default'] ?? 'NULL'}' : '';
      
      print('$indent$field: $type$size$key$nullable$defaultVal');
      
      // Print additional properties if they exist and aren't already shown
      final propsToSkip = {'type', 'key', 'null', 'size', 'default'};
      final additionalProps = props.keys.where((k) => !propsToSkip.contains(k)).toList();
      
      if (additionalProps.isNotEmpty) {
        print('$indent  Additional properties:');
        additionalProps.forEach((p) {
          print('$indent    $p: ${props[p]}');
        });
      }
    } else {
      print('$indent$field: $props');
    }
  });
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
  
  // Generate code for PATCH method if available
  if (methods.contains('PATCH')) {
    buffer.writeln('/// Update data in $path');
    buffer.writeln('Future<dynamic> update$methodName(Map<String, dynamic> data) async {');
    buffer.writeln('  final api = AtOnline(${appId != null ? "'$appId'" : 'YOUR_APP_ID'});');
    buffer.writeln('  return await api.req(\'$path\', method: \'PATCH\', body: data);');
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
  print('  atonline_describe --verbose --base-url=https://yourdomain.atonline.com/_special/rest/ User');
  print('');
}

/// Recursively print a map with proper indentation
void _printMap(dynamic map, String indent) {
  if (map is! Map) {
    print('$indent$map');
    return;
  }
  
  map.forEach((key, value) {
    if (value is Map) {
      print('$indent$key:');
      _printMap(value, '$indent  ');
    } else if (value is List) {
      if (value.isEmpty) {
        print('$indent$key: []');
      } else if (value.length < 5) {
        print('$indent$key: [${value.join(', ')}]');
      } else {
        print('$indent$key: [Array with ${value.length} items]');
      }
    } else {
      print('$indent$key: $value');
    }
  });
}