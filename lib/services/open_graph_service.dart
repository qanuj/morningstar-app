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

      // For other URLs, use enhanced headers
      final headers = _getHeadersForUrl(fullUrl);

      // Fetch the webpage
      final response = await http.get(
        Uri.parse(fullUrl),
        headers: headers,
      ).timeout(_timeout);

      if (response.statusCode != 200) {
        return _createFallbackData(fullUrl);
      }

      // Parse HTML for Open Graph tags
      final html = response.body;
      final ogData = _parseOpenGraphTags(html, fullUrl);

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

    // Extract Open Graph tags using regex
    final ogTitleRegex = RegExp(r'<meta\s+property="og:title"\s+content="([^"]*)"', caseSensitive: false);
    final ogDescriptionRegex = RegExp(r'<meta\s+property="og:description"\s+content="([^"]*)"', caseSensitive: false);
    final ogImageRegex = RegExp(r'<meta\s+property="og:image"\s+content="([^"]*)"', caseSensitive: false);
    final ogSiteNameRegex = RegExp(r'<meta\s+property="og:site_name"\s+content="([^"]*)"', caseSensitive: false);
    
    // Fallback to standard HTML tags
    final htmlTitleRegex = RegExp(r'<title[^>]*>([^<]*)</title>', caseSensitive: false);
    final metaDescriptionRegex = RegExp(r'<meta\s+name="description"\s+content="([^"]*)"', caseSensitive: false);
    final faviconRegex = RegExp(r'<link[^>]*rel="icon"[^>]*href="([^"]*)"', caseSensitive: false);
    final faviconRegex2 = RegExp(r'<link[^>]*rel="shortcut icon"[^>]*href="([^"]*)"', caseSensitive: false);

    // Extract Open Graph data
    final ogTitleMatch = ogTitleRegex.firstMatch(html);
    if (ogTitleMatch != null) {
      title = _decodeHtmlEntities(ogTitleMatch.group(1)!);
    }

    final ogDescriptionMatch = ogDescriptionRegex.firstMatch(html);
    if (ogDescriptionMatch != null) {
      description = _decodeHtmlEntities(ogDescriptionMatch.group(1)!);
    }

    final ogImageMatch = ogImageRegex.firstMatch(html);
    if (ogImageMatch != null) {
      image = _resolveUrl(ogImageMatch.group(1)!, url);
    }

    final ogSiteNameMatch = ogSiteNameRegex.firstMatch(html);
    if (ogSiteNameMatch != null) {
      siteName = _decodeHtmlEntities(ogSiteNameMatch.group(1)!);
    }

    // Fallback to HTML title if no OG title
    if (title == null || title.isEmpty) {
      final htmlTitleMatch = htmlTitleRegex.firstMatch(html);
      if (htmlTitleMatch != null) {
        title = _decodeHtmlEntities(htmlTitleMatch.group(1)!);
      }
    }

    // Fallback to meta description if no OG description
    if (description == null || description.isEmpty) {
      final metaDescriptionMatch = metaDescriptionRegex.firstMatch(html);
      if (metaDescriptionMatch != null) {
        description = _decodeHtmlEntities(metaDescriptionMatch.group(1)!);
      }
    }

    // Extract favicon
    final faviconMatch = faviconRegex.firstMatch(html) ?? faviconRegex2.firstMatch(html);
    if (faviconMatch != null) {
      favicon = _resolveUrl(faviconMatch.group(1)!, url);
    } else {
      // Try default favicon location
      try {
        final uri = Uri.parse(url);
        favicon = '${uri.scheme}://${uri.host}/favicon.ico';
      } catch (e) {
        // Ignore favicon if URL parsing fails
      }
    }

    return OpenGraphData(
      url: url,
      title: title?.isNotEmpty == true ? title : null,
      description: description?.isNotEmpty == true ? description : null,
      image: image?.isNotEmpty == true ? image : null,
      siteName: siteName?.isNotEmpty == true ? siteName : null,
      favicon: favicon?.isNotEmpty == true ? favicon : null,
    );
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
    final Map<String, String> headers = {
      'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 14_7_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.2 Mobile/15E148 Safari/604.1',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.5',
      'Accept-Encoding': 'gzip, deflate, br',
      'DNT': '1',
      'Connection': 'keep-alive',
      'Upgrade-Insecure-Requests': '1',
    };

    // Add specific headers for different platforms
    if (url.contains('instagram.com')) {
      headers['X-Instagram-AJAX'] = '1';
      headers['X-Requested-With'] = 'XMLHttpRequest';
    } else if (url.contains('youtube.com') || url.contains('youtu.be')) {
      headers['X-YouTube-Client-Name'] = '1';
      headers['X-YouTube-Client-Version'] = '2.0';
    } else if (url.contains('twitter.com') || url.contains('x.com')) {
      headers['X-Twitter-Active-User'] = 'yes';
    } else if (url.contains('facebook.com')) {
      headers['Sec-Fetch-Site'] = 'none';
      headers['Sec-Fetch-Mode'] = 'navigate';
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

          final response = await http.get(
            Uri.parse(testUrl),
            headers: {
              'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 14_7_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.2 Mobile/15E148 Safari/604.1',
              'Accept': '*/*',
              'Accept-Language': 'en-US,en;q=0.9',
              'Accept-Encoding': 'gzip, deflate, br',
              'Cache-Control': 'no-cache',
              'Pragma': 'no-cache',
              'Sec-Fetch-Dest': 'document',
              'Sec-Fetch-Mode': 'navigate',
              'Sec-Fetch-Site': 'none',
              'Upgrade-Insecure-Requests': '1',
            },
          ).timeout(const Duration(seconds: 15));

          if (response.statusCode == 200) {
            debugPrint('✅ Successfully fetched Instagram page');
            final ogData = _parseInstagramContent(response.body, url);
            if (ogData.image != null) {
              debugPrint('✅ Found Instagram image: ${ogData.image}');
              return ogData;
            }
          }
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

    // Instagram-specific meta tags
    final instagramImageRegex = RegExp(r'<meta\s+property="og:image"\s+content="([^"]*)"', caseSensitive: false);
    final instagramVideoRegex = RegExp(r'<meta\s+property="og:video"\s+content="([^"]*)"', caseSensitive: false);
    final instagramTitleRegex = RegExp(r'<meta\s+property="og:title"\s+content="([^"]*)"', caseSensitive: false);
    final instagramDescRegex = RegExp(r'<meta\s+property="og:description"\s+content="([^"]*)"', caseSensitive: false);

    // Try to find image
    final imageMatch = instagramImageRegex.firstMatch(html);
    if (imageMatch != null) {
      image = imageMatch.group(1);
    }

    // If no image, try video thumbnail
    if (image == null) {
      final videoMatch = instagramVideoRegex.firstMatch(html);
      if (videoMatch != null) {
        // For video posts, Instagram often has a thumbnail
        final videoThumbRegex = RegExp(r'<meta\s+property="og:image"\s+content="([^"]*)"', caseSensitive: false);
        final thumbMatch = videoThumbRegex.firstMatch(html);
        if (thumbMatch != null) {
          image = thumbMatch.group(1);
        }
      }
    }

    // Try alternative image selectors
    if (image == null) {
      final altImageRegex = RegExp(r'"display_url":"([^"]*)"', caseSensitive: false);
      final altMatch = altImageRegex.firstMatch(html);
      if (altMatch != null) {
        image = altMatch.group(1)?.replaceAll(r'\u0026', '&');
      }
    }

    // Extract title
    final titleMatch = instagramTitleRegex.firstMatch(html);
    if (titleMatch != null) {
      title = _decodeHtmlEntities(titleMatch.group(1)!);
    }

    // Extract description
    final descMatch = instagramDescRegex.firstMatch(html);
    if (descMatch != null) {
      description = _decodeHtmlEntities(descMatch.group(1)!);
    }

    return OpenGraphData(
      url: originalUrl,
      title: title ?? 'Instagram Post',
      description: description,
      image: image,
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
}