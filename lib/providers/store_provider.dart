import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/api_service.dart';

class StoreProvider with ChangeNotifier {
  List<Product> _products = [];
  List<Jersey> _jerseys = [];
  List<Kit> _kits = [];
  List<Order> _orders = [];
  bool _isLoading = false;
  StoreMeta? _meta;

  List<Product> get products => _products;
  List<Jersey> get jerseys => _jerseys;
  List<Kit> get kits => _kits;
  List<Order> get orders => _orders;
  bool get isLoading => _isLoading;
  StoreMeta? get meta => _meta;

  Future<void> loadStoreData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await ApiService.get('/store');
      final storeResponse = StoreResponse.fromJson(response);

      _products = storeResponse.products;
      _meta = storeResponse.meta;

      // Convert products to jerseys and kits
      _jerseys = [];
      _kits = [];

      for (final product in _products) {
        if (product.productType == 'JERSEY') {
          _jerseys.add(
            Jersey(
              id: product.id,
              clubId: product.clubId,
              name: product.name,
              description: product.description,
              basePrice: product.basePrice,
              images: product.images,
              createdAt: product.createdAt,
              updatedAt: product.updatedAt,
              createdById: product.createdById,
              updatedById: product.updatedById,
              isOrderingEnabled: product.isOrderingEnabled,
              maxOrdersPerUser: product.maxOrdersPerUser,
              club: product.club,
              count: product.count,
              productType: product.productType,
              userOrders: product.userOrders,
              hasOrdered: product.hasOrdered,
              canOrderMore: product.canOrderMore,
              userOrderCount: product.userOrderCount,
              availability: product.availability,
              fullSleevePrice: product.fullSleevePrice ?? 0,
              capPrice: product.capPrice ?? 0,
              trouserPrice: product.trouserPrice ?? 0,
              pricing: product.pricing,
            ),
          );
        } else if (product.productType == 'KIT') {
          _kits.add(
            Kit(
              id: product.id,
              clubId: product.clubId,
              name: product.name,
              description: product.description,
              basePrice: product.basePrice,
              images: product.images,
              createdAt: product.createdAt,
              updatedAt: product.updatedAt,
              createdById: product.createdById,
              updatedById: product.updatedById,
              isOrderingEnabled: product.isOrderingEnabled,
              maxOrdersPerUser: product.maxOrdersPerUser,
              club: product.club,
              count: product.count,
              productType: product.productType,
              userOrders: product.userOrders,
              hasOrdered: product.hasOrdered,
              canOrderMore: product.canOrderMore,
              userOrderCount: product.userOrderCount,
              availability: product.availability,
              type: 'OTHER',
              handType: 'BOTH',
              availableSizes: null,
              brand: null,
              model: null,
              color: null,
              material: null,
              weight: null,
              size: null,
              stockQuantity: 0,
              minStockLevel: 0,
            ),
          );
        }
      }
    } catch (e) {
      print('Error loading store data: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadOrders() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await ApiService.get('/my/orders');
      _orders = (response['data'] as List)
          .map((order) => Order.fromJson(order))
          .toList();
    } catch (e) {
      print('Error loading orders: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> placeJerseyOrder({
    required String jerseyId,
    required String jerseySize,
    required String sleeveLength,
    required String customName,
    String? jerseyNumber,
    required bool includeCap,
    required bool includeTrousers,
    String? trouserSize,
    String? notes,
    required double totalAmount,
  }) async {
    try {
      final orderData = {
        'jerseyId': jerseyId,
        'type': 'JERSEY',
        'jerseySize': jerseySize,
        'sleeveLength': sleeveLength,
        'customName': customName,
        'jerseyNumber': jerseyNumber,
        'includeCap': includeCap,
        'includeTrousers': includeTrousers,
        'trouserSize': trouserSize,
        'notes': notes,
        'totalAmount': totalAmount,
        'unitPrice': totalAmount,
        'quantity': 1,
      };

      await ApiService.post('/my/orders', orderData);

      // Reload store data and orders
      await loadStoreData();
      await loadOrders();
    } catch (e) {
      print('Error placing jersey order: $e');
      throw e;
    }
  }

  Future<void> placeKitOrder({
    required String kitId,
    String? selectedSize,
    required String selectedHand,
    String? notes,
    required double totalAmount,
  }) async {
    try {
      final orderData = {
        'kitId': kitId,
        'type': 'KIT',
        'selectedSize': selectedSize,
        'selectedHand': selectedHand,
        'notes': notes,
        'totalAmount': totalAmount,
        'unitPrice': totalAmount,
        'quantity': 1,
      };

      await ApiService.post('/my/orders', orderData);

      // Reload store data and orders
      await loadStoreData();
      await loadOrders();
    } catch (e) {
      print('Error placing kit order: $e');
      throw e;
    }
  }

  Jersey? getJerseyById(String id) {
    try {
      return _jerseys.firstWhere((jersey) => jersey.id == id);
    } catch (e) {
      return null;
    }
  }

  Kit? getKitById(String id) {
    try {
      return _kits.firstWhere((kit) => kit.id == id);
    } catch (e) {
      return null;
    }
  }
}
