import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/club_provider.dart';
import '../../models/club.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/svg_avatar.dart';
import 'club_chat.dart';

class ClubsScreen extends StatefulWidget {
  const ClubsScreen({super.key});

  @override
  ClubsScreenState createState() => ClubsScreenState();
}

class ClubsScreenState extends State<ClubsScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Load clubs using cache first for faster startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ClubProvider>(context, listen: false).loadClubs();
    });
  }

  Future<void> _loadClubs() async {
    setState(() => _isLoading = true);
    await Provider.of<ClubProvider>(context, listen: false).refreshClubs();
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: DetailAppBar(pageTitle: 'My Clubs'),
      body: Consumer<ClubProvider>(
        builder: (context, clubProvider, child) {
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
                : clubProvider.clubs.isEmpty
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
                            Icons.groups_outlined,
                            size: 64,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'No clubs found',
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
                          'You are not a member of any cricket club yet',
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
                    itemCount: clubProvider.clubs.length,
                    itemBuilder: (context, index) {
                      final membership = clubProvider.clubs[index];
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
        onTap: () => _openClubChat(membership),
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
                  SVGAvatar(
                    imageUrl: club.logo,
                    size: 50,
                    backgroundColor: Theme.of(
                      context,
                    ).primaryColor.withOpacity(0.1),
                    fallbackIcon: Icons.groups,
                    iconSize: 28,
                  ),
                  // Verified Badge
                  if (club.isVerified)
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.verified,
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

                    // Balance & Points Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Member count
                        Text(
                          '${club.membersCount ?? 0} members',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color?.withOpacity(0.7),
                          ),
                        ),

                        // Balance & Points
                        Row(
                          children: [
                            Text(
                              '₹${membership.balance.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.green[700],
                              ),
                            ),
                            SizedBox(width: 12),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star, size: 12, color: Colors.amber),
                                SizedBox(width: 2),
                                Text(
                                  '${membership.points}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(
                                      context,
                                    ).textTheme.bodySmall?.color,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Approval Status (if pending)
                    if (!membership.approved) ...[
                      SizedBox(height: 6),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.hourglass_empty,
                              size: 12,
                              color: Colors.orange[700],
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Approval Pending',
                              style: TextStyle(
                                color: Colors.orange[700],
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openClubChat(ClubMembership membership) {
    final club = membership.club;

    // Directly open the club chat screen
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ClubChatScreen(club: club)));
  }
}
