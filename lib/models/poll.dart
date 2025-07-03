class Poll {
  final String id;
  final String question;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final List<PollOption> options;
  final bool hasVoted;
  final String? userVote;

  Poll({
    required this.id,
    required this.question,
    required this.createdAt,
    this.expiresAt,
    required this.options,
    required this.hasVoted,
    this.userVote,
  });

  factory Poll.fromJson(Map<String, dynamic> json) {
    return Poll(
      id: json['id'],
      question: json['question'],
      createdAt: DateTime.parse(json['createdAt']),
      expiresAt: json['expiresAt'] != null ? DateTime.parse(json['expiresAt']) : null,
      options: (json['options'] as List).map((o) => PollOption.fromJson(o)).toList(),
      hasVoted: json['hasVoted'] ?? false,
      userVote: json['userVote'],
    );
  }
}

class PollOption {
  final String id;
  final String text;
  final int voteCount;

  PollOption({
    required this.id,
    required this.text,
    required this.voteCount,
  });

  factory PollOption.fromJson(Map<String, dynamic> json) {
    return PollOption(
      id: json['id'],
      text: json['text'],
      voteCount: json['voteCount'] ?? 0,
    );
  }
}