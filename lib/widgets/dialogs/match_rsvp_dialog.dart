import 'package:flutter/material.dart';

/// Dialog for users to RSVP to a match from chat
class MatchRSVPDialog extends StatefulWidget {
  final String matchId;
  final String? currentStatus; // 'going', 'not_going', 'maybe', null
  final Function(String status) onRSVP;

  const MatchRSVPDialog({
    super.key,
    required this.matchId,
    required this.onRSVP,
    this.currentStatus,
  });

  @override
  State<MatchRSVPDialog> createState() => _MatchRSVPDialogState();
}

class _MatchRSVPDialogState extends State<MatchRSVPDialog> {
  String? _selectedStatus;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.currentStatus;
  }

  void _handleRSVP() async {
    if (_selectedStatus == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      widget.onRSVP(_selectedStatus!);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('RSVP updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update RSVP: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).dialogBackgroundColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Color(0xFF4CAF50).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.how_to_reg,
                    color: Color(0xFF4CAF50),
                    size: 24,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RSVP to Match',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).textTheme.titleLarge?.color,
                        ),
                      ),
                      Text(
                        'Let us know if you can attend',
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
            
            SizedBox(height: 24),
            
            // RSVP Options
            Column(
              children: [
                _buildRSVPOption(
                  'going',
                  'I\'ll be there',
                  Icons.check_circle,
                  Color(0xFF4CAF50),
                  'Count me in!',
                ),
                SizedBox(height: 12),
                _buildRSVPOption(
                  'maybe',
                  'Maybe',
                  Icons.help_outline,
                  Color(0xFFFF9800),
                  'Not sure yet',
                ),
                SizedBox(height: 12),
                _buildRSVPOption(
                  'not_going',
                  'Can\'t make it',
                  Icons.cancel,
                  Color(0xFFFF5722),
                  'Won\'t be able to attend',
                ),
              ],
            ),
            
            SizedBox(height: 24),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _isLoading ? null : () {
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isLoading || _selectedStatus == null ? null : _handleRSVP,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            'Update RSVP',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRSVPOption(
    String status,
    String title,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    final isSelected = _selectedStatus == status;
    
    return InkWell(
      onTap: () {
        setState(() {
          _selectedStatus = status;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          border: Border.all(
            color: isSelected ? color : Theme.of(context).dividerColor,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? color.withOpacity(0.2) : color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: color,
                size: 20,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? color : Theme.of(context).textTheme.titleMedium?.color,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.radio_button_checked,
                color: color,
                size: 20,
              )
            else
              Icon(
                Icons.radio_button_unchecked,
                color: Theme.of(context).dividerColor,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}