enum ServiceCategory {
  washAndFold('Wash & Fold'),
  washAndIron('Wash & Iron'),
  steamIron('Steam Iron'),
  dryCleaning('Dry Cleaning'),
  shoeCleaning('Shoe Cleaning'),
  household('Household');

  final String title;
  const ServiceCategory(this.title);
}

/// Maps a backend service-category code onto the six tabs this app shows.
///
/// The server currently offers nine services; `dry_iron`, `wet_cleaning` and
/// `stain_removal` have no tab of their own, so they are folded into the
/// closest one rather than dropped - otherwise those items would be
/// unorderable in the app. Add a tab here and in the enum above if they
/// deserve their own.
ServiceCategory? serviceCategoryFromCode(String? code) {
  switch (code) {
    case 'wash_fold':
      return ServiceCategory.washAndFold;
    case 'wash_iron':
      return ServiceCategory.washAndIron;
    case 'steam_iron':
    case 'dry_iron':
      return ServiceCategory.steamIron;
    case 'dry_cleaning':
    case 'wet_cleaning':
    case 'stain_removal':
      return ServiceCategory.dryCleaning;
    case 'shoe_cleaning':
      return ServiceCategory.shoeCleaning;
    case 'households':
    case 'household':
      return ServiceCategory.household;
    default:
      return null;
  }
}

class LaundryItem {
  final String id;
  final String name;
  final ServiceCategory category;
  final int price;
  final String unit;
  final String iconKey;
  int quantity;

  LaundryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    this.unit = 'pc',
    required this.iconKey,
    this.quantity = 0,
  });

  LaundryItem copyWith({
    String? id,
    String? name,
    ServiceCategory? category,
    int? price,
    String? unit,
    String? iconKey,
    int? quantity,
  }) {
    return LaundryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      price: price ?? this.price,
      unit: unit ?? this.unit,
      iconKey: iconKey ?? this.iconKey,
      quantity: quantity ?? this.quantity,
    );
  }
}
