import 'package:flutter/material.dart';
import 'package:bus_management/config/supabase_config.dart';
import 'package:bus_management/screens/bus_units/bus_detail_screen.dart';
import 'package:intl/intl.dart';

class BusUnitsScreen extends StatefulWidget {
  const BusUnitsScreen({super.key});

  @override
  State<BusUnitsScreen> createState() => _BusUnitsScreenState();
}

class _BusUnitsScreenState extends State<BusUnitsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _busUnits = [];
  List<Map<String, dynamic>> _alerts = [];
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _loadBusUnits();
    _loadAlerts();
  }

  Future<void> _loadBusUnits() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final data = await supabase
          .from('bus_units')
          .select('*, bus_permits(*)');

      setState(() {
        _busUnits = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading bus units: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAlerts() async {
    try {
      final data = await supabase
          .from('bus_permit_alerts')
          .select('*')
          .order('expiration_date', ascending: true);

      setState(() {
        _alerts = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      print('Error loading alerts: $e');
    }
  }

  List<Map<String, dynamic>> get _filteredBusUnits {
    if (_filterStatus == 'all') {
      return _busUnits;
    }
    return _busUnits.where((bus) => bus['status'] == _filterStatus).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Bus Units',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: const Color(0xFF2F27CE),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh',
            onPressed: () {
              _loadBusUnits();
              _loadAlerts();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2F27CE)))
          : Column(
              children: [
                // Alerts Section
                if (_alerts.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3DC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFFB648)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Color(0xFFFF9800)),
                            SizedBox(width: 8),
                            Text(
                              'Permit Alerts',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF050315),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...List.generate(
                          _alerts.length > 3 ? 3 : _alerts.length, 
                          (index) => _buildAlertItem(_alerts[index])
                        ),
                        if (_alerts.length > 3)
                          TextButton(
                            onPressed: () {
                              // Navigate to full alerts screen
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF2F27CE),
                            ),
                            child: const Text('View All Alerts'),
                          ),
                      ],
                    ),
                  ),
                
                // Filter Options
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      const Text(
                        'Filter by status:',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 16),
                      DropdownButton<String>(
                        value: _filterStatus,
                        underline: Container(
                          height: 2,
                          color: const Color(0xFF2F27CE),
                        ),
                        onChanged: (String? newValue) {
                          setState(() {
                            _filterStatus = newValue!;
                          });
                        },
                        items: <String>['all', 'active', 'maintenance', 'inactive']
                            .map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              value == 'all' ? "All" : capitalizeStr(value)
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                
                // Bus Units List
                Expanded(
                  child: _filteredBusUnits.isEmpty
                      ? const Center(
                          child: Text('No bus units found. Add one to get started.'),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredBusUnits.length,
                          itemBuilder: (context, index) {
                            final bus = _filteredBusUnits[index];
                            return _buildBusCard(bus);
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const BusDetailScreen(
                isEditing: false,
              ),
            ),
          );
          
          if (result == true) {
            _loadBusUnits();
          }
        },
        backgroundColor: const Color(0xFF2F27CE),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildAlertItem(Map<String, dynamic> alert) {
    final formatter = DateFormat('MMM dd, yyyy');
    Color statusColor;
    
    switch (alert['alert_status']) {
      case 'overdue':
        statusColor = Colors.red;
        break;
      case 'due_in_7_days':
        statusColor = Colors.orange;
        break;
      default:
        statusColor = Colors.amber;
    }
    
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${alert['plate_number'] ?? ""} - ${_formatPermitType(alert['permit_type'])}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            'Expires: ${formatter.format(DateTime.parse(alert['expiration_date']))}',
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusCard(Map<String, dynamic> bus) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BusDetailScreen(
                isEditing: true,
                busData: bus,
              ),
            ),
          );
          
          if (result == true) {
            _loadBusUnits();
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDEDCFF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.directions_bus,
                      color: Color(0xFF2F27CE),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bus['plate_number'] ?? '',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF050315),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${bus['model'] ?? ''} (${bus['year'] ?? ''})',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(bus['status']),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildInfoChip(Icons.airline_seat_recline_normal, '${bus['capacity'] ?? 0} seats'),
                  _buildInfoChip(
                    Icons.description,
                    _getPermitStatus(bus['bus_permits'] ?? []),
                    _getPermitStatusColor(bus['bus_permits'] ?? []),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(dynamic status) {
    // Convert dynamic to String safely
    String statusText = status?.toString() ?? 'unknown';
    
    Color backgroundColor;
    Color textColor = Colors.white;
    
    switch (statusText) {
      case 'active':
        backgroundColor = Colors.green;
        break;
      case 'maintenance':
        backgroundColor = Colors.orange;
        break;
      case 'inactive':
        backgroundColor = Colors.red;
        break;
      default:
        backgroundColor = Colors.grey;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        capitalizeStr(statusText),
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, [Color? color]) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: color ?? Colors.grey[700],
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color ?? Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _getPermitStatus(List<dynamic> permits) {
    if (permits.isEmpty) {
      return 'No permits';
    }
    
    final expiredCount = permits.where((p) => p['status'] == 'expired').length;
    final expiringCount = permits.where((p) => p['status'] == 'expiring_soon').length;
    
    if (expiredCount > 0) {
      return '$expiredCount expired';
    } else if (expiringCount > 0) {
      return '$expiringCount expiring soon';
    } else {
      return 'All permits active';
    }
  }

  Color _getPermitStatusColor(List<dynamic> permits) {
    if (permits.isEmpty) {
      return Colors.grey;
    }
    
    if (permits.any((p) => p['status'] == 'expired')) {
      return Colors.red;
    } else if (permits.any((p) => p['status'] == 'expiring_soon')) {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }

  String _formatPermitType(dynamic permitType) {
    if (permitType == null) return "";
    String permitStr = permitType.toString();
    if (permitStr.isEmpty) return "";
    return capitalizeStr(permitStr.replaceAll('_', ' '));
  }

  // Helper method instead of extension
  String capitalizeStr(String input) {
    if (input.isEmpty) return input;
    return "${input[0].toUpperCase()}${input.substring(1)}";
  }
}