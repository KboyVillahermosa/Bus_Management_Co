import 'package:flutter/material.dart';
import 'package:bus_management/config/supabase_config.dart';
import 'package:intl/intl.dart';

class BusTripLogsScreen extends StatefulWidget {
  final Map<String, dynamic> bus;
  
  const BusTripLogsScreen({Key? key, required this.bus}) : super(key: key);

  @override
  State<BusTripLogsScreen> createState() => _BusTripLogsScreenState();
}

class _BusTripLogsScreenState extends State<BusTripLogsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _tripLogs = [];
  
  // Summary stats
  int _totalTrips = 0;
  double _totalFare = 0;
  double _totalExpenses = 0;
  double _netIncome = 0;
  
  @override
  void initState() {
    super.initState();
    _loadTripLogs();
  }
  
  Future<void> _loadTripLogs() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      // Load trip logs with proper joins
      final tripLogs = await supabase
          .from('bus_trip_logs')
          .select('''
            *,
            drivers(*),
            conductors(*)
          ''')
          .eq('bus_id', widget.bus['id'])
          .order('trip_date', ascending: false);
      
      // Calculate summary stats
      double totalFare = 0;
      double totalExpenses = 0;
      
      for (var log in tripLogs) {
        totalFare += (log['fare_collected'] ?? 0).toDouble();
        totalExpenses += (log['expenses'] ?? 0).toDouble();
      }
      
      setState(() {
        _tripLogs = List<Map<String, dynamic>>.from(tripLogs);
        _totalTrips = _tripLogs.length;
        _totalFare = totalFare;
        _totalExpenses = totalExpenses;
        _netIncome = _totalFare - _totalExpenses;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading trip logs: $e');
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading trip logs: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Trip Logs - ${widget.bus['plate_number']}'),
        backgroundColor: const Color(0xFF2F27CE),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2F27CE)))
          : _tripLogs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.directions_bus_outlined, color: Colors.grey, size: 64),
                      const SizedBox(height: 16),
                      const Text(
                        'No trip logs found',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'This bus does not have any recorded trips yet',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2F27CE),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Go Back'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadTripLogs,
                  color: const Color(0xFF2F27CE),
                  child: Column(
                    children: [
                      // Summary card
                      Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.2),
                              spreadRadius: 1,
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Trip Summary',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2F27CE),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _summaryItem(
                                  'Total Trips',
                                  _totalTrips.toString(),
                                  Icons.directions_bus,
                                  const Color(0xFF2F27CE),
                                ),
                                _summaryItem(
                                  'Total Fare',
                                  NumberFormat.currency(symbol: '₱', decimalDigits: 2).format(_totalFare),
                                  Icons.payments,
                                  Colors.green,
                                ),
                                _summaryItem(
                                  'Net Income',
                                  NumberFormat.currency(symbol: '₱', decimalDigits: 2).format(_netIncome),
                                  Icons.account_balance_wallet,
                                  _netIncome >= 0 ? Colors.green : Colors.red,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      // Trip logs list
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: _tripLogs.length,
                          itemBuilder: (context, index) {
                            final tripLog = _tripLogs[index];
                            
                            // Process driver and conductor data safely
                            final driver = tripLog['drivers'];
                            final conductor = tripLog['conductors'];
                            
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
                            
                            final tripDate = DateFormat('MMM dd, yyyy').format(
                              DateTime.parse(tripLog['trip_date'])
                            );
                            
                            final fare = tripLog['fare_collected'].toDouble();
                            final expenses = tripLog['expenses'].toDouble();
                            final netIncome = fare - expenses;
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(0),
                                child: ExpansionTile(
                                  leading: CircleAvatar(
                                    backgroundColor: _getConditionColor(tripLog['bus_condition']),
                                    child: const Icon(Icons.directions_bus, color: Colors.white),
                                  ),
                                  title: Text('Trip on $tripDate'),
                                  subtitle: Text(
                                    'Net Income: ${NumberFormat.currency(symbol: '₱', decimalDigits: 2).format(netIncome)}',
                                    style: TextStyle(
                                      color: netIncome >= 0 ? Colors.green : Colors.red,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Staff details
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Staff on Duty',
                                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                ),
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    const Icon(Icons.person, size: 16, color: Colors.blue),
                                                    const SizedBox(width: 8),
                                                    Expanded(child: Text('Driver: $driverName')),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    const Icon(Icons.person_outline, size: 16, color: Colors.orange),
                                                    const SizedBox(width: 8),
                                                    Expanded(child: Text('Conductor: $conductorName')),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          
                                          // Financial details
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Financial Summary',
                                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                ),
                                                const SizedBox(height: 8),
                                                _detailRow(
                                                  'Fare Collected', 
                                                  NumberFormat.currency(symbol: '₱', decimalDigits: 2).format(fare),
                                                  Icons.payments,
                                                  Colors.green,
                                                ),
                                                const SizedBox(height: 4),
                                                _detailRow(
                                                  'Expenses', 
                                                  NumberFormat.currency(symbol: '₱', decimalDigits: 2).format(expenses),
                                                  Icons.money_off,
                                                  Colors.red,
                                                ),
                                                const Divider(height: 16),
                                                _detailRow(
                                                  'Net Income', 
                                                  NumberFormat.currency(symbol: '₱', decimalDigits: 2).format(netIncome),
                                                  Icons.account_balance_wallet,
                                                  netIncome >= 0 ? Colors.green : Colors.red,
                                                  bold: true,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          
                                          // Bus condition
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Bus Status',
                                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                ),
                                                const SizedBox(height: 8),
                                                _detailRow(
                                                  'Condition', 
                                                  tripLog['bus_condition'],
                                                  Icons.health_and_safety,
                                                  _getConditionColor(tripLog['bus_condition']),
                                                ),
                                              ],
                                            ),
                                          ),
                                          
                                          // Notes (if any)
                                          if (tripLog['notes'] != null && tripLog['notes'].toString().isNotEmpty) ...[
                                            const SizedBox(height: 16),
                                            Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade100,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'Notes',
                                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(tripLog['notes']),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
      // Add FAB to add new trip log
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.pushNamed(
            context, 
            '/add_trip_log',
            arguments: widget.bus,
          );
          
          if (result == true) {
            _loadTripLogs();
          }
        },
        backgroundColor: const Color(0xFF2F27CE),
        child: const Icon(Icons.add),
      ),
    );
  }
  
  Widget _summaryItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
  
  Widget _detailRow(String label, String value, IconData icon, Color color, {bool bold = false}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: bold ? color : null,
            ),
          ),
        ),
      ],
    );
  }
  
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