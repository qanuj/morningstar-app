import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/svg_avatar.dart';
import '../auth/login.dart';
import 'edit_profile.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  ProfileScreenState createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    // Load fresh profile data when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      userProvider.loadUser(forceRefresh: true);
    });
  }

  Future<void> _refreshProfile(BuildContext context) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    await userProvider.loadUser(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: DetailAppBar(
        pageTitle: 'Profile',
      ),
      body: Consumer2<UserProvider, ThemeProvider>(
        builder: (context, userProvider, themeProvider, child) {
          final user = userProvider.user;

          if (user == null) {
            return Center(
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Theme.of(context).colorScheme.primary,
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => _refreshProfile(context),
            child: SingleChildScrollView(
              padding: EdgeInsets.zero,
              physics: AlwaysScrollableScrollPhysics(),
              child: Column(
              children: [
                // Profile Header Section
                Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  padding: EdgeInsets.fromLTRB(24, 24, 24, 32),
                  child: Column(
                    children: [
                      // Profile Picture
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).shadowColor.withOpacity(0.1),
                              blurRadius: 20,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: SVGAvatar(
                          imageUrl: user.profilePicture,
                          size: 80,
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          child: user.profilePicture == null
                              ? Text(
                                  user.name.isNotEmpty
                                      ? user.name[0].toUpperCase()
                                      : 'U',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).colorScheme.onPrimary,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      
                      SizedBox(height: 16),
                      
                      // User Name
                      Text(
                        user.name,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      
                      SizedBox(height: 4),
                      
                      // Phone Number
                      Text(
                        '@${user.phoneNumber}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                    ],
                  ),
                ),

                // Settings List
                Container(
                  color: Theme.of(context).cardColor,
                  child: Column(
                    children: [
                      // Personal Information Section
                      _buildExpandableSection(
                        icon: Icons.person_outline,
                        title: 'Personal information',
                        isExpanded: true,
                        onTap: () async {
                          final userProvider = Provider.of<UserProvider>(context, listen: false);
                          final result = await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => EditProfileScreen(),
                            ),
                          );
                          
                          // Refresh profile data when returning from edit screen
                          if (result == true && mounted) {
                            await userProvider.loadUser(forceRefresh: true);
                          }
                        },
                        children: [
                          _buildProfileInfoItem('Name', user.name),
                          if (user.email != null)
                            _buildProfileInfoItem('Email', user.email!),
                          _buildProfileInfoItem('Phone', user.phoneNumber),
                          if (user.city != null && user.state != null)
                            _buildProfileInfoItem('Location', '${user.city}, ${user.state}'),
                          if (user.dateOfBirth != null)
                            _buildProfileInfoItem('Date of Birth', '${user.dateOfBirth!.day}/${user.dateOfBirth!.month}/${user.dateOfBirth!.year}'),
                        ],
                      ),
                      
                      Divider(height: 1, color: Theme.of(context).dividerColor.withOpacity(0.3)),
                      
                      // Login and Security
                      _buildExpandableSection(
                        icon: Icons.security,
                        title: 'Login and security',
                        isExpanded: false,
                        onTap: () {
                          // TODO: Navigate to security settings
                        },
                      ),
                      
                      Divider(height: 1, color: Theme.of(context).dividerColor.withOpacity(0.3)),
                      
                      // Theme Setting
                      _buildExpandableSection(
                        icon: Icons.palette_outlined,
                        title: 'Theme',
                        isExpanded: false,
                        onTap: () {
                          _showThemeDialog(context, themeProvider);
                        },
                      ),
                      
                      Divider(height: 1, color: Theme.of(context).dividerColor.withOpacity(0.3)),
                      
                      // Notifications
                      _buildExpandableSection(
                        icon: Icons.notifications_outlined,
                        title: 'Notifications',
                        isExpanded: false,
                        onTap: () {
                          Navigator.of(context).pushNamed('/notifications');
                        },
                      ),
                      
                      Divider(height: 1, color: Theme.of(context).dividerColor.withOpacity(0.3)),
                      
                      // Share the app
                      _buildExpandableSection(
                        icon: Icons.share,
                        title: 'Share Duggy',
                        isExpanded: false,
                        onTap: () {
                          _shareApp(context);
                        },
                      ),
                      
                      Divider(height: 1, color: Theme.of(context).dividerColor.withOpacity(0.3)),
                      
                      // Log Out
                      _buildSettingsItem(
                        icon: Icons.logout,
                        title: 'Log Out',
                        onTap: () => _showLogoutDialog(context),
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: 32),
                
                // Member ID and Version
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Member ID',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                user.id,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context).textTheme.bodyMedium?.color,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(
                                Icons.copy,
                                size: 16,
                                color: Theme.of(context).textTheme.bodyMedium?.color,
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 32),
                      Text(
                        'Version: 1.0.0',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                        ),
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
    required bool isExpanded,
    VoidCallback? onTap,
    List<Widget>? children,
  }) {
    return Builder(
      builder: (context) => Column(
        children: [
          Material(
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
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (children != null && isExpanded)
                      GestureDetector(
                        onTap: onTap,
                        child: Text(
                          'Edit',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                    else
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
          if (isExpanded && children != null) ...children,
        ],
      ),
    );
  }

  Widget _buildProfileInfoItem(String label, String value) {
    return Builder(
      builder: (context) => Padding(
        padding: EdgeInsets.symmetric(horizontal: 56, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurface,
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

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? titleColor,
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
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: titleColor != null
                        ? titleColor.withOpacity(0.1)
                        : Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: titleColor ?? Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: titleColor ?? Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showThemeDialog(BuildContext context, ThemeProvider themeProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Theme.of(context).dialogBackgroundColor,
        title: Text(
          'Choose Theme',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildThemeDialogOption(
              'Light',
              Icons.light_mode,
              AppThemeMode.light,
              themeProvider,
              context,
            ),
            _buildThemeDialogOption(
              'Dark',
              Icons.dark_mode,
              AppThemeMode.dark,
              themeProvider,
              context,
            ),
            _buildThemeDialogOption(
              'System',
              Icons.settings_brightness,
              AppThemeMode.system,
              themeProvider,
              context,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeDialogOption(
    String label,
    IconData icon,
    AppThemeMode mode,
    ThemeProvider themeProvider,
    BuildContext context,
  ) {
    final isSelected = themeProvider.themeMode == mode;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          themeProvider.setThemeMode(mode);
          Navigator.of(context).pop();
        },
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected 
                    ? Theme.of(context).colorScheme.primary 
                    : Theme.of(context).textTheme.bodyMedium?.color,
              ),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    color: isSelected 
                        ? Theme.of(context).colorScheme.primary 
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check,
                  color: Theme.of(context).colorScheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _shareApp(BuildContext context) {
    // Simple share implementation without external packages
    // In a real app, you'd use share_plus package
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Theme.of(context).dialogBackgroundColor,
        title: Text(
          'Share Duggy',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Text(
          'Tell your friends about Duggy - the best cricket club management app!',
          style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Here you would implement actual sharing
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Sharing feature will be implemented soon!'),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                ),
              );
            },
            child: Text('Share'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Theme.of(context).dialogBackgroundColor,
        title: Text(
          'Logout',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final userProvider = Provider.of<UserProvider>(context, listen: false);
              
              navigator.pop();
              await AuthService.logout();
              userProvider.logout();
              
              if (context.mounted) {
                navigator.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => LoginScreen()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('Logout'),
          ),
        ],
      ),
    );
  }





}
