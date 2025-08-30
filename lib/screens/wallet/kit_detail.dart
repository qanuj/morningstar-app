// lib/screens/kit_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/product.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../utils/theme.dart';

class KitDetailScreen extends StatefulWidget {
  final Kit kit;

  KitDetailScreen({required this.kit});

  @override
  _KitDetailScreenState createState() => _KitDetailScreenState();
}

class _KitDetailScreenState extends State<KitDetailScreen> {
  String? _selectedSize;
  String _selectedHand = 'BOTH';
  final _notesController = TextEditingController();
  bool _isOrdering = false;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.kit.availableSizes?.isNotEmpty == true) {
      _selectedSize = widget.kit.availableSizes!.first;
    }
    _selectedHand = widget.kit.handType;
  }

  Future<void> _placeOrder() async {
    setState(() => _isOrdering = true);

    try {
      final clubId = await AuthService.getCurrentClubId();
      final orderData = {
        'kitId': widget.kit.id,
        'type': 'KIT',
        'selectedSize': _selectedSize,
        'selectedHand': _selectedHand,
        'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        'totalAmount': widget.kit.basePrice,
        'unitPrice': widget.kit.basePrice,
        'quantity': 1,
      };

      await ApiService.post('/clubs/$clubId/orders', orderData);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order placed successfully!')),
      );
      
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to place order: $e')),
      );
    }

    setState(() => _isOrdering = false);
  }

  @override
  Widget build(BuildContext context) {
    final isAvailable = widget.kit.stockQuantity > 0 && 
                       widget.kit.isOrderingEnabled && 
                       widget.kit.availability.canOrder;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.kit.name),
        backgroundColor: AppTheme.cricketGreen,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Gallery
            Container(
              height: 300,
              child: widget.kit.images.isNotEmpty
                  ? PageView.builder(
                      itemCount: widget.kit.images.length,
                      onPageChanged: (index) => setState(() => _currentImageIndex = index),
                      itemBuilder: (context, index) {
                        return CachedNetworkImage(
                          imageUrl: widget.kit.images[index].url,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Center(
                            child: CircularProgressIndicator(),
                          ),
                          errorWidget: (context, url, error) => Center(
                            child: Icon(Icons.sports_cricket, size: 100, color: Colors.grey),
                          ),
                        );
                      },
                    )
                  : Container(
                      color: Colors.grey[200],
                      child: Center(
                        child: Icon(Icons.sports_cricket, size: 100, color: Colors.grey),
                      ),
                    ),
            ),
            
            // Image indicators
            if (widget.kit.images.length > 1)
              Container(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: widget.kit.images.asMap().entries.map((entry) {
                    return Container(
                      margin: EdgeInsets.symmetric(horizontal: 4),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentImageIndex == entry.key 
                            ? AppTheme.cricketGreen 
                            : Colors.grey[300],
                      ),
                    );
                  }).toList(),
                ),
              ),

            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Info
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.kit.name,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            SizedBox(height: 8),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.cricketGreen.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                _getKitTypeText(widget.kit.type),
                                style: TextStyle(
                                  color: AppTheme.cricketGreen,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.kit.club.logo != null)
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: widget.kit.club.logo!,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Icon(Icons.sports_cricket),
                              errorWidget: (context, url, error) => Icon(Icons.sports_cricket),
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 16),
                  
                  if (widget.kit.description != null && widget.kit.description!.isNotEmpty)
                    Text(
                      widget.kit.description!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  SizedBox(height: 16),

                  // Order Status
                  if (widget.kit.hasOrdered)
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.blue),
                          SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Already Ordered',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w400,
                                    color: Colors.blue[700],
                                  ),
                                ),
                                Text(
                                  'You have ${widget.kit.userOrderCount} order(s) for this kit',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  SizedBox(height: 16),

                  // Product Details
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Product Details',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        SizedBox(height: 12),
                        if (widget.kit.brand != null)
                          _buildDetailRow('Brand', widget.kit.brand!),
                        if (widget.kit.model != null)
                          _buildDetailRow('Model', widget.kit.model!),
                        if (widget.kit.color != null)
                          _buildDetailRow('Color', widget.kit.color!),
                        if (widget.kit.material != null)
                          _buildDetailRow('Material', widget.kit.material!),
                        if (widget.kit.weight != null)
                          _buildDetailRow('Weight', '${widget.kit.weight!.toStringAsFixed(0)}g'),
                        if (widget.kit.size != null)
                          _buildDetailRow('Size', widget.kit.size!),
                        _buildDetailRow('Type', _getKitTypeText(widget.kit.type)),
                        _buildDetailRow('Stock', '${widget.kit.stockQuantity} available'),
                        _buildDetailRow('Price', '₹${widget.kit.basePrice.toStringAsFixed(0)}'),
                      ],
                    ),
                  ),

                  SizedBox(height: 24),

                  // Order Form
                  if (isAvailable) ...[
                    Text(
                      'Place Your Order',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    SizedBox(height: 16),

                    // Size Selection
                    if (widget.kit.availableSizes?.isNotEmpty == true) ...[
                      Text(
                        'Size',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
                      ),
                      SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: widget.kit.availableSizes!.map((size) {
                          return ChoiceChip(
                            label: Text(size),
                            selected: _selectedSize == size,
                            onSelected: (selected) {
                              if (selected) setState(() => _selectedSize = size);
                            },
                            selectedColor: AppTheme.cricketGreen,
                            labelStyle: TextStyle(
                              color: _selectedSize == size ? Colors.white : Colors.black,
                            ),
                          );
                        }).toList(),
                      ),
                      SizedBox(height: 16),
                    ],

                    // Hand Selection (for relevant items)
                    if (_needsHandSelection()) ...[
                      Text(
                        'Hand Preference',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
                      ),
                      SizedBox(height: 8),
                      Column(
                        children: [
                          RadioListTile<String>(
                            title: Text('Left Hand'),
                            value: 'LEFT',
                            groupValue: _selectedHand,
                            onChanged: (value) => setState(() => _selectedHand = value!),
                            activeColor: AppTheme.cricketGreen,
                          ),
                          RadioListTile<String>(
                            title: Text('Right Hand'),
                            value: 'RIGHT',
                            groupValue: _selectedHand,
                            onChanged: (value) => setState(() => _selectedHand = value!),
                            activeColor: AppTheme.cricketGreen,
                          ),
                          RadioListTile<String>(
                            title: Text('Both Hands'),
                            value: 'BOTH',
                            groupValue: _selectedHand,
                            onChanged: (value) => setState(() => _selectedHand = value!),
                            activeColor: AppTheme.cricketGreen,
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                    ],

                    // Notes
                    TextField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Special Instructions (Optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 32),

                    // Order Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: !_isOrdering ? _placeOrder : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.cricketGreen,
                          padding: EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isOrdering
                            ? CircularProgressIndicator(color: Colors.white)
                            : Text(
                                'Place Order - ₹${widget.kit.basePrice.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ] else ...[
                    // Unavailable message
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.error, color: Colors.red),
                          SizedBox(height: 8),
                          Text(
                            widget.kit.stockQuantity == 0 
                                ? 'Out of Stock'
                                : 'Ordering Unavailable',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: Colors.red[700],
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            widget.kit.stockQuantity == 0 
                                ? 'This item is currently out of stock.'
                                : widget.kit.availability.reason,
                            style: TextStyle(
                              color: Colors.red[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],

                  SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getKitTypeText(String type) {
    return type.replaceAll('_', ' ').toLowerCase().split(' ').map((word) {
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  bool _needsHandSelection() {
    final handRelevantTypes = [
      'BATTING_GLOVES',
      'WICKET_KEEPING_GLOVES',
      'BAT_ENGLISH_WILLOW',
      'BAT_KASHMIR_WILLOW',
      'BAT_PLASTIC',
      'BAT_ALUMINUM',
    ];
    return handRelevantTypes.contains(widget.kit.type);
  }
}