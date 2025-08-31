class StarredInfo {
  final bool isStarred;
  final String? starredAt;

  StarredInfo({
    required this.isStarred,
    this.starredAt,
  });

  factory StarredInfo.fromJson(Map<String, dynamic> json) {
    return StarredInfo(
      isStarred: json['isStarred'] ?? false,
      starredAt: json['starredAt'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isStarred': isStarred,
      'starredAt': starredAt,
    };
  }
}