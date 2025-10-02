import 'package:duggy/services/ogp/base_ogp_data_parser.dart';
import 'package:duggy/services/ogp/ogp_data_extract_base.dart';
import 'package:duggy/services/ogp/ogp_data_parser.dart';
import 'package:html/dom.dart';
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
  static final Map<String, OpenGraphData> _cache = {};

  /// Fetches Open Graph metadata for a given URL
  static Future<OpenGraphData> fetchMetadata(String url) async {
    try {
      // Check cache first
      if (_cache.containsKey(url)) {
        return _cache[url]!;
      }

      final http.Response response = await http.get(Uri.parse(url));
      final Document? document = OgpDataExtract.toDocument(response);
      final OgpData ogpData = OgpDataParser(document).parse();
      final ogData = OpenGraphData(
        url: ogpData.url ?? url,
        title: ogpData.title,
        description: ogpData.description,
        image: ogpData.image,
        siteName: ogpData.siteName,
        favicon: _createDefaultFavicon(url),
      );
      // Cache the result
      _cache[url] = ogData;

      return ogData;
    } catch (e) {
      debugPrint('Error fetching Open Graph data for $url: $e');
      return _empty(url);
    }
  }

  /// Regex fallback parsing when HTML parsing fails
  static OpenGraphData _empty(String url) {
    return OpenGraphData(url: url, favicon: _createDefaultFavicon(url));
  }

  /// Creates a default favicon URL
  static String? _createDefaultFavicon(String url) {
    try {
      final uri = Uri.parse(url);
      return '${uri.scheme}://${uri.host}/favicon.ico';
    } catch (e) {
      return null;
    }
  }

  /// Clears the cache (useful for testing or memory management)
  static void clearCache() {
    _cache.clear();
  }
}
