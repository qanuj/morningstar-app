import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../models/venue.dart';
import '../../models/city.dart';
import '../../services/venue_service.dart';
import '../../services/api_service.dart';
import '../../widgets/custom_app_bar.dart';

class AddVenueScreen extends StatefulWidget {
  final Function(Venue)? onVenueAdded;

  const AddVenueScreen({
    super.key,
    this.onVenueAdded,
  });

  @override
  State<AddVenueScreen> createState() => _AddVenueScreenState();
}

class _AddVenueScreenState extends State<AddVenueScreen> with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _countryController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _googleMapsLinkController = TextEditingController();

  bool _isLoading = false;
  bool _isGettingLocation = false;
  Position? _currentPosition;

  // Clipboard monitoring variables
  bool _isMonitoringClipboard = false;
  String? _lastClipboardContent;
  bool _justOpenedMaps = false;

  // City picker variables
  List<City> _cities = [];
  bool _isLoadingCities = false;
  City? _selectedCity;

  @override
  void initState() {
    super.initState();

    // Listen for Google Maps link changes
    _googleMapsLinkController.addListener(_onGoogleMapsLinkChanged);

    // Add lifecycle observer for clipboard monitoring
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);

    _nameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _googleMapsLinkController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed && _justOpenedMaps) {
      // Disable automatic clipboard checking to prevent permission prompts
      // User can manually paste Google Maps link if needed
      _justOpenedMaps = false;
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);

    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showErrorSnackBar('Location permissions are denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showErrorSnackBar('Location permissions are permanently denied, we cannot request permissions.');
        return;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _latitudeController.text = position.latitude.toString();
        _longitudeController.text = position.longitude.toString();
      });

      // Auto-fill city and state from coordinates
      await _getCityStateFromCoordinates(position.latitude, position.longitude);

      _showSuccessSnackBar('Location captured successfully!');
    } catch (e) {
      _showErrorSnackBar('Failed to get location: $e');
    } finally {
      setState(() => _isGettingLocation = false);
    }
  }

  Future<void> _showLocationConfirmationDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.location_on, color: Theme.of(context).primaryColor),
            SizedBox(width: 8),
            Text('Use Current Location?'),
          ],
        ),
        content: Text(
          'Are you currently at this venue? This will capture your exact location coordinates for the venue.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Yes, I\'m here'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _getCurrentLocation();
    }
  }

  Future<void> _saveVenue() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final venue = Venue(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        city: _cityController.text.trim(),
        state: null, // No longer using state
        country: null, // No longer using country
        latitude: _latitudeController.text.isNotEmpty
            ? double.tryParse(_latitudeController.text)
            : null,
        longitude: _longitudeController.text.isNotEmpty
            ? double.tryParse(_longitudeController.text)
            : null,
        isActive: true,
        createdAt: DateTime.now(),
      );

      final createdVenue = await VenueService.createVenue(
        name: _nameController.text.trim(),
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        city: _cityController.text.trim(),
        state: null, // No longer using state
        country: null, // No longer using country
        latitude: _latitudeController.text.isNotEmpty
            ? double.tryParse(_latitudeController.text)
            : null,
        longitude: _longitudeController.text.isNotEmpty
            ? double.tryParse(_longitudeController.text)
            : null,
      );

      if (createdVenue != null) {
        if (widget.onVenueAdded != null) {
          widget.onVenueAdded!(createdVenue);
        }

        _showSuccessSnackBar('Venue added successfully!');
        Navigator.of(context).pop(createdVenue);
      } else {
        _showErrorSnackBar('Failed to create venue. Please try again.');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to add venue: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _getCityStateFromCoordinates(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;

        setState(() {
          // Auto-fill city if not already filled
          if (_cityController.text.isEmpty && placemark.locality != null) {
            _cityController.text = placemark.locality!;
          }

          // If address is empty, try to construct it from components
          if (_addressController.text.isEmpty) {
            String address = '';
            if (placemark.street != null) address += placemark.street!;
            if (placemark.subLocality != null) {
              if (address.isNotEmpty) address += ', ';
              address += placemark.subLocality!;
            }
            if (address.isNotEmpty) {
              _addressController.text = address;
            }
          }
        });

        _showSuccessSnackBar('Location details auto-filled!');
      }
    } catch (e) {
      print('Error getting location details: $e');
      // Don't show error to user as this is a nice-to-have feature
    }
  }

  Future<void> _openGoogleMapsForLocationPicking() async {
    try {
      final Uri url = Uri.parse('https://maps.google.com/');
      if (await canLaunchUrl(url)) {
        // Set flag to monitor clipboard when user returns
        _justOpenedMaps = true;

        await launchUrl(url, mode: LaunchMode.externalApplication);

        // Show instruction dialog
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, color: Theme.of(context).primaryColor, size: 32),
                  SizedBox(height: 12),
                  Text(
                    'Copy a Google Maps link and return here.\nWe\'ll auto-fill the location!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Got it'),
                ),
              ],
            ),
          );
        }
      } else {
        _showErrorSnackBar('Could not open Google Maps');
      }
    } catch (e) {
      _showErrorSnackBar('Error opening Google Maps: $e');
    }
  }

  Future<void> _checkClipboardForGoogleMapsLink() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      final clipboardText = clipboardData?.text?.trim();

      if (clipboardText != null &&
          clipboardText.isNotEmpty &&
          _isValidGoogleMapsLink(clipboardText) &&
          clipboardText != _lastClipboardContent) {

        // Update last clipboard content to avoid repeated processing
        _lastClipboardContent = clipboardText;

        // Show confirmation dialog before auto-filling
        if (mounted) {
          final shouldAutoFill = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.link, color: Theme.of(context).primaryColor, size: 32),
                  SizedBox(height: 12),
                  Text(
                    'Use Google Maps link to auto-fill location?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('No'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Yes'),
                ),
              ],
            ),
          );

          if (shouldAutoFill == true) {
            // Auto-fill the Google Maps link field
            _googleMapsLinkController.text = clipboardText;

            // Extract location information
            await _extractLocationFromGoogleMapsLink(clipboardText);
          }
        }
      }
    } catch (e) {
      // Silent failure - don't show error for clipboard access issues
      print('Error checking clipboard: $e');
    }
  }

  Future<String?> _getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('token');
    } catch (e) {
      print('Error getting auth token: $e');
      return null;
    }
  }

  Future<void> _fetchCities() async {
    if (_isLoadingCities) return;

    setState(() => _isLoadingCities = true);

    try {
      final url = '${ApiService.baseUrl}/cities';
      print('Fetching cities from: $url');

      // Get headers including auth token if available
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };

      // Add authorization header if token is available
      final token = await _getAuthToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      print('Cities API response status: ${response.statusCode}');
      print('Cities API response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('Parsed cities data: $data');

        setState(() {
          _cities = data.map((json) => City.fromApiResponse(json)).toList();
        });

        print('Cities loaded: ${_cities.length} cities');
      } else {
        _showErrorSnackBar('Failed to load cities (${response.statusCode})');
      }
    } catch (e) {
      print('Error fetching cities: $e');
      _showErrorSnackBar('Error loading cities: $e');
    } finally {
      setState(() => _isLoadingCities = false);
    }
  }

  void _showCityPicker() async {
    // Fetch cities if not already loaded
    if (_cities.isEmpty && !_isLoadingCities) {
      await _fetchCities();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          children: [
            Text(
              'Select City',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 16),
            if (_isLoadingCities)
              Expanded(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_cities.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No cities available'),
                      SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _fetchCities,
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _cities.length,
                  itemBuilder: (context, index) {
                    final city = _cities[index];
                    return ListTile(
                      title: Text(city.name),
                      subtitle: city.state != null ? Text(city.state!) : null,
                      onTap: () {
                        setState(() {
                          _selectedCity = city;
                          _cityController.text = city.name;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _onGoogleMapsLinkChanged() {
    final link = _googleMapsLinkController.text.trim();
    if (link.isNotEmpty && _isValidGoogleMapsLink(link)) {
      _extractLocationFromGoogleMapsLink(link);
    }
  }

  bool _isValidGoogleMapsLink(String link) {
    return link.contains('maps.google.') ||
           link.contains('goo.gl/maps') ||
           link.contains('maps.app.goo.gl');
  }

  Future<void> _extractLocationFromGoogleMapsLink(String link) async {
    try {
      // Extract coordinates from various Google Maps link formats
      double? latitude;
      double? longitude;

      // Format 1: @lat,lng,zoom (most common)
      RegExp coordsRegex = RegExp(r'@(-?\d+\.?\d*),(-?\d+\.?\d*),?\d*z?');
      Match? coordsMatch = coordsRegex.firstMatch(link);

      if (coordsMatch != null) {
        latitude = double.tryParse(coordsMatch.group(1)!);
        longitude = double.tryParse(coordsMatch.group(2)!);
      } else {
        // Format 2: /place/name/@lat,lng
        RegExp placeRegex = RegExp(r'\/place\/[^\/]*\/@(-?\d+\.?\d*),(-?\d+\.?\d*)');
        Match? placeMatch = placeRegex.firstMatch(link);

        if (placeMatch != null) {
          latitude = double.tryParse(placeMatch.group(1)!);
          longitude = double.tryParse(placeMatch.group(2)!);
        } else {
          // Format 3: ll=lat,lng parameter
          RegExp llRegex = RegExp(r'll=(-?\d+\.?\d*),(-?\d+\.?\d*)');
          Match? llMatch = llRegex.firstMatch(link);

          if (llMatch != null) {
            latitude = double.tryParse(llMatch.group(1)!);
            longitude = double.tryParse(llMatch.group(2)!);
          } else {
            // Format 4: q=lat,lng
            RegExp qRegex = RegExp(r'q=(-?\d+\.?\d*),(-?\d+\.?\d*)');
            Match? qMatch = qRegex.firstMatch(link);

            if (qMatch != null) {
              latitude = double.tryParse(qMatch.group(1)!);
              longitude = double.tryParse(qMatch.group(2)!);
            }
          }
        }
      }

      if (latitude != null && longitude != null) {
        setState(() {
          _latitudeController.text = latitude.toString();
          _longitudeController.text = longitude.toString();
        });

        // Auto-fill location details from coordinates
        await _getCityStateFromCoordinates(latitude, longitude);

        _showSuccessSnackBar('Location extracted from Google Maps link!');
      } else {
        _showErrorSnackBar('Could not extract coordinates from the Google Maps link. Please check the link format.');
      }

    } catch (e) {
      _showErrorSnackBar('Error processing Google Maps link: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F5F5), // Light gray background
      appBar: DetailAppBar(
        pageTitle: 'Add New Venue',
        showBackButton: true,
        customActions: [
          ElevatedButton(
            onPressed: _isLoading ? null : _saveVenue,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 2,
            ),
            child: _isLoading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'Save',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
          SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 600),
            child: Card(
              elevation: 8,
              shadowColor: Colors.black.withOpacity(0.15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // City Picker (First Field)
                      GestureDetector(
                        onTap: _showCityPicker,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[400]!),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.white,
                          ),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              hintText: 'Select city',
                              prefixIcon: Icon(Icons.location_city),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                            ),
                            child: Text(
                              _cityController.text.isEmpty ? 'Select city' : _cityController.text,
                              style: TextStyle(
                                color: _cityController.text.isEmpty ? Colors.grey[600] : Colors.black,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 16),

                      // Venue Name
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          hintText: 'Enter venue name',
                          prefixIcon: Icon(Icons.stadium),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: (value) {
                          if (value?.trim().isEmpty ?? true) {
                            return 'Venue name is required';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),

                      // Address (Optional)
                      TextFormField(
                        controller: _addressController,
                        decoration: InputDecoration(
                          hintText: 'Enter venue address (optional)',
                          prefixIcon: Icon(Icons.location_on),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        maxLines: 2,
                      ),

                      SizedBox(height: 24),

                      // GPS Location Section
                      Container(
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.blue[100]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [

                            // Get Current Location Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isGettingLocation ? null : _showLocationConfirmationDialog,
                                icon: _isGettingLocation
                                    ? SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : Icon(Icons.my_location),
                                label: Text(_isGettingLocation
                                    ? 'Getting Location...'
                                    : 'Use Current Location'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 2,
                                ),
                              ),
                            ),

                            // Location Status Indicator
                            if (_latitudeController.text.isNotEmpty && _longitudeController.text.isNotEmpty) ...[
                              SizedBox(height: 16),
                              Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.check_circle, color: Colors.green, size: 16),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Coordinates: ${_latitudeController.text}, ${_longitudeController.text}',
                                        style: TextStyle(
                                          color: Colors.green[700],
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            SizedBox(height: 16),

                            // Google Maps Link
                            TextFormField(
                              controller: _googleMapsLinkController,
                              decoration: InputDecoration(
                                hintText: 'Paste Google Maps location link',
                                prefixIcon: Icon(Icons.link),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                suffixIcon: IconButton(
                                  icon: Icon(Icons.map),
                                  tooltip: 'Open Google Maps to get location',
                                  onPressed: _openGoogleMapsForLocationPicking,
                                ),
                              ),
                              validator: (value) {
                                if (value?.trim().isNotEmpty ?? false) {
                                  if (!value!.contains('maps.google.com') && !value.contains('goo.gl/maps')) {
                                    return 'Please enter a valid Google Maps link';
                                  }
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),

                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}