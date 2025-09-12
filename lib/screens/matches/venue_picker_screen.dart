import 'package:flutter/material.dart';
import '../../models/venue.dart';
import '../../services/venue_service.dart';
import '../../widgets/custom_app_bar.dart';

class VenuePickerScreen extends StatefulWidget {
  final String title;
  final Function(Venue) onVenueSelected;

  const VenuePickerScreen({
    super.key,
    required this.title,
    required this.onVenueSelected,
  });

  @override
  State<VenuePickerScreen> createState() => _VenuePickerScreenState();
}

class _VenuePickerScreenState extends State<VenuePickerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _popularScrollController = ScrollController();
  final ScrollController _allVenuesScrollController = ScrollController();
  
  List<Venue> _searchResults = [];
  List<Venue> _popularVenues = [];
  List<Venue> _allVenues = [];
  
  bool _isSearching = false;
  bool _showSearch = false;
  bool _isLoadingPopular = false;
  bool _isLoadingAll = false;
  bool _isLoadingMorePopular = false;
  bool _isLoadingMoreAll = false;
  bool _hasMorePopular = true;
  bool _hasMoreAll = true;
  
  int _popularOffset = 0;
  int _allVenuesOffset = 0;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _setupScrollListeners();
    _loadPopularVenues();
    _loadAllVenues();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _popularScrollController.dispose();
    _allVenuesScrollController.dispose();
    super.dispose();
  }

  void _setupScrollListeners() {
    _popularScrollController.addListener(() {
      if (_popularScrollController.position.pixels >= 
          _popularScrollController.position.maxScrollExtent - 200) {
        _loadMorePopularVenues();
      }
    });

    _allVenuesScrollController.addListener(() {
      if (_allVenuesScrollController.position.pixels >= 
          _allVenuesScrollController.position.maxScrollExtent - 200) {
        _loadMoreAllVenues();
      }
    });
  }

  Future<void> _loadPopularVenues({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _popularOffset = 0;
        _hasMorePopular = true;
        _popularVenues.clear();
      });
    }

    if (_isLoadingPopular) return;

    setState(() => _isLoadingPopular = true);

    try {
      final venues = await VenueService.getPopularVenues(
        limit: _pageSize,
        offset: refresh ? 0 : _popularOffset,
      );

      if (mounted) {
        setState(() {
          if (refresh) {
            _popularVenues = venues;
          } else {
            _popularVenues.addAll(venues);
          }
          _popularOffset = _popularVenues.length;
          _hasMorePopular = venues.length >= _pageSize;
          _isLoadingPopular = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingPopular = false);
      }
      print('Error loading popular venues: $e');
    }
  }

  Future<void> _loadAllVenues({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _allVenuesOffset = 0;
        _hasMoreAll = true;
        _allVenues.clear();
      });
    }

    if (_isLoadingAll) return;

    setState(() => _isLoadingAll = true);

    try {
      final venues = await VenueService.getAllVenues(
        limit: _pageSize,
        offset: refresh ? 0 : _allVenuesOffset,
      );

      if (mounted) {
        setState(() {
          if (refresh) {
            _allVenues = venues;
          } else {
            _allVenues.addAll(venues);
          }
          _allVenuesOffset = _allVenues.length;
          _hasMoreAll = venues.length >= _pageSize;
          _isLoadingAll = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingAll = false);
      }
      print('Error loading all venues: $e');
    }
  }

  Future<void> _loadMorePopularVenues() async {
    if (!_hasMorePopular || _isLoadingMorePopular) return;

    setState(() => _isLoadingMorePopular = true);

    try {
      final venues = await VenueService.getPopularVenues(
        limit: _pageSize,
        offset: _popularOffset,
      );

      if (mounted) {
        setState(() {
          _popularVenues.addAll(venues);
          _popularOffset = _popularVenues.length;
          _hasMorePopular = venues.length >= _pageSize;
          _isLoadingMorePopular = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMorePopular = false);
      }
      print('Error loading more popular venues: $e');
    }
  }

  Future<void> _loadMoreAllVenues() async {
    if (!_hasMoreAll || _isLoadingMoreAll) return;

    setState(() => _isLoadingMoreAll = true);

    try {
      final venues = await VenueService.getAllVenues(
        limit: _pageSize,
        offset: _allVenuesOffset,
      );

      if (mounted) {
        setState(() {
          _allVenues.addAll(venues);
          _allVenuesOffset = _allVenues.length;
          _hasMoreAll = venues.length >= _pageSize;
          _isLoadingMoreAll = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMoreAll = false);
      }
      print('Error loading more venues: $e');
    }
  }

  Future<void> _refreshPopularVenues() async {
    await _loadPopularVenues(refresh: true);
  }

  Future<void> _refreshAllVenues() async {
    await _loadAllVenues(refresh: true);
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final results = await VenueService.searchVenues(query);

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    }
  }

  void _showAddVenueDialog() {
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    final cityController = TextEditingController();
    final stateController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add New Venue'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Venue Name',
                  hintText: 'Enter venue name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: addressController,
                decoration: InputDecoration(
                  labelText: 'Address',
                  hintText: 'Enter venue address',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: cityController,
                      decoration: InputDecoration(
                        labelText: 'City',
                        hintText: 'City',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: stateController,
                      decoration: InputDecoration(
                        labelText: 'State',
                        hintText: 'State',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Venue name is required'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              try {
                final venue = await VenueService.createVenue(
                  name: nameController.text.trim(),
                  address: addressController.text.trim().isNotEmpty
                      ? addressController.text.trim()
                      : null,
                  city: cityController.text.trim().isNotEmpty
                      ? cityController.text.trim()
                      : null,
                  state: stateController.text.trim().isNotEmpty
                      ? stateController.text.trim()
                      : null,
                );

                if (venue != null && mounted) {
                  Navigator.of(context).pop(); // Close dialog
                  widget.onVenueSelected(venue);
                  Navigator.of(context).pop(); // Close venue picker
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to create venue'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error creating venue: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text('Add Venue'),
          ),
        ],
      ),
    );
  }

  Widget _buildVenueTile(Venue venue) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          widget.onVenueSelected(venue);
          Navigator.of(context).pop();
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Icon(
                  Icons.location_on,
                  color: Theme.of(context).primaryColor,
                  size: 28,
                ),
              ),
              SizedBox(width: 16),

              // Venue Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      venue.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    if (venue.fullAddress.isNotEmpty) ...[
                      SizedBox(height: 4),
                      Text(
                        venue.fullAddress,
                        style: TextStyle(
                          color: Colors.grey[600], 
                          fontSize: 14
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // Arrow
              Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPopularVenuesTab() {
    return RefreshIndicator(
      onRefresh: _refreshPopularVenues,
      color: Theme.of(context).primaryColor,
      child: _isLoadingPopular && _popularVenues.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Theme.of(context).primaryColor),
                  SizedBox(height: 16),
                  Text('Loading popular venues...'),
                ],
              ),
            )
          : _popularVenues.isEmpty
              ? ListView(
                  physics: AlwaysScrollableScrollPhysics(),
                  children: [
                    Container(
                      height: MediaQuery.of(context).size.height - 300,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.location_on, size: 64, color: Colors.grey[400]),
                            SizedBox(height: 16),
                            Text(
                              'No popular venues found',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Pull down to refresh or search for venues',
                              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  controller: _popularScrollController,
                  padding: EdgeInsets.symmetric(vertical: 8),
                  physics: AlwaysScrollableScrollPhysics(),
                  itemCount: _popularVenues.length + (_hasMorePopular ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _popularVenues.length) {
                      return Container(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: _isLoadingMorePopular
                              ? CircularProgressIndicator(
                                  color: Theme.of(context).primaryColor,
                                )
                              : SizedBox.shrink(),
                        ),
                      );
                    }
                    return _buildVenueTile(_popularVenues[index]);
                  },
                ),
    );
  }

  Widget _buildAllVenuesTab() {
    return RefreshIndicator(
      onRefresh: _refreshAllVenues,
      color: Theme.of(context).primaryColor,
      child: _isLoadingAll && _allVenues.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Theme.of(context).primaryColor),
                  SizedBox(height: 16),
                  Text('Loading venues...'),
                ],
              ),
            )
          : _allVenues.isEmpty
              ? ListView(
                  physics: AlwaysScrollableScrollPhysics(),
                  children: [
                    Container(
                      height: MediaQuery.of(context).size.height - 300,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.location_on, size: 64, color: Colors.grey[400]),
                            SizedBox(height: 16),
                            Text(
                              'No venues found',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Pull down to refresh or add a new venue',
                              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  controller: _allVenuesScrollController,
                  padding: EdgeInsets.symmetric(vertical: 8),
                  physics: AlwaysScrollableScrollPhysics(),
                  itemCount: _allVenues.length + (_hasMoreAll ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _allVenues.length) {
                      return Container(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: _isLoadingMoreAll
                              ? CircularProgressIndicator(
                                  color: Theme.of(context).primaryColor,
                                )
                              : SizedBox.shrink(),
                        ),
                      );
                    }
                    return _buildVenueTile(_allVenues[index]);
                  },
                ),
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Searching venues...'),
          ],
        ),
      );
    }

    if (_searchController.text.trim().isNotEmpty && _searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'No venues found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Try different search terms or add a new venue',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'Search for venues',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Enter venue name or location to search',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(vertical: 8),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        return _buildVenueTile(_searchResults[index]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: DetailAppBar(
        pageTitle: widget.title,
        showBackButton: true,
        customActions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchController.clear();
                  _searchResults = [];
                }
              });
            },
          ),
          IconButton(
            icon: Icon(Icons.add_location),
            onPressed: _showAddVenueDialog,
            tooltip: 'Add New Venue',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Field (when visible)
          if (_showSearch) ...[ 
            Container(
              color: Colors.white,
              padding: EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search venues...',
                  prefixIcon: Icon(
                    Icons.search,
                    color: Theme.of(context).primaryColor,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).primaryColor,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onChanged: (query) {
                  _performSearch(query);
                },
              ),
            ),
            Divider(height: 1),
          ],

          // Tab Bar (when not searching)
          if (!_showSearch) ...[
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                labelColor: Theme.of(context).primaryColor,
                unselectedLabelColor: Colors.grey[600],
                indicatorColor: Theme.of(context).primaryColor,
                indicatorWeight: 3,
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
                unselectedLabelStyle: TextStyle(
                  fontWeight: FontWeight.w400,
                  fontSize: 16,
                ),
                tabs: [
                  Tab(text: 'Popular'),
                  Tab(text: 'All Venues'),
                ],
              ),
            ),
          ],

          // Content Area
          Expanded(
            child: _showSearch
                ? _buildSearchResults()
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildPopularVenuesTab(),
                      _buildAllVenuesTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}