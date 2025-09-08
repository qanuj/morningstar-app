import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/club.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/svg_avatar.dart';

class ClubMembersScreen extends StatefulWidget {
  final Club club;

  const ClubMembersScreen({
    super.key,
    required this.club,
  });

  @override
  ClubMembersScreenState createState() => ClubMembersScreenState();
}

class ClubMembersScreenState extends State<ClubMembersScreen> {
  bool _isLoading = false;
  List<ClubMember> _members = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoading = true);
    // TODO: Load members from API
    // For now, using mock data
    _members = _generateMockMembers();
    setState(() => _isLoading = false);
  }

  List<ClubMember> _generateMockMembers() {
    return [
      ClubMember(
        id: '1',
        name: 'John Doe',
        email: 'john.doe@example.com',
        phoneNumber: '+91 98765 43210',
        role: 'Member',
        balance: 2500.0,
        points: 850,
        profilePicture: null,
        joinedDate: DateTime.now().subtract(Duration(days: 180)),
        isActive: true,
      ),
      ClubMember(
        id: '2',
        name: 'Jane Smith',
        email: 'jane.smith@example.com',
        phoneNumber: '+91 98765 43211',
        role: 'Captain',
        balance: 1800.0,
        points: 1200,
        profilePicture: null,
        joinedDate: DateTime.now().subtract(Duration(days: 120)),
        isActive: true,
      ),
      ClubMember(
        id: '3',
        name: 'Mike Johnson',
        email: 'mike.johnson@example.com',
        phoneNumber: '+91 98765 43212',
        role: 'Vice Captain',
        balance: 950.0,
        points: 650,
        profilePicture: null,
        joinedDate: DateTime.now().subtract(Duration(days: 90)),
        isActive: false,
      ),
      ClubMember(
        id: '4',
        name: 'Sarah Wilson',
        email: 'sarah.wilson@example.com',
        phoneNumber: '+91 98765 43213',
        role: 'Member',
        balance: 3200.0,
        points: 1450,
        profilePicture: null,
        joinedDate: DateTime.now().subtract(Duration(days: 200)),
        isActive: true,
      ),
      ClubMember(
        id: '5',
        name: 'David Brown',
        email: 'david.brown@example.com',
        phoneNumber: '+91 98765 43214',
        role: 'Member',
        balance: 750.0,
        points: 420,
        profilePicture: null,
        joinedDate: DateTime.now().subtract(Duration(days: 60)),
        isActive: true,
      ),
    ];
  }

  List<ClubMember> get _filteredMembers {
    if (_searchQuery.isEmpty) return _members;
    return _members.where((member) =>
      member.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      member.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      member.role.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredMembers = _filteredMembers;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: DetailAppBar(
        pageTitle: 'Club Members',
        customActions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () => _showSearchDialog(),
            tooltip: 'Search Members',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar (if searching)
          if (_searchQuery.isNotEmpty)
            Container(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).dividerColor.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        'Searching: "$_searchQuery"',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.clear),
                    onPressed: () => setState(() => _searchQuery = ''),
                    tooltip: 'Clear Search',
                  ),
                ],
              ),
            ),

          // Members List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadMembers,
              color: Theme.of(context).primaryColor,
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Theme.of(context).primaryColor,
                      ),
                    )
                  : filteredMembers.isEmpty
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
                              _searchQuery.isNotEmpty ? Icons.search_off : Icons.people_outline,
                              size: 64,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            _searchQuery.isNotEmpty ? 'No members found' : 'No members yet',
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
                            _searchQuery.isNotEmpty 
                                ? 'Try adjusting your search terms'
                                : 'Club members will appear here once they join',
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
                      itemCount: filteredMembers.length,
                      itemBuilder: (context, index) {
                        final member = filteredMembers[index];
                        return _buildMemberCard(member);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCard(ClubMember member) {
    return Material(
      color: Colors.transparent,
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
            // Member Profile Image
            Stack(
              children: [
                member.profilePicture == null || member.profilePicture!.isEmpty
                    ? SVGAvatar(
                        size: 50,
                        backgroundColor: _getMemberAvatarColor(member.name),
                        iconColor: Colors.white,
                        fallbackIcon: Icons.person,
                        child: Text(
                          member.name.isNotEmpty ? member.name[0].toUpperCase() : 'M',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : SVGAvatar.medium(
                        imageUrl: member.profilePicture,
                        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                        fallbackIcon: Icons.person,
                      ),
                // Active Status Indicator
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: member.isActive ? Colors.green : Colors.grey,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(width: 12),

            // Member Info (Expanded)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Member Name
                  Text(
                    member.name,
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

                  // Member Details Row
                  Row(
                    children: [
                      // Role Badge
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getRoleColor(member.role).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          member.role,
                          style: TextStyle(
                            color: _getRoleColor(member.role),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                      // Phone number
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          member.phoneNumber,
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
                    ],
                  ),

                  SizedBox(height: 4),

                  // Email
                  Text(
                    member.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.color?.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(width: 12),

            // Balance & Points
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${member.balance.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.green[700],
                  ),
                ),
                SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, size: 12, color: Colors.amber),
                    SizedBox(width: 2),
                    Text(
                      '${member.points}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(
                          context,
                        ).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2),
                Text(
                  _formatJoinedDate(member.joinedDate),
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(
                      context,
                    ).textTheme.bodySmall?.color?.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return Colors.purple;
      case 'captain':
        return Colors.blue;
      case 'vice captain':
        return Colors.indigo;
      default:
        return Theme.of(context).primaryColor;
    }
  }

  Color _getMemberAvatarColor(String name) {
    // Generate a consistent color based on the member's name
    final colors = [
      Colors.blue[600]!,
      Colors.green[600]!,
      Colors.orange[600]!,
      Colors.purple[600]!,
      Colors.red[600]!,
      Colors.teal[600]!,
      Colors.pink[600]!,
      Colors.indigo[600]!,
      Colors.amber[600]!,
      Colors.deepOrange[600]!,
    ];
    
    // Use the hash code of the name to pick a consistent color
    final colorIndex = name.hashCode.abs() % colors.length;
    return colors[colorIndex];
  }

  String _formatJoinedDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;
    
    if (difference < 7) {
      return '${difference}d ago';
    } else if (difference < 30) {
      return '${(difference / 7).round()}w ago';
    } else if (difference < 365) {
      return '${(difference / 30).round()}m ago';
    } else {
      return '${(difference / 365).round()}y ago';
    }
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Search Members'),
        content: TextField(
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter name, email, or role...',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => setState(() => _searchQuery = value),
          onSubmitted: (value) {
            setState(() => _searchQuery = value);
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text('Search'),
          ),
        ],
      ),
    );
  }
}

// Mock model class for ClubMember
class ClubMember {
  final String id;
  final String name;
  final String email;
  final String phoneNumber;
  final String role;
  final double balance;
  final int points;
  final String? profilePicture;
  final DateTime joinedDate;
  final bool isActive;

  ClubMember({
    required this.id,
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.role,
    required this.balance,
    required this.points,
    this.profilePicture,
    required this.joinedDate,
    required this.isActive,
  });
}