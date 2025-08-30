class MessageImage {
  final String url;
  final String? caption;
  
  MessageImage({required this.url, this.caption});
  
  factory MessageImage.fromJson(Map<String, dynamic> json) {
    return MessageImage(
      url: json['url'] ?? '',
      caption: json['caption'],
    );
  }
  
  Map<String, dynamic> toJson() => {
    'url': url,
    if (caption != null) 'caption': caption,
  };
}