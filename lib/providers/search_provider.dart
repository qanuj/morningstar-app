import 'package:flutter/material.dart';
import 'dart:async';

class SearchProvider with ChangeNotifier {
  String _searchQuery = '';
  bool _isSearching = false;
  List<String> _recentSearches = [];
  List<String> _suggestions = [];
  Timer? _debounceTimer;
  
  String get searchQuery => _searchQuery;
  bool get isSearching => _isSearching;
  List<String> get recentSearches => _recentSearches;
  List<String> get suggestions => _suggestions;
  
  bool get hasSearchQuery => _searchQuery.isNotEmpty;
  bool get hasRecentSearches => _recentSearches.isNotEmpty;
  bool get hasSuggestions => _suggestions.isNotEmpty;

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setIsSearching(bool searching) {
    _isSearching = searching;
    notifyListeners();
  }

  void clearSearch() {
    _searchQuery = '';
    _isSearching = false;
    _suggestions.clear();
    notifyListeners();
  }

  void addToRecentSearches(String query) {
    if (query.trim().isEmpty) return;
    
    // Remove if already exists
    _recentSearches.remove(query);
    
    // Add to beginning
    _recentSearches.insert(0, query);
    
    // Keep only last 10 searches
    if (_recentSearches.length > 10) {
      _recentSearches = _recentSearches.take(10).toList();
    }
    
    notifyListeners();
  }

  void removeFromRecentSearches(String query) {
    _recentSearches.remove(query);
    notifyListeners();
  }

  void clearRecentSearches() {
    _recentSearches.clear();
    notifyListeners();
  }

  void setSuggestions(List<String> suggestions) {
    _suggestions = suggestions;
    notifyListeners();
  }

  void addSuggestion(String suggestion) {
    if (!_suggestions.contains(suggestion)) {
      _suggestions.add(suggestion);
      notifyListeners();
    }
  }

  void clearSuggestions() {
    _suggestions.clear();
    notifyListeners();
  }

  void debounceSearch(String query, Function(String) onSearch, {int milliseconds = 500}) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(Duration(milliseconds: milliseconds), () {
      onSearch(query);
    });
  }

  List<String> getFilteredSuggestions(String query) {
    if (query.isEmpty) return [];
    
    return _suggestions
        .where((suggestion) => 
            suggestion.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  List<String> getFilteredRecentSearches(String query) {
    if (query.isEmpty) return _recentSearches;
    
    return _recentSearches
        .where((search) => 
            search.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}