import 'package:flutter/material.dart';
import '../../models/club.dart';
import '../../models/user.dart';
import '../../models/transaction.dart';
import '../../services/api_service.dart';
import '../../widgets/svg_avatar.dart';
import '../../utils/theme.dart';

class ClubMemberManageScreen extends StatefulWidget {
  final Club club;
  final User member;

  const ClubMemberManageScreen({
    super.key,
    required this.club,
    required this.member,
  });

  @override
  ClubMemberManageScreenState createState() => ClubMemberManageScreenState();
}

class ClubMemberManageScreenState extends State<ClubMemberManageScreen> {
  bool _isLoading = false;
  bool _isUpdatingRole = false;
  bool _isProcessingTransaction = false;
  
  // Member data
  late User _currentMember;
  List<Transaction> _recentTransactions = [];
  
  // Role management
  String _selectedRole = 'Member';
  final List<Map<String, dynamic>> _roles = [
    {
      'value': 'Owner',
      'title': 'Owner',
      'description': 'Full control • Manage billing • Transfer ownership',
      'color': Colors.purple,
    },
    {
      'value': 'Admin',
      'title': 'Admin', 
      'description': 'Manage members • Add expenses • Create matches',
      'color': AppTheme.primaryBlue,
    },
    {
      'value': 'Member',
      'title': 'Member',
      'description': 'View club info • RSVP to matches • View balance',
      'color': Colors.grey,
    },
  ];

  @override
  void initState() {
    super.initState();
    _currentMember = widget.member;
    _selectedRole = _getRoleFromUser(_currentMember);
    _loadMemberData();
  }

  String _getRoleFromUser(User user) {
    // Map user role to display role
    switch (user.role.toLowerCase()) {
      case 'owner':
        return 'Owner';
      case 'admin':
        return 'Admin';
      default:
        return 'Member';
    }
  }

  Future<void> _loadMemberData() async {
    setState(() => _isLoading = true);
    
    try {
      // Load member transactions
      await _loadRecentTransactions();
    } catch (e) {
      debugPrint('Error loading member data: $e');
      _showSnackBar('Failed to load member data', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadRecentTransactions() async {
    try {
      final response = await ApiService.get(
        '/transactions?clubId=${widget.club.id}&userId=${_currentMember.id}&limit=10'
      );
      
      final transactionsData = response['transactions'] as List<dynamic>? ?? [];
      _recentTransactions = transactionsData.map((data) => Transaction.fromJson(data)).toList();
      
      setState(() {});
    } catch (e) {
      debugPrint('Error loading transactions: $e');
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.errorRed : AppTheme.successGreen,
        duration: Duration(seconds: 3),
      ),
    );
  }

  Future<void> _updateMemberRole() async {
    if (_selectedRole == _getRoleFromUser(_currentMember)) return;
    
    setState(() => _isUpdatingRole = true);
    
    try {
      await ApiService.put('/members/${_currentMember.id}', {
        'clubId': widget.club.id,
        'role': _selectedRole.toUpperCase(),
      });
      
      _showSnackBar('Member role updated successfully');
      Navigator.pop(context, true); // Return true to indicate update
      
    } catch (e) {
      debugPrint('Error updating member role: $e');
      _showSnackBar('Failed to update member role', isError: true);
    } finally {
      setState(() => _isUpdatingRole = false);
    }
  }

  Future<void> _banMember() async {
    final confirmed = await _showConfirmationDialog(
      'Ban Member',
      'This will ban ${_currentMember.name} from the club. They won\'t be able to access club features.',
      'Ban',
      Colors.red,
    );
    
    if (!confirmed) return;
    
    setState(() => _isLoading = true);
    
    try {
      await ApiService.put('/members/${_currentMember.id}/ban', {
        'clubId': widget.club.id,
      });
      
      _showSnackBar('Member banned successfully');
      Navigator.pop(context, true);
      
    } catch (e) {
      debugPrint('Error banning member: $e');
      _showSnackBar('Failed to ban member', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _removeMember() async {
    if (_currentMember.balance > 0) {
      _showSnackBar('Clear member balance before removing', isError: true);
      return;
    }
    
    final confirmed = await _showConfirmationDialog(
      'Remove Member',
      'This will permanently remove ${_currentMember.name} from the club. This action cannot be undone.',
      'Remove',
      Colors.red,
    );
    
    if (!confirmed) return;
    
    setState(() => _isLoading = true);
    
    try {
      await ApiService.delete('/members/${_currentMember.id}?clubId=${widget.club.id}');
      
      _showSnackBar('Member removed successfully');
      Navigator.pop(context, true);
      
    } catch (e) {
      debugPrint('Error removing member: $e');
      _showSnackBar('Failed to remove member', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _clearBalance() async {
    final confirmed = await _showConfirmationDialog(
      'Clear Balance',
      'This will set ${_currentMember.name}\'s balance to ₹0. Current balance: ₹${_currentMember.balance.toStringAsFixed(2)}',
      'Clear Balance',
      AppTheme.primaryBlue,
    );
    
    if (!confirmed) return;
    
    setState(() => _isProcessingTransaction = true);
    
    try {
      await ApiService.post('/transactions/clear-balance', {
        'clubId': widget.club.id,
        'userId': _currentMember.id,
      });
      
      _showSnackBar('Balance cleared successfully');
      await _loadMemberData(); // Refresh data
      
    } catch (e) {
      debugPrint('Error clearing balance: $e');
      _showSnackBar('Failed to clear balance', isError: true);
    } finally {
      setState(() => _isProcessingTransaction = false);
    }
  }

  Future<bool> _showConfirmationDialog(
    String title,
    String content,
    String confirmText,
    Color confirmColor,
  ) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showTransactionDialog(String type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TransactionBottomSheet(
        member: _currentMember,
        club: widget.club,
        type: type,
        onComplete: () async {
          await _loadMemberData();
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showPointsDialog(String type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PointsBottomSheet(
        member: _currentMember,
        club: widget.club,
        type: type,
        onComplete: () async {
          await _loadMemberData();
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showTransactionsHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _MemberTransactionsScreen(
          member: _currentMember,
          club: widget.club,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlue,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Edit ${_currentMember.name}',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (_isUpdatingRole)
            Container(
              margin: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _updateMemberRole,
              child: Text(
                'Update Role',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryBlue,
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Member Info Card
                  _buildMemberInfoCard(),
                  
                  SizedBox(height: 20),
                  
                  // User Status
                  _buildUserStatusCard(),
                  
                  SizedBox(height: 20),
                  
                  // Remove from Club
                  _buildRemoveFromClubCard(),
                  
                  SizedBox(height: 20),
                  
                  // Role & Permissions
                  _buildRolePermissionsCard(),
                  
                  SizedBox(height: 20),
                  
                  // Quick Actions
                  _buildQuickActionsCard(),
                  
                  SizedBox(height: 20),
                  
                  // Recent Transactions
                  _buildRecentTransactionsCard(),
                  
                  SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildMemberInfoCard() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(20),
      child: Row(
        children: [
          // Profile Picture
          Stack(
            children: [
              _currentMember.profilePicture != null && _currentMember.profilePicture!.isNotEmpty
                  ? SVGAvatar.large(
                      imageUrl: _currentMember.profilePicture,
                      backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
                      fallbackIcon: Icons.person,
                    )
                  : Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          _currentMember.name.isNotEmpty 
                              ? _currentMember.name[0].toUpperCase()
                              : 'M',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
              // Online indicator
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          
          SizedBox(width: 16),
          
          // Member Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _currentMember.name,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).textTheme.titleLarge?.color,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'ADMIN',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 4),
                
                Text(
                  _currentMember.phoneNumber,
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
                
                SizedBox(height: 4),
                
                Text(
                  'joined ${_formatJoinedDate(_currentMember.createdAt)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(width: 16),
          
          // Balance and Points
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Balance',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
              Text(
                '₹${_currentMember.balance.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.successGreen,
                ),
              ),
              
              SizedBox(height: 8),
              
              Text(
                'Points',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star, size: 16, color: Colors.amber),
                  SizedBox(width: 4),
                  Text(
                    '0', // Points from member data
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserStatusCard() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'User Status',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.titleLarge?.color,
            ),
          ),
          
          SizedBox(height: 16),
          
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'User is active',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.green[700],
                        ),
                      ),
                      Text(
                        'This user has access to club features',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.green[600],
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: _banMember,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[50],
                    foregroundColor: Colors.red[700],
                    elevation: 0,
                    side: BorderSide(color: Colors.red[300]!),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.block, size: 16),
                      SizedBox(width: 4),
                      Text('Ban User'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemoveFromClubCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[200]!),
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Remove from Club',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.red[700],
            ),
          ),
          
          SizedBox(height: 16),
          
          Row(
            children: [
              Icon(Icons.person_remove, color: Colors.red[700], size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Remove User from Club',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.red[700],
                      ),
                    ),
                    Text(
                      'Permanently remove this member from the club entirely',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.red[600],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Balance: ₹${_currentMember.balance.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.red[700],
                    ),
                  ),
                  Text(
                    'Clear balance before removing',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _currentMember.balance <= 0 ? _removeMember : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[50],
                    foregroundColor: Colors.red[700],
                    elevation: 0,
                    side: BorderSide(color: Colors.red[300]!),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_remove, size: 16),
                      SizedBox(width: 4),
                      Text('Remove'),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _currentMember.balance > 0 ? _clearBalance : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isProcessingTransaction
                      ? SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text('Clear Balance'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRolePermissionsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Role & Permissions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.titleLarge?.color,
            ),
          ),
          
          SizedBox(height: 16),
          
          ..._roles.map((role) => _buildRoleOption(role)),
        ],
      ),
    );
  }

  Widget _buildRoleOption(Map<String, dynamic> role) {
    final isSelected = _selectedRole == role['value'];
    
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role['value']),
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected 
              ? role['color'].withOpacity(0.1)
              : Colors.transparent,
          border: Border.all(
            color: isSelected 
                ? role['color'] 
                : Theme.of(context).dividerColor.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? role['color'] : Colors.grey[400]!,
                  width: 2,
                ),
                color: isSelected ? role['color'] : Colors.transparent,
              ),
              child: isSelected 
                  ? Icon(Icons.circle, size: 12, color: role['color'])
                  : null,
            ),
            
            SizedBox(width: 12),
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    role['title'],
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected 
                          ? role['color']
                          : Theme.of(context).textTheme.titleMedium?.color,
                    ),
                  ),
                  Text(
                    role['description'],
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.titleLarge?.color,
            ),
          ),
          
          SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.add_circle,
                  label: 'Add Funds',
                  color: Colors.green,
                  onTap: () => _showTransactionDialog('CREDIT'),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.remove_circle,
                  label: 'Add Expense',
                  color: Colors.red,
                  onTap: () => _showTransactionDialog('DEBIT'),
                ),
              ),
            ],
          ),
          
          SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.star,
                  label: 'Add Points',
                  color: Colors.amber,
                  onTap: () => _showPointsDialog('add'),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.star_outline,
                  label: 'Remove Points', 
                  color: Colors.orange,
                  onTap: () => _showPointsDialog('remove'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        elevation: 0,
        padding: EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactionsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Transactions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.titleLarge?.color,
                ),
              ),
              TextButton(
                onPressed: _showTransactionsHistory,
                child: Text(
                  'View All',
                  style: TextStyle(
                    color: AppTheme.primaryBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          
          SizedBox(height: 12),
          
          if (_recentTransactions.isEmpty)
            Container(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.receipt_long,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'No transactions yet',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._recentTransactions.take(3).map((transaction) => 
                _buildTransactionItem(transaction)),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(Transaction transaction) {
    final isCredit = transaction.type == 'CREDIT';
    
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isCredit 
                  ? Colors.green.withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCredit ? Icons.add : Icons.remove,
              color: isCredit ? Colors.green : Colors.red,
              size: 16,
            ),
          ),
          
          SizedBox(width: 12),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.purpose ?? 'Transaction',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.titleMedium?.color,
                  ),
                ),
                Text(
                  _formatDate(transaction.createdAt),
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ),
          
          Text(
            '${isCredit ? '+' : '-'}₹${transaction.amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isCredit ? Colors.green[700] : Colors.red[700],
            ),
          ),
        ],
      ),
    );
  }

  String _formatJoinedDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;
    
    if (difference < 1) {
      return 'today';
    } else if (difference < 7) {
      return '$difference days ago';
    } else if (difference < 30) {
      return '${(difference / 7).round()} weeks ago';
    } else if (difference < 365) {
      return '${(difference / 30).round()} months ago';
    } else {
      return '${(difference / 365).round()} years ago';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

// Transaction Bottom Sheet
class _TransactionBottomSheet extends StatefulWidget {
  final User member;
  final Club club;
  final String type;
  final VoidCallback onComplete;

  const _TransactionBottomSheet({
    required this.member,
    required this.club,
    required this.type,
    required this.onComplete,
  });

  @override
  _TransactionBottomSheetState createState() => _TransactionBottomSheetState();
}

class _TransactionBottomSheetState extends State<_TransactionBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _purpose = 'OTHER';
  String _paymentMethod = 'CASH';
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            
            SizedBox(height: 20),
            
            Text(
              widget.type == 'CREDIT' ? 'Add Funds' : 'Add Expense',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ),
            
            SizedBox(height: 8),
            
            Text(
              'For: ${widget.member.name}',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.primaryBlue,
                fontWeight: FontWeight.w500,
              ),
            ),
            
            SizedBox(height: 20),
            
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _amountController,
                    decoration: InputDecoration(
                      labelText: 'Amount (₹)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: Icon(Icons.currency_rupee),
                    ),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Amount is required';
                      final amount = double.tryParse(value);
                      if (amount == null || amount <= 0) return 'Enter valid amount';
                      return null;
                    },
                  ),
                  
                  SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: Icon(Icons.description),
                    ),
                    maxLines: 2,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Description is required';
                      return null;
                    },
                  ),
                  
                  SizedBox(height: 16),
                  
                  DropdownButtonFormField<String>(
                    value: _purpose,
                    decoration: InputDecoration(
                      labelText: 'Purpose',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: [
                      DropdownMenuItem(value: 'MATCH_FEE', child: Text('Match Fee')),
                      DropdownMenuItem(value: 'MEMBERSHIP', child: Text('Membership')),
                      DropdownMenuItem(value: 'JERSEY_ORDER', child: Text('Jersey Order')),
                      DropdownMenuItem(value: 'GEAR_PURCHASE', child: Text('Gear Purchase')),
                      DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                    ],
                    onChanged: (value) => setState(() => _purpose = value!),
                  ),
                  
                  if (widget.type == 'CREDIT') ...[
                    SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _paymentMethod,
                      decoration: InputDecoration(
                        labelText: 'Payment Method',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: [
                        DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                        DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                        DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('Bank Transfer')),
                      ],
                      onChanged: (value) => setState(() => _paymentMethod = value!),
                    ),
                  ],
                  
                  SizedBox(height: 24),
                  
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: _isProcessing ? null : () => Navigator.pop(context),
                          child: Text('Cancel'),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isProcessing ? null : _processTransaction,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: _isProcessing
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text('Submit'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processTransaction() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isProcessing = true);
    
    try {
      await ApiService.post('/transactions', {
        'userId': widget.member.id,
        'clubId': widget.club.id,
        'amount': double.parse(_amountController.text),
        'type': widget.type,
        'purpose': _purpose,
        'description': _descriptionController.text,
        if (widget.type == 'CREDIT') 'paymentMethod': _paymentMethod,
      });
      
      widget.onComplete();
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to process transaction'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }
}

// Points Bottom Sheet
class _PointsBottomSheet extends StatefulWidget {
  final User member;
  final Club club;
  final String type;
  final VoidCallback onComplete;

  const _PointsBottomSheet({
    required this.member,
    required this.club,
    required this.type,
    required this.onComplete,
  });

  @override
  _PointsBottomSheetState createState() => _PointsBottomSheetState();
}

class _PointsBottomSheetState extends State<_PointsBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _pointsController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _category = 'PERFORMANCE';
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            
            SizedBox(height: 20),
            
            Text(
              widget.type == 'add' ? 'Add Points' : 'Remove Points',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ),
            
            SizedBox(height: 8),
            
            Text(
              'For: ${widget.member.name}',
              style: TextStyle(
                fontSize: 16,
                color: Colors.amber[700],
                fontWeight: FontWeight.w500,
              ),
            ),
            
            SizedBox(height: 20),
            
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _pointsController,
                    decoration: InputDecoration(
                      labelText: 'Points',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: Icon(Icons.star),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Points are required';
                      final points = int.tryParse(value);
                      if (points == null || points <= 0) return 'Enter valid points';
                      return null;
                    },
                  ),
                  
                  SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: Icon(Icons.description),
                    ),
                    maxLines: 2,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Description is required';
                      return null;
                    },
                  ),
                  
                  SizedBox(height: 16),
                  
                  DropdownButtonFormField<String>(
                    value: _category,
                    decoration: InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: [
                      DropdownMenuItem(value: 'PERFORMANCE', child: Text('Performance')),
                      DropdownMenuItem(value: 'ATTENDANCE', child: Text('Attendance')),
                      DropdownMenuItem(value: 'BONUS', child: Text('Bonus')),
                      DropdownMenuItem(value: 'PENALTY', child: Text('Penalty')),
                    ],
                    onChanged: (value) => setState(() => _category = value!),
                  ),
                  
                  SizedBox(height: 24),
                  
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: _isProcessing ? null : () => Navigator.pop(context),
                          child: Text('Cancel'),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isProcessing ? null : _processPoints,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber[600],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: _isProcessing
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text('Submit'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processPoints() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isProcessing = true);
    
    try {
      await ApiService.post('/points', {
        'userId': widget.member.id,
        'clubId': widget.club.id,
        'points': int.parse(_pointsController.text),
        'type': widget.type == 'add' ? 'EARNED' : 'DEDUCTED',
        'category': _category,
        'description': _descriptionController.text,
      });
      
      widget.onComplete();
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to process points'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }
}

// Member Transactions History Screen
class _MemberTransactionsScreen extends StatelessWidget {
  final User member;
  final Club club;

  const _MemberTransactionsScreen({
    required this.member,
    required this.club,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlue,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Recent Transactions - ${member.name}',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Showing last 1 transaction',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            
            SizedBox(height: 20),
            
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).shadowColor.withOpacity(0.1),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.account_balance_wallet,
                      color: Colors.green[600],
                      size: 24,
                    ),
                  ),
                  
                  SizedBox(width: 16),
                  
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add funds to club account',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).textTheme.titleLarge?.color,
                          ),
                        ),
                        
                        SizedBox(height: 4),
                        
                        Row(
                          children: [
                            Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                            SizedBox(width: 4),
                            Text(
                              'Sep 8, 2025',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  Text(
                    '₹1000',
                    style: TextStyle(
                      fontSize: 20,
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
    );
  }
}