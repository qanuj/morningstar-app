import 'package:flutter/material.dart';

class EmojiPickerWidget extends StatefulWidget {
  final Function(String) onEmojiSelected;
  
  const EmojiPickerWidget({
    Key? key,
    required this.onEmojiSelected,
  }) : super(key: key);

  @override
  _EmojiPickerWidgetState createState() => _EmojiPickerWidgetState();
}

class _EmojiPickerWidgetState extends State<EmojiPickerWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Emoji categories
  final Map<String, List<String>> emojiCategories = {
    'Smileys': [
      '😀', '😃', '😄', '😁', '😆', '😅', '🤣', '😂', '🙂', '🙃',
      '😉', '😊', '😇', '🥰', '😍', '🤩', '😘', '😗', '😚', '😙',
      '😋', '😛', '😜', '🤪', '😝', '🤑', '🤗', '🤭', '🤫', '🤔',
      '🤐', '🤨', '😐', '😑', '😶', '😏', '😒', '🙄', '😬', '🤥',
      '😔', '😪', '🤤', '😴', '😷', '🤒', '🤕', '🤢', '🤮', '🤧',
      '🥵', '🥶', '🥴', '😵', '🤯', '🤠', '🥳', '😎', '🤓', '🧐'
    ],
    'People': [
      '👶', '🧒', '👦', '👧', '🧑', '👨', '👩', '🧓', '👴', '👵',
      '👤', '👥', '👨‍💼', '👩‍💼', '👨‍🎓', '👩‍🎓', '👨‍⚕️', '👩‍⚕️', '👨‍🍳', '👩‍🍳',
      '👨‍💻', '👩‍💻', '👨‍🎤', '👩‍🎤', '👨‍🎨', '👩‍🎨', '👨‍✈️', '👩‍✈️', '👨‍🚀', '👩‍🚀',
      '👮‍♂️', '👮‍♀️', '🕵️‍♂️', '🕵️‍♀️', '💂‍♂️', '💂‍♀️', '👷‍♂️', '👷‍♀️', '🤴', '👸'
    ],
    'Animals': [
      '🐶', '🐱', '🐭', '🐹', '🐰', '🦊', '🐻', '🐼', '🐨', '🐯',
      '🦁', '🐮', '🐷', '🐽', '🐸', '🐵', '🙈', '🙉', '🙊', '🐒',
      '🐔', '🐧', '🐦', '🐤', '🐣', '🐥', '🦆', '🦅', '🦉', '🦇',
      '🐺', '🐗', '🐴', '🦄', '🐝', '🐛', '🦋', '🐌', '🐞', '🐜',
      '🦟', '🦗', '🕷️', '🦂', '🐢', '🐍', '🦎', '🦖', '🦕', '🐙'
    ],
    'Food': [
      '🍎', '🍊', '🍋', '🍌', '🍉', '🍇', '🍓', '🫐', '🍈', '🍒',
      '🍑', '🥭', '🍍', '🥥', '🥝', '🍅', '🍆', '🥑', '🥦', '🥬',
      '🥒', '🌶️', '🌽', '🥕', '🧄', '🧅', '🥔', '🍠', '🥐', '🥖',
      '🍞', '🥨', '🥯', '🧇', '🥞', '🍳', '🥚', '🧀', '🥓', '🥩',
      '🍗', '🍖', '🌭', '🍔', '🍟', '🍕', '🌮', '🌯', '🥙', '🥪'
    ],
    'Sports': [
      '⚽', '🏀', '🏈', '⚾', '🎾', '🏐', '🏉', '🎱', '🏓', '🏸',
      '🏒', '🏑', '🥍', '🏏', '🥅', '⛳', '🏹', '🎣', '🥊', '🥋',
      '🎽', '🛹', '🛷', '⛸️', '🥌', '🎿', '⛷️', '🏂', '🏋️‍♂️', '🏋️‍♀️',
      '🤼‍♂️', '🤼‍♀️', '🤸‍♂️', '🤸‍♀️', '⛹️‍♂️', '⛹️‍♀️', '🤺', '🤾‍♂️', '🤾‍♀️', '🏌️‍♂️'
    ],
    'Objects': [
      '📱', '💻', '⌨️', '🖥️', '🖨️', '🖱️', '🖲️', '🕹️', '🗜️', '💽',
      '💾', '💿', '📀', '📼', '📷', '📸', '📹', '🎥', '📽️', '🎞️',
      '📞', '☎️', '📟', '📠', '📺', '📻', '🎙️', '🎚️', '🎛️', '⏰',
      '🕰️', '⏱️', '⏲️', '⏰', '🕛', '🕐', '🕑', '🕒', '🕓', '🕔'
    ],
    'Hearts': [
      '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍', '🤎', '💔',
      '❣️', '💕', '💞', '💓', '💗', '💖', '💘', '💝', '💟', '💌',
      '💋', '💍', '💎', '💐', '🌹', '🌺', '🌻', '🌷', '🌸', '💒'
    ],
    'Flags': [
      '🏳️', '🏴', '🏁', '🚩', '🏳️‍🌈', '🏳️‍⚧️', '🇺🇳', '🇦🇫', '🇦🇱', '🇩🇿',
      '🇦🇸', '🇦🇩', '🇦🇴', '🇦🇮', '🇦🇶', '🇦🇬', '🇦🇷', '🇦🇲', '🇦🇼', '🇦🇺'
    ],
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: emojiCategories.length,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      child: Column(
        children: [
          Container(
            color: Theme.of(context).cardColor,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Theme.of(context).textTheme.bodySmall?.color,
              indicatorColor: Theme.of(context).primaryColor,
              tabs: emojiCategories.keys.map((category) {
                return Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_getCategoryIcon(category), style: TextStyle(fontSize: 16)),
                      SizedBox(width: 4),
                      Text(category, style: TextStyle(fontSize: 12)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: emojiCategories.entries.map((entry) {
                return _buildEmojiGrid(entry.value);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiGrid(List<String> emojis) {
    return GridView.builder(
      padding: EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: emojis.length,
      itemBuilder: (context, index) {
        final emoji = emojis[index];
        return GestureDetector(
          onTap: () => widget.onEmojiSelected(emoji),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).dividerColor,
                width: 0.5,
              ),
            ),
            child: Center(
              child: Text(
                emoji,
                style: TextStyle(fontSize: 24),
              ),
            ),
          ),
        );
      },
    );
  }

  String _getCategoryIcon(String category) {
    switch (category) {
      case 'Smileys':
        return '😀';
      case 'People':
        return '👤';
      case 'Animals':
        return '🐶';
      case 'Food':
        return '🍎';
      case 'Sports':
        return '⚽';
      case 'Objects':
        return '📱';
      case 'Hearts':
        return '❤️';
      case 'Flags':
        return '🏳️';
      default:
        return '😀';
    }
  }
}

// GIF Picker Widget
class GifPickerWidget extends StatefulWidget {
  final Function(String, String) onGifSelected; // URL and title
  
  const GifPickerWidget({
    Key? key,
    required this.onGifSelected,
  }) : super(key: key);

  @override
  _GifPickerWidgetState createState() => _GifPickerWidgetState();
}

class _GifPickerWidgetState extends State<GifPickerWidget> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, String>> searchResults = [];
  bool isLoading = false;

  // Sample GIF data - in real app, this would come from GIPHY API
  final List<Map<String, String>> trendingGifs = [
    {
      'url': 'https://media.giphy.com/media/3o7aD2saalBwwftBIY/giphy.gif',
      'title': 'Happy Dance',
      'thumbnail': 'https://media.giphy.com/media/3o7aD2saalBwwftBIY/200w.gif',
    },
    {
      'url': 'https://media.giphy.com/media/l0HlBO7eyXzSZkJri/giphy.gif',
      'title': 'Celebration',
      'thumbnail': 'https://media.giphy.com/media/l0HlBO7eyXzSZkJri/200w.gif',
    },
    {
      'url': 'https://media.giphy.com/media/26tn33aiTi1jkl6H6/giphy.gif',
      'title': 'Cricket',
      'thumbnail': 'https://media.giphy.com/media/26tn33aiTi1jkl6H6/200w.gif',
    },
    {
      'url': 'https://media.giphy.com/media/xT5LMHxhOfscxPfIfm/giphy.gif',
      'title': 'Excited',
      'thumbnail': 'https://media.giphy.com/media/xT5LMHxhOfscxPfIfm/200w.gif',
    },
    {
      'url': 'https://media.giphy.com/media/26BRrSvJUa0crqw4E/giphy.gif',
      'title': 'Thumbs Up',
      'thumbnail': 'https://media.giphy.com/media/26BRrSvJUa0crqw4E/200w.gif',
    },
    {
      'url': 'https://media.giphy.com/media/11sBLVxNs7v6WA/giphy.gif',
      'title': 'Applause',
      'thumbnail': 'https://media.giphy.com/media/11sBLVxNs7v6WA/200w.gif',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor,
                ),
              ),
            ),
            child: Column(
              children: [
                Text(
                  'Send GIF',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search for GIFs...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Theme.of(context).scaffoldBackgroundColor,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  onSubmitted: (query) => _searchGifs(query),
                ),
              ],
            ),
          ),
          
          // GIF Grid
          Expanded(
            child: _buildGifGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildGifGrid() {
    final gifs = searchResults.isNotEmpty ? searchResults : trendingGifs;
    
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    
    return GridView.builder(
      padding: EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: gifs.length,
      itemBuilder: (context, index) {
        final gif = gifs[index];
        return GestureDetector(
          onTap: () {
            widget.onGifSelected(gif['url']!, gif['title']!);
            Navigator.pop(context);
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).dividerColor,
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  Image.network(
                    gif['thumbnail']!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
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
                        Icons.gif_box,
                        size: 40,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 4,
                    left: 4,
                    right: 4,
                    child: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        gif['title']!,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
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
    );
  }

  void _searchGifs(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        searchResults.clear();
      });
      return;
    }
    
    setState(() {
      isLoading = true;
    });
    
    // TODO: Implement actual GIPHY API search
    // For now, just show placeholder
    await Future.delayed(Duration(seconds: 1));
    
    setState(() {
      isLoading = false;
      searchResults = trendingGifs.where((gif) => 
        gif['title']!.toLowerCase().contains(query.toLowerCase())
      ).toList();
    });
  }
}