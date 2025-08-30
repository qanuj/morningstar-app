import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/club.dart';
import '../providers/club_provider.dart';
import '../utils/theme.dart';

class ClubDetailScreen extends StatefulWidget {
  final ClubMembership membership;

  ClubDetailScreen({required this.membership});

  @override
  _ClubDetailScreenState createState() => _ClubDetailScreenState();
}

class _ClubDetailScreenState extends State<ClubDetailScreen> 
    with TickerProviderStateMixin {
  late AnimationController _headerAnimationController;
  late AnimationController _contentAnimationController;
  late Animation<double> _headerAnimation;
  late Animation<double> _contentAnimation;
  late ScrollController _scrollController;
  
  bool _isHeaderCollapsed = false;

  @override
  void initState() {
    super.initState();
    
    _headerAnimationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    
    _contentAnimationController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
    
    _headerAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _headerAnimationController,
      curve: Curves.easeInOut,
    ));
    
    _contentAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _contentAnimationController,
      curve: Curves.easeOutCubic,
    ));
    
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    
    // Start animations
    _headerAnimationController.forward();
    _contentAnimationController.forward();
  }

  void _onScroll() {
    final scrollOffset = _scrollController.offset;
    final shouldCollapse = scrollOffset > 100;
    
    if (shouldCollapse != _isHeaderCollapsed) {
      setState(() {
        _isHeaderCollapsed = shouldCollapse;
      });
    }
  }

  @override
  void dispose() {
    _headerAnimationController.dispose();
    _contentAnimationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final club = widget.membership.club;
    final membership = widget.membership;
    
    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Animated App Bar
          SliverAppBar(
            expandedHeight: 300,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: AppTheme.cricketGreen,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeroSection(club),
              title: AnimatedBuilder(
                animation: _headerAnimation,
                builder: (context, child) {
                  return _isHeaderCollapsed 
                    ? Text(
                        club.name,
                        style: TextStyle(
                          color: AppTheme.surfaceColor,
                          fontWeight: FontWeight.w400,
                          fontSize: 12,
                        ),
                      )
                    : SizedBox();
                },
              ),
            ),
            leading: Container(
              margin: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            actions: [
              Consumer<ClubProvider>(
                builder: (context, clubProvider, child) {
                  final isCurrentClub = clubProvider.currentClub?.club.id == club.id;
                  if (!isCurrentClub) {
                    return Container(
                      margin: EdgeInsets.all(8),
                      child: ElevatedButton(
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
                        child: Text('SWITCH'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.cricketGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    );
                  }
                  return SizedBox();
                },
              ),
            ],
          ),
          
          // Content
          SliverToBoxAdapter(
            child: AnimatedBuilder(
              animation: _contentAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, 50 * (1 - _contentAnimation.value)),
                  child: Opacity(
                    opacity: _contentAnimation.value,
                    child: _buildContent(club, membership),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection(Club club) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.cricketGreen,
            AppTheme.cricketGreen.withOpacity(0.8),
          ],
        ),
      ),
      child: Stack(
        children: [
          // Background Pattern
          Positioned.fill(
            child: Opacity(
              opacity: 0.1,
              child: Image.asset(
                'assets/cricket_pattern.png', // You'll need to add this asset
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(),
              ),
            ),
          ),
          
          // Content
          Positioned.fill(
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Club Logo with Glow Effect
                    Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white,
                        backgroundImage: club.logo != null 
                          ? NetworkImage(club.logo!)
                          : null,
                        child: club.logo == null
                          ? Icon(Icons.sports_cricket, size: 50, color: AppTheme.cricketGreen)
                          : null,
                      ),
                    ),
                    SizedBox(height: 16),
                    
                    // Club Name with Badges
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            club.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: AppTheme.surfaceColor,
                              shadows: [
                                Shadow(
                                  offset: Offset(0, 2),
                                  blurRadius: 4,
                                  color: Colors.black.withOpacity(0.3),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        if (club.isVerified) ...[
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.verified,
                              color: AppTheme.surfaceColor,
                              size: 20,
                            ),
                          ),
                        ],
                      ],
                    ),
                    
                    // Location
                    if (club.city != null || club.state != null) ...[
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.location_on, color: Colors.white70, size: 16),
                          SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              [club.city, club.state, club.country]
                                  .where((e) => e != null)
                                  .join(', '),
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ],
                    
                    // Description Preview
                    if (club.description != null) ...[
                      SizedBox(height: 12),
                      Text(
                        club.description!,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    
                    SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(Club club, ClubMembership membership) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // My Membership Section
                _buildMembershipSection(membership),
                SizedBox(height: 32),
                
                // Quick Stats
                _buildQuickStats(membership),
                SizedBox(height: 32),
                
                // Club Information
                _buildClubInfoSection(club),
                SizedBox(height: 32),
                
                // Contact Information
                _buildContactSection(club),
                SizedBox(height: 32),
                
                // Membership Details
                _buildMembershipDetailsSection(club),
                SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembershipSection(ClubMembership membership) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.cricketGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.person,
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
                      'My Membership',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Colors.grey[800],
                      ),
                    ),
                    Text(
                      'Your role and status in this club',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          
          // Status Badge
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: membership.approved ? Colors.green[50] : Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: membership.approved ? Colors.green[200]! : Colors.orange[200]!,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  membership.approved ? Icons.check_circle : Icons.hourglass_empty,
                  color: membership.approved ? Colors.green[600] : Colors.orange[600],
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  membership.approved ? 'Active Member' : 'Pending Approval',
                  style: TextStyle(
                    color: membership.approved ? Colors.green[700] : Colors.orange[700],
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          
          if (!membership.approved) ...[
            SizedBox(height: 12),
            Text(
              'Your membership is awaiting approval from the club admin. You\'ll be notified once approved.',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickStats(ClubMembership membership) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.cricketGreen.withOpacity(0.1),
            AppTheme.cricketGreen.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.cricketGreen.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Stats',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Role',
                  membership.role,
                  Icons.badge,
                  Colors.blue,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Points',
                  '${membership.points}',
                  Icons.star,
                  Colors.amber,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Balance',
                  '₹${membership.balance.toStringAsFixed(0)}',
                  Icons.account_balance_wallet,
                  Colors.green,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Total Spent',
                  '₹${membership.totalExpenses.toStringAsFixed(0)}',
                  Icons.receipt_long,
                  Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: Colors.grey[800],
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

  Widget _buildClubInfoSection(Club club) {
    return _buildSection(
      'Club Information',
      Icons.info_outline,
      [
        if (club.description != null)
          _buildInfoTile(
            'About',
            club.description!,
            Icons.description,
            isExpandable: true,
          ),
        if (club.city != null || club.state != null)
          _buildInfoTile(
            'Location',
            [club.city, club.state, club.country]
                .where((e) => e != null)
                .join(', '),
            Icons.location_on,
          ),
      ],
    );
  }

  Widget _buildContactSection(Club club) {
    final contacts = <Widget>[];
    
    if (club.contactEmail != null) {
      contacts.add(_buildInfoTile(
        'Email',
        club.contactEmail!,
        Icons.email,
        isCopyable: true,
      ));
    }
    
    if (club.contactPhone != null) {
      contacts.add(_buildInfoTile(
        'Phone',
        club.contactPhone!,
        Icons.phone,
        isCopyable: true,
      ));
    }
    
    if (club.upiId != null) {
      contacts.add(_buildInfoTile(
        'UPI ID',
        club.upiId!,
        Icons.payment,
        isCopyable: true,
      ));
    }
    
    if (contacts.isEmpty) return SizedBox();
    
    return _buildSection(
      'Contact Information',
      Icons.contact_phone,
      contacts,
    );
  }

  Widget _buildMembershipDetailsSection(Club club) {
    final details = <Widget>[];
    
    if (club.membershipFee > 0) {
      details.add(_buildInfoTile(
        'Membership Fee',
        '₹${club.membershipFee.toStringAsFixed(0)}',
        Icons.attach_money,
      ));
    }
    
    if (club.membershipFeeDescription != null) {
      details.add(_buildInfoTile(
        'Fee Description',
        club.membershipFeeDescription!,
        Icons.description,
        isExpandable: true,
      ));
    }
    
    if (details.isEmpty) return SizedBox();
    
    return _buildSection(
      'Membership Details',
      Icons.card_membership,
      details,
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.cricketGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: AppTheme.cricketGreen,
                  size: 24,
                ),
              ),
              SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoTile(
    String label,
    String value,
    IconData icon, {
    bool isExpandable = false,
    bool isCopyable = false,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
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
                    fontWeight: FontWeight.w400,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey[800],
                  ),
                  maxLines: isExpandable ? null : 2,
                  overflow: isExpandable ? null : TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (isCopyable)
            IconButton(
              icon: Icon(Icons.copy, size: 18, color: Colors.grey[600]),
              onPressed: () {
                // Copy to clipboard functionality
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Copied to clipboard'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}