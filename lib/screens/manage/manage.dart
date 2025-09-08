import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/club_provider.dart';
import '../../models/club.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/svg_avatar.dart';
import 'manage_club.dart';

class ManageScreen extends StatefulWidget {
  const ManageScreen({super.key});

  @override
  ManageScreenState createState() => ManageScreenState();
}

class ManageScreenState extends State<ManageScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadClubs();
  }

  Future<void> _loadClubs() async {
    setState(() => _isLoading = true);
    await Provider.of<ClubProvider>(context, listen: false).loadClubs();
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: DetailAppBar(
        pageTitle: 'Manage Clubs',
        customActions: [
          IconButton(
            icon: Icon(Icons.home_outlined),
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
            tooltip: 'Go to Home',
          ),
        ],
      ),
      body: Consumer<ClubProvider>(
        builder: (context, clubProvider, child) {
          // Filter clubs where user is an owner
          final ownedClubs = clubProvider.clubs
              .where((membership) => membership.role.toLowerCase() == 'owner')
              .toList();

          return RefreshIndicator(
            onRefresh: _loadClubs,
            color: Theme.of(context).primaryColor,
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Theme.of(context).primaryColor,
                    ),
                  )
                : ownedClubs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).primaryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.admin_panel_settings_outlined,
                            size: 64,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'No clubs to manage',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                            color: Theme.of(
                              context,
                            ).textTheme.titleLarge?.color,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You are not an owner of any cricket club',
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: ownedClubs.length,
                    itemBuilder: (context, index) {
                      final membership = ownedClubs[index];
                      return _buildClubCard(membership, clubProvider);
                    },
                  ),
          );
        },
      ),
    );
  }

  Widget _buildClubCard(ClubMembership membership, ClubProvider clubProvider) {
    final club = membership.club;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openClubManagement(membership),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor.withOpacity(0.1),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Club Profile Image
              Stack(
                children: [
                  SVGAvatar.medium(
                    imageUrl: club.logo,
                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                    fallbackIcon: Icons.groups,
                  ),
                  // Owner Badge
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.admin_panel_settings,
                        color: Colors.white,
                        size: 8,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(width: 12),

              // Club Info (Expanded)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Club Name
                    Text(
                      club.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Theme.of(context).textTheme.titleLarge?.color,
                        height: 1.2,
                      ),
                    ),

                    SizedBox(height: 4),

                    // Club Details Row
                    Row(
                      children: [
                        // Owner Badge
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Owner',
                            style: TextStyle(
                              color: Colors.green[700],
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),

                        // Location
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            [club.city, club.state, club.country]
                                .where((e) => e != null && e.isNotEmpty)
                                .join(', '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.color?.withOpacity(0.7),
                            ),
                          ),
                        ),

                        // Management Indicator
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openClubManagement(ClubMembership membership) {
    final club = membership.club;

    // Navigate to club management screen
    Navigator.of(
      context,
    ).push(MaterialPageRoute(
        builder: (_) => ManageClubScreen(club: club, membership: membership)));
  }
}