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
    ..addFlag('recursive', abbr: 'r', negatable: false, help: 'Recursively explore sub-endpoints')
    ..addOption('depth', abbr: 'd', help: 'Maximum depth for recursive exploration', defaultsTo: '1')
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
    final recursive = results['recursive'];
    final maxDepth = int.parse(results['depth']);
    final baseUrl = results['base-url'];
    final appId = results['app-id'] ?? Platform.environment['ATONLINE_APP_ID'];

    if (recursive) {
      await _exploreRecursively(endpoint, baseUrl, appId, verbose, generateCode, 0, maxDepth);
    } else {
      // Regular single endpoint exploration
      await _exploreEndpoint(endpoint, baseUrl, appId, verbose, generateCode);
    }
  } catch (e) {
    print('Error parsing arguments: $e');
    _printUsage(parser);
    exit(1);
  }
}

/// Explores a single API endpoint and prints information about it
Future<Map<String, dynamic>> _exploreEndpoint(String endpoint, String baseUrl, String? appId, 
    bool verbose, bool generateCode) async {
  try {
    // Make request to the API
    print('Exploring API endpoint: $endpoint');
    print('API Base URL: $baseUrl');
    print('');
      
    // Handle the root endpoint specially to avoid double slashes
    String fullUrl;
    if (endpoint.isEmpty || endpoint == '/') {
      fullUrl = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    } else {
      fullUrl = '$baseUrl${endpoint.startsWith('/') ? endpoint.substring(1) : endpoint}';
    }
    
    final url = Uri.parse(fullUrl);
    print('Request URL: $url');
    print('');
    
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
      
      // Handle redirects - show where they're redirecting to
      if (response.statusCode == 301 || response.statusCode == 302) {
        if (response.headers.containsKey('location')) {
          print('Redirect to: ${response.headers['location']}');
        }
      }
      
      if (response.body.isNotEmpty) {
        print(response.body);
      }
      return <String, dynamic>{}; // Return empty map on error
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
      return <String, dynamic>{}; // Return empty map on parsing error
    }
    
    // Extract API info from AtOnline's response format
    if (data is Map && data.containsKey('result') && data['result'] == 'success' && data.containsKey('data')) {
      final apiData = data['data'];
      
      print('API Endpoint: $endpoint');
      
      // Extract allowed methods
      final List<String> methods = [];
      if (apiData is Map) {
        // Check both allowed_methods (table) and allowed_methods_object (no table)
        final methodsKeys = ['allowed_methods', 'allowed_methods_object'];
        
        for (final key in methodsKeys) {
          if (apiData.containsKey(key) && apiData[key] is List) {
            methods.addAll((apiData[key] as List).map((m) => m.toString()));
          }
        }
        
        // Check Access-Control headers for methods
        if (methods.isEmpty && data.containsKey('headers')) {
          final headers = data['headers'];
          if (headers is Map && headers.containsKey('Access-Control-Allow-Methods')) {
            final methodsStr = headers['Access-Control-Allow-Methods'].toString();
            methods.addAll(methodsStr.split(',').map((m) => m.trim()));
          }
        }
        
        if (methods.isNotEmpty) {
          print('Available Methods: ${methods.join(', ')}');
        }
        
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
        
        // Print children/sub-endpoints if available
        final subEndpointKeys = ['children', 'prefix'];
        List<Map<String, dynamic>> subEndpoints = [];
        
        for (final subKey in subEndpointKeys) {
          if (apiData.containsKey(subKey) && apiData[subKey] is List) {
            final endpoints = apiData[subKey] as List;
            if (endpoints.isNotEmpty) {
              print('\nSub-Endpoints:');
              for (final sub in endpoints) {
                if (sub is Map) {
                  String name = sub.containsKey('Key') ? sub['Key'] : 
                               sub.containsKey('name') ? sub['name'] : '(unknown)';
                  
                  // Include methods if available
                  String methodsInfo = '';
                  if (sub.containsKey('methods') && sub['methods'] is List) {
                    methodsInfo = ' [${(sub['methods'] as List).join(', ')}]';
                  }
                  
                  // Include description if available
                  String description = '';
                  if (sub.containsKey('Description')) {
                    description = ' - ${sub['Description']}';
                  }
                  
                  print('  $name$methodsInfo$description');
                  
                  // Add to list of sub-endpoints for recursive exploration
                  subEndpoints.add({
                    'name': name,
                    'methods': sub['methods'] ?? [],
                    'description': sub['Description'] ?? '',
                  });
                } else if (sub is String) {
                  print('  $sub');
                  subEndpoints.add({'name': sub, 'methods': [], 'description': ''});
                }
              }
            }
          }
        }
        
        // Print access information
        if (apiData.containsKey('access')) {
          print('\nAccess: ${apiData['access']}');
        }
        
        // Show any other interesting properties
        final keysToShow = {
          'Description': 'Description',
          'Full_Key': 'Full Key',
          'Path': 'Path',
          'module': 'Module',
          'api_class': 'API Class',
        };
        
        keysToShow.forEach((key, label) {
          if (apiData.containsKey(key)) {
            final value = apiData[key];
            if (value is List) {
              print('\n$label: ${value.join('/')}');
            } else {
              print('\n$label: $value');
            }
          }
        });
        
        // Generate and print code if requested
        if (generateCode && methods.isNotEmpty) {
          final code = _generateEndpointCode(endpoint, methods, appId);
          print('\nGenerated Code:');
          print('---------------');
          print(code);
        }
        
        // Return data with sub-endpoints for recursive exploration
        return {
          'data': apiData,
          'methods': methods,
          'subEndpoints': subEndpoints,
        };
      }
    } else {
      // Handle non-standard response
      print('API Endpoint: $endpoint');
      
      // Try to extract methods from headers if present
      final List<String> methods = [];
      if (data is Map && data.containsKey('headers')) {
        final headers = data['headers'];
        if (headers is Map && headers.containsKey('access-control-allow-methods')) {
          final methodsStr = headers['access-control-allow-methods'].toString();
          methods.addAll(methodsStr.split(',').map((m) => m.trim()));
          print('Available Methods: ${methods.join(', ')}');
        }
      }
      
      // Check if we have some data to show
      var hasShownData = false;
      List<Map<String, dynamic>> subEndpoints = [];
      
      if (data is Map) {
        // Show interesting top-level fields
        final interestingKeys = ['Full_Key', 'Path', 'Description', 'children'];
        for (final key in interestingKeys) {
          if (data.containsKey(key)) {
            hasShownData = true;
            final value = data[key];
            if (value is List) {
              print('\n${key.replaceAll('_', ' ')}: ${value.join('/')}');
              
              // Add children as subEndpoints if available
              if (key == 'children') {
                for (final child in value) {
                  if (child is Map) {
                    String name = child['name'] ?? child['Key'] ?? '';
                    subEndpoints.add({
                      'name': name,
                      'methods': child['methods'] ?? [],
                      'description': child['Description'] ?? '',
                    });
                  } else if (child is String) {
                    subEndpoints.add({'name': child, 'methods': [], 'description': ''});
                  }
                }
              }
            } else {
              print('\n${key.replaceAll('_', ' ')}: $value');
            }
          }
        }
        
        // If the data key contains a Map of endpoints, show them
        if (data.containsKey('data') && data['data'] is Map && (data['data'] as Map).isNotEmpty) {
          hasShownData = true;
          print('\nAvailable Endpoints:');
          _printMap(data['data'], '  ');
          
          // Add data entries as subEndpoints
          data['data'].forEach((key, value) {
            subEndpoints.add({'name': key, 'methods': [], 'description': ''});
          });
        }
        
        // If we haven't shown any useful data yet, just show the raw response
        if (!hasShownData && verbose) {
          print('\nRaw Response:');
          _printMap(data, '  ');
        }
      }
      
      // Generate code even with limited information if methods are available
      if (generateCode && methods.isNotEmpty) {
        print('\nGenerated Code:');
        print('---------------');
        print(_generateEndpointCode(endpoint, methods, appId));
      }
      
      // Return data with any found sub-endpoints
      return {
        'data': data,
        'methods': methods,
        'subEndpoints': subEndpoints,
      };
    }
    
    return <String, dynamic>{};
  } catch (e) {
    print('Error: $e');
    return <String, dynamic>{};
  }
}

/// Recursively explores API endpoints up to a maximum depth
Future<void> _exploreRecursively(String endpoint, String baseUrl, String? appId, 
    bool verbose, bool generateCode, int currentDepth, int maxDepth) async {
  
  if (currentDepth > maxDepth) {
    return;
  }
  
  // Print depth indicator
  String depthPrefix = '=' * (currentDepth + 1) + '> ';
  if (currentDepth > 0) {
    print('\n$depthPrefix Exploring: $endpoint (Depth: $currentDepth of $maxDepth)');
  }
  
  // Explore current endpoint
  final result = await _exploreEndpoint(endpoint, baseUrl, appId, verbose, generateCode);
  
  // Stop if we've reached max depth or got no results
  if (currentDepth >= maxDepth || result.isEmpty || !result.containsKey('subEndpoints')) {
    return;
  }
  
  // Get list of sub-endpoints to explore
  final subEndpoints = result['subEndpoints'] as List<Map<String, dynamic>>;
  
  // Recursively explore each sub-endpoint
  for (final sub in subEndpoints) {
    String name = sub['name'];
    String subPath = endpoint.endsWith('/') || endpoint.isEmpty ? '$endpoint$name' : '$endpoint/$name';
    
    print('\n${'-' * 80}');
    await _exploreRecursively(subPath, baseUrl, appId, verbose, generateCode, currentDepth + 1, maxDepth);
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
  print('  atonline_describe --verbose --base-url=https://ws.atonline.com/_special/rest/ User');
  print('  atonline_describe --recursive --depth=2 --base-url=https://ws.atonline.com/_special/rest/ User');
  print('  atonline_describe -r -d 1 / # List all top-level endpoints');
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