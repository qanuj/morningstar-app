class SocialPost {
  final String id;
  final String userId;
  final String username;
  final String? userAvatar;
  final String timeAgo;
  final String caption;
  final String imageUrl;
  final String? videoUrl;
  final int likes;
  final int comments;
  final int shares;
  final bool isLiked;

  SocialPost({
    required this.id,
    required this.userId,
    required this.username,
    this.userAvatar,
    required this.timeAgo,
    required this.caption,
    required this.imageUrl,
    this.videoUrl,
    required this.likes,
    required this.comments,
    required this.shares,
    required this.isLiked,
  });

  factory SocialPost.fromJson(Map<String, dynamic> json) {
    return SocialPost(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      username: json['username'] ?? '',
      userAvatar: json['userAvatar'],
      timeAgo: json['timeAgo'] ?? '',
      caption: json['caption'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      videoUrl: json['videoUrl'],
      likes: json['likes'] ?? 0,
      comments: json['comments'] ?? 0,
      shares: json['shares'] ?? 0,
      isLiked: json['isLiked'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'username': username,
      'userAvatar': userAvatar,
      'timeAgo': timeAgo,
      'caption': caption,
      'imageUrl': imageUrl,
      'videoUrl': videoUrl,
      'likes': likes,
      'comments': comments,
      'shares': shares,
      'isLiked': isLiked,
    };
  }

  SocialPost copyWith({
    String? id,
    String? userId,
    String? username,
    String? userAvatar,
    String? timeAgo,
    String? caption,
    String? imageUrl,
    String? videoUrl,
    int? likes,
    int? comments,
    int? shares,
    bool? isLiked,
  }) {
    return SocialPost(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      userAvatar: userAvatar ?? this.userAvatar,
      timeAgo: timeAgo ?? this.timeAgo,
      caption: caption ?? this.caption,
      imageUrl: imageUrl ?? this.imageUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      shares: shares ?? this.shares,
      isLiked: isLiked ?? this.isLiked,
    );
  }
}