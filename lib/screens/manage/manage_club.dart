import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';
import '../../providers/club_provider.dart';
import '../../models/club.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/svg_avatar.dart';
import 'enhanced_club_members.dart';
import 'club_transactions.dart';
import 'club_settings.dart';
import 'club_matches.dart';

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

                  // Club ID and Stats
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Club ID',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  club.id,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium?.color,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(
                                  Icons.copy,
                                  size: 16,
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.color,
                                ),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Members',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              club.membersCount?.toString() ?? 'N/A',
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.color,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Club Balance',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              '₹${widget.membership.balance.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.green[700],
                              ),
                            ),
                          ],
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
    // Generate club info JSON
    final clubInfo = {
      'type': 'club_info',
      'id': club.id,
      'name': club.name,
      'description': club.description,
      'logo': club.logo,
      'city': club.city,
      'state': club.state,
      'country': club.country,
      'contactPhone': club.contactPhone,
      'contactEmail': club.contactEmail,
      'isVerified': club.isVerified,
      'membersCount': club.membersCount,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    
    final jsonString = jsonEncode(clubInfo);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Club Info Header
                Row(
                  children: [
                    SVGAvatar(
                      imageUrl: club.logo,
                      size: 40,
                      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                      fallbackIcon: Icons.groups,
                      iconSize: 24,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            club.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                              color: Theme.of(context).textTheme.titleLarge?.color,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Club Information QR Code',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 24),
                
                // QR Code
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: QrImageView(
                    data: jsonString,
                    version: QrVersions.auto,
                    size: 200.0,
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                  ),
                ),
                
                SizedBox(height: 16),
                
                // Info Text
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Contains club details in JSON format',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                
                SizedBox(height: 24),
                
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close, size: 18),
                        label: Text('Close'),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _shareClubInfo(club, jsonString),
                        icon: Icon(Icons.share, size: 18, color: Colors.white),
                        label: Text('Share', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _shareClubInfo(Club club, String jsonString) {
    Share.share(
      'Club Information for ${club.name}:\n\n$jsonString',
      subject: '${club.name} Club Information',
    );
  }
}