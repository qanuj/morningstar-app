import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/club_provider.dart';
import '../models/club.dart';
import '../utils/theme.dart';
import 'club_detail_screen.dart';

class ClubsScreen extends StatefulWidget {
  @override
  _ClubsScreenState createState() => _ClubsScreenState();
}

class _ClubsScreenState extends State<ClubsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ClubProvider>(context, listen: false).loadClubs();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ClubProvider>(
      builder: (context, clubProvider, child) {
        if (clubProvider.isLoading) {
          return Center(child: CircularProgressIndicator());
        }

        if (clubProvider.clubs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.groups_outlined,
                  size: 80,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  'No clubs found',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'You are not a member of any cricket club yet',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => clubProvider.loadClubs(),
          child: ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: clubProvider.clubs.length,
            itemBuilder: (context, index) {
              final membership = clubProvider.clubs[index];
              final club = membership.club;
              final isCurrentClub = clubProvider.currentClub?.club.id == club.id;

              return Card(
                margin: EdgeInsets.only(bottom: 16),
                elevation: isCurrentClub ? 8 : 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: isCurrentClub 
                    ? BorderSide(color: AppTheme.cricketGreen, width: 2)
                    : BorderSide.none,
                ),
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ClubDetailScreen(membership: membership),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: AppTheme.cricketGreen,
                              backgroundImage: club.logo != null 
                                ? NetworkImage(club.logo!)
                                : null,
                              child: club.logo == null
                                ? Icon(Icons.sports_cricket, color: Colors.white)
                                : null,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          club.name,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      if (club.isVerified)
                                        Icon(
                                          Icons.verified,
                                          color: Colors.blue,
                                          size: 20,
                                        ),
                                      if (isCurrentClub)
                                        Container(
                                          margin: EdgeInsets.only(left: 8),
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.cricketGreen,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            'ACTIVE',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (club.description != null)
                                    Text(
                                      club.description!,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
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
                        Row(
                          children: [
                            Expanded(
                              child: _buildInfoChip(
                                'Role',
                                membership.role,
                                Icons.person,
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: _buildInfoChip(
                                'Points',
                                '${membership.points}',
                                Icons.star,
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: _buildInfoChip(
                                'Balance',
                                '₹${membership.balance.toStringAsFixed(0)}',
                                Icons.account_balance_wallet,
                              ),
                            ),
                          ],
                        ),
                        if (!membership.approved)
                          Container(
                            margin: EdgeInsets.only(top: 12),
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.hourglass_empty, color: Colors.orange),
                                SizedBox(width: 8),
                                Text(
                                  'Membership pending approval',
                                  style: TextStyle(
                                    color: Colors.orange[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildInfoChip(String label, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.cricketGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: AppTheme.cricketGreen),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}