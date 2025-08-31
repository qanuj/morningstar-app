import 'package:flutter/material.dart';

/// Upload state widgets for audio messages
class AudioUploadStates {
  static Widget buildUploadingState(
    BuildContext context, {
    required Color Function(BuildContext) getIconColor,
    required Color Function(BuildContext) getDotColor,
    required Color Function(BuildContext) getDurationColor,
  }) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.8,
        minWidth: 280,
      ),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              // Audio icon
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? Colors.grey[700] 
                      : Colors.grey[300],
                ),
                child: Icon(
                  Icons.mic,
                  size: 18,
                  color: getIconColor(context).withOpacity(0.6),
                ),
              ),
              
              SizedBox(width: 12),
              
              // Uploading progress
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Progress bar
                    Container(
                      height: 4,
                      child: LinearProgressIndicator(
                        backgroundColor: getDotColor(context),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                    
                    SizedBox(height: 8),
                    
                    // Uploading text
                    Text(
                      'Uploading audio...',
                      style: TextStyle(
                        fontSize: 12,
                        color: getDurationColor(context),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget buildUploadFailedState(
    BuildContext context, {
    required String? errorMessage,
    required VoidCallback? onRetry,
    required Color Function(BuildContext) getDurationColor,
  }) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.8,
        minWidth: 280,
      ),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              // Error icon
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.withOpacity(0.1),
                ),
                child: Icon(
                  Icons.error_outline,
                  size: 18,
                  color: Colors.red,
                ),
              ),
              
              SizedBox(width: 12),
              
              // Error message and retry
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Error text
                    Text(
                      'Failed to upload audio',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    
                    if (errorMessage != null) ...[
                      SizedBox(height: 2),
                      Text(
                        errorMessage,
                        style: TextStyle(
                          fontSize: 12,
                          color: getDurationColor(context),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    
                    SizedBox(height: 8),
                    
                    // Retry button
                    if (onRetry != null)
                      GestureDetector(
                        onTap: onRetry,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.refresh,
                                size: 14,
                                color: Colors.white,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Retry',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}