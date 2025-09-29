import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../providers/club_provider.dart';
import '../../models/club.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/svg_avatar.dart';
import '../../widgets/club_logo_widget.dart';
import 'club_chat.dart';
import 'create_club_screen.dart';

class ClubsScreen extends StatefulWidget {
  const ClubsScreen({super.key});

  @override
  ClubsScreenState createState() => ClubsScreenState();
}

class ClubsScreenState extends State<ClubsScreen> {
  bool _isLoading = false;
  bool _hasOwnedClubs = false;
  bool _checkingOwnership = false;

  @override
  void initState() {
    super.initState();
    _checkingOwnership = true;
    // Load clubs using cache first for faster startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ClubProvider>(context, listen: false).loadClubs();
      _checkUserOwnedClubs();
    });
  }

  Future<void> _checkUserOwnedClubs() async {
    if (!Platform.isIOS && !Platform.isAndroid) {
      setState(() {
        _checkingOwnership = false;
        _hasOwnedClubs = false;
      });
      return;
    }

    try {
      final clubProvider = Provider.of<ClubProvider>(context, listen: false);
      await clubProvider.loadClubs(); // Ensure clubs are loaded

      // Check if user owns any clubs
      bool hasOwnedClubs = clubProvider.clubs.any(
        (membership) => membership.role == 'OWNER',
      );

      setState(() {
        _hasOwnedClubs = hasOwnedClubs;
        _checkingOwnership = false;
      });
    } catch (e) {
      print('Error checking user owned clubs: $e');
      setState(() {
        _checkingOwnership = false;
        _hasOwnedClubs = false;
      });
    }
  }

  Future<void> _loadClubs() async {
    setState(() => _isLoading = true);
    await Provider.of<ClubProvider>(context, listen: false).refreshClubs();
    await _checkUserOwnedClubs();
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: DuggyAppBar(
        subtitle: 'Clubs',
        actions: [
          if (_checkingOwnership)
            Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            )
          else if (!_hasOwnedClubs)
            TextButton(
              onPressed: _navigateToCreateClub,
              child: Text(
                'Run Club?',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
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
                ? Container(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Theme.of(context).colorScheme.surface
                        : Colors.grey[200],
                    child: SingleChildScrollView(
                      physics: AlwaysScrollableScrollPhysics(),
                      child: Container(
                        height: MediaQuery.of(context).size.height - 200,
                        child: Center(
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
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(
                                    context,
                                  ).textTheme.titleLarge?.color,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 32),
                                child: Text(
                                  'You are not a member of any cricket club yet. Create your own club or ask your club admin to invite you.',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium?.color,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Club Owner Note
                              Container(
                                margin: EdgeInsets.symmetric(horizontal: 24),
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Theme.of(
                                      context,
                                    ).primaryColor.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.lightbulb_outline,
                                      size: 20,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Club Owner? Create your club to manage members, matches, and more.',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Theme.of(context).primaryColor,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 32),

                              // Create Club Button
                              ElevatedButton.icon(
                                onPressed: _showCreateClubDialog,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(
                                    context,
                                  ).primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 2,
                                ),
                                icon: Icon(Icons.add, size: 20),
                                label: Text(
                                  'Create New Club',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Pull to refresh hint
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.refresh,
                                    size: 16,
                                    color: Theme.of(
                                      context,
                                    ).primaryColor.withOpacity(0.7),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Pull down to refresh',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Theme.of(
                                        context,
                                      ).primaryColor.withOpacity(0.7),
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : Container(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Theme.of(context).colorScheme.surface
                        : Colors.grey[200],
                    child: ListView.builder(
                      padding: EdgeInsets.all(16),
                      itemCount: clubProvider.clubs.length,
                      itemBuilder: (context, index) {
                        final membership = clubProvider.clubs[index];
                        return Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: _buildClubCard(membership, clubProvider),
                        );
                      },
                    ),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildClubCard(ClubMembership membership, ClubProvider clubProvider) {
    final club = membership.club;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openClubChat(membership),
        child: Container(
          padding: EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Club Profile Image
              Stack(
                children: [
                  ClubLogoWidget(
                    club: club,
                    size: 50,
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
                  // Unread Message Indicator
                  if (membership.hasUnreadMessage)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            width: 2,
                          ),
                        ),
                        child: Icon(Icons.circle, color: Colors.red, size: 10),
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

                    // Latest Message with Sender Name
                    if (club.latestMessage != null)
                      Text(
                        '${club.latestMessage!.senderName}: ${club.latestMessage!.content.body}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.color?.withOpacity(0.8),
                          height: 1.2,
                        ),
                      )
                    else
                      SizedBox(height: 16), // Empty space when no message

                    SizedBox(height: 4),

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

              // Last Message Time and Balance (if available) - moved to right side
              Container(
                margin: EdgeInsets.only(left: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (club.latestMessage != null)
                      Text(
                        _formatMessageTime(club.latestMessage!.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(
                            context,
                          ).textTheme.bodySmall?.color?.withOpacity(0.6),
                        ),
                      ),
                    SizedBox(height: 4),
                    // Balance
                    Text(
                      '₹${membership.balance.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.green[700],
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
  }

  void _openClubChat(ClubMembership membership) {
    final club = membership.club;

    // Mark club as read when opened
    Provider.of<ClubProvider>(context, listen: false).markClubAsRead(club.id);

    // Directly open the club chat screen
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ClubChatScreen(club: club)));
  }

  void _showCreateClubDialog() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => CreateClubScreen()));
  }

  void _navigateToCreateClub() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => CreateClubScreen()));
  }

  String _formatMessageTime(DateTime messageTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(
      messageTime.year,
      messageTime.month,
      messageTime.day,
    );
    final yesterday = today.subtract(Duration(days: 1));

    final difference = now.difference(messageTime);

    if (messageDate == today) {
      // Last 24 hours - show time
      final hour = messageTime.hour;
      final minute = messageTime.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '$displayHour:$minute $period';
    } else if (messageDate == yesterday) {
      // Yesterday
      return 'Yesterday';
    } else if (difference.inDays <= 7) {
      // Within the last week - show day name
      final weekdays = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      return weekdays[messageTime.weekday - 1];
    } else {
      // More than a week ago - show date in MM-dd-YYYY format
      final month = messageTime.month.toString().padLeft(2, '0');
      final day = messageTime.day.toString().padLeft(2, '0');
      final year = messageTime.year.toString();
      return '$month-$day-$year';
    }
  }
}
