import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/club.dart';
import '../providers/club_provider.dart';
import '../widgets/svg_avatar.dart';

class ClubSelectorDialog extends StatefulWidget {
  final String title;
  final String? subtitle;
  final Function(Club club)? onClubSelected;
  final Function(List<Club> clubs)? onMultipleClubsSelected;
  final bool Function(ClubMembership membership)? filterClubs;
  final bool showMemberCount;
  final bool showApprovalStatus;
  final bool multiSelect;
  final List<Club>? preSelectedClubs;

  const ClubSelectorDialog({
    super.key,
    required this.title,
    this.subtitle,
    this.onClubSelected,
    this.onMultipleClubsSelected,
    this.filterClubs,
    this.showMemberCount = true,
    this.showApprovalStatus = true,
    this.multiSelect = false,
    this.preSelectedClubs,
  }) : assert(
          (!multiSelect && onClubSelected != null) || 
          (multiSelect && onMultipleClubsSelected != null),
          'Single select requires onClubSelected, multi-select requires onMultipleClubsSelected',
        );

  @override
  State<ClubSelectorDialog> createState() => _ClubSelectorDialogState();
}

class _ClubSelectorDialogState extends State<ClubSelectorDialog> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  late Set<String> _selectedClubIds;

  @override
  void initState() {
    super.initState();
    _selectedClubIds = widget.preSelectedClubs?.map((club) => club.id).toSet() ?? {};
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleClubSelection(Club club) {
    setState(() {
      if (_selectedClubIds.contains(club.id)) {
        _selectedClubIds.remove(club.id);
      } else {
        _selectedClubIds.add(club.id);
      }
    });
  }

  List<Club> _getSelectedClubs(List<ClubMembership> allClubs) {
    return allClubs
        .where((membership) => _selectedClubIds.contains(membership.club.id))
        .map((membership) => membership.club)
        .toList();
  }

  List<ClubMembership> _getFilteredClubs(ClubProvider clubProvider) {
    var clubs = clubProvider.clubs;

    // Apply custom filter if provided
    if (widget.filterClubs != null) {
      clubs = clubs
          .where((membership) => widget.filterClubs!(membership))
          .toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      clubs = clubs
          .where(
            (membership) => membership.club.name.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ),
          )
          .toList();
    }

    return clubs;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ClubProvider>(
      builder: (context, clubProvider, child) {
        final filteredClubs = _getFilteredClubs(clubProvider);

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            widget.multiSelect ? Icons.checklist : Icons.groups,
                            color: Theme.of(context).primaryColor,
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        widget.title,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(context).primaryColor,
                                        ),
                                      ),
                                    ),
                                    if (widget.multiSelect && _selectedClubIds.isNotEmpty)
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).primaryColor,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${_selectedClubIds.length}',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                if (widget.subtitle != null) ...[
                                  SizedBox(height: 4),
                                  Text(
                                    widget.subtitle!,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (widget.multiSelect) ...[
                            if (_selectedClubIds.isNotEmpty) ...[
                              TextButton(
                                onPressed: () {
                                  setState(() => _selectedClubIds.clear());
                                },
                                child: Text(
                                  'Clear',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                              SizedBox(width: 8),
                            ],
                            TextButton(
                              onPressed: _selectedClubIds.isEmpty 
                                  ? null 
                                  : () {
                                      Navigator.of(context).pop();
                                      final selectedClubs = _getSelectedClubs(clubProvider.clubs);
                                      widget.onMultipleClubsSelected!(selectedClubs);
                                    },
                              child: Text(
                                'Done',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                          IconButton(
                            icon: Icon(Icons.close),
                            onPressed: () => Navigator.of(context).pop(),
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(),
                          ),
                        ],
                      ),

                      // Search bar
                      if (filteredClubs.length > 3) ...[
                        SizedBox(height: 16),
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search clubs...',
                            hintStyle: TextStyle(color: Colors.grey[500]),
                            prefixIcon: Icon(
                              Icons.search,
                              color: Colors.grey[500],
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            isDense: true,
                          ),
                          onChanged: (value) {
                            setState(() => _searchQuery = value);
                          },
                        ),
                      ],
                    ],
                  ),
                ),

                // Club list
                if (filteredClubs.isEmpty)
                  Padding(
                    padding: EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No clubs found matching "$_searchQuery"'
                              : 'You are not a member of any clubs yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (_searchQuery.isNotEmpty) ...[
                          SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            child: Text('Clear search'),
                          ),
                        ],
                      ],
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: filteredClubs.length,
                      itemBuilder: (context, index) {
                        final membership = filteredClubs[index];
                        final club = membership.club;

                        final isSelected = _selectedClubIds.contains(club.id);
                        
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              if (widget.multiSelect) {
                                _toggleClubSelection(club);
                              } else {
                                Navigator.of(context).pop();
                                widget.onClubSelected!(club);
                              }
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              decoration: widget.multiSelect && isSelected
                                  ? BoxDecoration(
                                      color: Theme.of(context).primaryColor.withOpacity(0.05),
                                      border: Border(
                                        left: BorderSide(
                                          color: Theme.of(context).primaryColor,
                                          width: 4,
                                        ),
                                      ),
                                    )
                                  : null,
                              child: Row(
                                children: [
                                  // Checkbox for multi-select
                                  if (widget.multiSelect) ...[
                                    Checkbox(
                                      value: isSelected,
                                      onChanged: (bool? value) {
                                        _toggleClubSelection(club);
                                      },
                                      activeColor: Theme.of(context).primaryColor,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    SizedBox(width: 12),
                                  ],
                                  
                                  // Club avatar
                                  Stack(
                                    children: [
                                      SVGAvatar(
                                        imageUrl: club.logo,
                                        size: 50,
                                        backgroundColor: Theme.of(
                                          context,
                                        ).primaryColor.withOpacity(0.1),
                                        fallbackIcon: Icons.groups,
                                        iconSize: 28,
                                      ),
                                      // Verified Badge
                                      if (club.isVerified)
                                        Positioned(
                                          right: 2,
                                          bottom: 2,
                                          child: Container(
                                            width: 16,
                                            height: 16,
                                            decoration: BoxDecoration(
                                              color: Colors.blue,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Theme.of(
                                                  context,
                                                ).scaffoldBackgroundColor,
                                                width: 2,
                                              ),
                                            ),
                                            child: Icon(
                                              Icons.verified,
                                              color: Colors.white,
                                              size: 8,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),

                                  SizedBox(width: 16),

                                  // Club info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          club.name,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Theme.of(
                                              context,
                                            ).textTheme.titleLarge?.color,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),

                                        SizedBox(height: 4),

                                        Row(
                                          children: [
                                            if (widget.showMemberCount) ...[
                                              Icon(
                                                Icons.people,
                                                size: 14,
                                                color: Colors.grey[600],
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                '${club.membersCount ?? 0} members',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],

                                            if (widget.showApprovalStatus &&
                                                !membership.approved) ...[
                                              if (widget.showMemberCount)
                                                Text(
                                                  ' • ',
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  'Approval Pending',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.orange[700],
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Arrow indicator (only for single select)
                                  if (!widget.multiSelect)
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                      color: Colors.grey[400],
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Helper factory methods for common use cases
class ClubSelectorDialogFactory {
  /// Show club selector for creating matches
  static void showForMatchCreation({
    required BuildContext context,
    required Function(Club club) onClubSelected,
    String title = 'Select Club',
  }) {
    showDialog(
      context: context,
      builder: (context) => ClubSelectorDialog(
        title: title,
        subtitle: 'Choose which club to create a match for',
        onClubSelected: onClubSelected,
        filterClubs: (membership) =>
            membership.approved && 
            (membership.role.toUpperCase() == 'ADMIN' || 
             membership.role.toUpperCase() == 'OWNER'), // Only show clubs where user is admin/owner
      ),
    );
  }

  /// Show club selector for general club selection
  static void showForClubSelection({
    required BuildContext context,
    Function(Club club)? onClubSelected,
    Function(List<Club> clubs)? onMultipleClubsSelected,
    String title = 'Select Club',
    String? subtitle,
    bool Function(ClubMembership membership)? filterClubs,
    bool multiSelect = false,
    List<Club>? preSelectedClubs,
    bool showMemberCount = true,
    bool showApprovalStatus = true,
  }) {
    showDialog(
      context: context,
      builder: (context) => ClubSelectorDialog(
        title: title,
        subtitle: subtitle,
        onClubSelected: onClubSelected,
        onMultipleClubsSelected: onMultipleClubsSelected,
        filterClubs: filterClubs,
        multiSelect: multiSelect,
        preSelectedClubs: preSelectedClubs,
        showMemberCount: showMemberCount,
        showApprovalStatus: showApprovalStatus,
      ),
    );
  }

  /// Show club selector for admin actions (only clubs where user is admin)
  static void showForAdminActions({
    required BuildContext context,
    Function(Club club)? onClubSelected,
    Function(List<Club> clubs)? onMultipleClubsSelected,
    String title = 'Select Club to Manage',
    bool multiSelect = false,
    List<Club>? preSelectedClubs,
  }) {
    showDialog(
      context: context,
      builder: (context) => ClubSelectorDialog(
        title: title,
        subtitle: multiSelect 
            ? 'Choose which clubs to manage'
            : 'Choose which club to manage',
        onClubSelected: onClubSelected,
        onMultipleClubsSelected: onMultipleClubsSelected,
        multiSelect: multiSelect,
        preSelectedClubs: preSelectedClubs,
        filterClubs: (membership) =>
            membership.approved &&
            (membership.role?.toLowerCase() == 'admin' ||
                membership.role?.toLowerCase() == 'owner'),
      ),
    );
  }

  /// Show multi-select club selector
  static void showMultiSelect({
    required BuildContext context,
    required Function(List<Club> clubs) onMultipleClubsSelected,
    required String title,
    String? subtitle,
    bool Function(ClubMembership membership)? filterClubs,
    List<Club>? preSelectedClubs,
    bool showMemberCount = true,
    bool showApprovalStatus = true,
  }) {
    showDialog(
      context: context,
      builder: (context) => ClubSelectorDialog(
        title: title,
        subtitle: subtitle,
        onMultipleClubsSelected: onMultipleClubsSelected,
        multiSelect: true,
        preSelectedClubs: preSelectedClubs,
        filterClubs: filterClubs,
        showMemberCount: showMemberCount,
        showApprovalStatus: showApprovalStatus,
      ),
    );
  }
}
