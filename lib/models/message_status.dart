enum MessageStatus {
  preparing,    // Initial state - just created
  compressing,  // Video compression in progress
  uploading,    // File upload in progress
  sending,      // Message sending to server
  sent,         // Successfully sent
  delivered,    // Delivered to recipient
  read,         // Read by recipient
  failed        // Failed to send
}