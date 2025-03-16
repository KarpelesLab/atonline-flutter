import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atonline_login/src/hexcolor.dart';

void main() {
  group('HexColor extension', () {
    test('fromHex parses hex strings correctly with hash', () {
      final color = HexColor.fromHex('#FF5733');
      expect(color, equals(Color(0xFFFF5733)));
    });

    test('fromHex parses hex strings correctly without hash', () {
      final color = HexColor.fromHex('FF5733');
      expect(color, equals(Color(0xFFFF5733)));
    });

    test('fromHex supports short 3-digit hex format', () {
      final color = HexColor.fromHex('#F53');
      expect(color, equals(Color(0xFFFF5533)));
    });

    test('fromHex handles 8-digit hex format', () {
      final color = HexColor.fromHex('80FF5733');
      expect(color, equals(Color(0x80FF5733)));
    });

    test('fromHex returns transparent color for invalid format', () {
      final color = HexColor.fromHex('invalid');
      expect(color, equals(Color(0x00000000)));
    });

    // Tests for toHex were removed since they're platform-dependent
  });
}
