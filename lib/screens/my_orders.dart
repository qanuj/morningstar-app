// lib/screens/my_orders_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';
import '../widgets/custom_app_bar.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({Key? key}) : super(key: key);
  
  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  List<Order> _orders = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);

    try {
      final response = await ApiService.get('/my/orders');
      setState(() {
        _orders = (response['data'] as List).map((order) => Order.fromJson(order)).toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load orders: $e')),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: DetailAppBar(
        pageTitle: 'My Orders',
        customActions: [
          IconButton(
            icon: Icon(Icons.home_outlined),
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
            tooltip: 'Go to Home',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Theme.of(context).colorScheme.primary,
              ),
            )
          : _orders.isEmpty
              ? Center(
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
                          Icons.shopping_bag_outlined,
                          size: 64,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      SizedBox(height: 24),
                      Text(
                        'No orders yet',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Theme.of(context).textTheme.titleLarge?.color,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Your store orders will appear here',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadOrders,
                  color: Theme.of(context).colorScheme.primary,
                  child: ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: _orders.length,
                    itemBuilder: (context, index) {
                      final order = _orders[index];
                      return _buildOrderCard(order);
                    },
                  ),
                ),
    );
  }

  Widget _buildOrderCard(Order order) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
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
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with order number and status
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order #${order.orderNumber}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Theme.of(context).textTheme.titleLarge?.color,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        DateFormat('MMM dd, yyyy • hh:mm a').format(order.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(order.status),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _getStatusText(order.status),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.surface,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Club info
            Row(
              children: [
                if (order.club.logo != null)
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: order.club.logo!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Icon(
                          Icons.sports_cricket, 
                          size: 16, 
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        errorWidget: (context, url, error) => Icon(
                          Icons.sports_cricket, 
                          size: 16, 
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                SizedBox(width: 8),
                Text(
                  order.club.name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            
            // Order details
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.dividerColor.withOpacity(0.3),
                  width: 0.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        order.type == 'JERSEY' ? Icons.checkroom : Icons.sports_cricket,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          order.type == 'JERSEY' ? 
                            (order.jersey?.name ?? 'Jersey Order') :
                            (order.kit?.name ?? 'Kit Order'),
                          style: TextStyle(
                            fontWeight: FontWeight.w400,
                            fontSize: 12,
                            color: Theme.of(context).textTheme.titleLarge?.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  
                  if (order.type == 'JERSEY') ...[
                    if (order.customName != null)
                      _buildDetailRow('Name', order.customName!),
                    if (order.jerseyNumber != null)
                      _buildDetailRow('Number', order.jerseyNumber!),
                    if (order.jerseySize != null)
                      _buildDetailRow('Size', order.jerseySize!),
                    if (order.sleeveLength != null)
                      _buildDetailRow('Sleeve', _formatSleeveLength(order.sleeveLength!)),
                    if (order.includeCap == true || order.includeTrousers == true) ...[
                      _buildDetailRow('Extras', _getExtrasText(order)),
                    ],
                  ] else if (order.type == 'KIT') ...[
                    if (order.selectedSize != null)
                      _buildDetailRow('Size', order.selectedSize!),
                    if (order.selectedHand != null)
                      _buildDetailRow('Hand', order.selectedHand!),
                  ],
                  
                  _buildDetailRow('Quantity', '${order.quantity}'),
                  _buildDetailRow('Unit Price', '₹${order.unitPrice.toStringAsFixed(0)}'),
                  
                  if (order.notes != null && order.notes!.isNotEmpty) ...[
                    SizedBox(height: 8),
                    Text(
                      'Notes: ${order.notes!}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // Status update info
            if (order.latestStatusUpdate != null) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.lightBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.lightBlue.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: AppTheme.lightBlue),
                        SizedBox(width: 6),
                        Text(
                          'Latest Update',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: AppTheme.lightBlue,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    if (order.latestStatusUpdate!.notes != null)
                      Text(
                        order.latestStatusUpdate!.notes!,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.lightBlue,
                        ),
                      ),
                    if (order.latestStatusUpdate!.changedBy != null)
                      Text(
                        'by ${order.latestStatusUpdate!.changedBy!.name}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.lightBlue,
                        ),
                      ),
                  ],
                ),
              ),
            ],
            
            SizedBox(height: 16),
            
            // Total and delivery info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Amount',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                    Text(
                      '₹${order.totalAmount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                if (order.estimatedDelivery != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Est. Delivery',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                      Text(
                        DateFormat('MMM dd, yyyy').format(order.estimatedDelivery!),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Theme.of(context).textTheme.titleLarge?.color,
                        ),
                      ),
                    ],
                  ),
              ],
            ),

            // Product images
            if (order.type == 'JERSEY' && order.jersey?.images.isNotEmpty == true) ...[
              SizedBox(height: 12),
              Container(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: order.jersey!.images.length,
                  itemBuilder: (context, index) {
                    return Container(
                      width: 60,
                      height: 60,
                      margin: EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: order.jersey!.images[index].url,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Icon(
                            Icons.checkroom,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          errorWidget: (context, url, error) => Icon(
                            Icons.checkroom,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ] else if (order.type == 'KIT' && order.kit?.images.isNotEmpty == true) ...[
              SizedBox(height: 12),
              Container(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: order.kit!.images.length,
                  itemBuilder: (context, index) {
                    return Container(
                      width: 60,
                      height: 60,
                      margin: EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: order.kit!.images[index].url,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Icon(
                            Icons.sports_cricket,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          errorWidget: (context, url, error) => Icon(
                            Icons.sports_cricket,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatSleeveLength(String sleeveLength) {
    switch (sleeveLength.toUpperCase()) {
      case 'HALF':
        return 'Half Sleeve';
      case 'FULL':
        return 'Full Sleeve';
      default:
        return sleeveLength;
    }
  }

  String _getExtrasText(Order order) {
    List<String> extras = [];
    if (order.includeCap == true) extras.add('Cap');
    if (order.includeTrousers == true) {
      extras.add('Trousers${order.trouserSize != null ? ' (${order.trouserSize})' : ''}');
    }
    return extras.join(', ');
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppTheme.warningOrange;
      case 'confirmed':
        return AppTheme.lightBlue;
      case 'in_production':
        return AppTheme.primaryBlue;
      case 'ready':
        return AppTheme.successGreen;
      case 'delivered':
        return AppTheme.lighterBlue;
      case 'cancelled':
        return AppTheme.errorRed;
      default:
        return AppTheme.secondaryTextColor;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'PENDING';
      case 'confirmed':
        return 'CONFIRMED';
      case 'in_production':
        return 'IN PRODUCTION';
      case 'ready':
        return 'READY';
      case 'delivered':
        return 'DELIVERED';
      case 'cancelled':
        return 'CANCELLED';
      default:
        return status.toUpperCase();
    }
  }
}