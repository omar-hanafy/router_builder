import 'package:flutter_test/flutter_test.dart';
import 'package:router_builder/router_builder.dart';

void main() {
  group('DuplicateRouteBehavior', () {
    test('predicates reflect the value', () {
      expect(DuplicateRouteBehavior.duplicate.isDuplicate, isTrue);
      expect(DuplicateRouteBehavior.refresh.isRefresh, isTrue);
      expect(DuplicateRouteBehavior.doNothing.isDoNothing, isTrue);
    });

    test('nullable extension defaults to false', () {
      const DuplicateRouteBehavior? value = null;
      expect(value.isDuplicate, isFalse);
      expect(value.isRefresh, isFalse);
      expect(value.isDoNothing, isFalse);
    });
  });
}
