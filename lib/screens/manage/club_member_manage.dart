import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../models/club.dart';
import '../../models/user.dart';
import '../../models/transaction.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
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
  String? _currentUserId;
  String? _currentUserRole;
  
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
    _loadCurrentUser();
    _loadMemberData();
  }

  Future<void> _loadCurrentUser() async {
    try {
      print('DEBUG: Starting AuthService.getCurrentUser() call...');
      final currentUserData = await AuthService.getCurrentUser();
      print('DEBUG: AuthService response = $currentUserData');
      print('DEBUG: Response type = ${currentUserData.runtimeType}');
      
      // Try different possible response structures
      String? userId;
      String? userRole;
      if (currentUserData is Map<String, dynamic>) {
        if (currentUserData['success'] == true && currentUserData['user'] != null) {
          userId = currentUserData['user']['id'];
          userRole = currentUserData['user']['role'];
          print('DEBUG: Found userId in success.user.id = $userId');
          print('DEBUG: Found userRole in success.user.role = $userRole');
        } else if (currentUserData['user'] != null) {
          userId = currentUserData['user']['id'];
          userRole = currentUserData['user']['role'];
          print('DEBUG: Found userId in user.id = $userId');
          print('DEBUG: Found userRole in user.role = $userRole');
        } else if (currentUserData['id'] != null) {
          userId = currentUserData['id'];
          userRole = currentUserData['role'];
          print('DEBUG: Found userId in id = $userId');
          print('DEBUG: Found userRole in role = $userRole');
        } else {
          print('DEBUG: Could not find userId in response');
          print('DEBUG: Available keys: ${currentUserData.keys}');
        }
      }
      
      setState(() {
        _currentUserId = userId;
        _currentUserRole = userRole;
      });
      print('DEBUG: Set _currentUserId = $_currentUserId');
      print('DEBUG: Set _currentUserRole = $_currentUserRole');
    } catch (e, stackTrace) {
      print('Error loading current user: $e');
      print('Stack trace: $stackTrace');
    }
  }

  bool get _isEditingSelf {
    if (_currentUserId == null) return false;
    
    // Compare with userId first, fallback to id if userId is null
    final memberUserId = _currentMember.userId ?? _currentMember.id;
    return _currentUserId == memberUserId;
  }

  bool get _isCurrentUserAdmin => _currentUserRole?.toUpperCase() == 'ADMIN';
  bool get _isTargetMemberOwner => _currentMember.role.toUpperCase() == 'OWNER';
  
  bool get _isCurrentUserOwner => _currentUserRole?.toUpperCase() == 'OWNER';
  
  bool get _isNonOwnerTryingToModifyOwner => !_isCurrentUserOwner && _isTargetMemberOwner;

  String _getRoleFromUser(User user) {
    // Map user role to display role
    return switch (user.role.toUpperCase()) {
      'OWNER' => 'Owner',
      'ADMIN' => 'Admin', 
      'MEMBER' => 'Member',
      _ => 'Member',
    };
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

  Future<void> _handleRemoveFromClub() async {
    // If user has balance, first show clear balance dialog
    if (_currentMember.balance > 0) {
      final clearConfirmed = await _showClearBalanceDialog();
      if (!clearConfirmed) return;
      
      // After clearing balance, proceed to remove confirmation
      final removeConfirmed = await _showRemoveConfirmationDialog();
      if (removeConfirmed) {
        await _removeMember();
      }
    } else {
      // If no balance, directly show remove confirmation
      final confirmed = await _showRemoveConfirmationDialog();
      if (confirmed) {
        await _removeMember();
      }
    }
  }

  Future<bool> _showClearBalanceDialog() async {
    return await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Clear Balance Required'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('This member has a balance of ₹${_currentMember.balance.toStringAsFixed(2)}'),
            SizedBox(height: 8),
            Text('Balance must be cleared before removing from club.'),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          CupertinoDialogAction(
            onPressed: () async {
              Navigator.pop(context, true);
              await _showClearBalanceTransactionDialog();
            },
            child: Text('Clear Balance'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _showClearBalanceTransactionDialog() async {
    final balanceAmount = _currentMember.balance;
    
    showCupertinoModalPopup(
      context: context,
      builder: (context) => _ClearBalanceTransactionDialog(
        member: _currentMember,
        club: widget.club,
        balanceAmount: balanceAmount,
        onComplete: () async {
          await _loadMemberData();
          Navigator.pop(context);
          // After clearing balance, show remove confirmation
          final removeConfirmed = await _showRemoveConfirmationDialog();
          if (removeConfirmed) {
            await _removeMember();
          }
        },
      ),
    );
  }

  Future<bool> _showRemoveConfirmationDialog() async {
    return await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Remove ${_currentMember.name}?'),
        content: Text('This will permanently remove this member from the club. This action cannot be undone.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: Text('Remove'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _clearBalance() async {
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
    return await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: confirmColor == CupertinoColors.systemRed,
            onPressed: () => Navigator.pop(context, true),
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
    return Material(
      child: CupertinoPageScaffold(
        backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.systemBackground,
        border: null,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: Icon(
            CupertinoIcons.xmark,
            color: CupertinoColors.systemBlue,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        middle: Text(
          _currentMember.name,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: CupertinoColors.label,
          ),
        ),
      ),
      child: _isLoading
          ? Center(
              child: CupertinoActivityIndicator(),
            )
          : CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.only(top: 20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                  // Member Info Card
                  _buildMemberInfoCard(),
                  
                  SizedBox(height: 20),
                  
                  // User Status
                  _buildUserStatusCard(),
                  
                  SizedBox(height: 20),
                  
                  // Role & Permissions
                  _buildRolePermissionsCard(),
                  
                  SizedBox(height: 20),
                  
                  // Remove from Club
                  _buildRemoveFromClubCard(),
                  
                  SizedBox(height: 12),
                  
                  // Ban User
                  _buildBanUserButton(),
                  
                  SizedBox(height: 20),
                  
                  // Quick Actions
                  _buildQuickActionsCard(),
                  
                  SizedBox(height: 20),
                  
                  // Recent Transactions
                  _buildRecentTransactionsCard(),
                  
                  SizedBox(height: 50),
                    ]),
                  ),
                ),
              ],
            ),
      ),
    );
  }

  Widget _buildMemberInfoCard() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(10),
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
                        _getRoleFromUser(_currentMember).toUpperCase(),
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
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'User Status',
            style: CupertinoTheme.of(context).textTheme.navTitleTextStyle,
          ),
          
          SizedBox(height: 12),
          
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: CupertinoColors.systemGreen.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(CupertinoIcons.checkmark_circle, color: CupertinoColors.systemGreen, size: 20),
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
                          color: CupertinoColors.systemGreen,
                        ),
                      ),
                      Text(
                        'This user has access to club features',
                        style: TextStyle(
                          fontSize: 14,
                          color: CupertinoColors.systemGreen.withOpacity(0.8),
                        ),
                      ),
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
    final isDisabled = _isEditingSelf || _isNonOwnerTryingToModifyOwner;
    
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: CupertinoButton(
        padding: EdgeInsets.symmetric(vertical: 12),
        color: isDisabled ? CupertinoColors.systemGrey : CupertinoColors.systemRed,
        borderRadius: BorderRadius.circular(8),
        minSize: 0,
        onPressed: isDisabled ? null : _handleRemoveFromClub,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.person_badge_minus, 
              size: 16, 
              color: CupertinoColors.white
            ),
            SizedBox(width: 8),
            Text(
              'Remove from Club',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBanUserButton() {
    final isDisabled = _isEditingSelf || _isNonOwnerTryingToModifyOwner;
    
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: CupertinoButton(
        padding: EdgeInsets.symmetric(vertical: 12),
        color: isDisabled ? CupertinoColors.systemGrey : CupertinoColors.systemOrange,
        borderRadius: BorderRadius.circular(8),
        minSize: 0,
        onPressed: isDisabled ? null : _banMember,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.xmark_circle, 
              size: 16, 
              color: CupertinoColors.white
            ),
            SizedBox(width: 8),
            Text(
              'Ban User',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRolePermissionsCard() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Role & Permissions',
            style: CupertinoTheme.of(context).textTheme.navTitleTextStyle,
          ),
          
          SizedBox(height: 12),
          
          ..._roles.map((role) => _buildRoleOption(role)),
        ],
      ),
    );
  }

  Widget _buildRoleOption(Map<String, dynamic> role) {
    final isSelected = _selectedRole == role['value'];
    final isOwnerRole = role['value'] == 'Owner';
    final isDisabled = _isEditingSelf || isOwnerRole || _isNonOwnerTryingToModifyOwner;
    
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: isDisabled ? null : () async {
        if (_selectedRole != role['value']) {
          setState(() => _selectedRole = role['value']);
          await _updateMemberRole();
        }
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDisabled 
              ? CupertinoColors.systemGrey6
              : (isSelected 
                  ? role['color'].withOpacity(0.1)
                  : CupertinoColors.systemBackground),
          border: Border.all(
            color: isDisabled
                ? CupertinoColors.systemGrey4
                : (isSelected 
                    ? role['color'] 
                    : CupertinoColors.systemGrey4),
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
                  color: isSelected ? role['color'] : CupertinoColors.systemGrey,
                  width: 2,
                ),
                color: isSelected ? role['color'] : CupertinoColors.systemBackground,
              ),
              child: isSelected 
                  ? Icon(CupertinoIcons.circle_fill, size: 12, color: CupertinoColors.white)
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
                      color: isDisabled
                          ? CupertinoColors.systemGrey
                          : (isSelected 
                              ? role['color']
                              : CupertinoColors.label),
                    ),
                  ),
                  Text(
                    role['description'],
                    style: TextStyle(
                      fontSize: 14,
                      color: isDisabled
                          ? CupertinoColors.systemGrey
                          : CupertinoColors.secondaryLabel,
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
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: CupertinoTheme.of(context).textTheme.navTitleTextStyle,
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
    return CupertinoButton(
      padding: EdgeInsets.symmetric(vertical: 16),
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
      onPressed: onTap,
      child: Column(
        children: [
          Icon(icon, size: 24, color: color),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactionsCard() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Transactions',
                style: CupertinoTheme.of(context).textTheme.navTitleTextStyle,
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _showTransactionsHistory,
                child: Text(
                  'View All',
                  style: TextStyle(
                    color: CupertinoColors.systemBlue,
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
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: CupertinoColors.systemGrey4.withOpacity(0.3),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withOpacity(0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Transaction icon with club avatar style
            Stack(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey5,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.account_balance,
                    color: CupertinoColors.systemGrey,
                    size: 20,
                  ),
                ),
                // Transaction type badge
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: isCredit ? Colors.green : Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: CupertinoColors.systemBackground,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      isCredit ? Icons.add : Icons.remove,
                      color: Colors.white,
                      size: 10,
                    ),
                  ),
                ),
              ],
            ),
            
            SizedBox(width: 12),
            
            // Transaction details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.purpose ?? 'Transaction',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.label,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    _formatDate(transaction.createdAt),
                    style: TextStyle(
                      fontSize: 14,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
                ],
              ),
            ),
            
            // Amount
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
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.systemBackground,
        border: null,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: Icon(
            CupertinoIcons.xmark,
            color: CupertinoColors.systemBlue,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        middle: Text(
          'Recent Transactions - ${member.name}',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: CupertinoColors.label,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Showing last 1 transaction',
              style: TextStyle(
                fontSize: 16,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            
            SizedBox(height: 20),
            
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CupertinoColors.systemBackground,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGreen.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      CupertinoIcons.money_dollar_circle,
                      color: CupertinoColors.systemGreen,
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
                            color: CupertinoColors.label,
                          ),
                        ),
                        
                        SizedBox(height: 4),
                        
                        Row(
                          children: [
                            Icon(CupertinoIcons.calendar, size: 14, color: CupertinoColors.secondaryLabel),
                            SizedBox(width: 4),
                            Text(
                              'Sep 8, 2025',
                              style: TextStyle(
                                fontSize: 14,
                                color: CupertinoColors.secondaryLabel,
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
                      color: CupertinoColors.systemGreen,
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

// Clear Balance Transaction Dialog
class _ClearBalanceTransactionDialog extends StatefulWidget {
  final User member;
  final Club club;
  final double balanceAmount;
  final VoidCallback onComplete;

  const _ClearBalanceTransactionDialog({
    required this.member,
    required this.club,
    required this.balanceAmount,
    required this.onComplete,
  });

  @override
  _ClearBalanceTransactionDialogState createState() => _ClearBalanceTransactionDialogState();
}

class _ClearBalanceTransactionDialogState extends State<_ClearBalanceTransactionDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  final _descriptionController = TextEditingController();
  String _purpose = 'OTHER';
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill with the exact balance amount to clear
    _amountController = TextEditingController(
      text: widget.balanceAmount.abs().toStringAsFixed(2),
    );
    // Pre-fill description
    _descriptionController.text = 'Balance cleared for member removal';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine if balance is positive (need to debit) or negative (need to credit)
    final isDebit = widget.balanceAmount > 0;
    final transactionType = isDebit ? 'DEBIT' : 'CREDIT';
    final actionText = isDebit ? 'Deduct Amount' : 'Add Funds';
    final iconColor = isDebit ? CupertinoColors.systemRed : CupertinoColors.systemGreen;
    
    return CupertinoActionSheet(
      title: Text(
        'Clear Balance - ${widget.member.name}',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      message: Column(
        children: [
          Text(
            'Current Balance: ₹${widget.balanceAmount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: widget.balanceAmount >= 0 ? CupertinoColors.systemGreen : CupertinoColors.systemRed,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Create a transaction to clear this balance to ₹0',
            style: TextStyle(fontSize: 13, color: CupertinoColors.secondaryLabel),
          ),
        ],
      ),
      actions: [
        Container(
          height: 400,
          decoration: BoxDecoration(
            color: CupertinoColors.systemBackground,
            borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
          ),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Amount field (read-only, pre-filled)
                  Text(
                    'Amount (₹)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.label,
                    ),
                  ),
                  SizedBox(height: 8),
                  CupertinoTextField(
                    controller: _amountController,
                    readOnly: true,
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey6,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: CupertinoColors.systemGrey4),
                    ),
                    prefix: Padding(
                      padding: EdgeInsets.only(left: 12),
                      child: Icon(CupertinoIcons.money_dollar, 
                          color: iconColor, size: 18),
                    ),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: iconColor,
                    ),
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Description field
                  Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.label,
                    ),
                  ),
                  SizedBox(height: 8),
                  CupertinoTextField(
                    controller: _descriptionController,
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemBackground,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: CupertinoColors.systemGrey4),
                    ),
                    prefix: Padding(
                      padding: EdgeInsets.only(left: 12),
                      child: Icon(CupertinoIcons.doc_text, 
                          color: CupertinoColors.systemGrey, size: 18),
                    ),
                    maxLines: 2,
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Purpose dropdown
                  Text(
                    'Purpose',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.label,
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemBackground,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: CupertinoColors.systemGrey4),
                    ),
                    child: CupertinoButton(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      onPressed: _showPurposePicker,
                      child: Row(
                        children: [
                          Icon(CupertinoIcons.tag, color: CupertinoColors.systemGrey, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _getPurposeDisplayName(_purpose),
                              style: TextStyle(color: CupertinoColors.label),
                            ),
                          ),
                          Icon(CupertinoIcons.chevron_down, 
                              color: CupertinoColors.systemGrey, size: 14),
                        ],
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 24),
                  
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: CupertinoButton(
                          onPressed: _isProcessing ? null : () => Navigator.pop(context),
                          child: Text('Cancel'),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: CupertinoButton(
                          color: iconColor,
                          onPressed: _isProcessing ? null : _processTransaction,
                          child: _isProcessing
                              ? CupertinoActivityIndicator()
                              : Text(actionText, style: TextStyle(color: CupertinoColors.white)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(context),
        child: Text('Cancel'),
      ),
    );
  }

  void _showPurposePicker() {
    final purposes = [
      {'value': 'MEMBERSHIP', 'display': 'Membership'},
      {'value': 'MATCH_FEE', 'display': 'Match Fee'},
      {'value': 'JERSEY_ORDER', 'display': 'Jersey Order'},
      {'value': 'GEAR_PURCHASE', 'display': 'Gear Purchase'},
      {'value': 'REFUND', 'display': 'Refund'},
      {'value': 'ADJUSTMENT', 'display': 'Balance Adjustment'},
      {'value': 'OTHER', 'display': 'Other'},
    ];

    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 300,
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(16),
              child: Text(
                'Select Purpose',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.label,
                ),
              ),
            ),
            Expanded(
              child: CupertinoPicker(
                itemExtent: 32,
                scrollController: FixedExtentScrollController(
                  initialItem: purposes.indexWhere((p) => p['value'] == _purpose),
                ),
                onSelectedItemChanged: (index) {
                  setState(() {
                    _purpose = purposes[index]['value']!;
                  });
                },
                children: purposes.map((purpose) => Center(
                  child: Text(purpose['display']!),
                )).toList(),
              ),
            ),
            Container(
              padding: EdgeInsets.all(16),
              width: double.infinity,
              child: CupertinoButton(
                color: CupertinoColors.systemBlue,
                onPressed: () => Navigator.pop(context),
                child: Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getPurposeDisplayName(String value) {
    switch (value) {
      case 'MEMBERSHIP': return 'Membership';
      case 'MATCH_FEE': return 'Match Fee';
      case 'JERSEY_ORDER': return 'Jersey Order';
      case 'GEAR_PURCHASE': return 'Gear Purchase';
      case 'REFUND': return 'Refund';
      case 'ADJUSTMENT': return 'Balance Adjustment';
      default: return 'Other';
    }
  }

  Future<void> _processTransaction() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isProcessing = true);
    
    try {
      final transactionType = widget.balanceAmount > 0 ? 'DEBIT' : 'CREDIT';
      
      await ApiService.post('/transactions', {
        'userId': widget.member.id,
        'clubId': widget.club.id,
        'amount': double.parse(_amountController.text),
        'type': transactionType,
        'purpose': _purpose,
        'description': _descriptionController.text,
      });
      
      widget.onComplete();
      
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: Text('Transaction Failed'),
            content: Text('Failed to process balance clearing transaction: $e'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context),
                child: Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }
}