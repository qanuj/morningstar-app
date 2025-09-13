import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/club_provider.dart';
import '../../models/club.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/svg_avatar.dart';
import 'enhanced_club_members.dart';
import 'club_transactions.dart';
import 'club_settings.dart';
import 'club_matches.dart';
import 'club_teams_screen.dart';
import '../club_invite_qr_screen.dart';

class ManageClubScreen extends StatefulWidget {
  final Club club;
  final ClubMembership membership;

  const ManageClubScreen({
    super.key,
    required this.club,
    required this.membership,
  });

  @override
  ManageClubScreenState createState() => ManageClubScreenState();
}

class ManageClubScreenState extends State<ManageClubScreen> {
  @override
  void initState() {
    super.initState();
    // Load fresh club data when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final clubProvider = Provider.of<ClubProvider>(context, listen: false);
      clubProvider.refreshClubs();
    });
  }

  Future<void> _refreshClub(BuildContext context) async {
    final clubProvider = Provider.of<ClubProvider>(context, listen: false);
    await clubProvider.refreshClubs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: DetailAppBar(
        pageTitle: 'Manage Club',
        customActions: [
          IconButton(
            onPressed: () => _showClubQRCode(widget.club),
            icon: Icon(Icons.qr_code),
            tooltip: 'Show Club QR Code',
          ),
        ],
      ),
      body: Consumer<ClubProvider>(
        builder: (context, clubProvider, child) {
          // Find the specific club being managed from the provider's clubs list
          // This ensures we get updated data after settings changes
          final clubs = clubProvider.clubs;
          final updatedClub = clubs
              .where((membership) => membership.club.id == widget.club.id)
              .map((membership) => membership.club)
              .firstOrNull;
          final club = updatedClub ?? widget.club;

          return RefreshIndicator(
            onRefresh: () => _refreshClub(context),
            child: SingleChildScrollView(
              padding: EdgeInsets.zero,
              physics: AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  // Club Header Section
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).shadowColor.withOpacity(0.06),
                          blurRadius: 16,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Club Logo
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Theme.of(
                                        context,
                                      ).shadowColor.withOpacity(0.1),
                                      blurRadius: 20,
                                      offset: Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  children: [
                                    SVGAvatar.extraLarge(
                                      imageUrl: club.logo,
                                      backgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.primary.withOpacity(0.1),
                                      fallbackIcon: Icons.groups,
                                    ),
                                    // Owner Badge
                                    if (club.isVerified)
                                      Positioned(
                                        right: 4,
                                        bottom: 4,
                                        child: Container(
                                          width: 24,
                                          height: 24,
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
                                            size: 14,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                              SizedBox(width: 20),

                              // Club Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Club Name
                                    Text(
                                      club.name,
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                      ),
                                    ),

                                    SizedBox(height: 4),

                                    // Owner Badge
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'Owner',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.green[700],
                                        ),
                                      ),
                                    ),

                                    SizedBox(height: 8),

                                    // Location
                                    if (club.city != null || club.state != null)
                                      Text(
                                        [club.city, club.state, club.country]
                                            .where((e) => e != null && e.isNotEmpty)
                                            .join(', '),
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium?.color,
                                        ),
                                      ),

                                    SizedBox(height: 4),

                                    // Contact Info
                                    if (club.contactPhone != null)
                                      Text(
                                        club.contactPhone!,
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium?.color,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          // Club Description
                          if (club.description != null && club.description!.isNotEmpty) ...[
                            Divider(
                              height: 24,
                              thickness: 1,
                              color: Theme.of(
                                context,
                              ).dividerColor.withOpacity(0.3),
                            ),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                club.description!,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.8),
                                  height: 1.4,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Management Options List
                  Container(
                    color: Theme.of(context).cardColor,
                    child: Column(
                      children: [
                        // Members Section
                        _buildExpandableSection(
                          icon: Icons.people_outline,
                          title: 'Members',
                          subtitle: 'Manage club members, balances & points',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => EnhancedClubMembersScreen(club: club),
                              ),
                            );
                          },
                        ),

                        Divider(
                          height: 1,
                          color: Theme.of(
                            context,
                          ).dividerColor.withOpacity(0.3),
                        ),

                        // Transactions Section
                        _buildExpandableSection(
                          icon: Icons.account_balance_wallet_outlined,
                          title: 'Transactions',
                          subtitle: 'View all club transactions',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ClubTransactionsScreen(club: club),
                              ),
                            );
                          },
                        ),

                        Divider(
                          height: 1,
                          color: Theme.of(
                            context,
                          ).dividerColor.withOpacity(0.3),
                        ),

                        // Club Settings
                        _buildExpandableSection(
                          icon: Icons.settings_outlined,
                          title: 'Club Settings',
                          subtitle: 'Manage club information & preferences',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ClubSettingsScreen(club: club),
                              ),
                            );
                          },
                        ),

                        Divider(
                          height: 1,
                          color: Theme.of(
                            context,
                          ).dividerColor.withOpacity(0.3),
                        ),

                        // Match Management
                        _buildExpandableSection(
                          icon: Icons.sports_cricket_outlined,
                          title: 'Matches',
                          subtitle: 'Schedule & manage club matches',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ClubMatchesScreen(club: club),
                              ),
                            );
                          },
                        ),

                        Divider(
                          height: 1,
                          color: Theme.of(
                            context,
                          ).dividerColor.withOpacity(0.3),
                        ),

                        // Team Management
                        _buildExpandableSection(
                          icon: Icons.sports_outlined,
                          title: 'Teams',
                          subtitle: 'Manage club teams & players',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ClubTeamsScreen(club: club),
                              ),
                            );
                          },
                        ),

                        Divider(
                          height: 1,
                          color: Theme.of(
                            context,
                          ).dividerColor.withOpacity(0.3),
                        ),

                        // Store Management
                        _buildExpandableSection(
                          icon: Icons.store_outlined,
                          title: 'Store',
                          subtitle: 'Manage club merchandise & inventory',
                          onTap: () {
                            // TODO: Navigate to store management
                          },
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildExpandableSection({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return Builder(
      builder: (context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                  size: 24,
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showClubQRCode(Club club) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClubInviteQRScreen(club: club),
      ),
    );
  }

}