import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/svg_avatar.dart';
import '../auth/login.dart';
import '../news/notifications.dart';
import 'edit_profile.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  ProfileScreenState createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    // Load fresh profile data when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      userProvider.loadUser(forceRefresh: true);
    });
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
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
      appBar: DetailAppBar(pageTitle: 'Profile'),
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
                              // Profile Picture
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
                                child: SVGAvatar(
                                  imageUrl: user.profilePicture,
                                  size: 80,
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.primary,
                                  child: user.profilePicture == null
                                      ? Text(
                                          user.name.isNotEmpty
                                              ? user.name[0].toUpperCase()
                                              : 'U',
                                          style: TextStyle(
                                            fontSize: 32,
                                            fontWeight: FontWeight.w600,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onPrimary,
                                          ),
                                        )
                                      : null,
                                ),
                              ),

                              SizedBox(width: 20),

                              // User Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Name and Age Row
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.baseline,
                                      textBaseline: TextBaseline.alphabetic,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            user.name,
                                            style: TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.w600,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurface,
                                            ),
                                          ),
                                        ),
                                        if (user.dateOfBirth != null) ...[
                                          SizedBox(width: 8),
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              '${DateTime.now().year - user.dateOfBirth!.year}',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),

                                    // Email
                                    if (user.email != null) ...[
                                      SizedBox(height: 4),
                                      Text(
                                        user.email!,
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium?.color,
                                        ),
                                      ),
                                    ],

                                    SizedBox(height: 8),

                                    // Phone Number
                                    Text(
                                      user.phoneNumber,
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium?.color,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),

                                    SizedBox(height: 4),

                                    // Location
                                    if (user.city != null || user.state != null)
                                      Text(
                                        [
                                          user.city,
                                          user.state,
                                        ].where((e) => e != null).join(', '),
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium?.color,
                                        ),
                                      ),

                                    if (user.bio != null &&
                                        user.bio!.isNotEmpty) ...[
                                      SizedBox(height: 12),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),

                          // Full-width divider and bio section
                          if (user.bio != null && user.bio!.isNotEmpty) ...[
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
                                user.bio!,
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

                  // Settings List
                  Container(
                    color: Theme.of(context).cardColor,
                    child: Column(
                      children: [
                        // Personal Information Section
                        _buildExpandableSection(
                          icon: Icons.person_outline,
                          title: 'Personal information',
                          isExpanded: false,
                          onTap: () async {
                            final userProvider = Provider.of<UserProvider>(
                              context,
                              listen: false,
                            );
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
                        ),

                        Divider(
                          height: 1,
                          color: Theme.of(
                            context,
                          ).dividerColor.withOpacity(0.3),
                        ),

                        // Login and Security
                        _buildExpandableSection(
                          icon: Icons.security,
                          title: 'Login and security',
                          isExpanded: false,
                          onTap: () {
                            // TODO: Navigate to security settings
                          },
                        ),

                        Divider(
                          height: 1,
                          color: Theme.of(
                            context,
                          ).dividerColor.withOpacity(0.3),
                        ),

                        // Theme Setting
                        _buildExpandableSection(
                          icon: Icons.palette_outlined,
                          title: 'Theme',
                          isExpanded: false,
                          subtitle: _getThemeModeText(themeProvider.themeMode),
                          onTap: () {
                            _showThemeDialog(context, themeProvider);
                          },
                        ),

                        Divider(
                          height: 1,
                          color: Theme.of(
                            context,
                          ).dividerColor.withOpacity(0.3),
                        ),

                        // Notifications
                        _buildExpandableSection(
                          icon: Icons.notifications_outlined,
                          title: 'Notifications',
                          isExpanded: false,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => NotificationsScreen(),
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

                        // Share the app
                        _buildExpandableSection(
                          icon: Icons.share,
                          title: 'Share Duggy',
                          isExpanded: false,
                          onTap: () {
                            _shareApp(context);
                          },
                        ),

                        Divider(
                          height: 1,
                          color: Theme.of(
                            context,
                          ).dividerColor.withOpacity(0.3),
                        ),

                        // Log Out
                        _buildExpandableSection(
                          icon: Icons.logout,
                          title: 'Log Out',
                          isExpanded: false,
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
                        SizedBox(height: 32),
                        Text(
                          _appVersion.isNotEmpty ? 'Version: $_appVersion' : 'Version: Loading...',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).textTheme.bodySmall?.color?.withOpacity(0.7),
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
    String? subtitle,
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
                    if (subtitle != null) ...[
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      SizedBox(width: 8),
                    ],
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
                Icon(Icons.check, color: Theme.of(context).colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }

  void _shareApp(BuildContext context) async {
    const String shareText =
        '''🏏 Check out Duggy - the ultimate cricket club management app!
    
📱 Manage your cricket club with ease
⚡ Track matches, players, and expenses
🎯 Join the cricket community today!

Download now and transform your cricket club experience!''';

    // Use share_plus for direct native sharing
    final box = context.findRenderObject() as RenderBox?;
    await Share.share(
      shareText,
      subject: 'Check out Duggy Cricket App!',
      sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
    );
  }


  String _getThemeModeText(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return 'Light';
      case AppThemeMode.dark:
        return 'Dark';
      case AppThemeMode.system:
        return 'System';
    }
  }

  void _showLogoutDialog(BuildContext context) {
    if (Platform.isIOS) {
      _showIOSLogoutDialog(context);
    } else {
      _showAndroidLogoutDialog(context);
    }
  }

  void _showIOSLogoutDialog(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Logout'),
        content: Text('Are you sure you want to logout?'),
        actions: [
          CupertinoDialogAction(
            child: Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: Text('Logout'),
            onPressed: () async {
              final navigator = Navigator.of(context);
              final userProvider = Provider.of<UserProvider>(
                context,
                listen: false,
              );

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
          ),
        ],
      ),
    );
  }

  void _showAndroidLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Logout'),
        content: Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final userProvider = Provider.of<UserProvider>(
                context,
                listen: false,
              );

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
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text('Logout'),
          ),
        ],
      ),
    );
  }
}
