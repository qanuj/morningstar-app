import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/custom_app_bar.dart';
import '../../services/api_service.dart';

class SubscriptionManagementScreen extends StatefulWidget {
  final String? specificClubId; // Optional: show only this club's subscription

  const SubscriptionManagementScreen({super.key, this.specificClubId});

  @override
  State<SubscriptionManagementScreen> createState() =>
      _SubscriptionManagementScreenState();
}

class _SubscriptionManagementScreenState
    extends State<SubscriptionManagementScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _ownedClubs = [];
  Map<String, Map<String, dynamic>> _clubSubscriptions = {};

  @override
  void initState() {
    super.initState();
    _loadOwnedClubsAndSubscriptions();
  }

  Future<void> _loadOwnedClubsAndSubscriptions() async {
    setState(() => _isLoading = true);

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final memberships = await userProvider.getMemberships(forceRefresh: true);

      // Filter to only owned clubs, and optionally to a specific club
      final ownedClubs = memberships
          .where(
            (membership) =>
                membership.role == 'OWNER' &&
                (widget.specificClubId == null ||
                    membership.club.id == widget.specificClubId),
          )
          .map(
            (membership) => {
              'id': membership.club.id,
              'name': membership.club.name,
              'logo': membership.club.logo,
              'slug': membership.club.id, // Using club ID as slug for now
            },
          )
          .toList();

      setState(() {
        _ownedClubs = ownedClubs;
      });

      // Load subscription details for each owned club
      for (final club in ownedClubs) {
        final clubId = club['id'] as String;
        try {
          final response = await ApiService.get('/clubs/$clubId/subscription');
          setState(() {
            _clubSubscriptions[clubId] = response;
          });
        } catch (e) {
          print('Error loading subscription for club ${club['name']}: $e');
          // Set empty subscription for clubs without subscription
          setState(() {
            _clubSubscriptions[clubId] = {};
          });
        }
      }
    } catch (e) {
      print('Error loading owned clubs: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: DuggyAppBar(subtitle: 'Manage Subscriptions'),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Theme.of(context).primaryColor,
              ),
            )
          : _ownedClubs.isEmpty
          ? Container(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(context).colorScheme.surface
                  : Colors.grey[200],
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.business_outlined,
                        size: 64,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No Clubs Owned',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).textTheme.titleLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'You need to be a club owner to manage subscriptions.',
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Container(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(context).colorScheme.surface
                  : Colors.grey[200],
              child: ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: _ownedClubs.length,
                itemBuilder: (context, index) {
                  final club = _ownedClubs[index];
                  final subscription = _clubSubscriptions[club['id']];
                  return Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: _buildClubSubscriptionCard(club, subscription),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildClubSubscriptionCard(
    Map<String, dynamic> club,
    Map<String, dynamic>? subscription,
  ) {
    final hasSubscription = subscription != null && subscription.isNotEmpty;
    final subscriptionData = hasSubscription
        ? subscription['subscription']
        : null;
    final currentPlan = hasSubscription ? subscription['currentPlan'] : null;
    final memberUsage = hasSubscription ? subscription['memberUsage'] : null;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
      child: Container(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Club Header
            Row(
              children: [
                // Club Logo
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: club['logo'] != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(25),
                          child: Image.network(
                            club['logo'],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.groups,
                                color: Theme.of(context).primaryColor,
                                size: 28,
                              );
                            },
                          ),
                        )
                      : Icon(
                          Icons.groups,
                          color: Theme.of(context).primaryColor,
                          size: 28,
                        ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        club['name'],
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Theme.of(context).textTheme.titleLarge?.color,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        hasSubscription
                            ? 'Subscription Active'
                            : 'No Active Subscription',
                        style: TextStyle(
                          fontSize: 13,
                          color: hasSubscription
                              ? Colors.green[700]
                              : Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.color?.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (hasSubscription) ...[
              SizedBox(height: 16),
              Divider(),
              SizedBox(height: 12),

              // Subscription Details
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Plan',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          currentPlan?['name'] ?? 'Unknown Plan',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Status',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                        SizedBox(height: 2),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(
                              subscriptionData?['status'],
                            ).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            subscriptionData?['status'] ?? 'Unknown',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _getStatusColor(
                                subscriptionData?['status'],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              if (memberUsage != null) ...[
                SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Member Usage',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: (memberUsage['percentageUsed'] ?? 0) / 100.0,
                            backgroundColor: Colors.grey[300],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              (memberUsage['percentageUsed'] ?? 0) > 80
                                  ? Colors.red
                                  : Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          '${memberUsage['current'] ?? 0}/${memberUsage['limit'] ?? 0}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],

              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _manageSubscription(club['id']),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: Icon(Icons.settings, size: 18),
                      label: Text(
                        'Manage',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange[700],
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This club is currently on a free trial or has no active subscription.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _upgradeSubscription(club['id']),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: Icon(Icons.upgrade, size: 18),
                      label: Text(
                        'Subscribe',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toUpperCase()) {
      case 'ACTIVE':
        return Colors.green;
      case 'TRIAL':
        return Colors.blue;
      case 'EXPIRED':
      case 'CANCELED':
        return Colors.red;
      case 'ON_HOLD':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  void _manageSubscription(String clubId) {
    // Navigate to club settings subscription tab
    // You can implement this based on your navigation structure
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening subscription management...'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
    );
  }

  void _upgradeSubscription(String clubId) {
    // Navigate to subscription upgrade screen
    // You can implement this based on your navigation structure
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening subscription upgrade...'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
    );
  }
}
