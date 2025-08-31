import 'package:flutter/material.dart';

class GifPickerWidget extends StatefulWidget {
  final Function(String gifUrl, String title) onGifSelected;

  const GifPickerWidget({
    Key? key,
    required this.onGifSelected,
  }) : super(key: key);

  @override
  _GifPickerWidgetState createState() => _GifPickerWidgetState();
}

class _GifPickerWidgetState extends State<GifPickerWidget> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  List<Map<String, String>> _gifs = [];

  @override
  void initState() {
    super.initState();
    _loadTrendingGifs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadTrendingGifs() {
    setState(() {
      _isLoading = true;
    });

    // TODO: Implement actual GIF API integration (Giphy, Tenor, etc.)
    // For now, use placeholder data
    Future.delayed(Duration(seconds: 1), () {
      setState(() {
        _isLoading = false;
        _gifs = [
          {
            'url': 'https://media.giphy.com/media/26BRrSvJUa0crqw4E/giphy.gif',
            'title': 'Hello',
          },
          {
            'url': 'https://media.giphy.com/media/3o7abKhOpu0NwenH3O/giphy.gif',
            'title': 'Thanks',
          },
          {
            'url': 'https://media.giphy.com/media/l0HlvtIPzPdt2usKs/giphy.gif',
            'title': 'Celebration',
          },
          {
            'url': 'https://media.giphy.com/media/26BROrSHlmyzzHf3i/giphy.gif',
            'title': 'Thumbs Up',
          },
          {
            'url': 'https://media.giphy.com/media/3o6Zt4HU9uwXmXSAuI/giphy.gif',
            'title': 'OK',
          },
          {
            'url': 'https://media.giphy.com/media/l0HlPystfePnAI3G8/giphy.gif',
            'title': 'Applause',
          },
        ];
      });
    });
  }

  void _searchGifs(String query) {
    if (query.trim().isEmpty) {
      _loadTrendingGifs();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // TODO: Implement actual GIF search
    // For now, filter existing gifs
    Future.delayed(Duration(milliseconds: 500), () {
      setState(() {
        _isLoading = false;
        _gifs = _gifs
            .where((gif) => gif['title']!.toLowerCase().contains(query.toLowerCase()))
            .toList();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Text(
                'Send GIF',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close),
              ),
            ],
          ),
          SizedBox(height: 16),

          // Search bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search GIFs...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Theme.of(context).cardColor,
            ),
            onSubmitted: _searchGifs,
            onChanged: (value) {
              // Debounce search
              Future.delayed(Duration(milliseconds: 500), () {
                if (_searchController.text == value) {
                  _searchGifs(value);
                }
              });
            },
          ),
          SizedBox(height: 16),

          // GIF Grid
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading GIFs...'),
                      ],
                    ),
                  )
                : _gifs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.gif_box,
                              size: 64,
                              color: Theme.of(context).textTheme.bodySmall?.color,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No GIFs found',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).textTheme.titleLarge?.color,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Try searching for something else',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Theme.of(context).textTheme.bodyMedium?.color,
                              ),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 1,
                        ),
                        itemCount: _gifs.length,
                        itemBuilder: (context, index) {
                          final gif = _gifs[index];
                          return GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              widget.onGifSelected(gif['url']!, gif['title']!);
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Theme.of(context).shadowColor.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Stack(
                                  children: [
                                    Container(
                                      width: double.infinity,
                                      height: double.infinity,
                                      color: Colors.grey[300],
                                      child: Image.network(
                                        gif['url']!,
                                        fit: BoxFit.cover,
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null) return child;
                                          return Center(
                                            child: CircularProgressIndicator(
                                              value: loadingProgress.expectedTotalBytes != null
                                                  ? loadingProgress.cumulativeBytesLoaded /
                                                      loadingProgress.expectedTotalBytes!
                                                  : null,
                                            ),
                                          );
                                        },
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          color: Colors.grey[300],
                                          child: Icon(
                                            Icons.broken_image,
                                            size: 48,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                    ),
                                    
                                    // Overlay with title
                                    Positioned(
                                      bottom: 0,
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.transparent,
                                              Colors.black.withOpacity(0.7),
                                            ],
                                          ),
                                        ),
                                        child: Text(
                                          gif['title']!,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}