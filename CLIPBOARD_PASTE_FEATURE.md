# Clipboard Image Paste Feature

## Overview
The message input field now supports pasting images directly from the clipboard, making it easy for users to share screenshots, photos, and other images copied from various sources.

## How It Works

### For Users
1. **Copy an image** from any source (Photos app, Safari, Files app, etc.)
2. **Focus the message input field** - you'll see a blue "Paste" button appear in the top-right corner when clipboard content is detected
3. **Tap the Paste button** or use **Cmd+V** (iOS) / **Ctrl+V** (Android) to paste the image
4. The image will be automatically processed and attached to your message

### Visual Indicators
- **Paste Button**: A blue floating button appears in the message input when clipboard content is available
- **Success Notification**: A green snackbar confirms successful paste operations
- **Error Handling**: Clear error messages for unsupported formats or failed operations

### Supported Sources
- ✅ Photos app (images copied to clipboard)
- ✅ Safari (images copied from web pages)
- ✅ Files app (images copied from local storage)
- ✅ Screenshots (automatically copied to clipboard)
- ✅ Other apps that copy images to system clipboard

### Technical Details

#### Platform Integration
- **iOS**: Uses `UIPasteboard` via method channel for native clipboard access
- **Android**: Uses `ClipboardManager` via method channel for native clipboard access
- **Cross-platform**: Flutter's `Clipboard.getData()` for text content

#### Image Processing
- Automatic format detection and validation
- Conversion to PNG format for consistency
- Temporary file storage with unique naming
- Error handling for corrupted or invalid image data

#### Performance Optimizations
- Lazy clipboard checking (only when text field gains focus)
- Efficient image processing using the `image` package
- Automatic cleanup of temporary files

## Code Architecture

### Key Components
1. **PasteableTextField**: Enhanced text field with clipboard integration
2. **Platform Channels**: Native iOS/Android clipboard access
3. **Image Processing**: Format conversion and validation
4. **UI Feedback**: Visual indicators and success/error notifications

### Integration Points
- Extends `MentionableTextField` to preserve mention functionality
- Integrates with existing message attachment system
- Compatible with keyboard shortcuts and accessibility features

## Troubleshooting

### Common Issues
1. **Paste button not appearing**: 
   - Ensure an image is actually copied to clipboard
   - Try tapping the text field to refresh clipboard status

2. **Paste operation fails**:
   - Check if the copied content is a valid image format
   - Try copying the image again from the source

3. **Image quality issues**:
   - The system automatically converts to PNG for compatibility
   - Original image quality is preserved during conversion

### Debug Logging
Enable debug logs to troubleshoot issues:
```dart
print('📋 Clipboard content check result: $_hasClipboardContent');
print('📋 Image data size: ${imageData.length} bytes');
```

## Future Enhancements
- Support for multiple image paste
- Preview thumbnails before sending
- Advanced image compression options
- Integration with drag-and-drop functionality