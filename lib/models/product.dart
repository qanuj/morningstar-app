// lib/models/product.dart
class Club {
  final String id;
  final String name;
  final String? logo;

  Club({
    required this.id,
    required this.name,
    this.logo,
  });

  factory Club.fromJson(Map<String, dynamic> json) {
    return Club(
      id: json['id'],
      name: json['name'],
      logo: json['logo'],
    );
  }
}

class ImageData {
  final String url;
  final String type;

  ImageData({
    required this.url,
    required this.type,
  });

  factory ImageData.fromJson(Map<String, dynamic> json) {
    return ImageData(
      url: json['url'],
      type: json['type'],
    );
  }
}

class ProductCount {
  final int orders;

  ProductCount({required this.orders});

  factory ProductCount.fromJson(Map<String, dynamic> json) {
    return ProductCount(
      orders: json['orders'] ?? 0,
    );
  }
}

class Pricing {
  final double basePrice;
  final double fullSleevePrice;
  final double capPrice;
  final double trouserPrice;

  Pricing({
    required this.basePrice,
    required this.fullSleevePrice,
    required this.capPrice,
    required this.trouserPrice,
  });

  factory Pricing.fromJson(Map<String, dynamic> json) {
    return Pricing(
      basePrice: (json['basePrice'] ?? 0).toDouble(),
      fullSleevePrice: (json['fullSleevePrice'] ?? 0).toDouble(),
      capPrice: (json['capPrice'] ?? 0).toDouble(),
      trouserPrice: (json['trouserPrice'] ?? 0).toDouble(),
    );
  }
}

class UserOrder {
  final String id;
  final String type;
  final String? jerseyId;
  final String? kitId;
  final String status;
  final int quantity;
  final double totalAmount;
  final DateTime createdAt;

  UserOrder({
    required this.id,
    required this.type,
    this.jerseyId,
    this.kitId,
    required this.status,
    required this.quantity,
    required this.totalAmount,
    required this.createdAt,
  });

  factory UserOrder.fromJson(Map<String, dynamic> json) {
    return UserOrder(
      id: json['id'],
      type: json['type'],
      jerseyId: json['jerseyId'],
      kitId: json['kitId'],
      status: json['status'],
      quantity: json['quantity'] ?? 1,
      totalAmount: (json['totalAmount'] ?? 0).toDouble(),
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

class Availability {
  final bool canOrder;
  final String reason;

  Availability({
    required this.canOrder,
    required this.reason,
  });

  factory Availability.fromJson(Map<String, dynamic> json) {
    return Availability(
      canOrder: json['canOrder'] ?? false,
      reason: json['reason'] ?? '',
    );
  }
}

class Product {
  final String id;
  final String clubId;
  final String name;
  final String? description;
  final double basePrice;
  final List<ImageData> images;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdById;
  final String? updatedById;
  final bool isOrderingEnabled;
  final int maxOrdersPerUser;
  final Club club;
  final ProductCount count;
  final String productType;
  final List<UserOrder> userOrders;
  final bool hasOrdered;
  final bool canOrderMore;
  final int userOrderCount;
  final Availability availability;
  
  // Jersey-specific fields that might be present
  final double? fullSleevePrice;
  final double? capPrice;
  final double? trouserPrice;
  final Pricing? pricing;

  Product({
    required this.id,
    required this.clubId,
    required this.name,
    this.description,
    required this.basePrice,
    required this.images,
    required this.createdAt,
    required this.updatedAt,
    this.createdById,
    this.updatedById,
    required this.isOrderingEnabled,
    required this.maxOrdersPerUser,
    required this.club,
    required this.count,
    required this.productType,
    required this.userOrders,
    required this.hasOrdered,
    required this.canOrderMore,
    required this.userOrderCount,
    required this.availability,
    this.fullSleevePrice,
    this.capPrice,
    this.trouserPrice,
    this.pricing,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      clubId: json['clubId'],
      name: json['name'],
      description: json['description'],
      basePrice: (json['basePrice'] ?? 0).toDouble(),
      images: (json['images'] as List? ?? [])
          .map((img) => ImageData.fromJson(img))
          .toList(),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      createdById: json['createdById'],
      updatedById: json['updatedById'],
      isOrderingEnabled: json['isOrderingEnabled'] ?? true,
      maxOrdersPerUser: json['maxOrdersPerUser'] ?? 5,
      club: Club.fromJson(json['club']),
      count: ProductCount.fromJson(json['_count']),
      productType: json['productType'],
      userOrders: (json['userOrders'] as List? ?? [])
          .map((order) => UserOrder.fromJson(order))
          .toList(),
      hasOrdered: json['hasOrdered'] ?? false,
      canOrderMore: json['canOrderMore'] ?? true,
      userOrderCount: json['userOrderCount'] ?? 0,
      availability: Availability.fromJson(json['availability']),
      fullSleevePrice: json['fullSleevePrice']?.toDouble(),
      capPrice: json['capPrice']?.toDouble(),
      trouserPrice: json['trouserPrice']?.toDouble(),
      pricing: json['pricing'] != null ? Pricing.fromJson(json['pricing']) : null,
    );
  }
}

class Jersey extends Product {
  final double fullSleevePrice;
  final double capPrice;
  final double trouserPrice;
  final Pricing? pricing;

  Jersey({
    required String id,
    required String clubId,
    required String name,
    String? description,
    required double basePrice,
    required List<ImageData> images,
    required DateTime createdAt,
    required DateTime updatedAt,
    String? createdById,
    String? updatedById,
    required bool isOrderingEnabled,
    required int maxOrdersPerUser,
    required Club club,
    required ProductCount count,
    required String productType,
    required List<UserOrder> userOrders,
    required bool hasOrdered,
    required bool canOrderMore,
    required int userOrderCount,
    required Availability availability,
    required this.fullSleevePrice,
    required this.capPrice,
    required this.trouserPrice,
    this.pricing,
  }) : super(
          id: id,
          clubId: clubId,
          name: name,
          description: description,
          basePrice: basePrice,
          images: images,
          createdAt: createdAt,
          updatedAt: updatedAt,
          createdById: createdById,
          updatedById: updatedById,
          isOrderingEnabled: isOrderingEnabled,
          maxOrdersPerUser: maxOrdersPerUser,
          club: club,
          count: count,
          productType: productType,
          userOrders: userOrders,
          hasOrdered: hasOrdered,
          canOrderMore: canOrderMore,
          userOrderCount: userOrderCount,
          availability: availability,
        );

  factory Jersey.fromJson(Map<String, dynamic> json) {
    return Jersey(
      id: json['id'],
      clubId: json['clubId'],
      name: json['name'],
      description: json['description'],
      basePrice: (json['basePrice'] ?? 0).toDouble(),
      images: (json['images'] as List? ?? [])
          .map((img) => ImageData.fromJson(img))
          .toList(),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      createdById: json['createdById'],
      updatedById: json['updatedById'],
      isOrderingEnabled: json['isOrderingEnabled'] ?? true,
      maxOrdersPerUser: json['maxOrdersPerUser'] ?? 5,
      club: Club.fromJson(json['club']),
      count: ProductCount.fromJson(json['_count']),
      productType: json['productType'],
      userOrders: (json['userOrders'] as List? ?? [])
          .map((order) => UserOrder.fromJson(order))
          .toList(),
      hasOrdered: json['hasOrdered'] ?? false,
      canOrderMore: json['canOrderMore'] ?? true,
      userOrderCount: json['userOrderCount'] ?? 0,
      availability: Availability.fromJson(json['availability']),
      fullSleevePrice: (json['fullSleevePrice'] ?? 0).toDouble(),
      capPrice: (json['capPrice'] ?? 0).toDouble(),
      trouserPrice: (json['trouserPrice'] ?? 0).toDouble(),
      pricing: json['pricing'] != null ? Pricing.fromJson(json['pricing']) : null,
    );
  }
}

class Kit extends Product {
  final String type;
  final String handType;
  final List<String>? availableSizes;
  final String? brand;
  final String? model;
  final String? color;
  final String? material;
  final double? weight;
  final String? size;
  final int stockQuantity;
  final int minStockLevel;

  Kit({
    required String id,
    required String clubId,
    required String name,
    String? description,
    required double basePrice,
    required List<ImageData> images,
    required DateTime createdAt,
    required DateTime updatedAt,
    String? createdById,
    String? updatedById,
    required bool isOrderingEnabled,
    required int maxOrdersPerUser,
    required Club club,
    required ProductCount count,
    required String productType,
    required List<UserOrder> userOrders,
    required bool hasOrdered,
    required bool canOrderMore,
    required int userOrderCount,
    required Availability availability,
    required this.type,
    required this.handType,
    this.availableSizes,
    this.brand,
    this.model,
    this.color,
    this.material,
    this.weight,
    this.size,
    required this.stockQuantity,
    required this.minStockLevel,
  }) : super(
          id: id,
          clubId: clubId,
          name: name,
          description: description,
          basePrice: basePrice,
          images: images,
          createdAt: createdAt,
          updatedAt: updatedAt,
          createdById: createdById,
          updatedById: updatedById,
          isOrderingEnabled: isOrderingEnabled,
          maxOrdersPerUser: maxOrdersPerUser,
          club: club,
          count: count,
          productType: productType,
          userOrders: userOrders,
          hasOrdered: hasOrdered,
          canOrderMore: canOrderMore,
          userOrderCount: userOrderCount,
          availability: availability,
        );

  factory Kit.fromJson(Map<String, dynamic> json) {
    return Kit(
      id: json['id'],
      clubId: json['clubId'],
      name: json['name'],
      description: json['description'],
      basePrice: (json['basePrice'] ?? 0).toDouble(),
      images: (json['images'] as List? ?? [])
          .map((img) => ImageData.fromJson(img))
          .toList(),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      createdById: json['createdById'],
      updatedById: json['updatedById'],
      isOrderingEnabled: json['isOrderingEnabled'] ?? true,
      maxOrdersPerUser: json['maxOrdersPerUser'] ?? 5,
      club: Club.fromJson(json['club']),
      count: ProductCount.fromJson(json['_count']),
      productType: json['productType'],
      userOrders: (json['userOrders'] as List? ?? [])
          .map((order) => UserOrder.fromJson(order))
          .toList(),
      hasOrdered: json['hasOrdered'] ?? false,
      canOrderMore: json['canOrderMore'] ?? true,
      userOrderCount: json['userOrderCount'] ?? 0,
      availability: Availability.fromJson(json['availability']),
      type: json['type'],
      handType: json['handType'] ?? 'BOTH',
      availableSizes: json['availableSizes'] != null
          ? List<String>.from(json['availableSizes'])
          : null,
      brand: json['brand'],
      model: json['model'],
      color: json['color'],
      material: json['material'],
      weight: json['weight']?.toDouble(),
      size: json['size'],
      stockQuantity: json['stockQuantity'] ?? 0,
      minStockLevel: json['minStockLevel'] ?? 0,
    );
  }
}

class StatusUpdate {
  final String status;
  final String? notes;
  final DateTime createdAt;
  final ChangedBy? changedBy;

  StatusUpdate({
    required this.status,
    this.notes,
    required this.createdAt,
    this.changedBy,
  });

  factory StatusUpdate.fromJson(Map<String, dynamic> json) {
    return StatusUpdate(
      status: json['status'],
      notes: json['notes'],
      createdAt: DateTime.parse(json['createdAt']),
      changedBy: json['changedBy'] != null
          ? ChangedBy.fromJson(json['changedBy'])
          : null,
    );
  }
}

class ChangedBy {
  final String name;

  ChangedBy({required this.name});

  factory ChangedBy.fromJson(Map<String, dynamic> json) {
    return ChangedBy(
      name: json['name'],
    );
  }
}

class OrderJersey {
  final String id;
  final String name;
  final String? description;
  final double basePrice;
  final double fullSleevePrice;
  final double capPrice;
  final double trouserPrice;
  final List<ImageData> images;
  final bool isOrderingEnabled;
  final int maxOrdersPerUser;
  final DateTime createdAt;
  final ProductCount count;

  OrderJersey({
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
    required this.createdAt,
    required this.count,
  });

  factory OrderJersey.fromJson(Map<String, dynamic> json) {
    return OrderJersey(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      basePrice: (json['basePrice'] ?? 0).toDouble(),
      fullSleevePrice: (json['fullSleevePrice'] ?? 0).toDouble(),
      capPrice: (json['capPrice'] ?? 0).toDouble(),
      trouserPrice: (json['trouserPrice'] ?? 0).toDouble(),
      images: (json['images'] as List? ?? [])
          .map((img) => ImageData.fromJson(img))
          .toList(),
      isOrderingEnabled: json['isOrderingEnabled'] ?? true,
      maxOrdersPerUser: json['maxOrdersPerUser'] ?? 5,
      createdAt: DateTime.parse(json['createdAt']),
      count: ProductCount.fromJson(json['_count']),
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
  final String? notes;
  final DateTime? estimatedDelivery;
  final DateTime? actualDelivery;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Club club;
  final StatusUpdate? latestStatusUpdate;
  final OrderJersey? jersey;
  final Kit? kit;

  // Jersey specific
  final String? jerseySize;
  final String? sleeveLength;
  final String? customName;
  final String? jerseyNumber;
  final bool? includeCap;
  final bool? includeTrousers;
  final String? trouserSize;

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
    this.notes,
    this.estimatedDelivery,
    this.actualDelivery,
    required this.createdAt,
    required this.updatedAt,
    required this.club,
    this.latestStatusUpdate,
    this.jersey,
    this.kit,
    this.jerseySize,
    this.sleeveLength,
    this.customName,
    this.jerseyNumber,
    this.includeCap,
    this.includeTrousers,
    this.trouserSize,
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
      notes: json['notes'],
      estimatedDelivery: json['estimatedDelivery'] != null
          ? DateTime.parse(json['estimatedDelivery'])
          : null,
      actualDelivery: json['actualDelivery'] != null
          ? DateTime.parse(json['actualDelivery'])
          : null,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      club: Club.fromJson(json['club']),
      latestStatusUpdate: json['latestStatusUpdate'] != null
          ? StatusUpdate.fromJson(json['latestStatusUpdate'])
          : null,
      jersey: json['jersey'] != null
          ? OrderJersey.fromJson(json['jersey'])
          : null,
      kit: json['kit'] != null ? Kit.fromJson(json['kit']) : null,
      jerseySize: json['jerseySize'],
      sleeveLength: json['sleeveLength'],
      customName: json['customName'],
      jerseyNumber: json['jerseyNumber'],
      includeCap: json['includeCap'],
      includeTrousers: json['includeTrousers'],
      trouserSize: json['trouserSize'],
      selectedSize: json['selectedSize'],
      selectedHand: json['selectedHand'],
    );
  }
}

class StoreResponse {
  final List<Product> products;
  final StoreMeta meta;

  StoreResponse({
    required this.products,
    required this.meta,
  });

  factory StoreResponse.fromJson(Map<String, dynamic> json) {
    return StoreResponse(
      products: (json['products'] as List)
          .map((product) => Product.fromJson(product))
          .toList(),
      meta: StoreMeta.fromJson(json['meta']),
    );
  }
}

class StoreMeta {
  final int total;
  final int limit;
  final String type;
  final int jerseyCount;
  final int kitCount;

  StoreMeta({
    required this.total,
    required this.limit,
    required this.type,
    required this.jerseyCount,
    required this.kitCount,
  });

  factory StoreMeta.fromJson(Map<String, dynamic> json) {
    return StoreMeta(
      total: json['total'] ?? 0,
      limit: json['limit'] ?? 50,
      type: json['type'] ?? 'all',
      jerseyCount: json['jerseyCount'] ?? 0,
      kitCount: json['kitCount'] ?? 0,
    );
  }
}