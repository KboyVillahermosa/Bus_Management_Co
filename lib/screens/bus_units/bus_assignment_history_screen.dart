import 'package:flutter/material.dart';
import 'package:bus_management/config/supabase_config.dart';
import 'package:intl/intl.dart';

class BusAssignmentHistoryScreen extends StatefulWidget {
  final Map<String, dynamic> bus;
  
  const BusAssignmentHistoryScreen({Key? key, required this.bus}) : super(key: key);

  @override
  State<BusAssignmentHistoryScreen> createState() => _BusAssignmentHistoryScreenState();
}

class _BusAssignmentHistoryScreenState extends State<BusAssignmentHistoryScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _assignments = [];
  
  @override
  void initState() {
    super.initState();
    _loadAssignments();
  }
  
  Future<void> _loadAssignments() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      // Load assignment history with proper joins
      final assignments = await supabase
          .from('bus_assignments')
          .select('''
            *,
            drivers(*),
            conductors(*)
          ''')
          .eq('bus_id', widget.bus['id'])
          .order('assignment_date', ascending: false);
      
      setState(() {
        _assignments = List<Map<String, dynamic>>.from(assignments);
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading assignments: $e');
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading assignment history: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Assignment History - ${widget.bus['plate_number']}'),
        backgroundColor: const Color(0xFF2F27CE),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2F27CE)))
          : _assignments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.history, color: Colors.grey, size: 64),
                      const SizedBox(height: 16),
                      const Text(
                        'No assignment history',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'This bus has not been assigned to any staff yet',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAssignments,
                  color: const Color(0xFF2F27CE),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _assignments.length,
                    itemBuilder: (context, index) {
                      final assignment = _assignments[index];
                      
                      // Process driver and conductor data safely
                      final driver = assignment['drivers'];
                      final conductor = assignment['conductors'];
                      
                      String driverName = 'Unknown Driver';
                      String conductorName = 'Unknown Conductor';
                      
                      if (driver != null) {
                        driverName = '${driver['first_name'] ?? ''} ${driver['last_name'] ?? ''}'.trim();
                        if (driverName.isEmpty) driverName = 'Driver #${driver['id'].toString().substring(0, 8)}';
                      }
                      
                      if (conductor != null) {
                        conductorName = '${conductor['first_name'] ?? ''} ${conductor['last_name'] ?? ''}'.trim();
                        if (conductorName.isEmpty) conductorName = 'Conductor #${conductor['id'].toString().substring(0, 8)}';
                      }
                      
                      final startDate = DateFormat('MMM dd, yyyy').format(
                        DateTime.parse(assignment['assignment_date'])
                      );
                      final endDate = assignment['end_date'] != null 
                          ? DateFormat('MMM dd, yyyy').format(DateTime.parse(assignment['end_date']))
                          : 'Present';
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      color: assignment['is_active'] ? Colors.green : Colors.grey,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  Text(
                                    assignment['is_active'] ? 'Active Assignment' : 'Past Assignment',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: assignment['is_active'] ? Colors.green : Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Icon(Icons.date_range, size: 16, color: Color(0xFF2F27CE)),
                                  const SizedBox(width: 8),
                                  Text('$startDate to $endDate', style: const TextStyle(fontWeight: FontWeight.w500)),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Driver', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                        Row(
                                          children: [
                                            const Icon(Icons.person, size: 16, color: Colors.blue),
                                            const SizedBox(width: 4),
                                            Expanded(child: Text(driverName, style: const TextStyle(fontWeight: FontWeight.w500))),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Conductor', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                        Row(
                                          children: [
                                            const Icon(Icons.person_outline, size: 16, color: Colors.orange),
                                            const SizedBox(width: 4),
                                            Expanded(child: Text(conductorName, style: const TextStyle(fontWeight: FontWeight.w500))),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}