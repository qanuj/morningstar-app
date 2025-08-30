import 'package:flutter/material.dart';
import '../widgets/duggy_logo.dart';

class AppDialogs {
  static void showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Center(
          child: Container(
            padding: EdgeInsets.all(8),
            child: DuggyLogoVariant.medium(
              color: Theme.of(context).colorScheme.primary,
              showText: true,
            ),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Duggy - Your Cricket Club Companion',
              style: TextStyle(fontWeight: FontWeight.w400, fontSize: 12),
            ),
            SizedBox(height: 12),
            Text(
              'Version 1.0.0',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall?.color,
                fontSize: 12,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Manage your cricket club activities, matches, store orders, and more with Duggy.',
              style: TextStyle(
                height: 1.5,
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontSize: 12,
              ),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.language,
                    color: Theme.of(context).colorScheme.primary,
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Visit duggy.app for more information',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w400,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('Close', style: TextStyle(fontWeight: FontWeight.w400)),
          ),
        ],
      ),
    );
  }
}
