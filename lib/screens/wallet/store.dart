// lib/screens/store_screen.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/product.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../utils/theme.dart';

import './jersey_detail.dart';
import './kit_detail.dart';

class StoreScreen extends StatefulWidget {
  @override
  _StoreScreenState createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  List<Product> _products = [];
  List<Jersey> _jerseys = [];
  List<Kit> _kits = [];
  bool _isLoading = false;
  StoreMeta? _meta;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadStoreData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStoreData() async {
    setState(() => _isLoading = true);

    try {
      final clubId = await AuthService.getCurrentClubId();
      if (clubId != null) {
        final response = await ApiService.get('/store');
        final storeResponse = StoreResponse.fromJson(response);
        
        setState(() {
          _products = storeResponse.products;
          _meta = storeResponse.meta;
          
          // Convert products to jerseys and kits directly from API response
          _jerseys = [];
          _kits = [];
          
          for (final product in _products) {
            if (product.productType == 'JERSEY') {
              _jerseys.add(Jersey(
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
              ));
            } else if (product.productType == 'KIT') {
              _kits.add(Kit(
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
              ));
            }
          }
        });
      }
    } catch (e) {
      print('Store loading error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load store data: $e')),
      );
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Store'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.home_outlined),
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
            tooltip: 'Go to Home',
          ),
        ],
      ),
      body: Column(
        children: [
          // Store Header
          Container(
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).dividerColor.withOpacity(0.3),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).shadowColor.withOpacity(0.04),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.store,
                    color: Theme.of(context).colorScheme.primary,
                    size: 24,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Club Store',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Theme.of(context).textTheme.titleLarge?.color,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        _meta != null 
                          ? '${_meta!.jerseyCount} jerseys • ${_meta!.kitCount} kits'
                          : 'Loading products...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),

          // Custom Tab Bar
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16),
            padding: EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).dividerColor.withOpacity(0.3),
                width: 0.5,
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              labelColor: Theme.of(context).colorScheme.onPrimary,
              unselectedLabelColor: Theme.of(context).textTheme.bodySmall?.color,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
              unselectedLabelStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
              tabs: [
                Tab(
                  text: _meta != null ? 'Jerseys (${_meta!.jerseyCount})' : 'Jerseys',
                ),
                Tab(
                  text: _meta != null ? 'Kits (${_meta!.kitCount})' : 'Kits',
                ),
                Tab(text: 'My Orders'),
              ],
            ),
          ),

          SizedBox(height: 16),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildJerseysTab(),
                _buildKitsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJerseysTab() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          strokeWidth: 3,
          color: Theme.of(context).colorScheme.primary,
        ),
      );
    }

    if (_jerseys.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppTheme.cricketGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.checkroom_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'No jerseys available',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Check back later for new jerseys',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadStoreData,
      color: Theme.of(context).colorScheme.primary,
      child: GridView.builder(
        padding: EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: _jerseys.length,
        itemBuilder: (context, index) {
          final jersey = _jerseys[index];
          return _buildJerseyCard(jersey);
        },
      ),
    );
  }

  Widget _buildKitsTab() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          strokeWidth: 3,
          color: Theme.of(context).colorScheme.primary,
        ),
      );
    }

    if (_kits.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppTheme.cricketGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.sports_cricket_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'No kits available',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Check back later for new kits',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadStoreData,
      color: Theme.of(context).colorScheme.primary,
      child: GridView.builder(
        padding: EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: _kits.length,
        itemBuilder: (context, index) {
          final kit = _kits[index];
          return _buildKitCard(kit);
        },
      ),
    );
  }

  Widget _buildJerseyCard(Jersey jersey) {
    return Container(
      decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).dividerColor.withOpacity(0.3),
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).shadowColor.withOpacity(0.04),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => JerseyDetailScreen(jersey: jersey),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Section
              Expanded(
                flex: 3,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    color: Theme.of(context).scaffoldBackgroundColor,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    child: jersey.images.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: jersey.images.first.url,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              child: Icon(
                                Icons.checkroom,
                                size: 50,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          )
                        : Container(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            child: Icon(
                              Icons.checkroom,
                              size: 50,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                  ),
                ),
              ),
              
              // Content Section
              Expanded(
                flex: 2,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        jersey.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          fontSize: 12,
                          color: Theme.of(context).textTheme.titleLarge?.color,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      if (jersey.description != null && jersey.description!.isNotEmpty)
                        Text(
                          jersey.description!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      
                      // Order status indicator
                      if (jersey.hasOrdered) ...[
                        SizedBox(height: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.lightBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppTheme.lightBlue.withOpacity(0.3),
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            'Ordered (${jersey.userOrderCount})',
                            style: TextStyle(
                              color: AppTheme.lightBlue,
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                      
                      Spacer(),
                      
                      // Price and availability
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '₹${jersey.basePrice.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w400,
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 12,
                            ),
                          ),
                          if (!jersey.availability.canOrder)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.errorRed.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Unavailable',
                                style: TextStyle(
                                  color: AppTheme.errorRed,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKitCard(Kit kit) {
    return Container(
      decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).dividerColor.withOpacity(0.3),
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).shadowColor.withOpacity(0.04),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => KitDetailScreen(kit: kit),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Section
              Expanded(
                flex: 3,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    color: Theme.of(context).scaffoldBackgroundColor,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    child: kit.images.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: kit.images.first.url,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              child: Icon(
                                Icons.sports_cricket,
                                size: 50,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          )
                        : Container(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            child: Icon(
                              Icons.sports_cricket,
                              size: 50,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                  ),
                ),
              ),
              
              // Content Section
              Expanded(
                flex: 2,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        kit.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          fontSize: 12,
                          color: Theme.of(context).textTheme.titleLarge?.color,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.cricketGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getKitTypeText(kit.type),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      if (kit.brand != null) ...[
                        SizedBox(height: 4),
                        Text(
                          kit.brand!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                      ],
                      
                      // Order status indicator
                      if (kit.hasOrdered) ...[
                        SizedBox(height: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.lightBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppTheme.lightBlue.withOpacity(0.3),
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            'Ordered (${kit.userOrderCount})',
                            style: TextStyle(
                              color: AppTheme.lightBlue,
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                      
                      Spacer(),
                      
                      // Price and availability
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '₹${kit.basePrice.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w400,
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 12,
                            ),
                          ),
                          if (!kit.availability.canOrder)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.errorRed.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                kit.stockQuantity == 0 ? 'Out of Stock' : 'Unavailable',
                                style: TextStyle(
                                  color: AppTheme.errorRed,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getKitTypeText(String type) {
    return type.replaceAll('_', ' ').toLowerCase().split(' ').map((word) {
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }
}