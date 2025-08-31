import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/club.dart';
import '../providers/user_provider.dart';

class ClubInfoDialog extends StatelessWidget {
  final Club club;
  final DetailedClubInfo? detailedClubInfo;

  const ClubInfoDialog({
    Key? key,
    required this.club,
    this.detailedClubInfo,
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
                    child: (detailedClubInfo?.logo ?? club.logo) != null && (detailedClubInfo?.logo ?? club.logo)!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: detailedClubInfo?.logo ?? club.logo!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF003f9b)),
                                strokeWidth: 2,
                              ),
                            ),
                            errorWidget: (context, url, error) => Icon(
                              Icons.sports_cricket,
                              size: 40,
                              color: Color(0xFF003f9b),
                            ),
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
                  detailedClubInfo?.name ?? club.name,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Color(0xFF003f9b),
                  ),
                  textAlign: TextAlign.center,
                ),
                
                // Club Description
                if ((detailedClubInfo?.description ?? club.description) != null) ...[
                  SizedBox(height: 8),
                  Text(
                    detailedClubInfo?.description ?? club.description!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white70
                          : Color(0xFF6C757D),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                
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
                      _buildMembershipRow('Role', _getUserRole(user?.id ?? ''), Icons.group),
                      _buildMembershipRow('Joined', 'Recently', Icons.calendar_today),
                      _buildMembershipRow('Balance', _formatCurrency(0.0, detailedClubInfo?.membershipFeeCurrency ?? 'INR'), Icons.account_balance_wallet),
                    ],
                  ),
                ),
                
                SizedBox(height: 20),
                
                // Club Info
                _buildInfoRow(Icons.people, 'Total Members', detailedClubInfo != null ? '${detailedClubInfo!.membersCount} members' : 'Loading...'),
                _buildInfoRow(Icons.sports_cricket, 'Sport', 'Cricket'),
                if (club.city != null)
                  _buildInfoRow(Icons.location_on, 'Location', club.city!),
                if (detailedClubInfo?.membershipFee != null && detailedClubInfo!.membershipFee! > 0)
                  _buildInfoRow(Icons.currency_rupee, 'Membership Fee', _formatCurrency(detailedClubInfo!.membershipFee!, detailedClubInfo!.membershipFeeCurrency)),
                if (detailedClubInfo?.owners.isNotEmpty == true)
                  _buildInfoRow(Icons.admin_panel_settings, 'Owners', _formatOwners()),
                if (detailedClubInfo?.admins.isNotEmpty == true)
                  _buildInfoRow(Icons.supervisor_account, 'Admins', _formatAdmins()),
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

  String _getUserRole(String userId) {
    if (detailedClubInfo == null) return 'Member';
    
    // Check if user is owner
    if (detailedClubInfo!.owners.any((owner) => owner.id == userId)) {
      return 'Owner';
    }
    
    // Check if user is admin
    if (detailedClubInfo!.admins.any((admin) => admin.id == userId)) {
      return 'Admin';
    }
    
    return 'Member';
  }

  String _formatCurrency(double amount, String currency) {
    if (currency == 'INR') {
      return '₹${amount.toStringAsFixed(2)}';
    }
    return '$currency ${amount.toStringAsFixed(2)}';
  }

  String _formatOwners() {
    if (detailedClubInfo?.owners.isEmpty == true) return 'None';
    return detailedClubInfo!.owners.take(3).map((owner) => owner.name).join(', ') +
        (detailedClubInfo!.owners.length > 3 ? ' +${detailedClubInfo!.owners.length - 3} more' : '');
  }

  String _formatAdmins() {
    if (detailedClubInfo?.admins.isEmpty == true) return 'None';
    return detailedClubInfo!.admins.take(3).map((admin) => admin.name).join(', ') +
        (detailedClubInfo!.admins.length > 3 ? ' +${detailedClubInfo!.admins.length - 3} more' : '');
  }
}