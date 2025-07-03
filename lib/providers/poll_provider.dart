import 'package:flutter/material.dart';
import '../models/poll.dart';
import '../services/api_service.dart';

class PollProvider with ChangeNotifier {
  List<Poll> _polls = [];
  bool _isLoading = false;
  String _filter = 'all'; // all, active, expired, voted, not_voted

  List<Poll> get polls => _polls;
  bool get isLoading => _isLoading;
  String get filter => _filter;

  List<Poll> get filteredPolls {
    switch (_filter) {
      case 'active':
        return _polls.where((poll) => 
          poll.expiresAt == null || poll.expiresAt!.isAfter(DateTime.now())
        ).toList();
      case 'expired':
        return _polls.where((poll) => 
          poll.expiresAt != null && poll.expiresAt!.isBefore(DateTime.now())
        ).toList();
      case 'voted':
        return _polls.where((poll) => poll.hasVoted).toList();
      case 'not_voted':
        return _polls.where((poll) => !poll.hasVoted).toList();
      default:
        return _polls;
    }
  }

  List<Poll> get activePolls => _polls.where((poll) => 
    poll.expiresAt == null || poll.expiresAt!.isAfter(DateTime.now())
  ).toList();

  List<Poll> get expiredPolls => _polls.where((poll) => 
    poll.expiresAt != null && poll.expiresAt!.isBefore(DateTime.now())
  ).toList();

  void setFilter(String filter) {
    _filter = filter;
    notifyListeners();
  }

  Future<void> loadPolls() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await ApiService.get('/polls');
      _polls = (response['data'] as List).map((poll) => Poll.fromJson(poll)).toList();
    } catch (e) {
      print('Error loading polls: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> votePoll(String pollId, String optionId) async {
    try {
      await ApiService.post('/polls/$pollId/vote', {'optionId': optionId});
      await loadPolls(); // Reload to get updated data
    } catch (e) {
      print('Error voting on poll: $e');
      throw e;
    }
  }

  Future<void> updateVote(String pollId, String optionId) async {
    try {
      await ApiService.put('/polls/$pollId/vote', {'optionId': optionId});
      await loadPolls(); // Reload to get updated data
    } catch (e) {
      print('Error updating vote: $e');
      throw e;
    }
  }

  Poll? getPollById(String id) {
    try {
      return _polls.firstWhere((poll) => poll.id == id);
    } catch (e) {
      return null;
    }
  }

  int getTotalVotes(Poll poll) {
    return poll.options.fold(0, (sum, option) => sum + option.voteCount);
  }

  double getOptionPercentage(PollOption option, Poll poll) {
    final totalVotes = getTotalVotes(poll);
    return totalVotes > 0 ? (option.voteCount / totalVotes * 100) : 0.0;
  }

  bool isPollExpired(Poll poll) {
    return poll.expiresAt != null && poll.expiresAt!.isBefore(DateTime.now());
  }

  String getUserVoteOptionText(Poll poll) {
    if (poll.userVote == null) return 'Not voted';
    
    final option = poll.options.firstWhere(
      (option) => option.id == poll.userVote!.pollOptionId,
      orElse: () => PollOption(id: '', text: 'Unknown', voteCount: 0, pollId: poll.id),
    );
    
    return option.text;
  }
}