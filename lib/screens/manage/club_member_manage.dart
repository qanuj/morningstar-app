import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import '../../models/club.dart';
import '../../models/user.dart';
import '../../models/transaction.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/svg_avatar.dart';
import '../../widgets/transaction_dialog_helper.dart';
import '../../widgets/custom_app_bar.dart';
import '../../utils/theme.dart';
import '../transactions/bulk_transaction_screen.dart';
import '../points/bulk_points_screen.dart';
import '../../widgets/transactions_list_widget.dart';

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
  
  // Transaction pagination
  bool _isLoadingTransactions = false;
  bool _hasMoreTransactions = true;
  int _transactionPage = 1;
  final int _transactionPageSize = 20;
  final ScrollController _transactionScrollController = ScrollController();

  // Role management
  String _selectedRole = 'Member';
  bool _isRolePermissionExpanded = false; // Collapsed by default
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
    _transactionScrollController.addListener(_onTransactionScroll);
    _loadCurrentUser();
    _loadMemberData();
  }

  @override
  void dispose() {
    _transactionScrollController.dispose();
    super.dispose();
  }

  void _onTransactionScroll() {
    if (_transactionScrollController.position.pixels >=
        _transactionScrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingTransactions && _hasMoreTransactions) {
        _loadMoreTransactions();
      }
    }
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
        if (currentUserData['success'] == true &&
            currentUserData['user'] != null) {
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

  bool get _isNonOwnerTryingToModifyOwner =>
      !_isCurrentUserOwner && _isTargetMemberOwner;

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
      // Reset transaction pagination
      _transactionPage = 1;
      _hasMoreTransactions = true;
      _recentTransactions.clear();
      
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
    if (_isLoadingTransactions) return;
    
    setState(() => _isLoadingTransactions = true);

    try {
      final response = await ApiService.get(
        '/clubs/${widget.club.id}/transactions?userId=${_currentMember.userId ?? _currentMember.id}&page=$_transactionPage&limit=$_transactionPageSize',
      );

      final transactionsData = response['transactions'] as List<dynamic>? ?? [];
      final newTransactions = transactionsData
          .map((data) => Transaction.fromJson(data))
          .toList();

      if (_transactionPage == 1) {
        _recentTransactions = newTransactions;
      } else {
        _recentTransactions.addAll(newTransactions);
      }

      _hasMoreTransactions = newTransactions.length == _transactionPageSize;
      setState(() {});
    } catch (e) {
      debugPrint('Error loading transactions: $e');
    } finally {
      setState(() => _isLoadingTransactions = false);
    }
  }

  Future<void> _loadMoreTransactions() async {
    _transactionPage++;
    await _loadRecentTransactions();
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
      await ApiService.delete(
        '/members/${_currentMember.id}?clubId=${widget.club.id}',
      );

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
                Text(
                  'This member has a balance of ₹${_currentMember.balance.toStringAsFixed(2)}',
                ),
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
        ) ??
        false;
  }

  Future<void> _showClearBalanceTransactionDialog() async {
    final balanceAmount = _currentMember.balance;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _ClearBalanceTransactionScreen(
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
      ),
    );
  }

  Future<bool> _showRemoveConfirmationDialog() async {
    return await showCupertinoDialog<bool>(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: Text('Remove ${_currentMember.name}?'),
            content: Text(
              'This will permanently remove this member from the club. This action cannot be undone.',
            ),
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
        ) ??
        false;
  }

  Future<void> _clearBalance() async {
    setState(() => _isProcessingTransaction = true);

    try {
      await ApiService.post('/transactions/clear-balance', {
        'clubId': widget.club.id,
        'userId': _currentMember.userId ?? _currentMember.id,
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
        ) ??
        false;
  }

  void _showTransactionScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BulkTransactionScreen(
          selectedMembers: [_currentMember],
          onSubmit: _handleBulkTransactionSubmit,
        ),
      ),
    );
  }


  void _showPointsScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BulkPointsScreen(
          selectedMembers: [_currentMember],
          onSubmit: _handleBulkPointsSubmit,
        ),
      ),
    );
  }

  Future<void> _handleBulkTransactionSubmit(
    Map<String, dynamic> data,
    String type,
  ) async {
    try {
      final userIds = [_currentMember.userId ?? _currentMember.id];

      final requestPayload = {
        'userIds': userIds,
        'amount': double.parse(data['amount']),
        'type': type,
        'purpose': data['purpose'],
        'description': data['description'],
        'clubId': widget.club.id,
        'paymentMethod': type == 'CREDIT' ? data['paymentMethod'] : null,
      };

      await ApiService.post('/transactions/bulk', requestPayload);

      // Refresh member data after successful transaction
      await _loadMemberData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              type == 'CREDIT'
                  ? 'Funds added successfully!'
                  : 'Expense added successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process transaction: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleBulkPointsSubmit(
    Map<String, dynamic> data,
    String action,
  ) async {
    try {
      await ApiService.post('/points', {
        'userId': _currentMember.userId ?? _currentMember.id,
        'clubId': widget.club.id,
        'points': int.parse(data['points']),
        'type': action == 'add' ? 'EARNED' : 'DEDUCTED',
        'category': data['category'],
        'description': data['description'],
      });

      // Refresh member data
      await _loadMemberData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == 'add' ? 'Points added successfully!' : 'Points deducted successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process points: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
          middle: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Club Logo
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryBlue,
                ),
                child: widget.club.logo != null && widget.club.logo!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          widget.club.logo!,
                          width: 24,
                          height: 24,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryBlue,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  widget.club.name.isNotEmpty
                                      ? widget.club.name[0].toUpperCase()
                                      : 'C',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      )
                    : Center(
                        child: Text(
                          widget.club.name.isNotEmpty
                              ? widget.club.name[0].toUpperCase()
                              : 'C',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
              ),
              SizedBox(width: 8),
              // Club Name
              Flexible(
                child: Text(
                  widget.club.name,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.label,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        child: _isLoading
            ? Center(child: CupertinoActivityIndicator())
            : Column(
                children: [
                  // Fixed content at top
                  Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: Column(
                      children: [
                        // Member Info Card
                        _buildMemberInfoCard(),

                        SizedBox(height: 20),

                        // Quick Actions
                        _buildQuickActionsCard(),

                        SizedBox(height: 20),

                        // Role & Permissions (collapsible with remove/ban inside)
                        _buildRolePermissionsCard(),

                        SizedBox(height: 20),
                      ],
                    ),
                  ),
                  
                  // Expandable transactions section
                  _buildRecentTransactionsCard(),
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
              _currentMember.profilePicture != null &&
                      _currentMember.profilePicture!.isNotEmpty
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


  Widget _buildRolePermissionsCard() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with expand/collapse button
            CupertinoButton(
              padding: EdgeInsets.all(16),
              onPressed: () {
                setState(() {
                  _isRolePermissionExpanded = !_isRolePermissionExpanded;
                });
              },
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Role & Permissions',
                      style: CupertinoTheme.of(context).textTheme.navTitleTextStyle,
                    ),
                  ),
                  Icon(
                    _isRolePermissionExpanded 
                        ? CupertinoIcons.chevron_up 
                        : CupertinoIcons.chevron_down,
                    color: CupertinoColors.systemGrey,
                    size: 20,
                  ),
                ],
              ),
            ),

            // Expandable content
            if (_isRolePermissionExpanded) ...[
              Container(
                padding: EdgeInsets.only(left: 16, right: 16, bottom: 16),
                child: Column(
                  children: [
                    // Role options
                    ..._roles.map((role) => _buildRoleOption(role)),
                    
                    SizedBox(height: 20),
                    
                    // Remove and Ban actions
                    Row(
                      children: [
                        Expanded(
                          child: _buildDangerButton(
                            icon: CupertinoIcons.person_badge_minus,
                            label: 'Remove from Club',
                            color: CupertinoColors.systemRed,
                            onPressed: _isEditingSelf || _isNonOwnerTryingToModifyOwner 
                                ? null 
                                : _handleRemoveFromClub,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _buildDangerButton(
                            icon: CupertinoIcons.xmark_circle,
                            label: 'Ban User',
                            color: CupertinoColors.systemOrange,
                            onPressed: _isEditingSelf || _isNonOwnerTryingToModifyOwner 
                                ? null 
                                : _banMember,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDangerButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onPressed,
  }) {
    final isDisabled = onPressed == null;
    
    return CupertinoButton(
      padding: EdgeInsets.symmetric(vertical: 12),
      color: isDisabled ? CupertinoColors.systemGrey : color,
      borderRadius: BorderRadius.circular(8),
      minSize: 0,
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 16,
            color: CupertinoColors.white,
          ),
          SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleOption(Map<String, dynamic> role) {
    final isSelected = _selectedRole == role['value'];
    final isOwnerRole = role['value'] == 'Owner';
    final isDisabled =
        _isEditingSelf || isOwnerRole || _isNonOwnerTryingToModifyOwner;

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: isDisabled
          ? null
          : () async {
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
                : (isSelected ? role['color'] : CupertinoColors.systemGrey4),
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
                  color: isSelected
                      ? role['color']
                      : CupertinoColors.systemGrey,
                  width: 2,
                ),
                color: isSelected
                    ? role['color']
                    : CupertinoColors.systemBackground,
              ),
              child: isSelected
                  ? Icon(
                      CupertinoIcons.circle_fill,
                      size: 12,
                      color: CupertinoColors.white,
                    )
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
                  icon: Icons.account_balance_wallet,
                  label: 'Transactions',
                  color: AppTheme.primaryBlue,
                  onTap: _showTransactionScreen,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.star,
                  label: 'Points',
                  color: Colors.amber,
                  onTap: _showPointsScreen,
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
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactionsCard() {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Transactions',
              style: CupertinoTheme.of(context).textTheme.navTitleTextStyle,
            ),

            SizedBox(height: 12),

            Expanded(
              child: RefreshIndicator(
                color: AppTheme.primaryBlue,
                onRefresh: _loadMemberData,
                child: _recentTransactions.isEmpty && !_isLoadingTransactions
                    ? _buildEmptyTransactionsState()
                    : ListView(
                        controller: _transactionScrollController,
                        physics: AlwaysScrollableScrollPhysics(),
                        children: TransactionsListWidget(
                          transactions: _recentTransactions,
                          listType: TransactionListType.member,
                          isLoadingMore: _isLoadingTransactions,
                          hasMoreData: _hasMoreTransactions,
                          currency: widget.club.membershipFeeCurrency,
                          showDateHeaders: true,
                        ).buildTransactionListItems(context),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods for transaction grouping and display
  Map<String, List<Transaction>> _groupTransactionsByDate(List<Transaction> transactions) {
    final Map<String, List<Transaction>> groupedTransactions = {};
    for (final transaction in transactions) {
      final dateKey = DateFormat('yyyy-MM-dd').format(DateTime.parse(transaction.createdAt));
      if (!groupedTransactions.containsKey(dateKey)) {
        groupedTransactions[dateKey] = [];
      }
      groupedTransactions[dateKey]!.add(transaction);
    }
    return groupedTransactions;
  }

  String _formatDateHeader(String dateKey) {
    final date = DateTime.parse(dateKey);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(Duration(days: 1));
    final transactionDate = DateTime(date.year, date.month, date.day);

    if (transactionDate == today) {
      return 'Today';
    } else if (transactionDate == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('MMM dd, yyyy').format(date);
    }
  }

  Widget _buildDateHeader(String dateKey) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).colorScheme.onSurface.withOpacity(0.1)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _formatDateHeader(dateKey),
        style: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark
              ? Theme.of(context).colorScheme.onSurface.withOpacity(0.8)
              : Colors.grey.shade600,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  List<Widget> _buildTransactionListItems() {
    final List<Widget> items = [];
    final groupedTransactions = _groupTransactionsByDate(_recentTransactions);
    final sortedDateKeys = groupedTransactions.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // Latest first

    for (final dateKey in sortedDateKeys) {
      final transactions = groupedTransactions[dateKey]!;
      // Add date header
      items.add(_buildDateHeader(dateKey));
      // Add transaction cards for this date
      for (final transaction in transactions) {
        items.add(_buildTransactionItem(transaction));
      }
    }

    // Add loading indicator for pagination
    if (_isLoadingTransactions || _hasMoreTransactions) {
      items.add(Container(
        padding: EdgeInsets.all(16),
        alignment: Alignment.center,
        child: CupertinoActivityIndicator(),
      ));
    }

    return items;
  }

  Widget _buildEmptyTransactionsState() {
    return ListView(
      physics: AlwaysScrollableScrollPhysics(),
      children: [
        Container(
          padding: EdgeInsets.all(64),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
              SizedBox(height: 16),
              Text(
                'No transactions yet',
                style: TextStyle(
                  color: Colors.grey[600], 
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Pull to refresh or use Quick Actions above',
                style: TextStyle(
                  color: Colors.grey[500], 
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionItem(Transaction transaction) {
    final isCredit = transaction.type == 'CREDIT';
    final icon = _getTransactionIcon(transaction.purpose);
    final createdAt = DateTime.parse(transaction.createdAt);
    
    return Container(
      margin: EdgeInsets.only(bottom: 8, left: 4, right: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.3),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // User Avatar with Transaction Badge (matching wallet style)
            Stack(
              children: [
                // User/Club Avatar
                SVGAvatar(
                  imageUrl: _currentMember.profilePicture,
                  size: 40,
                  backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                  fallbackIcon: Icons.person,
                  iconSize: 24,
                ),
                // Transaction Badge
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
                        color: Theme.of(context).cardColor,
                        width: 2,
                      ),
                    ),
                    child: Icon(icon, color: Colors.white, size: 10),
                  ),
                ),
              ],
            ),
            SizedBox(width: 12),

            // Transaction Info (Center)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    transaction.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w400,
                      fontSize: 12,
                      color: Theme.of(context).textTheme.titleLarge?.color,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: 4),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Theme.of(context).colorScheme.onSurface.withOpacity(0.15)
                          : Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _getPurposeText(transaction.purpose),
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Theme.of(context).colorScheme.onSurface.withOpacity(0.9)
                            : Theme.of(context).primaryColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Amount and Time (Right)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${isCredit ? '+' : '-'}₹${transaction.amount.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: isCredit ? Colors.green : Colors.red,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  DateFormat('hh:mm a').format(createdAt),
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getTransactionIcon(String purpose) {
    switch (purpose) {
      case 'MATCH_FEE':
        return Icons.sports_cricket;
      case 'MEMBERSHIP':
        return Icons.card_membership;
      case 'ORDER':
      case 'JERSEY_ORDER':
      case 'GEAR_PURCHASE':
        return Icons.shopping_cart;
      case 'CLUB_TOPUP':
        return Icons.account_balance_wallet;
      case 'REFUND':
        return Icons.money;
      default:
        return Icons.receipt;
    }
  }

  String _getPurposeText(String purpose) {
    switch (purpose) {
      case 'MATCH_FEE':
        return 'Match Fee';
      case 'MEMBERSHIP':
        return 'Membership Fee';
      case 'ORDER':
        return 'Store Order';
      case 'JERSEY_ORDER':
        return 'Jersey Order';
      case 'GEAR_PURCHASE':
        return 'Gear Purchase';
      case 'CLUB_TOPUP':
        return 'Wallet Top-up';
      case 'REFUND':
        return 'Refund';
      case 'ADJUSTMENT':
        return 'Balance Adjustment';
      default:
        return 'Other';
    }
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


// Clear Balance Transaction Screen
class _ClearBalanceTransactionScreen extends StatefulWidget {
  final User member;
  final Club club;
  final double balanceAmount;
  final VoidCallback onComplete;

  const _ClearBalanceTransactionScreen({
    required this.member,
    required this.club,
    required this.balanceAmount,
    required this.onComplete,
  });

  @override
  _ClearBalanceTransactionScreenState createState() =>
      _ClearBalanceTransactionScreenState();
}

class _ClearBalanceTransactionScreenState
    extends State<_ClearBalanceTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  final _descriptionController = TextEditingController();
  String _purpose = 'ADJUSTMENT';
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
    final actionText = isDebit ? 'Deduct Amount' : 'Add Funds';
    final iconColor = isDebit ? AppTheme.errorRed : AppTheme.successGreen;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: DetailAppBar(
        pageTitle: 'Clear Balance',
        onBackTap: () => Navigator.pop(context),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Header info card
            Container(
              width: double.infinity,
              margin: EdgeInsets.all(16),
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).dividerColor.withOpacity(0.3),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).shadowColor.withOpacity(0.04),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: iconColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isDebit ? Icons.remove_circle : Icons.add_circle,
                          color: iconColor,
                          size: 24,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.member.name,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Current Balance: ₹${widget.balanceAmount.toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: widget.balanceAmount >= 0 
                                  ? AppTheme.successGreen 
                                  : AppTheme.errorRed,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Create a transaction to clear this balance to ₹0',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Form fields
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Amount field (read-only, pre-filled)
                    Text(
                      'Amount',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    TextFormField(
                      controller: _amountController,
                      readOnly: true,
                      decoration: InputDecoration(
                        prefixText: '₹',
                        prefixIcon: Icon(
                          Icons.account_balance_wallet,
                          color: iconColor,
                        ),
                        fillColor: Theme.of(context).disabledColor.withOpacity(0.05),
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: Theme.of(context).dividerColor.withOpacity(0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: iconColor,
                            width: 2,
                          ),
                        ),
                      ),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: iconColor,
                      ),
                    ),

                    SizedBox(height: 20),

                    // Purpose dropdown
                    Text(
                      'Purpose',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _purpose,
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.category),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: [
                        {'value': 'MEMBERSHIP', 'display': 'Membership'},
                        {'value': 'MATCH_FEE', 'display': 'Match Fee'},
                        {'value': 'JERSEY_ORDER', 'display': 'Jersey Order'},
                        {'value': 'GEAR_PURCHASE', 'display': 'Gear Purchase'},
                        {'value': 'REFUND', 'display': 'Refund'},
                        {'value': 'ADJUSTMENT', 'display': 'Balance Adjustment'},
                        {'value': 'OTHER', 'display': 'Other'},
                      ].map((purpose) {
                        return DropdownMenuItem<String>(
                          value: purpose['value'],
                          child: Text(purpose['display']!),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _purpose = value);
                        }
                      },
                    ),

                    SizedBox(height: 20),

                    // Description field
                    Text(
                      'Description',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.description),
                        hintText: 'Enter description for this transaction',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      maxLines: 3,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Description is required';
                        }
                        return null;
                      },
                    ),

                    SizedBox(height: 100), // Space for bottom buttons
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // Bottom action buttons
      bottomNavigationBar: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).dividerColor.withOpacity(0.2),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isProcessing ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text('Cancel'),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _processTransaction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: iconColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isProcessing
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          actionText,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Future<void> _processTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isProcessing = true);

    try {
      final transactionType = widget.balanceAmount > 0 ? 'DEBIT' : 'CREDIT';

      await ApiService.post('/transactions', {
        'userId': widget.member.userId ?? widget.member.id,
        'clubId': widget.club.id,
        'amount': double.parse(_amountController.text),
        'type': transactionType,
        'purpose': _purpose,
        'description': _descriptionController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Balance cleared successfully'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }

      widget.onComplete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process transaction: ${e.toString()}'),
            backgroundColor: AppTheme.errorRed,
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
