import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/club_message.dart';
import 'base_message_bubble.dart';

/// A specialized message bubble for displaying location messages
class LocationMessageBubble extends StatelessWidget {
  final ClubMessage message;
  final bool isOwn;
  final bool isPinned;
  final bool isSelected;
  final bool showSenderInfo;
  final Function(String messageId, String emoji, String userId)? onReactionRemoved;
  final Function()? onOpenMap;

  const LocationMessageBubble({
    super.key,
    required this.message,
    required this.isOwn,
    required this.isPinned,
    required this.isSelected,
    this.showSenderInfo = false,
    this.onReactionRemoved,
    this.onOpenMap,
  });

  @override
  Widget build(BuildContext context) {
    return BaseMessageBubble(
      message: message,
      isOwn: isOwn,
      isPinned: isPinned,
      isSelected: isSelected,
      customColor: Color(0xFF2196F3).withOpacity(0.1),
      showMetaOverlay: true,
      showShadow: true,
      onReactionRemoved: onReactionRemoved,
      content: _buildLocationContent(context),
    );
  }

  Widget _buildLocationContent(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final locationDetails = message.locationDetails ?? {};
    
    // Extract location information
    final locationName = locationDetails['name']?.toString() ?? 'Location';
    final address = locationDetails['address']?.toString() ?? '';
    final latitude = locationDetails['latitude'] as double?;
    final longitude = locationDetails['longitude'] as double?;
    final phoneNumber = locationDetails['phoneNumber']?.toString();
    final website = locationDetails['website']?.toString();
    
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF2196F3).withOpacity(isDarkMode ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Color(0xFF2196F3).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Location header with location icon
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Color(0xFF2196F3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.location_on,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            locationName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2196F3),
                            ),
                          ),
                          if (address.isNotEmpty)
                            Text(
                              address,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDarkMode ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.7),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 16),
                
                // Location details
                if (message.content.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(
                      message.content,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.white.withOpacity(0.87) : Colors.black.withOpacity(0.87),
                      ),
                    ),
                  ),
                
                // Contact information
                if (phoneNumber != null || website != null)
                  Column(
                    children: [
                      if (phoneNumber != null)
                        _buildContactRow(
                          context,
                          Icons.phone,
                          phoneNumber,
                          () => _launchPhone(phoneNumber),
                        ),
                      if (website != null)
                        _buildContactRow(
                          context,
                          Icons.language,
                          'Visit Website',
                          () => _launchUrl(website),
                        ),
                      SizedBox(height: 8),
                    ],
                  ),
                
                // Map button
                if (latitude != null && longitude != null)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _openInMap(latitude, longitude, locationName),
                      icon: Icon(
                        Icons.map,
                        size: 18,
                        color: Colors.white,
                      ),
                      label: Text(
                        'Open in Maps',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF2196F3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // Navigate button (top right corner)
          Positioned(
            top: 12,
            right: 12,
            child: InkWell(
              onTap: onOpenMap,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color(0xFF2196F3).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.navigation,
                  color: Color(0xFF2196F3),
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow(BuildContext context, IconData icon, String text, VoidCallback onTap) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: Color(0xFF2196F3),
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF2196F3),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openInMap(double latitude, double longitude, String locationName) async {
    final url = 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
    _launchUrl(url);
  }

  void _launchPhone(String phoneNumber) async {
    final url = 'tel:$phoneNumber';
    _launchUrl(url);
  }

  void _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print('❌ Error launching URL: $e');
    }
  }
}