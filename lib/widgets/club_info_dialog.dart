import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/club.dart';
import '../providers/user_provider.dart';

class ClubInfoDialog extends StatelessWidget {
  final Club club;

  const ClubInfoDialog({
    Key? key,
    required this.club,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final userProvider = context.read<UserProvider>();
    final user = userProvider.user;
    
    return Dialog(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Color(0xFF2a2f32)
          : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: EdgeInsets.all(24),
        child: Stack(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Club Logo
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF003f9b).withOpacity(0.1),
                    border: Border.all(
                      color: Color(0xFF003f9b),
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(40),
                    child: club.logo != null && club.logo!.isNotEmpty
                        ? Image.network(
                            club.logo!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.sports_cricket,
                                size: 40,
                                color: Color(0xFF003f9b),
                              );
                            },
                          )
                        : Icon(
                            Icons.sports_cricket,
                            size: 40,
                            color: Color(0xFF003f9b),
                          ),
                  ),
                ),
                SizedBox(height: 16),
                
                // Club Name
                Text(
                  club.name,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Color(0xFF003f9b),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),
                
                // Your Membership Section
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Color(0xFF003f9b).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Color(0xFF003f9b).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            color: Color(0xFF003f9b),
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Your Membership',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF003f9b),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      _buildMembershipRow('Status', 'Active Member', Icons.verified),
                      _buildMembershipRow('Role', 'Member', Icons.group), // TODO: Fetch from API
                      _buildMembershipRow('Joined', 'Recently', Icons.calendar_today),
                      _buildMembershipRow('Balance', '₹0.00', Icons.account_balance_wallet),
                    ],
                  ),
                ),
                
                SizedBox(height: 20),
                
                // Club Info
                _buildInfoRow(Icons.people, 'Total Members', 'Loading...'), // TODO: Fetch from API
                _buildInfoRow(Icons.sports_cricket, 'Sport', 'Cricket'),
                _buildInfoRow(Icons.location_on, 'Location', club.city ?? 'Not specified'),
                _buildInfoRow(Icons.calendar_today, 'Established', 'N/A'), // TODO: Fetch from API
              ],
            ),
            
            // Close icon in top right
            Positioned(
              top: -8,
              right: -8,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(
                  Icons.close,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withOpacity(0.7)
                      : Colors.black.withOpacity(0.6),
                ),
                tooltip: 'Close',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMembershipRow(String label, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: Color(0xFF003f9b).withOpacity(0.7),
          ),
          SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF003f9b).withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF003f9b),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: Color(0xFF003f9b),
          ),
          SizedBox(width: 12),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF003f9b).withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF003f9b),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}