// Verifies that the live price list from the server maps cleanly onto the six
// service tabs this app renders. The catalogue used to be hardcoded in
// CartManager, so a price changed in the admin panel never reached the app and
// the customer could be quoted one figure while the server charged another.
//
// The codes asserted here are the ones GET /api/v1/catalog/items actually
// returns (checked against the running backend on 2026-10-07). If the server
// gains a new service, this test fails and tells you to add a tab for it.
import 'package:flutter_test/flutter_test.dart';
import 'package:yes_dhobi/models/laundry_item.dart';

void main() {
  group('service code mapping', () {
    test('every service the server actually serves items for has a tab', () {
      const liveCodes = <String>[
        'wash_fold',
        'wash_iron',
        'steam_iron',
        'dry_cleaning',
        'shoe_cleaning',
        'households',
      ];
      for (final code in liveCodes) {
        expect(
          serviceCategoryFromCode(code),
          isNotNull,
          reason: 'no tab for service "$code" - items under it would be unorderable',
        );
      }
    });

    test('maps each code to the tab a customer would expect', () {
      expect(serviceCategoryFromCode('wash_fold'), ServiceCategory.washAndFold);
      expect(serviceCategoryFromCode('wash_iron'), ServiceCategory.washAndIron);
      expect(serviceCategoryFromCode('steam_iron'), ServiceCategory.steamIron);
      expect(serviceCategoryFromCode('dry_cleaning'), ServiceCategory.dryCleaning);
      expect(serviceCategoryFromCode('shoe_cleaning'), ServiceCategory.shoeCleaning);
      expect(serviceCategoryFromCode('households'), ServiceCategory.household);
    });

    test('folds the three services with no tab of their own into the nearest one', () {
      // the server defines these, but this build has no tab for them; they are
      // folded rather than dropped so the items stay orderable
      expect(serviceCategoryFromCode('dry_iron'), ServiceCategory.steamIron);
      expect(serviceCategoryFromCode('wet_cleaning'), ServiceCategory.dryCleaning);
      expect(serviceCategoryFromCode('stain_removal'), ServiceCategory.dryCleaning);
    });

    test('returns null for anything unrecognised instead of guessing', () {
      expect(serviceCategoryFromCode('something_new'), isNull);
      expect(serviceCategoryFromCode(null), isNull);
      expect(serviceCategoryFromCode(''), isNull);
    });
  });
}
