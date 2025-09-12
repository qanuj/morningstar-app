import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../models/social_post.dart';
import '../../widgets/svg_avatar.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SocialFeedScreen extends StatefulWidget {
  const SocialFeedScreen({super.key});

  @override
  SocialFeedScreenState createState() => SocialFeedScreenState();
}

class SocialFeedScreenState extends State<SocialFeedScreen> {
  final ScrollController _scrollController = ScrollController();
  List<SocialPost> _posts = [];
  bool _isLoading = false;
  bool _hasMorePosts = true;

  @override
  void initState() {
    super.initState();
    _loadInitialPosts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _loadInitialPosts() {
    setState(() {
      _posts = _generateDummyPosts(10);
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      _loadMorePosts();
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoading || !_hasMorePosts) return;

    setState(() => _isLoading = true);

    // Simulate API delay
    await Future.delayed(Duration(milliseconds: 800));

    setState(() {
      _posts.addAll(_generateDummyPosts(5));
      _isLoading = false;
      
      // Stop loading more after 50 posts for demo
      if (_posts.length > 50) {
        _hasMorePosts = false;
      }
    });
  }

  Future<void> _onRefresh() async {
    await Future.delayed(Duration(milliseconds: 1000));
    setState(() {
      _posts = _generateDummyPosts(10);
      _hasMorePosts = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _SocialFeedAppBar(),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: ListView.builder(
          controller: _scrollController,
          itemCount: _posts.length + (_isLoading ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == _posts.length) {
              return _buildLoadingIndicator();
            }
            return _PostCard(post: _posts[index]);
          },
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: EdgeInsets.all(16),
      alignment: Alignment.center,
      child: CircularProgressIndicator(
        color: Theme.of(context).primaryColor,
      ),
    );
  }

  List<SocialPost> _generateDummyPosts(int count) {
    final baseIndex = _posts.length;
    return List.generate(count, (index) {
      final postIndex = baseIndex + index;
      return SocialPost(
        id: 'post_$postIndex',
        userId: 'user_${(postIndex % 8) + 1}',
        username: _getDummyUsername(postIndex % 8),
        userAvatar: _getDummyAvatar(postIndex % 8),
        timeAgo: _getDummyTimeAgo(postIndex),
        caption: _getDummyCaption(postIndex),
        imageUrl: _getDummyImageUrl(postIndex),
        videoUrl: postIndex % 7 == 0 ? _getDummyVideoUrl(postIndex) : null,
        likes: _getDummyLikes(postIndex),
        comments: _getDummyComments(postIndex),
        shares: _getDummyShares(postIndex),
        isLiked: false,
      );
    });
  }

  String _getDummyUsername(int index) {
    final names = [
      'Rajesh Sharma', 'Priya Patel', 'Arjun Singh', 'Meera Gupta',
      'Vikram Kumar', 'Kavya Reddy', 'Rohit Verma', 'Sneha Jain'
    ];
    return names[index % names.length];
  }

  String? _getDummyAvatar(int index) {
    if (index % 3 == 0) return null; // Some users without avatars
    return 'https://i.pravatar.cc/150?u=user_$index';
  }

  String _getDummyTimeAgo(int index) {
    final times = [
      '2m ago', '15m ago', '1h ago', '2h ago', '4h ago', 
      '1d ago', '2d ago', '1w ago'
    ];
    return times[index % times.length];
  }

  String _getDummyCaption(int index) {
    final captions = [
      'Great match today! Our team showed amazing spirit 🏏 #TeamWork #Cricket',
      'Beautiful sunset after practice session 🌅 Perfect end to a perfect day!',
      'Celebrating our victory with the team! 🎉 Hard work pays off #Victory',
      'New cricket gear arrived! Ready for the season 🏏⚡ #CricketLife',
      'Team bonding session at the club house 🤝 Building stronger connections',
      'Morning workout session completed 💪 Fitness is the key to performance',
      'Match preparations in full swing! 🔥 Bring it on opponents #Ready',
      'Club anniversary celebration! 🎂 10 years of amazing cricket memories',
      'Young talent training session 👨‍🏫 Future stars in the making',
      'Weekend tournament highlights! What an incredible match 🏆',
    ];
    return captions[index % captions.length];
  }

  String _getDummyImageUrl(int index) {
    final images = [
      'https://picsum.photos/400/300?random=$index',
      'https://picsum.photos/400/400?random=${index + 100}',
      'https://picsum.photos/400/250?random=${index + 200}',
    ];
    return images[index % images.length];
  }

  String _getDummyVideoUrl(int index) {
    return 'https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4';
  }

  int _getDummyLikes(int index) {
    return (index * 3 + 5) % 50 + 1;
  }

  int _getDummyComments(int index) {
    return (index * 2 + 1) % 15;
  }

  int _getDummyShares(int index) {
    return (index + 1) % 8;
  }
}

class _SocialFeedAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _SocialFeedAppBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColorDark,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withOpacity(0.3),
            offset: Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          width: 40,
          height: 40,
          padding: EdgeInsets.all(8),
          child: SvgPicture.asset(
            'assets/images/duggy_logo.svg',
            width: 24,
            height: 24,
            fit: BoxFit.contain,
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Duggy',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              'Social Feed',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: Colors.white),
            onPressed: () {
              // TODO: Implement search
            },
          ),
          IconButton(
            icon: Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {
              // TODO: Implement notifications
            },
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
}

class _PostCard extends StatefulWidget {
  final SocialPost post;

  const _PostCard({required this.post});

  @override
  _PostCardState createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> with SingleTickerProviderStateMixin {
  late bool isLiked;
  late int likes;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    isLiked = widget.post.isLiked;
    likes = widget.post.likes;
    
    _animationController = AnimationController(
      duration: Duration(milliseconds: 200),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleLike() {
    setState(() {
      isLiked = !isLiked;
      likes += isLiked ? 1 : -1;
    });
    
    if (isLiked) {
      _animationController.forward().then((_) {
        _animationController.reverse();
      });
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      color: Theme.of(context).cardColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User header
          _buildUserHeader(),
          
          // Post content (image/video)
          _buildPostContent(),
          
          // Action buttons (like, comment, share)
          _buildActionButtons(),
          
          // Post stats
          _buildPostStats(),
          
          // Caption
          _buildCaption(),
          
          // Comments preview
          _buildCommentsPreview(),
          
          SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildUserHeader() {
    return Padding(
      padding: EdgeInsets.all(12),
      child: Row(
        children: [
          SVGAvatar.small(
            imageUrl: widget.post.userAvatar,
            backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            iconColor: Theme.of(context).colorScheme.primary,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.post.username,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Theme.of(context).textTheme.titleLarge?.color,
                  ),
                ),
                Text(
                  widget.post.timeAgo,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.more_vert),
            onPressed: () {
              // TODO: Show post options
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPostContent() {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxHeight: 400,
      ),
      child: widget.post.videoUrl != null 
        ? _buildVideoPlayer()
        : _buildImageContent(),
    );
  }

  Widget _buildImageContent() {
    return Image.network(
      widget.post.imageUrl,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          height: 200,
          color: Colors.grey[300],
          child: Icon(
            Icons.image_not_supported,
            size: 50,
            color: Colors.grey[600],
          ),
        );
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          height: 200,
          child: Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / 
                    loadingProgress.expectedTotalBytes!
                  : null,
            ),
          ),
        );
      },
    );
  }

  Widget _buildVideoPlayer() {
    return Container(
      height: 250,
      color: Colors.black,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.grey[900],
          ),
          Icon(
            Icons.play_circle_fill,
            size: 64,
            color: Colors.white.withOpacity(0.8),
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '0:30',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Like button
          AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: IconButton(
                  icon: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.red : Theme.of(context).iconTheme.color,
                  ),
                  onPressed: _toggleLike,
                ),
              );
            },
          ),
          
          // Comment button
          IconButton(
            icon: Icon(Icons.chat_bubble_outline),
            onPressed: () {
              _showCommentsBottomSheet();
            },
          ),
          
          // Share button
          IconButton(
            icon: Icon(Icons.share_outlined),
            onPressed: () {
              _showShareOptions();
            },
          ),
          
          Spacer(),
          
          // Bookmark button
          IconButton(
            icon: Icon(Icons.bookmark_border),
            onPressed: () {
              // TODO: Implement bookmark
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPostStats() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          if (likes > 0) ...[
            Text(
              '$likes ${likes == 1 ? 'like' : 'likes'}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
          
          if (widget.post.comments > 0) ...[
            if (likes > 0) SizedBox(width: 16),
            GestureDetector(
              onTap: _showCommentsBottomSheet,
              child: Text(
                '${widget.post.comments} ${widget.post.comments == 1 ? 'comment' : 'comments'}',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  fontSize: 14,
                ),
              ),
            ),
          ],
          
          if (widget.post.shares > 0) ...[
            if (likes > 0 || widget.post.comments > 0) SizedBox(width: 16),
            Text(
              '${widget.post.shares} ${widget.post.shares == 1 ? 'share' : 'shares'}',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall?.color,
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCaption() {
    return Padding(
      padding: EdgeInsets.all(12),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '${widget.post.username} ',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ),
            TextSpan(
              text: widget.post.caption,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentsPreview() {
    if (widget.post.comments == 0) return SizedBox.shrink();
    
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12),
      child: GestureDetector(
        onTap: _showCommentsBottomSheet,
        child: Text(
          'View all ${widget.post.comments} comments',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodySmall?.color,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  void _showCommentsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CommentsBottomSheet(post: widget.post),
    );
  }

  void _showShareOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => _ShareBottomSheet(post: widget.post),
    );
  }
}

class _CommentsBottomSheet extends StatelessWidget {
  final SocialPost post;

  const _CommentsBottomSheet({required this.post});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Comments',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          
          Divider(),
          
          // Comments list
          Expanded(
            child: ListView.builder(
              itemCount: 5, // Dummy comments
              itemBuilder: (context, index) {
                return _buildCommentItem(index);
              },
            ),
          ),
          
          // Comment input
          _buildCommentInput(context),
        ],
      ),
    );
  }

  Widget _buildCommentItem(int index) {
    final comments = [
      'Great shot! 🏏',
      'Amazing game yesterday!',
      'When is the next match?',
      'Love the team spirit 💪',
      'Congratulations on the win!'
    ];
    
    final usernames = [
      'John Doe', 'Sarah Smith', 'Mike Johnson', 'Emma Wilson', 'David Brown'
    ];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SVGAvatar.small(
            imageUrl: 'https://i.pravatar.cc/150?u=comment_$index',
            backgroundColor: Colors.grey[300],
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${usernames[index]} ',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.black,
                        ),
                      ),
                      TextSpan(
                        text: comments[index],
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${index + 1}h',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(width: 16),
                    GestureDetector(
                      onTap: () {
                        // TODO: Like comment
                      },
                      child: Text(
                        'Like',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    GestureDetector(
                      onTap: () {
                        // TODO: Reply to comment
                      },
                      child: Text(
                        'Reply',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.favorite_border, size: 18),
            onPressed: () {
              // TODO: Like comment
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Row(
        children: [
          Consumer<UserProvider>(
            builder: (context, userProvider, child) {
              return SVGAvatar.small(
                imageUrl: userProvider.user?.profilePicture,
                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                iconColor: Theme.of(context).colorScheme.primary,
              );
            },
          ),
          SizedBox(width: 12),
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Add a comment...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ),
          SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.send, color: Theme.of(context).primaryColor),
            onPressed: () {
              // TODO: Send comment
            },
          ),
        ],
      ),
    );
  }
}

class _ShareBottomSheet extends StatelessWidget {
  final SocialPost post;

  const _ShareBottomSheet({required this.post});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          Text(
            'Share Post',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          
          SizedBox(height: 20),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildShareOption(
                icon: Icons.copy,
                label: 'Copy Link',
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Copy link to clipboard
                },
              ),
              _buildShareOption(
                icon: Icons.message,
                label: 'Message',
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Share via message
                },
              ),
              _buildShareOption(
                icon: Icons.share,
                label: 'More',
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Show system share sheet
                },
              ),
            ],
          ),
          
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildShareOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 24),
          ),
          SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}