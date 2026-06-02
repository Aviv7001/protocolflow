class MaterialItem {
  final String id;
  final String name;
  final String quantity;
  final String catalogNumber;
  final String manufacturer;
  final String location;
  final String stockConcentration;

  MaterialItem({
    required this.id,
    required this.name,
    required this.quantity,
    this.catalogNumber = '',
    this.manufacturer = '',
    this.location = '',
    this.stockConcentration = '',
  });

  MaterialItem copyWith({
    String? id,
    String? name,
    String? quantity,
    String? catalogNumber,
    String? manufacturer,
    String? location,
    String? stockConcentration,
  }) {
    return MaterialItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      catalogNumber: catalogNumber ?? this.catalogNumber,
      manufacturer: manufacturer ?? this.manufacturer,
      location: location ?? this.location,
      stockConcentration: stockConcentration ?? this.stockConcentration,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'catalogNumber': catalogNumber,
      'manufacturer': manufacturer,
      'location': location,
      'stockConcentration': stockConcentration,
    };
  }

  factory MaterialItem.fromJson(Map<String, dynamic> json) {
    return MaterialItem(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      quantity: json['quantity'] ?? '',
      catalogNumber: json['catalogNumber'] ?? '',
      manufacturer: json['manufacturer'] ?? '',
      location: json['location'] ?? '',
      stockConcentration: json['stockConcentration'] ?? '',
    );
  }
}
