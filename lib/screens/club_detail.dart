import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/club.dart';
import '../providers/club_provider.dart';
import '../utils/theme.dart';

class ClubDetailScreen extends StatelessWidget {
  final ClubMembership membership;

  ClubDetailScreen({required this.membership});

  @override
  Widget build(BuildContext context) {
    final club = membership.club;

    return Scaffold(
      appBar: AppBar(
        title: Text(club.name),
        backgroundColor: AppTheme.cricketGreen,
        foregroundColor: Colors.white,
        actions: [
          Consumer<ClubProvider>(
            builder: (context, clubProvider, child) {
              final isCurrentClub = clubProvider.currentClub?.club.id == club.id;
              if (!isCurrentClub) {
                return TextButton(
                  onPressed: () async {
                    await clubProvider.setCurrentClub(membership);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Switched to ${club.name}')),
                    );
                  },
                  child: Text(
                    'SWITCH',
                    style: TextStyle(color: Colors.white),
                  ),
                );
              }
              return SizedBox.shrink();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Club Header
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: AppTheme.cricketGreen,
                      backgroundImage: club.logo != null 
                        ? NetworkImage(club.logo!)
                        : null,
                      child: club.logo == null
                        ? Icon(Icons.sports_cricket, size: 40, color: Colors.white)
                        : null,
                    ),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          club.name,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (club.isVerified) ...[
                          SizedBox(width: 8),
                          Icon(Icons.verified, color: Colors.blue),
                        ],
                      ],
                    ),
                    if (club.description != null) ...[
                      SizedBox(height: 8),
                      Text(
                        club.description!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                    ],
                    if (club.city != null || club.state != null) ...[
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.location_on, size: 16, color: Colors.grey),
                          SizedBox(width: 4),
                          Text(
                            [club.city, club.state, club.country]
                                .where((e) => e != null)
                                .join(', '),
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            
            // My Membership Info
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Membership',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Role',
                            membership.role,
                            Icons.person,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Points',
                            '${membership.points}',
                            Icons.star,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Balance',
                            '₹${membership.balance.toStringAsFixed(0)}',
                            Icons.account_balance_wallet,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Total Spent',
                            '₹${membership.totalExpenses.toStringAsFixed(0)}',
                            Icons.receipt,
                          ),
                        ),
                      ],
                    ),
                    if (!membership.approved) ...[
                      SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.hourglass_empty, color: Colors.orange),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Your membership is pending approval from club admin',
                                style: TextStyle(
                                  color: Colors.orange[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            
            // Club Details
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Club Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    if (club.membershipFee > 0)
                      _buildDetailRow(
                        'Membership Fee',
                        '₹${club.membershipFee.toStringAsFixed(0)}',
                        Icons.attach_money,
                      ),
                    if (club.membershipFeeDescription != null)
                      _buildDetailRow(
                        'Fee Description',
                        club.membershipFeeDescription!,
                        Icons.description,
                      ),
                    if (club.upiId != null)
                      _buildDetailRow(
                        'UPI ID',
                        club.upiId!,
                        Icons.payment,
                      ),
                    if (club.contactEmail != null)
                      _buildDetailRow(
                        'Contact Email',
                        club.contactEmail!,
                        Icons.email,
                      ),
                    if (club.contactPhone != null)
                      _buildDetailRow(
                        'Contact Phone',
                        club.contactPhone!,
                        Icons.phone,
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

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cricketGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.cricketGreen),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.cricketGreen),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
