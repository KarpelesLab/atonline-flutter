import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final baseUrl = 'https://hub.atonline.com/_special/rest/';
  
  // Test fixedString endpoint
  try {
    print('\nTesting Misc/Debug:fixedString:');
    final response = await http.get(Uri.parse('${baseUrl}Misc/Debug:fixedString'));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print(JsonEncoder.withIndent('  ').convert(data));
    } else {
      print('Error: ${response.statusCode}');
      print(response.body);
    }
  } catch (e) {
    print('Error: $e');
  }
  
  // Test fixedArray endpoint
  try {
    print('\nTesting Misc/Debug:fixedArray:');
    final response = await http.get(Uri.parse('${baseUrl}Misc/Debug:fixedArray'));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print(JsonEncoder.withIndent('  ').convert(data));
    } else {
      print('Error: ${response.statusCode}');
      print(response.body);
    }
  } catch (e) {
    print('Error: $e');
  }
  
  // Test error endpoint
  try {
    print('\nTesting Misc/Debug:error:');
    final response = await http.get(Uri.parse('${baseUrl}Misc/Debug:error'));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print(JsonEncoder.withIndent('  ').convert(data));
    } else {
      print('Error: ${response.statusCode}');
      print(response.body);
    }
  } catch (e) {
    print('Error: $e');
  }
}
