// lib/models/transaction.dart
class Transaction {
  final String id;
  final double amount;
  final String type; // CREDIT or DEBIT
  final String purpose;
  final String description;
  final DateTime createdAt;
  final String? orderId;

  Transaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.purpose,
    required this.description,
    required this.createdAt,
    this.orderId,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'],
      amount: (json['amount'] ?? 0).toDouble(),
      type: json['type'],
      purpose: json['purpose'],
      description: json['description'],
      createdAt: DateTime.parse(json['createdAt']),
      orderId: json['orderId'],
    );
  }
}

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

---

// lib/screens/transactions_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/theme.dart';

class TransactionsScreen extends StatefulWidget {
  @override
  _TransactionsScreenState createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  List<Transaction> _transactions = [];
  bool _isLoading = false;
  double _balance = 0.0;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);

    try {
      final clubId = await AuthService.getCurrentClubId();
      if (clubId != null) {
        final response = await ApiService.get('/clubs/$clubId/transactions');
        setState(() {
          _transactions = (response['transactions'] as List)
              .map((tx) => Transaction.fromJson(tx))
              .toList();
          _balance = (response['balance'] ?? 0).toDouble();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load transactions: $e')),
      );
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadTransactions,
      child: Column(
        children: [
          // Balance Card
          Container(
            width: double.infinity,
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.cricketGreen, AppTheme.darkGreen],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.cricketGreen.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  'Current Balance',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '₹${_balance.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showTopUpDialog(),
                        icon: Icon(Icons.add, color: AppTheme.cricketGreen),
                        label: Text(
                          'Add Money',
                          style: TextStyle(color: AppTheme.cricketGreen),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.cricketGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Transactions List
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _transactions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long,
                              size: 80,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No transactions yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _transactions.length,
                        itemBuilder: (context, index) {
                          final transaction = _transactions[index];
                          return _buildTransactionCard(transaction);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(Transaction transaction) {
    final isCredit = transaction.type == 'CREDIT';
    final icon = _getTransactionIcon(transaction.purpose);
    
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isCredit ? Colors.green[100] : Colors.red[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: isCredit ? Colors.green : Colors.red,
          ),
        ),
        title: Text(
          transaction.description,
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getPurposeText(transaction.purpose),
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            Text(
              DateFormat('MMM dd, yyyy • hh:mm a').format(transaction.createdAt),
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 11,
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${isCredit ? '+' : '-'}₹${transaction.amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isCredit ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getTransactionIcon(String purpose) {
    switch (purpose) {
      case 'MATCH_FEE':
        return Icons.sports_cricket;
      case 'MEMBERSHIP':
        return Icons.card_membership;
      case 'ORDER':
        return Icons.shopping_cart;
      case 'CLUB_TOPUP':
        return Icons.account_balance_wallet;
      default:
        return Icons.receipt;
    }
  }

  String _getPurposeText(String purpose) {
    switch (purpose) {
      case 'MATCH_FEE':
        return 'Match Fee';
      case 'MEMBERSHIP':
        return 'Membership Fee';
      case 'ORDER':
        return 'Store Order';
      case 'CLUB_TOPUP':
        return 'Wallet Top-up';
      default:
        return 'Other';
    }
  }

  void _showTopUpDialog() {
    final _amountController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Money to Wallet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: '₹',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Note: This will create a transaction record. Please coordinate with your club admin for actual payment.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(_amountController.text);
              if (amount != null && amount > 0) {
                Navigator.of(context).pop();
                await _topUpWallet(amount);
              }
            },
            child: Text('Add Money'),
          ),
        ],
      ),
    );
  }

  Future<void> _topUpWallet(double amount) async {
    try {
      final clubId = await AuthService.getCurrentClubId();
      await ApiService.post('/clubs/$clubId/topup', {'amount': amount});
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Top-up request created successfully')),
      );
      
      await _loadTransactions();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create top-up request: $e')),
      );
    }
  }
}

---

// lib/screens/store_screen.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/theme.dart';
import 'jersey_detail_screen.dart';
import 'kit_detail_screen.dart';
import 'my_orders_screen.dart';

class StoreScreen extends StatefulWidget {
  @override
  _StoreScreenState createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  List<Jersey> _jerseys = [];
  List<Kit> _kits = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadStoreData();
  }

  Future<void> _loadStoreData() async {
    setState(() => _isLoading = true);

    try {
      final clubId = await AuthService.getCurrentClubId();
      if (clubId != null) {
        // Load jerseys
        final jerseysResponse = await ApiService.get('/clubs/$clubId/jerseys');
        _jerseys = (jerseysResponse as List).map((j) => Jersey.fromJson(j)).toList();

        // Load kits
        final kitsResponse = await ApiService.get('/clubs/$clubId/kits');
        _kits = (kitsResponse as List).map((k) => Kit.fromJson(k)).toList();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load store data: $e')),
      );
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Store'),
        backgroundColor: AppTheme.cricketGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.shopping_bag),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => MyOrdersScreen()),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: 'Jerseys'),
            Tab(text: 'Kits'),
            Tab(text: 'My Orders'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildJerseysTab(),
                _buildKitsTab(),
                MyOrdersScreen(),
              ],
            ),
    );
  }

  Widget _buildJerseysTab() {
    if (_jerseys.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.checkroom, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No jerseys available',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadStoreData,
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
    if (_kits.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sports_cricket, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No kits available',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadStoreData,
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
    return Card(
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
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  color: Colors.grey[100],
                ),
                child: jersey.images.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: jersey.images.first,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Center(
                          child: CircularProgressIndicator(),
                        ),
                        errorWidget: (context, url, error) => Icon(
                          Icons.checkroom,
                          size: 50,
                          color: Colors.grey,
                        ),
                      )
                    : Icon(
                        Icons.checkroom,
                        size: 50,
                        color: Colors.grey,
                      ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      jersey.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    if (jersey.description != null)
                      Text(
                        jersey.description!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '₹${jersey.basePrice.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.cricketGreen,
                            fontSize: 16,
                          ),
                        ),
                        if (!jersey.isOrderingEnabled)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Unavailable',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
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
    );
  }

  Widget _buildKitCard(Kit kit) {
    return Card(
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
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  color: Colors.grey[100],
                ),
                child: kit.images.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: kit.images.first,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Center(
                          child: CircularProgressIndicator(),
                        ),
                        errorWidget: (context, url, error) => Icon(
                          Icons.sports_cricket,
                          size: 50,
                          color: Colors.grey,
                        ),
                      )
                    : Icon(
                        Icons.sports_cricket,
                        size: 50,
                        color: Colors.grey,
                      ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kit.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      _getKitTypeText(kit.type),
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.cricketGreen,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (kit.brand != null) ...[
                      SizedBox(height: 2),
                      Text(
                        kit.brand!,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                    Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '₹${kit.basePrice.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.cricketGreen,
                            fontSize: 16,
                          ),
                        ),
                        if (kit.stockQuantity == 0)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Out of Stock',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
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
    );
  }

  String _getKitTypeText(String type) {
    return type.replaceAll('_', ' ').toLowerCase().split(' ').map((word) {
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }
}