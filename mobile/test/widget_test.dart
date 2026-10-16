// Replaces the default counter test that `flutter create` would add.
import 'package:flutter_test/flutter_test.dart';
import 'package:sarifio_app/core/money.dart';

void main() {
  test('fee label for the default 1% fee', () {
    expect(FeeEngine.percentLabel(FeeEngine.defaultFeeBps), '1%');
    expect(FeeEngine.percentLabel(150), '1.5%');
  });
}
