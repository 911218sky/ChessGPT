import 'package:flutter_test/flutter_test.dart';

import 'package:chessgpt/src/utils/text_sanitizer.dart';

void main() {
  test('removes leading dialogue speaker labels', () {
    expect(
      sanitizeDisplayText('Coach: Watch the loose knight.'),
      'Watch the loose knight.',
    );
    expect(sanitizeDisplayText('棋靈王：先補中心。'), '先補中心。');
    expect(
      sanitizeDisplayText('**Teacher**: Keep the king safe.'),
      'Keep the king safe.',
    );
  });
}
