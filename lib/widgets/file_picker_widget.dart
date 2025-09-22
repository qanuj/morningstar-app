import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class FilePickerWidget extends StatefulWidget {
  final Function(File, String) onFileSelected; // File and display name
  final List<String> allowedExtensions;
  final int maxFileSizeMB;
  
  const FilePickerWidget({
    Key? key,
    required this.onFileSelected,
    this.allowedExtensions = const ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'zip', 'rar'],
    this.maxFileSizeMB = 50,
  }) : super(key: key);

  @override
  _FilePickerWidgetState createState() => _FilePickerWidgetState();
}

class _FilePickerWidgetState extends State<FilePickerWidget> {
  File? selectedFile;
  String? fileName;
  String? fileSize;
  String? fileType;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Select Document',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 20),
          
          if (selectedFile != null) ...[
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).primaryColor.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getFileIcon(fileName ?? ''),
                      color: Theme.of(context).primaryColor,
                      size: 32,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fileName ?? 'Unknown file',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Text(
                          '${fileSize ?? ''} • ${fileType?.toUpperCase() ?? ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _removeFile,
                    icon: Icon(
                      Icons.close,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
          ],
          
          // File type options
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildFileTypeOption(
                icon: Icons.picture_as_pdf,
                label: 'PDF',
                color: Colors.red,
                extensions: ['pdf'],
              ),
              _buildFileTypeOption(
                icon: Icons.description,
                label: 'Document',
                color: Colors.blue,
                extensions: ['doc', 'docx', 'txt'],
              ),
              _buildFileTypeOption(
                icon: Icons.table_chart,
                label: 'Spreadsheet',
                color: Colors.green,
                extensions: ['xls', 'xlsx', 'csv'],
              ),
              _buildFileTypeOption(
                icon: Icons.slideshow,
                label: 'Presentation',
                color: Colors.orange,
                extensions: ['ppt', 'pptx'],
              ),
              _buildFileTypeOption(
                icon: Icons.archive,
                label: 'Archive',
                color: Colors.purple,
                extensions: ['zip', 'rar', '7z'],
              ),
              _buildFileTypeOption(
                icon: Icons.insert_drive_file,
                label: 'All Files',
                color: Colors.grey,
                extensions: widget.allowedExtensions,
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
          if (selectedFile != null) ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onFileSelected(selectedFile!, fileName ?? 'Document');
                      Navigator.pop(context);
                    },
                    child: Text('Send File'),
                  ),
                ),
              ],
            ),
          ],
          
          SizedBox(height: 8),
          
          Text(
            'Maximum file size: ${widget.maxFileSizeMB}MB',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileTypeOption({
    required IconData icon,
    required String label,
    required Color color,
    required List<String> extensions,
  }) {
    return GestureDetector(
      onTap: () => _pickFile(extensions),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }

  void _pickFile(List<String> extensions) async {
    try {
      // Use file_picker package - no storage permissions needed
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: extensions,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        PlatformFile file = result.files.first;
        File selectedFileObj = File(file.path!);

        // Check file size
        int fileSizeBytes = await selectedFileObj.length();
        double fileSizeMB = fileSizeBytes / (1024 * 1024);

        if (fileSizeMB > widget.maxFileSizeMB) {
          _showError('File size exceeds ${widget.maxFileSizeMB}MB limit');
          return;
        }

        setState(() {
          selectedFile = selectedFileObj;
          fileName = file.name;
          fileSize = _formatFileSize(fileSizeBytes);
          fileType = file.extension;
        });
      }
    } catch (e) {
      _showError('Failed to pick file: $e');
    }
  }

  void _removeFile() {
    setState(() {
      selectedFile = null;
      fileName = null;
      fileSize = null;
      fileType = null;
    });
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  IconData _getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
      case 'csv':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'txt':
        return Icons.text_snippet;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.archive;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'mp4':
      case 'avi':
      case 'mov':
        return Icons.video_file;
      case 'mp3':
      case 'wav':
      case 'aac':
        return Icons.audio_file;
      default:
        return Icons.insert_drive_file;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }
}

// Document Viewer Widget
class DocumentViewerWidget extends StatelessWidget {
  final String documentUrl;
  final String documentName;
  final String? documentSize;

  const DocumentViewerWidget({
    Key? key,
    required this.documentUrl,
    required this.documentName,
    this.documentSize,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(documentName),
        actions: [
          IconButton(
            icon: Icon(Icons.download),
            onPressed: () => _downloadDocument(),
          ),
          IconButton(
            icon: Icon(Icons.share),
            onPressed: () => _shareDocument(),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getFileIcon(documentName),
              size: 100,
              color: Theme.of(context).primaryColor,
            ),
            SizedBox(height: 24),
            Text(
              documentName,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            if (documentSize != null) ...[
              SizedBox(height: 8),
              Text(
                documentSize!,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
            ],
            SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _openDocument(),
                  icon: Icon(Icons.open_in_new),
                  label: Text('Open'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _downloadDocument(),
                  icon: Icon(Icons.download),
                  label: Text('Download'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'txt':
        return Icons.text_snippet;
      case 'zip':
      case 'rar':
        return Icons.archive;
      default:
        return Icons.insert_drive_file;
    }
  }

  void _openDocument() {
    // TODO: Implement document opening with url_launcher or in-app viewer
  }

  void _downloadDocument() {
    // TODO: Implement document download
  }

  void _shareDocument() {
    // TODO: Implement document sharing
  }
}