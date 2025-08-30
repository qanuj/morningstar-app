import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/club_provider.dart';
import '../models/club.dart';
import '../utils/theme.dart';
import 'club_detail.dart';

class ClubsScreen extends StatefulWidget {
  @override
  _ClubsScreenState createState() => _ClubsScreenState();
}

class _ClubsScreenState extends State<ClubsScreen> with TickerProviderStateMixin {
  String? _expandedClubId;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ClubProvider>(context, listen: false).loadClubs();
    });
  }

  void _toggleExpanded(String clubId) {
    setState(() {
      _expandedClubId = _expandedClubId == clubId ? null : clubId;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('My Clubs'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppTheme.primaryTextColor,
      ),
      body: Consumer<ClubProvider>(
        builder: (context, clubProvider, child) {
          if (clubProvider.isLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    strokeWidth: 3,
                    color: AppTheme.cricketGreen,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Loading clubs...',
                    style: TextStyle(
                      color: AppTheme.secondaryTextColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          }

          if (clubProvider.clubs.isEmpty) {
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
                      Icons.groups_outlined,
                      size: 64,
                      color: AppTheme.cricketGreen,
                    ),
                  ),
                  SizedBox(height: 24),
                  Text(
                    'No clubs found',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.primaryTextColor,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'You are not a member of any cricket club yet',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.secondaryTextColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () => clubProvider.loadClubs(),
                    icon: Icon(Icons.refresh),
                    label: Text('Refresh'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.cricketGreen,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => clubProvider.loadClubs(),
            color: AppTheme.cricketGreen,
            child: SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: AppTheme.softCardDecoration,
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.cricketGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.groups,
                            color: AppTheme.cricketGreen,
                            size: 24,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'My Cricket Clubs',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: AppTheme.primaryTextColor,
                                ),
                              ),
                              Text(
                                '${clubProvider.clubs.length} ${clubProvider.clubs.length == 1 ? 'membership' : 'memberships'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.secondaryTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),
                  
                  // Clubs List
                  ...clubProvider.clubs.map((membership) {
                    return _buildClubCard(membership, clubProvider);
                  }).toList(),
                  
                  SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildClubCard(ClubMembership membership, ClubProvider clubProvider) {
    final club = membership.club;
    final isCurrentClub = clubProvider.currentClub?.club.id == club.id;
    final isExpanded = _expandedClubId == club.id;

    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCurrentClub 
            ? AppTheme.cricketGreen.withOpacity(0.3) 
            : AppTheme.dividerColor.withOpacity(0.3),
          width: isCurrentClub ? 2 : 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isCurrentClub 
              ? AppTheme.cricketGreen.withOpacity(0.1) 
              : Colors.black.withOpacity(0.04),
            blurRadius: isCurrentClub ? 12 : 8,
            offset: Offset(0, isCurrentClub ? 4 : 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _toggleExpanded(club.id),
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                // Compact Header
                Row(
                  children: [
                    // Club Avatar with Status Ring
                    Container(
                      padding: EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isCurrentClub 
                            ? AppTheme.cricketGreen 
                            : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 28,
                          backgroundColor: AppTheme.cricketGreen,
                          backgroundImage: club.logo != null 
                            ? NetworkImage(club.logo!)
                            : null,
                          child: club.logo == null
                            ? Icon(Icons.sports_cricket, color: Colors.white, size: 24)
                            : null,
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    
                    // Club Info
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
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    color: AppTheme.primaryTextColor,
                                  ),
                                ),
                              ),
                              if (club.isVerified) ...[
                                Icon(
                                  Icons.verified,
                                  color: Colors.blue,
                                  size: 20,
                                ),
                                SizedBox(width: 4),
                              ],
                              if (isCurrentClub)
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.cricketGreen,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'ACTIVE',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.cricketGreen.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  membership.role,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.cricketGreen,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                              SizedBox(width: 12),
                              Icon(Icons.star, size: 16, color: Colors.amber),
                              SizedBox(width: 4),
                              Text(
                                '${membership.points}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.secondaryTextColor,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // Expand/Collapse Icon
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.cricketGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0,
                        duration: Duration(milliseconds: 300),
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          color: AppTheme.cricketGreen,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                
                // Expandable Content
                AnimatedCrossFade(
                  firstChild: SizedBox(),
                  secondChild: _buildExpandedContent(membership, clubProvider),
                  crossFadeState: isExpanded 
                    ? CrossFadeState.showSecond 
                    : CrossFadeState.showFirst,
                  duration: Duration(milliseconds: 300),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedContent(ClubMembership membership, ClubProvider clubProvider) {
    final club = membership.club;
    final isCurrentClub = clubProvider.currentClub?.club.id == club.id;
    
    return Column(
      children: [
        SizedBox(height: 20),
        
        // Divider
        Container(
          height: 1,
          margin: EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                AppTheme.dividerColor.withOpacity(0.5),
                Colors.transparent,
              ],
            ),
          ),
        ),
        
        // Club Description
        if (club.description != null) ...[
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cricketGreen.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              club.description!,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.secondaryTextColor,
                height: 1.5,
              ),
            ),
          ),
          SizedBox(height: 16),
        ],
        
        // Location
        if (club.city != null || club.state != null) ...[
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.location_on, size: 16, color: AppTheme.cricketGreen),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    [club.city, club.state, club.country]
                        .where((e) => e != null)
                        .join(', '),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.secondaryTextColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
        ],
        
        // Stats Row
        Row(
          children: [
            Expanded(
              child: _buildStatItem(
                'Balance',
                '₹${membership.balance.toStringAsFixed(0)}',
                Icons.account_balance_wallet,
                Colors.green,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildStatItem(
                'Spent',
                '₹${membership.totalExpenses.toStringAsFixed(0)}',
                Icons.receipt,
                Colors.orange,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildStatItem(
                'Points',
                '${membership.points}',
                Icons.star,
                Colors.amber,
              ),
            ),
          ],
        ),
        
        // Status Indicators
        if (!membership.approved) ...[
          SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.orange.withOpacity(0.3),
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.hourglass_empty, 
                    color: Colors.orange[600], 
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pending Approval',
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontWeight: FontWeight.w400,
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Your membership is awaiting admin approval',
                        style: TextStyle(
                          color: Colors.orange[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        
        SizedBox(height: 20),
        
        // Action Buttons
        Row(
          children: [
            // Switch Club Button
            if (!isCurrentClub)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await clubProvider.setCurrentClub(membership);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Switched to ${club.name}'),
                        backgroundColor: AppTheme.cricketGreen,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  },
                  icon: Icon(Icons.swap_horiz, size: 18),
                  label: Text('Switch Club'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.cricketGreen,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            
            // View Details Button
            if (!isCurrentClub) SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ClubDetailScreen(membership: membership),
                    ),
                  );
                },
                icon: Icon(Icons.info_outline, size: 18),
                label: Text('View Details'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.cricketGreen,
                  side: BorderSide(
                    color: AppTheme.cricketGreen.withOpacity(0.5),
                    width: 1,
                  ),
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: AppTheme.primaryTextColor,
            ),
          ),
          SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }
}