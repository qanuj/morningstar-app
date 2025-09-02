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

      // Fetch the webpage
      final response = await http.get(
        Uri.parse(fullUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (compatible; DuggyBot/1.0; +https://duggy.app)',
        },
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

  /// Clears the cache (useful for testing or memory management)
  static void clearCache() {
    _cache.clear();
  }
}