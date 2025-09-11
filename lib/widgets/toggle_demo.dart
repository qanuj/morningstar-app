import 'package:flutter/material.dart';
import 'enhanced_switch.dart';
import '../utils/theme.dart';

class ToggleDemo extends StatefulWidget {
  @override
  _ToggleDemoState createState() => _ToggleDemoState();
}

class _ToggleDemoState extends State<ToggleDemo> {
  bool _toggle1 = false;
  bool _toggle2 = true;
  bool _toggle3 = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Toggle Switch Demo'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enhanced Switch Examples',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 24),

            // Standard enhanced switch with labels
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Standard Switch with Labels',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    SizedBox(height: 12),
                    EnhancedSwitch(
                      value: _toggle1,
                      onChanged: (value) => setState(() => _toggle1 = value),
                      label: 'Notifications Enabled',
                      subtitle: 'Receive push notifications for important updates',
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // Compact enhanced switch with ON/OFF labels
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Compact Switch with ON/OFF Labels',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Dark Mode'),
                        EnhancedSwitch(
                          value: _toggle2,
                          onChanged: (value) => setState(() => _toggle2 = value),
                          showLabels: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // Custom colored switch
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Custom Colored Switch',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    SizedBox(height: 12),
                    EnhancedSwitch(
                      value: _toggle3,
                      onChanged: (value) => setState(() => _toggle3 = value),
                      label: 'Premium Features',
                      subtitle: 'Enable advanced features and analytics',
                      activeColor: AppTheme.successGreen,
                      inactiveColor: Colors.red[300],
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 24),

            Text(
              'Key Features:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '• Clear visual distinction between ON and OFF states\n'
              '• White thumb with colored track for better contrast\n'
              '• Animated transitions with check/close icons\n'
              '• Customizable colors and labels\n'
              '• Consistent with app theme and branding',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}