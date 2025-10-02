// lib/screens/debug/network_timing_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';
import '../../services/network_timing_service.dart';
import '../../utils/theme.dart';

class NetworkTimingScreen extends StatefulWidget {
  const NetworkTimingScreen({super.key});

  @override
  NetworkTimingScreenState createState() => NetworkTimingScreenState();
}

class NetworkTimingScreenState extends State<NetworkTimingScreen> {
  List<NetworkTiming> _timings = [];
  Map<String, double> _averageMetrics = {};
  bool _timingEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadTimingData();
  }

  void _loadTimingData() {
    setState(() {
      _timings = NetworkTimingService.timings;
      _averageMetrics = NetworkTimingService.getAverageMetrics();
      _timingEnabled = NetworkTimingService.enabled;
    });
  }

  void _toggleTiming() {
    if (_timingEnabled) {
      ApiService.disableNetworkTiming();
    } else {
      ApiService.enableNetworkTiming();
    }
    setState(() {
      _timingEnabled = !_timingEnabled;
    });
  }

  void _clearTimings() {
    ApiService.clearNetworkTimings();
    _loadTimingData();
    _showSnackBar('Timing data cleared', isError: false);
  }

  void _exportTimings() {
    final timingData = _timings.map((t) => t.toJson()).toList();
    final jsonString = timingData.toString();

    Clipboard.setData(ClipboardData(text: jsonString));
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.errorRed : AppTheme.successGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        title: Text('Network Timing Analysis'),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_timingEnabled ? Icons.pause : Icons.play_arrow),
            onPressed: _toggleTiming,
            tooltip: _timingEnabled ? 'Disable Timing' : 'Enable Timing',
          ),
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: _clearTimings,
            tooltip: 'Clear Data',
          ),
          IconButton(
            icon: Icon(Icons.share),
            onPressed: _exportTimings,
            tooltip: 'Export Data',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _loadTimingData();
        },
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatusCard(colorScheme),
              SizedBox(height: 16),
              _buildMetricsCard(colorScheme),
              SizedBox(height: 16),
              _buildIssuesCard(colorScheme),
              SizedBox(height: 16),
              _buildTimingsList(colorScheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard(ColorScheme colorScheme) {
    return Card(
      color: colorScheme.surface,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _timingEnabled ? Icons.timer : Icons.timer_off,
                  color: _timingEnabled
                      ? AppTheme.successGreen
                      : AppTheme.errorRed,
                ),
                SizedBox(width: 8),
                Text(
                  'Network Timing',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                Spacer(),
                Switch(
                  value: _timingEnabled,
                  onChanged: (value) => _toggleTiming(),
                  activeColor: colorScheme.primary,
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              _timingEnabled
                  ? 'Precise timing measurement is active. DNS, connection, and TLS delays are being logged.'
                  : 'Timing measurement is disabled. Enable to track network performance.',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                _buildStatusChip('Requests', '${_timings.length}', colorScheme),
                SizedBox(width: 8),
                _buildStatusChip(
                  'Errors',
                  '${_timings.where((t) => t.error != null).length}',
                  colorScheme,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, String value, ColorScheme colorScheme) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsCard(ColorScheme colorScheme) {
    if (_averageMetrics.isEmpty) {
      return SizedBox.shrink();
    }

    return Card(
      color: colorScheme.surface,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Average Performance',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 16),
            _buildMetricRow(
              'Total Time',
              _averageMetrics['avgTotalTime'],
              colorScheme,
            ),
            _buildMetricRow(
              'DNS Resolution',
              _averageMetrics['avgDnsTime'],
              colorScheme,
            ),
            _buildMetricRow(
              'Connection',
              _averageMetrics['avgConnectionTime'],
              colorScheme,
            ),
            _buildMetricRow(
              'TLS Handshake',
              _averageMetrics['avgTlsTime'],
              colorScheme,
            ),
            _buildMetricRow(
              'First Byte (TTFB)',
              _averageMetrics['avgFirstByteTime'],
              colorScheme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, double? value, ColorScheme colorScheme) {
    if (value == null || value == 0) return SizedBox.shrink();

    Color valueColor = colorScheme.onSurface;
    if (label == 'Total Time' && value > 2000) {
      valueColor = AppTheme.errorRed;
    } else if (label == 'DNS Resolution' && value > 1000) {
      valueColor = AppTheme.warningOrange;
    } else if (label == 'TLS Handshake' && value > 2000) {
      valueColor = AppTheme.warningOrange;
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          Text(
            '${value.toStringAsFixed(1)}ms',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIssuesCard(ColorScheme colorScheme) {
    final slowRequests = ApiService.getSlowRequests();
    final dnsIssues = ApiService.getDnsIssues();
    final tlsIssues = ApiService.getTlsIssues();

    if (slowRequests.isEmpty && dnsIssues.isEmpty && tlsIssues.isEmpty) {
      return SizedBox.shrink();
    }

    return Card(
      color: colorScheme.surface,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Performance Issues',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 16),
            if (slowRequests.isNotEmpty)
              _buildIssueRow(
                'Slow Requests (>2s)',
                slowRequests.length,
                AppTheme.errorRed,
              ),
            if (dnsIssues.isNotEmpty)
              _buildIssueRow(
                'DNS Issues (>1s)',
                dnsIssues.length,
                AppTheme.warningOrange,
              ),
            if (tlsIssues.isNotEmpty)
              _buildIssueRow(
                'TLS Issues (>2s)',
                tlsIssues.length,
                AppTheme.warningOrange,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildIssueRow(String label, int count, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.warning, color: color, size: 16),
              SizedBox(width: 8),
              Text(label, style: TextStyle(fontSize: 14, color: color)),
            ],
          ),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimingsList(ColorScheme colorScheme) {
    if (_timings.isEmpty) {
      return Card(
        color: colorScheme.surface,
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 48,
                  color: colorScheme.onSurface.withOpacity(0.3),
                ),
                SizedBox(height: 16),
                Text(
                  'No timing data available',
                  style: TextStyle(
                    fontSize: 16,
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Make some API requests to see timing analysis',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      color: colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Recent Requests',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: _timings.length > 20 ? 20 : _timings.length,
            separatorBuilder: (context, index) => Divider(height: 1),
            itemBuilder: (context, index) {
              final timing = _timings.reversed.toList()[index];
              return _buildTimingItem(timing, colorScheme);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTimingItem(NetworkTiming timing, ColorScheme colorScheme) {
    final isError = timing.error != null;
    final isSlow = timing.totalDuration.inMilliseconds > 2000;

    return ListTile(
      leading: Icon(
        isError ? Icons.error : (isSlow ? Icons.warning : Icons.check_circle),
        color: isError
            ? AppTheme.errorRed
            : (isSlow ? AppTheme.warningOrange : AppTheme.successGreen),
      ),
      title: Text(
        '${timing.method} ${timing.host}${timing.path}',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        isError
            ? 'Error: ${timing.error}'
            : '${timing.totalDuration.inMilliseconds}ms • ${timing.statusCode}',
        style: TextStyle(
          fontSize: 12,
          color: colorScheme.onSurface.withOpacity(0.7),
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (timing.dnsResolutionDuration != null)
            Text(
              'DNS: ${timing.dnsResolutionDuration!.inMilliseconds}ms',
              style: TextStyle(
                fontSize: 10,
                color: colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          if (timing.tlsHandshakeDuration != null)
            Text(
              'TLS: ${timing.tlsHandshakeDuration!.inMilliseconds}ms',
              style: TextStyle(
                fontSize: 10,
                color: colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
        ],
      ),
      onTap: () => _showTimingDetails(timing),
    );
  }

  void _showTimingDetails(NetworkTiming timing) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Timing Details'),
        content: SingleChildScrollView(
          child: Text(
            timing.formattedLog,
            style: TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: timing.formattedLog));
              Navigator.of(context).pop();
              _showSnackBar(
                'Timing details copied to clipboard',
                isError: false,
              );
            },
            child: Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }
}
