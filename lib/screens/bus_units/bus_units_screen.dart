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
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    tooltip: 'More options',
                    onPressed: () {
                      _showBusOptions(context, bus);
                    },
                  ),
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

  // Add this method for showing the popup menu
  void _showBusOptions(BuildContext context, Map<String, dynamic> bus) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  "Bus Options",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.person_add, color: Color(0xFF2F27CE)),
                title: const Text('Assign Driver & Conductor'),
                onTap: () {
                  Navigator.pop(context); // Close bottom sheet
                  _showAssignDriverDialog(bus);
                },
              ),
              ListTile(
                leading: const Icon(Icons.history, color: Color(0xFF2F27CE)),
                title: const Text('View Assignment History'),
                onTap: () {
                  Navigator.pop(context); // Close bottom sheet
                  _showAssignmentHistory(bus);
                },
              ),
              ListTile(
                leading: const Icon(Icons.add_road, color: Color(0xFF2F27CE)),
                title: const Text('Add Trip Log'),
                onTap: () {
                  Navigator.pop(context); // Close bottom sheet
                  _showAddTripLogDialog(bus);
                },
              ),
              ListTile(
                leading: const Icon(Icons.summarize, color: Color(0xFF2F27CE)),
                title: const Text('View Trip Logs'),
                onTap: () {
                  Navigator.pop(context); // Close bottom sheet
                  _showTripLogs(bus);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete Bus'),
                onTap: () {
                  Navigator.pop(context); // Close bottom sheet
                  _deleteBus(bus);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // Add this method to handle bus deletion
  Future<void> _deleteBus(Map<String, dynamic> bus) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Bus?'),
        content: Text(
          'Are you sure you want to delete bus ${bus['plate_number']}? This action cannot be undone and will delete all associated permits.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    try {
      setState(() {
        _isLoading = true;
      });
      
      // Delete the bus unit
      await supabase
          .from('bus_units')
          .delete()
          .eq('id', bus['id']);
      
      // Reload the list
      _loadBusUnits();
    } catch (e) {
      print('Error deleting bus: $e');
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting bus: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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

  Future<void> _showAssignDriverDialog(Map<String, dynamic> bus) async {
    final _formKey = GlobalKey<FormState>();
    DateTime _startDate = DateTime.now();
    DateTime _endDate = DateTime.now().add(const Duration(days: 30));
    Map<String, dynamic>? _selectedDriver;
    Map<String, dynamic>? _selectedConductor;
    List<Map<String, dynamic>> _drivers = [];
    List<Map<String, dynamic>> _conductors = [];
    bool _isLoading = true;
    
    // Show loading dialog while fetching data
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFF2F27CE))),
    );
    
    try {
      // Get all drivers without filtering
      final driversData = await supabase.from('drivers').select('*');
      // Get all conductors without filtering
      final conductorsData = await supabase.from('conductors').select('*');
  
      _drivers = List<Map<String, dynamic>>.from(driversData);
      _conductors = List<Map<String, dynamic>>.from(conductorsData);

      _isLoading = false;
      
      // Close loading dialog
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      // Close loading dialog
      if (context.mounted) Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
      return;
    }
  
    if (_drivers.isEmpty || _conductors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No available drivers or conductors found')),
      );
      return;
    }
  
    // Show the assignment dialog with improved design
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDEDCFF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.people_alt, color: Color(0xFF2F27CE)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Assign Staff to Bus ${bus['plate_number']}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                ],
              ),
              content: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Driver dropdown with improved styling
                      const Text('Driver', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButtonFormField<Map<String, dynamic>>(
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                            border: InputBorder.none,
                            hintText: 'Select Driver',
                            prefixIcon: Icon(Icons.person, color: Color(0xFF2F27CE)),
                          ),
                          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF2F27CE)),
                          isExpanded: true,
                          value: _selectedDriver,
                          items: _drivers.map((driver) {
                            final fullName = '${driver['first_name'] ?? ''} ${driver['last_name'] ?? ''}';
                            return DropdownMenuItem<Map<String, dynamic>>(
                              value: driver,
                              child: Text(fullName),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedDriver = value;
                            });
                          },
                          validator: (value) => value == null ? 'Please select a driver' : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Conductor dropdown with improved styling
                      const Text('Conductor', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButtonFormField<Map<String, dynamic>>(
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                            border: InputBorder.none,
                            hintText: 'Select Conductor',
                            prefixIcon: Icon(Icons.person_outline, color: Color(0xFF2F27CE)),
                          ),
                          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF2F27CE)),
                          isExpanded: true,
                          value: _selectedConductor,
                          items: _conductors.map((conductor) {
                            // Try different ways to access name information
                            String displayName;
                            
                            // Debug what fields are available
                            print('Conductor data: ${conductor.keys}');
                            
                            // Option 1: Check if first_name and last_name exist directly
                            if (conductor['first_name'] != null) {
                              displayName = '${conductor['first_name']} ${conductor['last_name'] ?? ''}';
                            }
                            // Option 2: Check if single name field exists
                            else if (conductor['name'] != null) {
                              displayName = conductor['name'];
                            }
                            // Option 3: Check if contact_number exists for fallback
                            else if (conductor['contact_number'] != null) {
                              displayName = 'Conductor (${conductor['contact_number']})';
                            }
                            // Option 4: Use any identifier available as last resort
                            else {
                              String id = (conductor['id'] ?? '').toString();
                              id = id.length > 8 ? id.substring(0, 8) : id;
                              displayName = 'Conductor #$id';
                            }
                            
                            return DropdownMenuItem<Map<String, dynamic>>(
                              value: conductor,
                              child: Text(displayName),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedConductor = value;
                            });
                          },
                          validator: (value) => value == null ? 'Please select a conductor' : null,
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Date Selection with improved styling
                      const Text('Assignment Period', 
                        style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: _startDate,
                                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                  builder: (context, child) {
                                    return Theme(
                                      data: Theme.of(context).copyWith(
                                        colorScheme: const ColorScheme.light(
                                          primary: Color(0xFF2F27CE),
                                        ),
                                      ),
                                      child: child!,
                                    );
                                  },
                                );
                                if (date != null) {
                                  setState(() {
                                    _startDate = date;
                                    if (_endDate.isBefore(_startDate)) {
                                      _endDate = _startDate.add(const Duration(days: 1));
                                    }
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Start Date', 
                                      style: TextStyle(fontSize: 12, color: Colors.grey)
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.calendar_today, size: 16, color: Color(0xFF2F27CE)),
                                        const SizedBox(width: 6),
                                        Text(
                                          DateFormat('MMM dd, yyyy').format(_startDate),
                                          style: const TextStyle(fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: _endDate,
                                  firstDate: _startDate,
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                  builder: (context, child) {
                                    return Theme(
                                      data: Theme.of(context).copyWith(
                                        colorScheme: const ColorScheme.light(
                                          primary: Color(0xFF2F27CE),
                                        ),
                                      ),
                                      child: child!,
                                    );
                                  },
                                );
                                if (date != null) {
                                  setState(() {
                                    _endDate = date;
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('End Date', 
                                      style: TextStyle(fontSize: 12, color: Colors.grey)
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.calendar_today, size: 16, color: Color(0xFF2F27CE)),
                                        const SizedBox(width: 6),
                                        Text(
                                          DateFormat('MMM dd, yyyy').format(_endDate),
                                          style: const TextStyle(fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      try {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFF2F27CE))),
                        );
                        
                        await supabase
                          .from('bus_assignments')
                          .update({'is_active': false, 'end_date': DateFormat('yyyy-MM-dd').format(DateTime.now())})
                          .eq('bus_id', bus['id'])
                          .eq('is_active', true);
                        
                        final assignmentData = {
                          'bus_id': bus['id'],
                          'driver_id': _selectedDriver!['id'],
                          'conductor_id': _selectedConductor!['id'],
                          'assignment_date': DateFormat('yyyy-MM-dd').format(_startDate),
                          'end_date': DateFormat('yyyy-MM-dd').format(_endDate),
                          'is_active': true,
                          'created_by': supabase.auth.currentUser!.id,
                        };
                        
                        await supabase.from('bus_assignments').insert(assignmentData);
                        
                        if (context.mounted) Navigator.pop(context);
                        if (context.mounted) Navigator.pop(context);
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Staff assigned successfully!'),
                            backgroundColor: Color(0xFF2F27CE),
                          ),
                        );
                      } catch (e) {
                        if (context.mounted) Navigator.pop(context);
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error assigning staff: $e')),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2F27CE),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Assign'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showAssignmentHistory(Map<String, dynamic> bus) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    
    try {
      // Load assignment history
      final assignments = await supabase
          .from('bus_assignments')
          .select('*, drivers(*, profiles(*)), conductors(*, profiles(*))')
          .eq('bus_id', bus['id'])
          .order('assignment_date', ascending: false);
      
      // Close loading dialog
      if (context.mounted) Navigator.pop(context);
      
      if (!context.mounted) return;
      
      if (assignments.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No assignment history found for this bus')),
        );
        return;
      }
      
      // Show assignment history dialog
      showDialog(
        context: context,
        builder: (context) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: double.maxFinite,
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Assignment History - ${bus['plate_number']}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: assignments.length,
                      itemBuilder: (context, index) {
                        final assignment = assignments[index];
                        final driver = assignment['drivers']['profiles'];
                        final conductor = assignment['conductors']['profiles'];
                        
                        final driverName = '${driver['first_name'] ?? ''} ${driver['last_name'] ?? ''}';
                        final conductorName = '${conductor['first_name'] ?? ''} ${conductor['last_name'] ?? ''}';
                        
                        final startDate = DateFormat('MMM dd, yyyy').format(DateTime.parse(assignment['assignment_date']));
                        final endDate = assignment['end_date'] != null 
                            ? DateFormat('MMM dd, yyyy').format(DateTime.parse(assignment['end_date']))
                            : 'Present';
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text('$driverName (Driver) & $conductorName (Conductor)'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Period: $startDate to $endDate'),
                                Text('Status: ${assignment['is_active'] ? 'Active' : 'Inactive'}'),
                              ],
                            ),
                            isThreeLine: true,
                            leading: CircleAvatar(
                              backgroundColor: assignment['is_active'] ? Colors.green : Colors.grey,
                              child: const Icon(Icons.people, color: Colors.white),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      // Close loading dialog if there's an error
      if (context.mounted) Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading assignment history: $e')),
      );
    }
  }

  Future<void> _showAddTripLogDialog(Map<String, dynamic> bus) async {
    final _formKey = GlobalKey<FormState>();
    final _fareController = TextEditingController();
    final _expensesController = TextEditingController();
    final _notesController = TextEditingController();
    
    Map<String, dynamic>? _currentAssignment;
    Map<String, dynamic>? _selectedDriver;
    Map<String, dynamic>? _selectedConductor;
    DateTime _tripDate = DateTime.now();
    String _busCondition = 'Good';
    bool _isLoading = true;
    
    // Show loading dialog while fetching data
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    
    try {
      // Check if there's an active assignment for this bus
      final activeAssignment = await supabase
          .from('bus_assignments')
          .select('*, drivers(*, profiles(*)), conductors(*, profiles(*))')
          .eq('bus_id', bus['id'])
          .eq('is_active', true)
          .maybeSingle();
    
      _currentAssignment = activeAssignment;
    
      if (_currentAssignment != null) {
        _selectedDriver = _currentAssignment['drivers'];
        _selectedConductor = _currentAssignment['conductors'];
      }
    
      _isLoading = false;
    
      // Close loading dialog
      if (context.mounted) Navigator.pop(context);
    
      if (!context.mounted) return;
    } catch (e) {
      // Close loading dialog
      if (context.mounted) Navigator.pop(context);
    
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
      return;
    }
  
    // Show the trip log dialog
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Add Trip Log - ${bus['plate_number']}'),
              content: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Trip Date
                      ListTile(
                        title: const Text('Trip Date'),
                        subtitle: Text(DateFormat('MMM dd, yyyy').format(_tripDate)),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _tripDate,
                            firstDate: DateTime.now().subtract(const Duration(days: 30)),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setState(() {
                              _tripDate = date;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Display selected driver and conductor if available
                      if (_currentAssignment != null) ...[
                        ListTile(
                          leading: const Icon(Icons.person),
                          title: const Text('Driver'),
                          subtitle: Text(
                            '${_selectedDriver!['profiles']['first_name']} ${_selectedDriver!['profiles']['last_name']}'
                          ),
                        ),
                        ListTile(
                          leading: const Icon(Icons.person_outline),
                          title: const Text('Conductor'),
                          subtitle: Text(
                            '${_selectedConductor!['profiles']['first_name']} ${_selectedConductor!['profiles']['last_name']}'
                          ),
                        ),
                      ] else ...[
                        const Text(
                          'No active assignment found for this bus. Please assign a driver and conductor first.',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                      const SizedBox(height: 16),
                      
                      // Fare Collected
                      TextFormField(
                        controller: _fareController,
                        decoration: const InputDecoration(
                          labelText: 'Fare Collected (₱)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter fare amount';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Please enter a valid number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Expenses
                      TextFormField(
                        controller: _expensesController,
                        decoration: const InputDecoration(
                          labelText: 'Expenses (₱)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter expenses amount';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Please enter a valid number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Bus Condition
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Bus Condition',
                          border: OutlineInputBorder(),
                        ),
                        value: _busCondition,
                        items: ['Good', 'Fair', 'Poor', 'Needs Maintenance']
                            .map((condition) => DropdownMenuItem<String>(
                                  value: condition,
                                  child: Text(condition),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _busCondition = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Notes
                      TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Notes/Remarks',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _currentAssignment == null ? null : () async {
                    if (_formKey.currentState!.validate()) {
                      try {
                        // Show loading dialog
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => const Center(child: CircularProgressIndicator()),
                        );
                        
                        // Create trip log
                        final tripData = {
                          'bus_id': bus['id'],
                          'driver_id': _selectedDriver!['id'],
                          'conductor_id': _selectedConductor!['id'],
                          'trip_date': DateFormat('yyyy-MM-dd').format(_tripDate),
                          'fare_collected': double.parse(_fareController.text),
                          'expenses': double.parse(_expensesController.text),
                          'bus_condition': _busCondition,
                          'notes': _notesController.text,
                          'created_by': supabase.auth.currentUser!.id,
                        };
                        
                        await supabase
                            .from('bus_trip_logs')
                            .insert(tripData);
                        
                        // Update bus status if condition is poor or needs maintenance
                        if (_busCondition == 'Poor' || _busCondition == 'Needs Maintenance') {
                          await supabase
                              .from('bus_units')
                              .update({'status': 'maintenance'})
                              .eq('id', bus['id']);
                              
                          // Reload bus units
                          _loadBusUnits();
                        }
                        
                        // Close loading dialog
                        if (context.mounted) Navigator.pop(context);
                        
                        // Close trip log dialog
                        if (context.mounted) Navigator.pop(context);
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Trip log added successfully!')),
                        );
                      } catch (e) {
                        // Close loading dialog if there's an error
                        if (context.mounted) Navigator.pop(context);
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error adding trip log: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showTripLogs(Map<String, dynamic> bus) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    
    try {
      // Load trip logs
      final tripLogs = await supabase
          .from('bus_trip_logs')
          .select('*, drivers(*, profiles(*)), conductors(*, profiles(*))')
          .eq('bus_id', bus['id'])
          .order('trip_date', ascending: false);
      
      // Close loading dialog
      if (context.mounted) Navigator.pop(context);
      
      if (!context.mounted) return;
      
      if (tripLogs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No trip logs found for this bus')),
        );
        return;
      }
      
      // Show trip logs dialog
      showDialog(
        context: context,
        builder: (context) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: double.maxFinite,
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Trip Logs - ${bus['plate_number']}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: tripLogs.length,
                      itemBuilder: (context, index) {
                        final tripLog = tripLogs[index];
                        final driver = tripLog['drivers']['profiles'];
                        final conductor = tripLog['conductors']['profiles'];
                        
                        final driverName = '${driver['first_name'] ?? ''} ${driver['last_name'] ?? ''}';
                        final conductorName = '${conductor['first_name'] ?? ''} ${conductor['last_name'] ?? ''}';
                        
                        final tripDate = DateFormat('MMM dd, yyyy').format(DateTime.parse(tripLog['trip_date']));
                        final netIncome = tripLog['fare_collected'] - tripLog['expenses'];
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text('Trip on $tripDate'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start, 
                              children: [
                                Text('Driver: $driverName'),
                                Text('Conductor: $conductorName'),
                                Text('Fare: ₱${tripLog['fare_collected'].toStringAsFixed(2)} | Expenses: ₱${tripLog['expenses'].toStringAsFixed(2)}'),
                                Text('Net Income: ₱${netIncome.toStringAsFixed(2)}'),
                                Text('Condition: ${tripLog['bus_condition']}'),
                                if (tripLog['notes'] != null && tripLog['notes'].isNotEmpty)
                                  Text('Notes: ${tripLog['notes']}'),
                              ],
                            ),
                            isThreeLine: true,
                            leading: CircleAvatar(
                              backgroundColor: _getConditionColor(tripLog['bus_condition']),
                              child: const Icon(Icons.directions_bus, color: Colors.white),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      // Close loading dialog if there's an error
      if (context.mounted) Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading trip logs: $e')),
      );
    }
  }

  // Helper method to get color based on bus condition
  Color _getConditionColor(String condition) {
    switch (condition) {
      case 'Good':
        return Colors.green;
      case 'Fair':
        return Colors.blue;
      case 'Poor':
        return Colors.orange;
      case 'Needs Maintenance':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}