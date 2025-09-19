import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  static const String _clubStarterAnnual = 'club_starter_annual';
  static const String _teamCaptainAnnual = 'team_captain_annual';
  static const String _leagueMasterAnnual = 'league_master_annual';

  static const Set<String> _productIds = {
    _clubStarterAnnual,
    _teamCaptainAnnual,
    _leagueMasterAnnual,
  };

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  List<ProductDetails> _products = [];
  bool _isAvailable = false;
  bool _purchasePending = false;
  String? _queryProductError;

  // Getters
  bool get isAvailable => _isAvailable;
  bool get purchasePending => _purchasePending;
  List<ProductDetails> get products => _products;
  String? get queryProductError => _queryProductError;

  Future<void> initializeStore() async {
    // Check if the store is available on this device
    final bool available = await _inAppPurchase.isAvailable();
    if (!available) {
      _isAvailable = false;
      _queryProductError = 'Store not available on this device';
      return;
    }

    // Listen to purchase stream
    final Stream<List<PurchaseDetails>> purchaseUpdated = _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen(
      (List<PurchaseDetails> purchaseDetailsList) {
        _listenToPurchaseUpdated(purchaseDetailsList);
      },
      onDone: () {
        _subscription.cancel();
      },
      onError: (Object error) {
        debugPrint('Purchase stream error: $error');
      },
    );

    // Query available products
    await _queryProducts();
  }

  Future<void> _queryProducts() async {
    try {
      final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(_productIds);

      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('Products not found: ${response.notFoundIDs}');
      }

      if (response.error != null) {
        _queryProductError = response.error!.message;
        debugPrint('Query products error: ${response.error}');
        return;
      }

      if (response.productDetails.isEmpty) {
        _queryProductError = 'No products found';
        debugPrint('No products found');
        return;
      }

      _products = response.productDetails;
      _isAvailable = true;
      _queryProductError = null;

      debugPrint('Products loaded: ${_products.length}');
      for (var product in _products) {
        debugPrint('Product: ${product.id} - ${product.title} - ${product.price}');
      }
    } catch (e) {
      _queryProductError = 'Failed to query products: $e';
      debugPrint('Exception querying products: $e');
    }
  }

  Future<bool> buySubscription(String productId) async {
    if (!_isAvailable) {
      debugPrint('Store not available for purchase');
      return false;
    }

    final ProductDetails? productDetails = _products
        .cast<ProductDetails?>()
        .firstWhere((product) => product?.id == productId, orElse: () => null);

    if (productDetails == null) {
      debugPrint('Product not found: $productId');
      return false;
    }

    final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);

    try {
      _purchasePending = true;

      if (Platform.isIOS) {
        // For iOS subscriptions
        final bool success = await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
        debugPrint('iOS subscription purchase initiated: $success');
        return success;
      } else {
        // For Android subscriptions
        final bool success = await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
        debugPrint('Android subscription purchase initiated: $success');
        return success;
      }
    } catch (e) {
      _purchasePending = false;
      debugPrint('Purchase error: $e');
      return false;
    }
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      debugPrint('Purchase status: ${purchaseDetails.status}');

      if (purchaseDetails.status == PurchaseStatus.pending) {
        _purchasePending = true;
      } else {
        _purchasePending = false;

        if (purchaseDetails.status == PurchaseStatus.error) {
          debugPrint('Purchase error: ${purchaseDetails.error}');
          _handleError(purchaseDetails.error!);
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
                   purchaseDetails.status == PurchaseStatus.restored) {
          _handleSuccessfulPurchase(purchaseDetails);
        }

        if (purchaseDetails.pendingCompletePurchase) {
          _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    }
  }

  void _handleSuccessfulPurchase(PurchaseDetails purchaseDetails) {
    debugPrint('Purchase successful: ${purchaseDetails.productID}');

    // Here you would typically:
    // 1. Verify the purchase with your backend
    // 2. Update user's subscription status in your database
    // 3. Grant access to premium features

    // For now, we'll just complete the purchase
    if (purchaseDetails.pendingCompletePurchase) {
      _inAppPurchase.completePurchase(purchaseDetails);
    }
  }

  void _handleError(IAPError error) {
    debugPrint('Purchase failed: ${error.message}');
    // Handle purchase errors - show user-friendly messages
  }

  Future<void> restorePurchases() async {
    if (!_isAvailable) {
      debugPrint('Store not available for restore');
      return;
    }

    try {
      await _inAppPurchase.restorePurchases();
      debugPrint('Restore purchases initiated');
    } catch (e) {
      debugPrint('Restore purchases error: $e');
    }
  }

  // Get product details by ID
  ProductDetails? getProductById(String productId) {
    try {
      return _products.firstWhere((product) => product.id == productId);
    } catch (e) {
      return null;
    }
  }

  // Check if user has active subscription
  Future<bool> hasActiveSubscription(String productId) async {
    // This would typically check with your backend API
    // For now, return false as placeholder
    return false;
  }

  void dispose() {
    _subscription.cancel();
  }
}