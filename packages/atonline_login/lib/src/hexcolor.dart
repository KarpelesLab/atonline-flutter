import 'package:flutter/material.dart';

extension HexColor on Color {
  /// String is in the format "abc" "aabbcc" or "ffaabbcc" with an optional leading "#".
  static Color fromHex(String hexString) {
    if (hexString.startsWith("#")) {
      hexString = hexString.substring(1);
    }

    switch (hexString.length) {
      case 6:
        hexString = "ff" + hexString;
        break;
      case 8:
        // (all good)
        break;
      case 3:
        hexString = "ff" +
            hexString[0] +
            hexString[0] +
            hexString[1] +
            hexString[1] +
            hexString[2] +
            hexString[2];
        break;
      default:
        // fail.
        return Color(0);
    }

    return Color(int.parse(hexString, radix: 16));
  }

  /// Prefixes a hash sign if [leadingHashSign] is set to `true` (default is `true`).
  String toHex({bool leadingHashSign = true}) => '${leadingHashSign ? '#' : ''}'
      '${(a.round()).toRadixString(16).padLeft(2, '0')}'
      '${(r.round()).toRadixString(16).padLeft(2, '0')}'
      '${(g.round()).toRadixString(16).padLeft(2, '0')}'
      '${(b.round()).toRadixString(16).padLeft(2, '0')}';
}
