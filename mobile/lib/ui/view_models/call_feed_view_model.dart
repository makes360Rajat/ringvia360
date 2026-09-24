import 'package:flutter/material.dart';
import '../../data/models/call_record.dart';
import '../../data/repositories/call_repository.dart';

class CallFeedViewModel extends ChangeNotifier {
  final CallRepository _callRepository;

  CallFeedViewModel({required CallRepository callRepository})
      : _callRepository = callRepository {
    loadCalls();
  }

  List<CallRecord> _allCalls = [];
  List<CallRecord> get allCalls => _allCalls;

  CallDirection? _selectedDirectionFilter;
  CallDirection? get selectedDirectionFilter => _selectedDirectionFilter;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  // Active audio player state
  String? _currentlyPlayingCallId;
  String? get currentlyPlayingCallId => _currentlyPlayingCallId;

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  List<CallRecord> get filteredCalls {
    return _allCalls.where((call) {
      if (_selectedDirectionFilter != null && call.direction != _selectedDirectionFilter) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        return call.contactName.toLowerCase().contains(query) ||
            call.company.toLowerCase().contains(query) ||
            call.phoneNumber.contains(query);
      }
      return true;
    }).toList();
  }

  Future<void> loadCalls() async {
    _allCalls = await _callRepository.getCalls();
    notifyListeners();
  }

  void setFilter(CallDirection? direction) {
    _selectedDirectionFilter = direction;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void togglePlayAudio(String callId) {
    if (_currentlyPlayingCallId == callId && _isPlaying) {
      _isPlaying = false;
    } else {
      _currentlyPlayingCallId = callId;
      _isPlaying = true;
    }
    notifyListeners();
  }
}
