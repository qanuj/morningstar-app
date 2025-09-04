class MessageReply {
  final String messageId;
  final String senderId;
  final String senderName;
  final String content;
  final String? messageType;

  MessageReply({
    required this.messageId,
    required this.senderId,
    required this.senderName,
    required this.content,
    this.messageType,
  });

  factory MessageReply.fromJson(Map<String, dynamic> json) {
    // Handle nested content structure from server
    String messageContent = '';
    String? messageType;
    
    final content = json['content'];
    if (content is String) {
      messageContent = content;
      messageType = json['messageType'];
    } else if (content is Map<String, dynamic>) {
      messageContent = content['body'] ?? content['text'] ?? '';
      messageType = content['type'] ?? json['messageType'];
    }
    
    return MessageReply(
      messageId: json['messageId'] ?? '',
      senderId: json['senderId'] ?? '',
      senderName: json['senderName'] ?? '',
      content: messageContent,
      messageType: messageType,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'messageId': messageId,
      'senderId': senderId,
      'senderName': senderName,
      'content': content,
      'messageType': messageType,
    };
  }
}