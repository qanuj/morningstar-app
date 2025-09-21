import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/media_storage_service.dart';

/// Smart cached image widget that handles both regular images and SVG avatars
/// Uses hash-based URL caching to prevent re-downloading
class CachedMediaImage extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final String? clubId;
  final BorderRadius? borderRadius;
  final bool isAvatar; // Special handling for SVG avatars

  const CachedMediaImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.clubId,
    this.borderRadius,
    this.isAvatar = false,
  });

  @override
  State<CachedMediaImage> createState() => _CachedMediaImageState();
}

class _CachedMediaImageState extends State<CachedMediaImage> {
  String? _localPath;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadCachedImage();
  }

  @override
  void didUpdateWidget(CachedMediaImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _loadCachedImage();
    }
  }

  Future<void> _loadCachedImage() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _localPath = null;
    });

    try {
      // Get cached media path (downloads if not cached)
      final localPath = await MediaStorageService.getCachedMediaPath(
        widget.imageUrl,
      );

      if (!mounted) return;

      if (localPath != null && await File(localPath).exists()) {
        setState(() {
          _localPath = localPath;
          _isLoading = false;
        });
      } else {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading cached image: $e');
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  Widget _buildImageWidget() {
    if (_localPath == null) {
      return _buildErrorWidget();
    }

    final file = File(_localPath!);

    // Handle SVG avatars specially
    if (widget.isAvatar && _localPath!.toLowerCase().endsWith('.svg')) {
      return SvgPicture.file(
        file,
        width: widget.width,
        height: widget.height,
        fit: widget.fit ?? BoxFit.cover,
        placeholderBuilder: (context) => _buildPlaceholder(),
      );
    }

    // Handle regular images
    return Image.file(
      file,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      errorBuilder: (context, error, stackTrace) {
        debugPrint('❌ Error displaying cached image: $error');
        return _buildErrorWidget();
      },
    );
  }

  Widget _buildPlaceholder() {
    if (widget.placeholder != null) {
      return widget.placeholder!;
    }

    // Default placeholder based on type
    if (widget.isAvatar) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: widget.borderRadius,
        ),
        child: Icon(
          Icons.person,
          size: (widget.width ?? 40) * 0.6,
          color: Colors.grey[600],
        ),
      );
    }

    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: widget.borderRadius,
      ),
      child: Icon(
        Icons.image,
        size: (widget.width ?? 100) * 0.3,
        color: Colors.grey[600],
      ),
    );
  }

  Widget _buildErrorWidget() {
    if (widget.errorWidget != null) {
      return widget.errorWidget!;
    }

    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.red[100],
        borderRadius: widget.borderRadius,
      ),
      child: Icon(
        Icons.error_outline,
        size: (widget.width ?? 100) * 0.3,
        color: Colors.red[400],
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: widget.borderRadius,
      ),
      child: Center(
        child: SizedBox(
          width: (widget.width ?? 100) * 0.2,
          height: (widget.width ?? 100) * 0.2,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[400]!),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget child;

    if (_isLoading) {
      child = _buildLoadingWidget();
    } else if (_hasError) {
      child = _buildErrorWidget();
    } else {
      child = _buildImageWidget();
    }

    // Apply border radius if specified
    if (widget.borderRadius != null) {
      child = ClipRRect(borderRadius: widget.borderRadius!, child: child);
    }

    return child;
  }
}

/// Specialized widget for profile avatars with SVG support
class CachedAvatarImage extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final String? fallbackText;

  const CachedAvatarImage({
    super.key,
    this.imageUrl,
    this.size = 40,
    this.fallbackText,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildFallbackAvatar();
    }

    return CachedMediaImage(
      imageUrl: imageUrl!,
      width: size,
      height: size,
      isAvatar: true,
      borderRadius: BorderRadius.circular(size / 2),
      errorWidget: _buildFallbackAvatar(),
      placeholder: _buildLoadingAvatar(),
    );
  }

  Widget _buildFallbackAvatar() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey[400],
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          fallbackText?.isNotEmpty == true
              ? fallbackText!.substring(0, 1).toUpperCase()
              : '?',
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingAvatar() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        shape: BoxShape.circle,
      ),
      child: Center(
        child: SizedBox(
          width: size * 0.4,
          height: size * 0.4,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[400]!),
          ),
        ),
      ),
    );
  }
}
