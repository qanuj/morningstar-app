import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class OpenGraphData {
  final String url;
  final String? title;
  final String? description;
  final String? image;
  final String? siteName;
  final String? favicon;

  OpenGraphData({
    required this.url,
    this.title,
    this.description,
    this.image,
    this.siteName,
    this.favicon,
  });

  factory OpenGraphData.fromUrl(String url) {
    return OpenGraphData(url: url);
  }
}

class OpenGraphService {
  static const Duration _timeout = Duration(seconds: 10);
  static final Map<String, OpenGraphData> _cache = {};

  /// Fetches Open Graph metadata for a given URL
  static Future<OpenGraphData> fetchMetadata(String url) async {
    try {
      // Check cache first
      if (_cache.containsKey(url)) {
        return _cache[url]!;
      }

      // Ensure URL has protocol
      String fullUrl = url;
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        fullUrl = 'https://$url';
      }

      // Check if this is an Instagram URL and handle specially
      if (_isInstagramUrl(fullUrl)) {
        final instagramData = await _fetchInstagramMetadata(fullUrl);
        _cache[url] = instagramData;
        return instagramData;
      }

      // For other URLs, use enhanced headers with retry logic
      OpenGraphData? ogData;

      // Try multiple user agents if the first one fails
      final userAgents = [
        'WhatsApp/2.21.11.17 A',
        'facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)',
        'Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
      ];

      for (int attempt = 0; attempt < userAgents.length; attempt++) {
        try {
          final headers = _getHeadersForUrl(fullUrl);
          headers['User-Agent'] = userAgents[attempt];

          debugPrint('🌐 Attempt ${attempt + 1} for $fullUrl with User-Agent: ${userAgents[attempt]}');

          // Fetch the webpage
          final response = await http.get(
            Uri.parse(fullUrl),
            headers: headers,
          ).timeout(_timeout);

          debugPrint('📡 Response status: ${response.statusCode}');
          debugPrint('📄 Response length: ${response.body.length}');

          if (response.statusCode == 200 && response.body.isNotEmpty) {
            // Parse HTML for Open Graph tags
            final html = response.body;
            ogData = _parseOpenGraphTags(html, fullUrl);

            // Check if we got good data
            if (ogData.title != null || ogData.image != null) {
              debugPrint('✅ Successfully fetched Open Graph data on attempt ${attempt + 1}');
              break;
            } else {
              debugPrint('⚠️ No Open Graph data found on attempt ${attempt + 1}');
            }
          } else {
            debugPrint('❌ Failed attempt ${attempt + 1}: Status ${response.statusCode}');
          }
        } catch (e) {
          debugPrint('❌ Error on attempt ${attempt + 1}: $e');
          if (attempt == userAgents.length - 1) {
            // Last attempt failed
            rethrow;
          }
        }
      }

      // If we still don't have good data, return fallback
      if (ogData == null || (ogData.title == null && ogData.image == null)) {
        debugPrint('⚠️ All attempts failed, using fallback data');
        return _createFallbackData(fullUrl);
      }

      // Cache the result
      _cache[url] = ogData;

      return ogData;
    } catch (e) {
      debugPrint('Error fetching Open Graph data for $url: $e');
      return _createFallbackData(url);
    }
  }

  /// Parses Open Graph tags from HTML content
  static OpenGraphData _parseOpenGraphTags(String html, String url) {
    String? title;
    String? description;
    String? image;
    String? siteName;
    String? favicon;

    debugPrint('🔍 Parsing Open Graph for URL: $url');
    debugPrint('📄 HTML length: ${html.length}');

    // Enhanced regex patterns for Open Graph tags with improved parsing
    final ogTitleRegex = RegExp(r'<meta\s+property="og:title"\s+content="([^"]*)"', caseSensitive: false);
    final ogDescriptionRegex = RegExp(r'<meta\s+property="og:description"\s+content="([^"]*)"', caseSensitive: false);
    final ogImageRegex = RegExp(r'<meta\s+property="og:image"\s+content="([^"]*)"', caseSensitive: false);
    final ogSiteNameRegex = RegExp(r'<meta\s+property="og:site_name"\s+content="([^"]*)"', caseSensitive: false);

    // Alternative patterns for single quotes
    final ogTitleRegexSingle = RegExp(r"<meta\s+property='og:title'\s+content='([^']*)'", caseSensitive: false);
    final ogDescriptionRegexSingle = RegExp(r"<meta\s+property='og:description'\s+content='([^']*)'", caseSensitive: false);
    final ogImageRegexSingle = RegExp(r"<meta\s+property='og:image'\s+content='([^']*)'", caseSensitive: false);
    final ogSiteNameRegexSingle = RegExp(r"<meta\s+property='og:site_name'\s+content='([^']*)'", caseSensitive: false);

    // Fallback to standard HTML tags
    final htmlTitleRegex = RegExp(r'<title[^>]*>([^<]*?)</title>', caseSensitive: false);
    final metaDescriptionRegex = RegExp(r'<meta\s+name="description"\s+content="([^"]*)"', caseSensitive: false);
    final faviconRegex = RegExp(r'<link[^>]*rel="icon"[^>]*href="([^"]*)"', caseSensitive: false);
    final faviconRegex2 = RegExp(r'<link[^>]*rel="shortcut icon"[^>]*href="([^"]*)"', caseSensitive: false);

    // Extract Open Graph title with double quotes
    var match = ogTitleRegex.firstMatch(html);
    if (match != null && match.group(1) != null) {
      title = _decodeHtmlEntities(match.group(1)!.trim());
      debugPrint('✅ Found OG title (double quotes): $title');
    }

    // Try single quotes if double quotes failed
    if (title == null || title.isEmpty) {
      match = ogTitleRegexSingle.firstMatch(html);
      if (match != null && match.group(1) != null) {
        title = _decodeHtmlEntities(match.group(1)!.trim());
        debugPrint('✅ Found OG title (single quotes): $title');
      }
    }

    // Extract Open Graph description
    match = ogDescriptionRegex.firstMatch(html);
    if (match != null && match.group(1) != null) {
      description = _decodeHtmlEntities(match.group(1)!.trim());
      debugPrint('✅ Found OG description (double quotes): ${description!.length > 100 ? description!.substring(0, 100) + "..." : description}');
    }

    // Try single quotes if double quotes failed
    if (description == null || description.isEmpty) {
      match = ogDescriptionRegexSingle.firstMatch(html);
      if (match != null && match.group(1) != null) {
        description = _decodeHtmlEntities(match.group(1)!.trim());
        debugPrint('✅ Found OG description (single quotes): ${description!.length > 100 ? description!.substring(0, 100) + "..." : description}');
      }
    }

    // Extract Open Graph image
    match = ogImageRegex.firstMatch(html);
    if (match != null && match.group(1) != null) {
      final rawImage = match.group(1)!.trim();
      if (rawImage.isNotEmpty) {
        image = _resolveUrl(rawImage, url);
        debugPrint('✅ Found OG image (double quotes): $image');
      }
    }

    // Try single quotes if double quotes failed
    if (image == null || image.isEmpty) {
      match = ogImageRegexSingle.firstMatch(html);
      if (match != null && match.group(1) != null) {
        final rawImage = match.group(1)!.trim();
        if (rawImage.isNotEmpty) {
          image = _resolveUrl(rawImage, url);
          debugPrint('✅ Found OG image (single quotes): $image');
        }
      }
    }

    // Extract Open Graph site name
    match = ogSiteNameRegex.firstMatch(html);
    if (match != null && match.group(1) != null) {
      siteName = _decodeHtmlEntities(match.group(1)!.trim());
      debugPrint('✅ Found OG site name (double quotes): $siteName');
    }

    // Try single quotes if double quotes failed
    if (siteName == null || siteName.isEmpty) {
      match = ogSiteNameRegexSingle.firstMatch(html);
      if (match != null && match.group(1) != null) {
        siteName = _decodeHtmlEntities(match.group(1)!.trim());
        debugPrint('✅ Found OG site name (single quotes): $siteName');
      }
    }

    // Fallback to HTML title if no OG title
    if (title == null || title.isEmpty) {
      final htmlTitleMatch = htmlTitleRegex.firstMatch(html);
      if (htmlTitleMatch != null) {
        title = _decodeHtmlEntities(htmlTitleMatch.group(1)!.trim());
        if (title!.isNotEmpty) {
          debugPrint('🔄 Using HTML title as fallback: $title');
        }
      }
    }

    // Fallback to meta description if no OG description
    if (description == null || description.isEmpty) {
      final metaDescriptionMatch = metaDescriptionRegex.firstMatch(html);
      if (metaDescriptionMatch != null) {
        description = _decodeHtmlEntities(metaDescriptionMatch.group(1)!.trim());
        if (description!.isNotEmpty) {
          debugPrint('🔄 Using meta description as fallback: ${description!.length > 100 ? description!.substring(0, 100) + "..." : description}');
        }
      }
    }

    // Extract favicon
    final faviconMatch = faviconRegex.firstMatch(html) ?? faviconRegex2.firstMatch(html);
    if (faviconMatch != null) {
      favicon = _resolveUrl(faviconMatch.group(1)!.trim(), url);
      debugPrint('✅ Found favicon: $favicon');
    } else {
      // Try default favicon location
      try {
        final uri = Uri.parse(url);
        favicon = '${uri.scheme}://${uri.host}/favicon.ico';
        debugPrint('🔄 Using default favicon: $favicon');
      } catch (e) {
        debugPrint('❌ Failed to create default favicon URL: $e');
      }
    }

    final result = OpenGraphData(
      url: url,
      title: title?.isNotEmpty == true ? title : null,
      description: description?.isNotEmpty == true ? description : null,
      image: image?.isNotEmpty == true ? image : null,
      siteName: siteName?.isNotEmpty == true ? siteName : null,
      favicon: favicon?.isNotEmpty == true ? favicon : null,
    );

    debugPrint('📋 Final OpenGraph result:');
    debugPrint('   Title: ${result.title}');
    debugPrint('   Description: ${result.description?.length}');
    debugPrint('   Image: ${result.image}');
    debugPrint('   Site: ${result.siteName}');

    return result;
  }

  /// Creates fallback data when Open Graph fetch fails
  static OpenGraphData _createFallbackData(String url) {
    try {
      final uri = Uri.parse(url);
      return OpenGraphData(
        url: url,
        title: uri.host,
        siteName: uri.host,
        favicon: '${uri.scheme}://${uri.host}/favicon.ico',
      );
    } catch (e) {
      return OpenGraphData(url: url);
    }
  }

  /// Resolves relative URLs to absolute URLs
  static String _resolveUrl(String url, String baseUrl) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    
    try {
      final baseUri = Uri.parse(baseUrl);
      if (url.startsWith('//')) {
        return '${baseUri.scheme}:$url';
      } else if (url.startsWith('/')) {
        return '${baseUri.scheme}://${baseUri.host}$url';
      } else {
        final basePath = baseUri.path.endsWith('/') ? baseUri.path : '${baseUri.path}/';
        return '${baseUri.scheme}://${baseUri.host}$basePath$url';
      }
    } catch (e) {
      return url;
    }
  }

  /// Decodes HTML entities like &amp;, &lt;, etc.
  static String _decodeHtmlEntities(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#x27;', "'")
        .replaceAll('&#x2F;', '/')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ');
  }

  /// Checks if the URL is an Instagram URL
  static bool _isInstagramUrl(String url) {
    return url.contains('instagram.com');
  }

  /// Checks if the URL is a YouTube URL
  static bool _isYouTubeUrl(String url) {
    return url.contains('youtube.com') || url.contains('youtu.be');
  }

  /// Gets appropriate headers for different types of URLs
  static Map<String, String> _getHeadersForUrl(String url) {
    // Enhanced headers to match WhatsApp/social media crawlers
    final Map<String, String> headers = {
      'User-Agent': 'WhatsApp/2.21.11.17 A',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.9',
      'Accept-Encoding': 'gzip, deflate, br',
      'Cache-Control': 'no-cache',
      'Pragma': 'no-cache',
      'Sec-Fetch-Dest': 'document',
      'Sec-Fetch-Mode': 'navigate',
      'Sec-Fetch-Site': 'none',
      'Upgrade-Insecure-Requests': '1',
      'Connection': 'keep-alive',
    };

    // Fallback User-Agents for different scenarios
    final List<String> fallbackUserAgents = [
      'WhatsApp/2.21.11.17 A',
      'facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)',
      'Mozilla/5.0 (compatible; WhatsApp/2.21.11.17; +https://faq.whatsapp.com/general/security-and-privacy/sending-links-on-whatsapp)',
      'Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1',
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
    ];

    // Add specific headers for different platforms
    if (url.contains('instagram.com')) {
      headers['User-Agent'] = 'facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)';
      headers['X-Instagram-AJAX'] = '1';
      headers['X-Requested-With'] = 'XMLHttpRequest';
    } else if (url.contains('youtube.com') || url.contains('youtu.be')) {
      headers['User-Agent'] = 'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)';
      headers['X-YouTube-Client-Name'] = '1';
      headers['X-YouTube-Client-Version'] = '2.0';
    } else if (url.contains('twitter.com') || url.contains('x.com')) {
      headers['User-Agent'] = 'Twitterbot/1.0';
      headers['X-Twitter-Active-User'] = 'yes';
    } else if (url.contains('facebook.com')) {
      headers['User-Agent'] = 'facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)';
      headers['Sec-Fetch-Site'] = 'none';
      headers['Sec-Fetch-Mode'] = 'navigate';
    } else {
      // For general websites, use WhatsApp user agent by default
      headers['User-Agent'] = 'WhatsApp/2.21.11.17 A';
    }

    return headers;
  }

  /// Fetches Instagram metadata with special handling
  static Future<OpenGraphData> _fetchInstagramMetadata(String url) async {
    try {
      debugPrint('🔍 Fetching Instagram metadata for: $url');

      // Try different Instagram URL formats
      final List<String> urlsToTry = [
        url,
        // Convert /reel/ to /p/ format which sometimes works better
        url.replaceAll('/reel/', '/p/'),
        // Add embed format
        '${url}embed/',
      ];

      for (final testUrl in urlsToTry) {
        try {
          debugPrint('🔍 Trying URL: $testUrl');

          // Create HTTP client with proper configuration
          final client = http.Client();
          final request = http.Request('GET', Uri.parse(testUrl));

          // Add headers that work better with Instagram
          request.headers.addAll({
            'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.9',
            'Accept-Encoding': 'identity', // Disable compression to avoid encoding issues
            'Cache-Control': 'no-cache',
            'Pragma': 'no-cache',
            'Sec-Fetch-Dest': 'document',
            'Sec-Fetch-Mode': 'navigate',
            'Sec-Fetch-Site': 'none',
            'Upgrade-Insecure-Requests': '1',
            'Connection': 'keep-alive',
          });

          final response = await client.send(request).timeout(const Duration(seconds: 15));

          if (response.statusCode == 200) {
            debugPrint('✅ Successfully fetched Instagram page');

            // Read response body with proper encoding handling
            final responseBody = await response.stream.bytesToString();
            debugPrint('📄 Response body length: ${responseBody.length}');

            final ogData = _parseInstagramContent(responseBody, url);
            if (ogData.image != null && ogData.image!.isNotEmpty) {
              debugPrint('✅ Found Instagram image: ${ogData.image}');
              client.close();
              return ogData;
            } else {
              debugPrint('⚠️ No image found in Instagram response');
            }
          } else {
            debugPrint('❌ Instagram request failed with status: ${response.statusCode}');
          }

          client.close();
        } catch (e) {
          debugPrint('❌ Failed to fetch $testUrl: $e');
          continue;
        }
      }

      // If all attempts fail, create fallback with Instagram branding
      debugPrint('⚠️ Creating Instagram fallback data');
      return _createInstagramFallback(url);
    } catch (e) {
      debugPrint('❌ Error in _fetchInstagramMetadata: $e');
      return _createInstagramFallback(url);
    }
  }

  /// Parses Instagram-specific content for metadata
  static OpenGraphData _parseInstagramContent(String html, String originalUrl) {
    String? title;
    String? description;
    String? image;

    debugPrint('🔍 Parsing Instagram HTML (length: ${html.length})');

    // Multiple regex patterns for Instagram meta tags
    final List<RegExp> imageRegexes = [
      RegExp(r'<meta\s+property="og:image"\s+content="([^"]*)"', caseSensitive: false),
      RegExp(r'<meta\s+property="og:image:url"\s+content="([^"]*)"', caseSensitive: false),
      RegExp(r'<meta\s+name="twitter:image"\s+content="([^"]*)"', caseSensitive: false),
      RegExp(r'"display_url":"([^"]*)"', caseSensitive: false),
      RegExp(r'"thumbnail_src":"([^"]*)"', caseSensitive: false),
    ];

    final List<RegExp> titleRegexes = [
      RegExp(r'<meta\s+property="og:title"\s+content="([^"]*)"', caseSensitive: false),
      RegExp(r'<title[^>]*>([^<]*)</title>', caseSensitive: false),
      RegExp(r'<meta\s+name="twitter:title"\s+content="([^"]*)"', caseSensitive: false),
    ];

    final List<RegExp> descriptionRegexes = [
      RegExp(r'<meta\s+property="og:description"\s+content="([^"]*)"', caseSensitive: false),
      RegExp(r'<meta\s+name="description"\s+content="([^"]*)"', caseSensitive: false),
      RegExp(r'<meta\s+name="twitter:description"\s+content="([^"]*)"', caseSensitive: false),
    ];

    // Try to find image using multiple patterns
    for (final regex in imageRegexes) {
      final match = regex.firstMatch(html);
      if (match != null && match.group(1) != null) {
        final foundImage = match.group(1)!;
        // Clean up escaped characters
        image = foundImage
            .replaceAll(r'\u0026', '&')
            .replaceAll(r'\\/', '/')
            .replaceAll(r'\\', '');

        if (image!.isNotEmpty &&
            !image!.contains('placeholder') &&
            !image!.contains('default')) {
          debugPrint('✅ Found Instagram image: $image');
          break;
        } else {
          image = null; // Reset if it's a placeholder
        }
      }
    }

    // Try to find title using multiple patterns
    for (final regex in titleRegexes) {
      final match = regex.firstMatch(html);
      if (match != null && match.group(1) != null) {
        title = _decodeHtmlEntities(match.group(1)!);
        if (title!.isNotEmpty && title != 'Instagram') {
          debugPrint('✅ Found Instagram title: $title');
          break;
        }
      }
    }

    // Try to find description using multiple patterns
    for (final regex in descriptionRegexes) {
      final match = regex.firstMatch(html);
      if (match != null && match.group(1) != null) {
        description = _decodeHtmlEntities(match.group(1)!);
        if (description!.isNotEmpty) {
          debugPrint('✅ Found Instagram description: ${description!.length > 100 ? description!.substring(0, 100) + "..." : description}');
          break;
        }
      }
    }

    debugPrint('🔍 Instagram parsing results: title=$title, description=${description?.length}, image=$image');

    return OpenGraphData(
      url: originalUrl,
      title: title?.isNotEmpty == true ? title : (originalUrl.contains('/reel/') ? 'Instagram Reel' : 'Instagram Post'),
      description: description?.isNotEmpty == true ? description : null,
      image: image?.isNotEmpty == true ? image : null,
      siteName: 'Instagram',
      favicon: 'https://www.instagram.com/static/images/ico/favicon.ico',
    );
  }

  /// Creates fallback data specifically for Instagram
  static OpenGraphData _createInstagramFallback(String url) {
    // Extract basic info from URL
    String title = 'Instagram Post';
    String? description;

    if (url.contains('/reel/')) {
      title = 'Instagram Reel';
      description = 'Watch this reel on Instagram';
    } else if (url.contains('/p/')) {
      title = 'Instagram Post';
      description = 'View this post on Instagram';
    }

    return OpenGraphData(
      url: url,
      title: title,
      description: description,
      siteName: 'Instagram',
      favicon: 'https://www.instagram.com/static/images/ico/favicon.ico',
      // Use Instagram's default placeholder image
      image: 'https://www.instagram.com/static/images/ico/apple-touch-icon-180x180-precomposed.png',
    );
  }

  /// Clears the cache (useful for testing or memory management)
  static void clearCache() {
    _cache.clear();
  }

  /// Test method to debug Open Graph parsing for specific URLs
  static Future<void> testOpenGraphParsing(String url) async {
    try {
      debugPrint('🧪 Testing Open Graph parsing for: $url');
      clearCache(); // Clear cache to force fresh fetch

      final ogData = await fetchMetadata(url);

      debugPrint('🧪 Test Results for $url:');
      debugPrint('   ✅ Title: ${ogData.title ?? "NOT FOUND"}');
      debugPrint('   ✅ Description: ${ogData.description ?? "NOT FOUND"}');
      debugPrint('   ✅ Image: ${ogData.image ?? "NOT FOUND"}');
      debugPrint('   ✅ Site Name: ${ogData.siteName ?? "NOT FOUND"}');
      debugPrint('   ✅ Favicon: ${ogData.favicon ?? "NOT FOUND"}');

    } catch (e) {
      debugPrint('🧪 Test failed for $url: $e');
    }
  }
}