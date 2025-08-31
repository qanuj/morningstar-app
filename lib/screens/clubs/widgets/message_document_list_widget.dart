import 'package:duggy/models/message_document.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class MessageDocumentListWidget extends StatelessWidget {
  final List<MessageDocument> documents;

  const MessageDocumentListWidget({super.key, required this.documents});

  @override
  Widget build(BuildContext context) {
    if (documents.isEmpty) return SizedBox.shrink();

    return Column(
      children: documents
          .map((doc) => _buildDocumentItem(context, doc))
          .toList(),
    );
  }

  Widget _buildDocumentItem(BuildContext context, MessageDocument document) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 2),
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[800]
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          _buildDocumentIcon(document.type),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  document.filename,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (document.size != null)
                  Text(
                    document.size!,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _openDocument(context, document),
            icon: Icon(Icons.download, color: Color(0xFF06aeef), size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentIcon(String? type) {
    IconData icon;
    Color color;

    switch (type?.toLowerCase()) {
      case 'pdf':
        icon = Icons.picture_as_pdf;
        color = Colors.red;
        break;
      case 'doc':
      case 'docx':
        icon = Icons.description;
        color = Colors.blue;
        break;
      case 'xls':
      case 'xlsx':
        icon = Icons.table_chart;
        color = Colors.green;
        break;
      case 'ppt':
      case 'pptx':
        icon = Icons.slideshow;
        color = Colors.orange;
        break;
      case 'txt':
        icon = Icons.text_fields;
        color = Colors.grey;
        break;
      case 'zip':
      case 'rar':
        icon = Icons.archive;
        color = Colors.purple;
        break;
      default:
        icon = Icons.insert_drive_file;
        color = Colors.grey;
    }

    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  Future<void> _openDocument(
    BuildContext context,
    MessageDocument document,
  ) async {
    try {
      final Uri url = Uri.parse(document.url);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        _showErrorDialog(context, 'Cannot open this document');
      }
    } catch (e) {
      _showErrorDialog(context, 'Error opening document: ${e.toString()}');
    }
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }
}
