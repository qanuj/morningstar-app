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
    return MessageReply(
      messageId: json['messageId'] ?? '',
      senderId: json['senderId'] ?? '',
      senderName: json['senderName'] ?? '',
      content: json['content'] ?? '',
      messageType: json['messageType'],
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