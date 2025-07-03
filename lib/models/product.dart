// lib/models/product.dart
class Jersey {
  final String id;
  final String name;
  final String? description;
  final double basePrice;
  final double fullSleevePrice;
  final double capPrice;
  final double trouserPrice;
  final List<String> images;
  final bool isOrderingEnabled;
  final int maxOrdersPerUser;

  Jersey({
    required this.id,
    required this.name,
    this.description,
    required this.basePrice,
    required this.fullSleevePrice,
    required this.capPrice,
    required this.trouserPrice,
    required this.images,
    required this.isOrderingEnabled,
    required this.maxOrdersPerUser,
  });

  factory Jersey.fromJson(Map<String, dynamic> json) {
    return Jersey(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      basePrice: (json['basePrice'] ?? 0).toDouble(),
      fullSleevePrice: (json['fullSleevePrice'] ?? 0).toDouble(),
      capPrice: (json['capPrice'] ?? 0).toDouble(),
      trouserPrice: (json['trouserPrice'] ?? 0).toDouble(),
      images: List<String>.from(json['images'] ?? []),
      isOrderingEnabled: json['isOrderingEnabled'] ?? true,
      maxOrdersPerUser: json['maxOrdersPerUser'] ?? 5,
    );
  }
}

class Kit {
  final String id;
  final String name;
  final String? description;
  final String type;
  final String handType;
  final double basePrice;
  final List<String>? availableSizes;
  final List<String> images;
  final String? brand;
  final String? model;
  final int stockQuantity;
  final bool isOrderingEnabled;
  final int maxOrdersPerUser;

  Kit({
    required this.id,
    required this.name,
    this.description,
    required this.type,
    required this.handType,
    required this.basePrice,
    this.availableSizes,
    required this.images,
    this.brand,
    this.model,
    required this.stockQuantity,
    required this.isOrderingEnabled,
    required this.maxOrdersPerUser,
  });

  factory Kit.fromJson(Map<String, dynamic> json) {
    return Kit(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      type: json['type'],
      handType: json['handType'] ?? 'BOTH',
      basePrice: (json['basePrice'] ?? 0).toDouble(),
      availableSizes: json['availableSizes'] != null 
        ? List<String>.from(json['availableSizes'])
        : null,
      images: List<String>.from(json['images'] ?? []),
      brand: json['brand'],
      model: json['model'],
      stockQuantity: json['stockQuantity'] ?? 0,
      isOrderingEnabled: json['isOrderingEnabled'] ?? true,
      maxOrdersPerUser: json['maxOrdersPerUser'] ?? 5,
    );
  }
}

class Order {
  final String id;
  final String orderNumber;
  final String type;
  final int quantity;
  final double unitPrice;
  final double totalAmount;
  final String status;
  final String? paymentMethod;
  final DateTime createdAt;
  final DateTime? estimatedDelivery;
  final String? notes;

  // Jersey specific
  final String? jerseySize;
  final String? sleeveLength;
  final String? customName;
  final String? jerseyNumber;
  final bool? includeCap;
  final bool? includeTrousers;

  // Kit specific
  final String? selectedSize;
  final String? selectedHand;

  Order({
    required this.id,
    required this.orderNumber,
    required this.type,
    required this.quantity,
    required this.unitPrice,
    required this.totalAmount,
    required this.status,
    this.paymentMethod,
    required this.createdAt,
    this.estimatedDelivery,
    this.notes,
    this.jerseySize,
    this.sleeveLength,
    this.customName,
    this.jerseyNumber,
    this.includeCap,
    this.includeTrousers,
    this.selectedSize,
    this.selectedHand,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'],
      orderNumber: json['orderNumber'],
      type: json['type'],
      quantity: json['quantity'] ?? 1,
      unitPrice: (json['unitPrice'] ?? 0).toDouble(),
      totalAmount: (json['totalAmount'] ?? 0).toDouble(),
      status: json['status'],
      paymentMethod: json['paymentMethod'],
      createdAt: DateTime.parse(json['createdAt']),
      estimatedDelivery: json['estimatedDelivery'] != null 
        ? DateTime.parse(json['estimatedDelivery'])
        : null,
      notes: json['notes'],
      jerseySize: json['jerseySize'],
      sleeveLength: json['sleeveLength'],
      customName: json['customName'],
      jerseyNumber: json['jerseyNumber'],
      includeCap: json['includeCap'],
      includeTrousers: json['includeTrousers'],
      selectedSize: json['selectedSize'],
      selectedHand: json['selectedHand'],
    );
  }
}
