// lib/screens/jersey_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/theme.dart';

class JerseyDetailScreen extends StatefulWidget {
  final Jersey jersey;

  JerseyDetailScreen({required this.jersey});

  @override
  _JerseyDetailScreenState createState() => _JerseyDetailScreenState();
}

class _JerseyDetailScreenState extends State<JerseyDetailScreen> {
  String _selectedSize = 'M';
  String _sleeveLength = 'HALF';
  bool _includeCap = false;
  bool _includeTrousers = false;
  String _trouserSize = 'M';
  final _nameController = TextEditingController();
  final _numberController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isOrdering = false;
  int _currentImageIndex = 0;

  final List<String> _sizes = ['XS', 'S', 'M', 'L', 'XL', 'XXL', 'XXXL'];

  double get _totalPrice {
    double total = widget.jersey.basePrice;
    if (_sleeveLength == 'FULL') {
      total += widget.jersey.fullSleevePrice;
    }
    if (_includeCap) {
      total += widget.jersey.capPrice;
    }
    if (_includeTrousers) {
      total += widget.jersey.trouserPrice;
    }
    return total;
  }

  @override
  void initState() {
    super.initState();
    // Pre-fill existing order details if user has already ordered
    if (widget.jersey.hasOrdered && widget.jersey.userOrders.isNotEmpty) {
      _loadExistingOrderDetails();
    }
  }

  void _loadExistingOrderDetails() {
    // This would typically come from a separate API call to get order details
    // For now, we'll just show that the user has already ordered
  }

  Future<void> _placeOrder() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter name for jersey')),
      );
      return;
    }

    setState(() => _isOrdering = true);

    try {
      final clubId = await AuthService.getCurrentClubId();
      final orderData = {
        'jerseyId': widget.jersey.id,
        'type': 'JERSEY',
        'jerseySize': _selectedSize,
        'sleeveLength': _sleeveLength,
        'customName': _nameController.text.trim(),
        'jerseyNumber': _numberController.text.trim().isEmpty ? null : _numberController.text.trim(),
        'includeCap': _includeCap,
        'includeTrousers': _includeTrousers,
        'trouserSize': _includeTrousers ? _trouserSize : null,
        'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        'totalAmount': _totalPrice,
        'unitPrice': _totalPrice,
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
    final canOrder = widget.jersey.availability.canOrder && widget.jersey.isOrderingEnabled;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.jersey.name),
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
              child: widget.jersey.images.isNotEmpty
                  ? PageView.builder(
                      itemCount: widget.jersey.images.length,
                      onPageChanged: (index) => setState(() => _currentImageIndex = index),
                      itemBuilder: (context, index) {
                        return CachedNetworkImage(
                          imageUrl: widget.jersey.images[index].url,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Center(
                            child: CircularProgressIndicator(),
                          ),
                          errorWidget: (context, url, error) => Center(
                            child: Icon(Icons.checkroom, size: 100, color: Colors.grey),
                          ),
                        );
                      },
                    )
                  : Container(
                      color: Colors.grey[200],
                      child: Center(
                        child: Icon(Icons.checkroom, size: 100, color: Colors.grey),
                      ),
                    ),
            ),
            
            // Image indicators
            if (widget.jersey.images.length > 1)
              Container(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: widget.jersey.images.asMap().entries.map((entry) {
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
                              widget.jersey.name,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            SizedBox(height: 8),
                            if (widget.jersey.description != null && widget.jersey.description!.isNotEmpty)
                              Text(
                                widget.jersey.description!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (widget.jersey.club.logo != null)
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: widget.jersey.club.logo!,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Icon(Icons.sports_cricket),
                              errorWidget: (context, url, error) => Icon(Icons.sports_cricket),
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 16),

                  // Order Status
                  if (widget.jersey.hasOrdered)
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
                                  'You have ${widget.jersey.userOrderCount} order(s) for this jersey',
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

                  // Pricing
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.cricketGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pricing',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        SizedBox(height: 8),
                        _buildPriceRow('Base Price', widget.jersey.basePrice),
                        if (widget.jersey.fullSleevePrice > 0)
                          _buildPriceRow('Full Sleeve (extra)', widget.jersey.fullSleevePrice),
                        if (widget.jersey.capPrice > 0)
                          _buildPriceRow('Cap (extra)', widget.jersey.capPrice),
                        if (widget.jersey.trouserPrice > 0)
                          _buildPriceRow('Trousers (extra)', widget.jersey.trouserPrice),
                        Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            Text(
                              '₹${_totalPrice.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: AppTheme.cricketGreen,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 24),

                  // Order Form
                  if (canOrder) ...[
                    Text(
                      'Customize Your Jersey',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    SizedBox(height: 16),

                    // Name Field
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Name on Jersey *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 16),

                    // Number Field
                    TextField(
                      controller: _numberController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Jersey Number (Optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 16),

                    // Size Selection
                    Text(
                      'Size',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
                    ),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: _sizes.map((size) {
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

                    // Sleeve Length
                    Text(
                      'Sleeve Length',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: Text('Half Sleeve'),
                            value: 'HALF',
                            groupValue: _sleeveLength,
                            onChanged: (value) => setState(() => _sleeveLength = value!),
                            activeColor: AppTheme.cricketGreen,
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: Text('Full Sleeve'),
                            value: 'FULL',
                            groupValue: _sleeveLength,
                            onChanged: (value) => setState(() => _sleeveLength = value!),
                            activeColor: AppTheme.cricketGreen,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),

                    // Extras
                    Text(
                      'Extras',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
                    ),
                    SizedBox(height: 8),
                    
                    if (widget.jersey.capPrice > 0)
                      CheckboxListTile(
                        title: Text('Include Cap (+₹${widget.jersey.capPrice.toStringAsFixed(0)})'),
                        value: _includeCap,
                        onChanged: (value) => setState(() => _includeCap = value!),
                        activeColor: AppTheme.cricketGreen,
                      ),
                    
                    if (widget.jersey.trouserPrice > 0) ...[
                      CheckboxListTile(
                        title: Text('Include Trousers (+₹${widget.jersey.trouserPrice.toStringAsFixed(0)})'),
                        value: _includeTrousers,
                        onChanged: (value) => setState(() => _includeTrousers = value!),
                        activeColor: AppTheme.cricketGreen,
                      ),
                      if (_includeTrousers) ...[
                        SizedBox(height: 8),
                        Text(
                          'Trouser Size',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
                        ),
                        SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: _sizes.map((size) {
                            return ChoiceChip(
                              label: Text(size),
                              selected: _trouserSize == size,
                              onSelected: (selected) {
                                if (selected) setState(() => _trouserSize = size);
                              },
                              selectedColor: AppTheme.cricketGreen,
                              labelStyle: TextStyle(
                                color: _trouserSize == size ? Colors.white : Colors.black,
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],

                    SizedBox(height: 16),

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
                          disabledBackgroundColor: Colors.grey,
                        ),
                        child: _isOrdering
                            ? CircularProgressIndicator(color: Colors.white)
                            : Text(
                                'Place Order - ₹${_totalPrice.toStringAsFixed(0)}',
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
                            'Ordering Unavailable',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: Colors.red[700],
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            widget.jersey.availability.reason,
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

  Widget _buildPriceRow(String label, double price) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text('₹${price.toStringAsFixed(0)}'),
        ],
      ),
    );
  }
}