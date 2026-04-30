import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'All Dart source files are valid UTF-8 and contain no mojibake text',
    () {
      final root = Directory('lib');
      expect(root.existsSync(), isTrue);

      const suspiciousTokens = <String>['Ã', 'Ø§Ù', 'Ù„Ø', 'â€', '\uFFFD'];

      final violations = <String>[];

      for (final entity in root.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) {
          continue;
        }

        final normalizedPath = entity.path.replaceAll('\\', '/');
        final bytes = entity.readAsBytesSync();

        // Enforce UTF-8 decodability.
        final content = utf8.decode(bytes, allowMalformed: false);

        // This file intentionally contains mojibake characters in a regex
        // detector used to catch corrupted backend messages.
        if (normalizedPath.endsWith(
          'lib/features/auth/presentation/cubit/auth_cubit.dart',
        )) {
          continue;
        }

        for (final token in suspiciousTokens) {
          if (content.contains(token)) {
            violations.add('$normalizedPath -> token "$token"');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'Mojibake/encoding corruption detected:\n${violations.join('\n')}',
      );
    },
  );
}
