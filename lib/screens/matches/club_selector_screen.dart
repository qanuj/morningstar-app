import 'dart:convert';
import 'package:flutter/material.dart';
import '../../models/club.dart';
import '../../services/club_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/svg_avatar.dart';
import '../qr_scanner.dart';

class ClubSelectorScreen extends StatefulWidget {
  final String title;
  final String? excludeClubId;
  final Function(Club) onClubSelected;

  const ClubSelectorScreen({
    super.key,
    required this.title,
    this.excludeClubId,
    required this.onClubSelected,
  });

  @override
  State<ClubSelectorScreen> createState() => _ClubSelectorScreenState();
}

class _ClubSelectorScreenState extends State<ClubSelectorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  List<Club> _searchResults = [];
  bool _isSearching = false;
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final results = await ClubService.searchAllClubs(
        query,
        excludeClubId: widget.excludeClubId,
      );

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _scanQRCode() async {
    try {
      final String? qrData = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (context) => const QRScanner(title: 'Scan Club QR Code'),
        ),
      );

      if (qrData != null && mounted) {
        final Club? parsedClub = _parseClubFromQRData(qrData);

        if (parsedClub != null) {
          // Check if this club should be excluded
          if (parsedClub.id == widget.excludeClubId) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Cannot select this club'),
                backgroundColor: Colors.orange,
              ),
            );
            return;
          }

          // Call the selection callback and close the screen
          widget.onClubSelected(parsedClub);
          Navigator.of(context).pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('QR code does not contain valid club information'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error scanning QR code: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Club? _parseClubFromQRData(String qrData) {
    try {
      final jsonData = json.decode(qrData);
      if (jsonData is Map<String, dynamic>) {
        final type = jsonData['type'] as String?;

        if (type == 'club_invite') {
          final clubId = jsonData['club_id'] as String?;
          final clubName = jsonData['club_name'] as String?;

          if (clubId != null && clubName != null) {
            return Club(
              id: clubId,
              name: clubName,
              isVerified: false,
              membershipFee: 0.0,
              membershipFeeCurrency: 'INR',
              upiIdCurrency: 'INR',
              owners: [],
            );
          }
        } else if (type == 'club_info') {
          final clubId = jsonData['id'] as String?;
          final clubName = jsonData['name'] as String?;
          final clubDescription = jsonData['description'] as String?;
          final clubCity = jsonData['city'] as String?;
          final clubState = jsonData['state'] as String?;
          final clubCountry = jsonData['country'] as String?;
          final clubLogo = jsonData['logo'] as String?;
          final isVerified = jsonData['isVerified'] as bool? ?? false;
          final contactPhone = jsonData['contactPhone'] as String?;
          final contactEmail = jsonData['contactEmail'] as String?;

          if (clubId != null && clubName != null) {
            return Club(
              id: clubId,
              name: clubName,
              description: clubDescription,
              city: clubCity,
              state: clubState,
              country: clubCountry,
              logo: clubLogo,
              isVerified: isVerified,
              contactPhone: contactPhone,
              contactEmail: contactEmail,
              membershipFee: 0.0,
              membershipFeeCurrency: 'INR',
              upiIdCurrency: 'INR',
              owners: [],
            );
          }
        }
      }
    } catch (e) {
      // Not valid JSON
    }

    return null; // Could not parse club data
  }

  Widget _buildClubTile(Club club) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          widget.onClubSelected(club);
          Navigator.of(context).pop();
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              // SVG Avatar for club logo
              SVGAvatar(
                imageUrl: club.logo,
                size: 50,
                backgroundColor: Theme.of(
                  context,
                ).primaryColor.withOpacity(0.1),
                iconColor: Theme.of(context).primaryColor,
                fallbackIcon: Icons.sports_cricket,
                showBorder: false,
                borderColor: Theme.of(context).primaryColor,
                borderWidth: 2,
                child: club.logo == null
                    ? Text(
                        club.name.substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      )
                    : null,
              ),
              SizedBox(width: 16),

              // Club Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      club.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 4),
                    if (club.city?.isNotEmpty ?? false)
                      Text(
                        club.city!,
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    if (club.owners.isNotEmpty) ...[
                      SizedBox(height: 2),
                      Text(
                        '${club.owners.first.name}${club.owners.length > 1 ? ' +${club.owners.length - 1} more' : ''}',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Arrow
              Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMyClubsTab() {
    return FutureBuilder<List<Club>>(
      future: ClubService.getUserClubs(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        final myClubs =
            snapshot.data
                ?.where((club) => club.id != widget.excludeClubId)
                .toList() ??
            [];

        if (myClubs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.sports_cricket, size: 64, color: Colors.grey[400]),
                SizedBox(height: 16),
                Text(
                  'No clubs found',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Join a club to see it here',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.symmetric(vertical: 8),
          itemCount: myClubs.length,
          itemBuilder: (context, index) {
            return _buildClubTile(myClubs[index]);
          },
        );
      },
    );
  }

  Widget _buildOpponentsTab() {
    return FutureBuilder<List<Club>>(
      future: ClubService.getOpponentClubs(excludeClubId: widget.excludeClubId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        final opponents = snapshot.data ?? [];

        if (opponents.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.group, size: 64, color: Colors.grey[400]),
                SizedBox(height: 16),
                Text(
                  'No opponent clubs found',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Try searching for clubs',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.symmetric(vertical: 8),
          itemCount: opponents.length,
          itemBuilder: (context, index) {
            return _buildClubTile(opponents[index]);
          },
        );
      },
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Searching clubs...'),
          ],
        ),
      );
    }

    if (_searchController.text.trim().isNotEmpty && _searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'No clubs found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Try different search terms',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'Search for clubs',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Enter club name to search',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(vertical: 8),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        return _buildClubTile(_searchResults[index]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: DetailAppBar(
        pageTitle: widget.title,
        showBackButton: true,
        customActions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchController.clear();
                  _searchResults = [];
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Field (when visible)
          if (_showSearch) ...[
            Container(
              color: Colors.white,
              padding: EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search for clubs...',
                  prefixIcon: Icon(
                    Icons.search,
                    color: Theme.of(context).primaryColor,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      Icons.qr_code_scanner,
                      color: Theme.of(context).primaryColor,
                    ),
                    onPressed: _scanQRCode,
                    tooltip: 'Scan QR Code',
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).primaryColor,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onChanged: (query) {
                  _performSearch(query);
                },
              ),
            ),
            Divider(height: 1),
          ],

          // Tab Bar (when not searching)
          if (!_showSearch) ...[
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                labelColor: Theme.of(context).primaryColor,
                unselectedLabelColor: Colors.grey[600],
                indicatorColor: Theme.of(context).primaryColor,
                indicatorWeight: 3,
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
                unselectedLabelStyle: TextStyle(
                  fontWeight: FontWeight.w400,
                  fontSize: 16,
                ),
                tabs: [
                  Tab(text: 'My Clubs'),
                  Tab(text: 'Opponents'),
                ],
              ),
            ),
          ],

          // Content Area
          Expanded(
            child: _showSearch
                ? _buildSearchResults()
                : TabBarView(
                    controller: _tabController,
                    children: [_buildMyClubsTab(), _buildOpponentsTab()],
                  ),
          ),
        ],
      ),
    );
  }
}
