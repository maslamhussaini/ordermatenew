// test/features/organization/store_default_selection_test.dart
//
// Covers Store.resolveDefault, the pure selection rule behind the Workspace
// "Store / Branch" dropdown default:
//   - exactly one store -> auto-select it
//   - a previously-selected/persisted store that's still in the list -> keep it
//   - multiple stores with no persisted selection -> null (let the user pick;
//     omtbl_stores has no default/primary flag, so this is deliberately not
//     guessed)

import 'package:flutter_test/flutter_test.dart';
import 'package:ordermate/features/organization/domain/entities/store.dart';

Store _store(int id, {String name = 'Store'}) => Store(
      id: id,
      organizationId: 1,
      name: name,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  group('Store.resolveDefault', () {
    test('returns null for an empty list', () {
      expect(Store.resolveDefault(const []), isNull);
    });

    test('auto-selects the only store', () {
      final store = _store(1);
      expect(Store.resolveDefault([store]), store);
    });

    test('multiple stores with no previous selection -> null (ask the user)',
        () {
      final result = Store.resolveDefault([_store(1), _store(2)]);
      expect(result, isNull);
    });

    test('restores a previously-selected store still present in the list',
        () {
      final stores = [_store(1), _store(2), _store(3)];
      final result =
          Store.resolveDefault(stores, previouslySelectedId: 2);
      expect(result?.id, 2);
    });

    test(
        'previously-selected id belonging to a different organization/list '
        'is ignored, not leaked through', () {
      final stores = [_store(1), _store(2)];
      final result =
          Store.resolveDefault(stores, previouslySelectedId: 999);
      expect(result, isNull);
    });
  });
}
