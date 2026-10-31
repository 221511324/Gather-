import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gather/core/widgets/directional_icons.dart';

void main() {
  test('mirrored icons are the same glyph as their Material originals', () {
    const pairs = [(DirectionalIcons.logout, Icons.logout_rounded)];
    for (final (mirrored, original) in pairs) {
      expect(mirrored.codePoint, original.codePoint);
      expect(mirrored.fontFamily, original.fontFamily);
      expect(mirrored.fontPackage, original.fontPackage);
      expect(mirrored.matchTextDirection, isTrue);
    }
  });
}
