import 'package:flutter/material.dart';
import '../utils/theme.dart';

class EnhancedSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;
  final String? subtitle;
  final bool showLabels;
  final Color? activeColor;
  final Color? inactiveColor;

  const EnhancedSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.subtitle,
    this.showLabels = false,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    if (label != null) {
      return SwitchListTile(
        title: Text(
          label!,
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              )
            : null,
        value: value,
        onChanged: onChanged,
        activeColor: activeColor ?? AppTheme.primaryBlue,
        inactiveTrackColor: inactiveColor ?? Colors.grey[400],
        inactiveThumbColor: Colors.white,
        contentPadding: EdgeInsets.zero,
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
          if (showLabels) ...[
            Text(
              'OFF',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: value ? Colors.grey[500] : AppTheme.primaryBlue,
              ),
            ),
            SizedBox(width: 8),
          ],
          _buildEnhancedSwitch(context),
          if (showLabels) ...[
            SizedBox(width: 8),
            Text(
              'ON',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: value ? AppTheme.primaryBlue : Colors.grey[500],
              ),
            ),
          ],
        ],
      );
  }

  Widget _buildEnhancedSwitch(BuildContext context) {
    return GestureDetector(
      onTap: onChanged != null ? () => onChanged!(!value) : null,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        width: 50,
        height: 26,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          color: value
              ? (activeColor ?? AppTheme.primaryBlue)
              : (inactiveColor ?? Colors.grey[400]),
          border: Border.all(
            color: value
                ? (activeColor ?? AppTheme.primaryBlue)
                : Colors.grey[500]!,
            width: 1.5,
          ),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              top: 2,
              left: value ? 24 : 2,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      spreadRadius: 1,
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: value
                    ? Icon(
                        Icons.check,
                        color: activeColor ?? AppTheme.primaryBlue,
                        size: 14,
                      )
                    : Icon(
                        Icons.close,
                        color: Colors.grey[600],
                        size: 14,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}