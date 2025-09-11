import 'package:flutter/material.dart';
import 'dart:async';

class AutocompleteField<T> extends StatefulWidget {
  final String hintText;
  final String? helperText;
  final String? Function(String?)? validator;
  final Future<List<T>> Function(String) searchFunction;
  final String Function(T) displayStringForOption;
  final void Function(T) onSelected;
  final void Function(String)? onChanged;
  final TextEditingController? controller;
  final InputDecoration? decoration;

  const AutocompleteField({
    super.key,
    required this.hintText,
    this.helperText,
    this.validator,
    required this.searchFunction,
    required this.displayStringForOption,
    required this.onSelected,
    this.onChanged,
    this.controller,
    this.decoration,
  });

  @override
  State<AutocompleteField<T>> createState() => _AutocompleteFieldState<T>();
}

class _AutocompleteFieldState<T> extends State<AutocompleteField<T>> {
  late TextEditingController _controller;
  Timer? _debounceTimer;
  List<T> _suggestions = [];
  bool _isLoading = false;
  bool _showSuggestions = false;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _removeOverlay();
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _showSuggestions = false;
  }

  void _onTextChanged(String value) {
    widget.onChanged?.call(value);
    
    _debounceTimer?.cancel();
    _debounceTimer = Timer(Duration(milliseconds: 500), () {
      if (value.trim().isNotEmpty) {
        _searchSuggestions(value.trim());
      } else {
        setState(() {
          _suggestions = [];
          _isLoading = false;
        });
        _removeOverlay();
      }
    });
  }

  Future<void> _searchSuggestions(String query) async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final suggestions = await widget.searchFunction(query);
      if (mounted) {
        setState(() {
          _suggestions = suggestions;
          _isLoading = false;
        });
        
        if (suggestions.isNotEmpty) {
          _showSuggestionsOverlay();
        } else {
          _removeOverlay();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _suggestions = [];
          _isLoading = false;
        });
        _removeOverlay();
      }
    }
  }

  void _showSuggestionsOverlay() {
    _removeOverlay();
    
    _overlayEntry = OverlayEntry(
      builder: (context) => CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        offset: Offset(0, 60),
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: MediaQuery.of(context).size.width - 32,
            constraints: BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                return ListTile(
                  dense: true,
                  title: Text(
                    widget.displayStringForOption(suggestion),
                    style: TextStyle(fontSize: 14),
                  ),
                  onTap: () {
                    _controller.text = widget.displayStringForOption(suggestion);
                    widget.onSelected(suggestion);
                    _removeOverlay();
                    FocusScope.of(context).unfocus();
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
    
    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _showSuggestions = true);
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        controller: _controller,
        onChanged: _onTextChanged,
        onTap: () {
          if (_suggestions.isNotEmpty && !_showSuggestions) {
            _showSuggestionsOverlay();
          }
        },
        validator: widget.validator,
        decoration: widget.decoration ?? InputDecoration(
          hintText: widget.hintText,
          helperText: widget.helperText,
          hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
          suffixIcon: _isLoading 
              ? Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                )
              : _controller.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _controller.clear();
                        widget.onChanged?.call('');
                        _removeOverlay();
                      },
                    )
                  : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.red, width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.red, width: 2),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          helperStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ),
    );
  }
}