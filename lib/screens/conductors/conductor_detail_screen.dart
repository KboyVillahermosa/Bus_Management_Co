import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:bus_management/config/supabase_config.dart';

class ConductorDetailScreen extends StatefulWidget {
  final Map<String, dynamic> conductor;
  
  const ConductorDetailScreen({Key? key, required this.conductor}) : super(key: key);

  @override
  State<ConductorDetailScreen> createState() => _ConductorDetailScreenState();
}

class _ConductorDetailScreenState extends State<ConductorDetailScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _salaryHistory = [];
  List<Map<String, dynamic>> _assignments = [];
  List<Map<String, dynamic>> _cashAdvances = [];
  List<Map<String, dynamic>> _deductions = [];
  List<Map<String, dynamic>> _bonuses = [];

  @override
  void initState() {
    super.initState();
    _loadConductorData();
  }

  Future<void> _loadConductorData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Load salary history
      final salaryData = await supabase
          .from('conductor_salaries')
          .select()
          .eq('conductor_id', widget.conductor['id'])
          .order('pay_period_end', ascending: false)
          .limit(5);
      
      // Load assignments
      final assignmentData = await supabase
          .from('conductor_assignments')
          .select('*, buses(*)')
          .eq('conductor_id', widget.conductor['id'])
          .order('assignment_date', ascending: false)
          .limit(5);
      
      // Load cash advances
      final cashAdvanceData = await supabase
          .from('conductor_cash_advances')
          .select()
          .eq('conductor_id', widget.conductor['id'])
          .order('date_requested', ascending: false)
          .limit(5);
      
      // Load deductions
      final deductionData = await supabase
          .from('conductor_deductions')
          .select()
          .eq('conductor_id', widget.conductor['id'])
          .order('deduction_date', ascending: false)
          .limit(5);
      
      // Load bonuses
      final bonusData = await supabase
          .from('conductor_bonuses')
          .select()
          .eq('conductor_id', widget.conductor['id'])
          .order('bonus_date', ascending: false)
          .limit(5);
      
      setState(() {
        _salaryHistory = salaryData;
        _assignments = assignmentData;
        _cashAdvances = cashAdvanceData;
        _deductions = deductionData;
        _bonuses = bonusData;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading conductor data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.conductor['profiles'];
    final fullName = '${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}';
    final employmentDate = widget.conductor['employment_date'] != null 
        ? DateFormat('MMM dd, yyyy').format(DateTime.parse(widget.conductor['employment_date'])) 
        : 'Not set';
    
    return Scaffold(
      appBar: AppBar(
        title: Text(fullName),
        backgroundColor: const Color(0xFF2F27CE),
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Conductor Info Card
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: CircleAvatar(
                              radius: 50,
                              backgroundColor: const Color(0xFFDEDCFF),
                              child: Text(
                                fullName.isNotEmpty ? fullName[0] : '?',
                                style: const TextStyle(
                                  fontSize: 40,
                                  color: Color(0xFF2F27CE),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _infoRow('Name', fullName),
                          _infoRow('Contact', widget.conductor['phone_number'] ?? 'Not provided'),
                          _infoRow('License No', widget.conductor['license_number'] ?? 'Not provided'),
                          _infoRow('Employment Date', employmentDate),
                          _infoRow('Base Salary', 
                              NumberFormat.currency(symbol: '₱').format(widget.conductor['base_salary'] ?? 0)),
                          _infoRow('Status', widget.conductor['employment_status'] ?? 'Active'),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  const Text(
                    'Conductor Actions',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Action Cards
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.5,
                    children: [
                      _actionCard(
                        'Salary History', 
                        Icons.history, 
                        Colors.blue,
                        () => _showSalaryHistory(),
                      ),
                      _actionCard(
                        'Bus Assignments', 
                        Icons.directions_bus, 
                        Colors.green,
                        () => _showAssignments(),
                      ),
                      _actionCard(
                        'Upcoming Salary', 
                        Icons.calendar_today, 
                        Colors.orange,
                        () => _showUpcomingSalary(),
                      ),
                      _actionCard(
                        'Cash Advances', 
                        Icons.money, 
                        Colors.red,
                        () => _showCashAdvances(),
                      ),
                      _actionCard(
                        'Deductions', 
                        Icons.remove_circle, 
                        Colors.purple,
                        () => _showDeductions(),
                      ),
                      _actionCard(
                        'Bonuses', 
                        Icons.add_circle, 
                        Colors.teal,
                        () => _showBonuses(),
                      ),
                      _actionCard(
                        '13th Month', 
                        Icons.card_giftcard, 
                        Colors.amber,
                        () => _show13thMonth(),
                      ),
                    ],
                  ),
                  
                  // Recent activity section
                  if (_salaryHistory.isNotEmpty || _assignments.isNotEmpty)
                    const SizedBox(height: 24),
                  
                  if (_salaryHistory.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Recent Salary Payments',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._buildRecentSalaryItems(),
                      ],
                    ),
                    
                  if (_assignments.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        const Text(
                          'Recent Bus Assignments',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._buildRecentAssignmentItems(),
                      ],
                    ),
                ],
              ),
            ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _actionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 36,
                color: color,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildRecentSalaryItems() {
    if (_salaryHistory.isEmpty) {
      return [
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('No salary history found'),
          ),
        )
      ];
    }

    return _salaryHistory.take(3).map((salary) {
      final period = '${DateFormat('MMM dd').format(DateTime.parse(salary['pay_period_start']))} - ${DateFormat('MMM dd, yyyy').format(DateTime.parse(salary['pay_period_end']))}';
      
      return Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: _getStatusColor(salary['payment_status']),
            child: Text(
              salary['payment_status'].substring(0, 1),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          title: Text('₱${salary['net_amount'].toStringAsFixed(2)}'),
          subtitle: Text(period),
          trailing: Text(salary['payment_status']),
        ),
      );
    }).toList();
  }

  List<Widget> _buildRecentAssignmentItems() {
    if (_assignments.isEmpty) {
      return [
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('No assignments found'),
          ),
        )
      ];
    }

    return _assignments.take(3).map((assignment) {
      final bus = assignment['buses'];
      final period = assignment['end_date'] != null 
          ? '${DateFormat('MMM dd, yyyy').format(DateTime.parse(assignment['assignment_date']))} - ${DateFormat('MMM dd, yyyy').format(DateTime.parse(assignment['end_date']))}'
          : 'Since ${DateFormat('MMM dd, yyyy').format(DateTime.parse(assignment['assignment_date']))}';
      
      return Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: assignment['is_active'] ? Colors.green : Colors.grey,
            child: const Icon(Icons.directions_bus, color: Colors.white),
          ),
          title: Text('Bus ${bus['bus_number']} - ${bus['plate_number']}'),
          subtitle: Text(period),
          trailing: assignment['is_active'] ? const Text('Active') : const Text('Inactive'),
        ),
      );
    }).toList();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Paid':
        return Colors.green;
      case 'Pending':
        return Colors.orange;
      case 'Approved':
        return Colors.blue;
      case 'Rejected':
        return Colors.red;
      case 'Cancelled':
        return Colors.grey;
      default:
        return Colors.purple;
    }
  }

  void _showSalaryHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _DetailListScreen(
          title: 'Salary History',
          conductor: widget.conductor,
          fetchData: () async {
            return await supabase
                .from('conductor_salaries')
                .select()
                .eq('conductor_id', widget.conductor['id'])
                .order('pay_period_end', ascending: false);
          },
          itemBuilder: (context, item) {
            final period = '${DateFormat('MMM dd').format(DateTime.parse(item['pay_period_start']))} - ${DateFormat('MMM dd, yyyy').format(DateTime.parse(item['pay_period_end']))}';
            
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: _getStatusColor(item['payment_status']),
                child: Text(
                  item['payment_status'].substring(0, 1),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text('₱${item['net_amount'].toStringAsFixed(2)}'),
              subtitle: Text(period),
              trailing: Text(item['payment_status']),
            );
          },
        ),
      ),
    );
  }

  void _showAssignments() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _DetailListScreen(
          title: 'Bus Assignments',
          conductor: widget.conductor,
          fetchData: () async {
            return await supabase
                .from('conductor_assignments')
                .select('*, buses(*)')
                .eq('conductor_id', widget.conductor['id'])
                .order('assignment_date', ascending: false);
          },
          itemBuilder: (context, item) {
            final bus = item['buses'];
            final period = item['end_date'] != null 
                ? '${DateFormat('MMM dd, yyyy').format(DateTime.parse(item['assignment_date']))} - ${DateFormat('MMM dd, yyyy').format(DateTime.parse(item['end_date']))}'
                : 'Since ${DateFormat('MMM dd, yyyy').format(DateTime.parse(item['assignment_date']))}';
            
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: item['is_active'] ? Colors.green : Colors.grey,
                child: const Icon(Icons.directions_bus, color: Colors.white),
              ),
              title: Text('Bus ${bus['bus_number']} - ${bus['plate_number']}'),
              subtitle: Text(period),
              trailing: item['is_active'] ? const Text('Active') : const Text('Inactive'),
            );
          },
        ),
      ),
    );
  }

  void _showCashAdvances() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _DetailListScreen(
          title: 'Cash Advances',
          conductor: widget.conductor,
          fetchData: () async {
            return await supabase
                .from('conductor_cash_advances')
                .select()
                .eq('conductor_id', widget.conductor['id'])
                .order('date_requested', ascending: false);
          },
          itemBuilder: (context, item) {
            final requestDate = DateFormat('MMM dd, yyyy').format(DateTime.parse(item['date_requested']));
            
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: _getStatusColor(item['status']),
                child: const Icon(Icons.attach_money, color: Colors.white),
              ),
              title: Text('₱${item['amount'].toStringAsFixed(2)}'),
              subtitle: Text('Requested on $requestDate\n${item['notes'] ?? ''}'),
              isThreeLine: true,
              trailing: Text(item['status']),
            );
          },
        ),
      ),
    );
  }

  void _showDeductions() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _DetailListScreen(
          title: 'Deductions',
          conductor: widget.conductor,
          fetchData: () async {
            return await supabase
                .from('conductor_deductions')
                .select()
                .eq('conductor_id', widget.conductor['id'])
                .order('deduction_date', ascending: false);
          },
          itemBuilder: (context, item) {
            final deductionDate = DateFormat('MMM dd, yyyy').format(DateTime.parse(item['deduction_date']));
            
            return ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.red,
                child: Icon(Icons.money_off, color: Colors.white),
              ),
              title: Text('₱${item['amount'].toStringAsFixed(2)} - ${item['deduction_type']}'),
              subtitle: Text('$deductionDate\n${item['description'] ?? ''}'),
              isThreeLine: true,
            );
          },
        ),
      ),
    );
  }

  void _showBonuses() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _DetailListScreen(
          title: 'Bonuses & Incentives',
          conductor: widget.conductor,
          fetchData: () async {
            return await supabase
                .from('conductor_bonuses')
                .select()
                .eq('conductor_id', widget.conductor['id'])
                .order('bonus_date', ascending: false);
          },
          itemBuilder: (context, item) {
            final bonusDate = DateFormat('MMM dd, yyyy').format(DateTime.parse(item['bonus_date']));
            
            return ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.green,
                child: Icon(Icons.card_giftcard, color: Colors.white),
              ),
              title: Text('₱${item['amount'].toStringAsFixed(2)} - ${item['bonus_type']}'),
              subtitle: Text('$bonusDate\n${item['description'] ?? ''}'),
              isThreeLine: true,
            );
          },
        ),
      ),
    );
  }

  void _showUpcomingSalary() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _DetailListScreen(
          title: 'Upcoming Salary',
          conductor: widget.conductor,
          fetchData: () async {
            // Get current date
            final now = DateTime.now();
            // Format for query
            final nowStr = DateFormat('yyyy-MM-dd').format(now);
            
            return await supabase
                .from('conductor_salaries')
                .select()
                .eq('conductor_id', widget.conductor['id'])
                .gte('payment_date', nowStr)
                .eq('payment_status', 'Pending')
                .order('payment_date');
          },
          itemBuilder: (context, item) {
            final paymentDate = DateFormat('MMM dd, yyyy').format(DateTime.parse(item['payment_date']));
            final period = '${DateFormat('MMM dd').format(DateTime.parse(item['pay_period_start']))} - ${DateFormat('MMM dd').format(DateTime.parse(item['pay_period_end']))}';
            
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.orange,
                child: const Icon(Icons.calendar_today, color: Colors.white),
              ),
              title: Text('₱${item['net_amount'].toStringAsFixed(2)}'),
              subtitle: Text('Payment on $paymentDate\nPeriod: $period'),
              isThreeLine: true,
            );
          },
          emptyMessage: 'No upcoming salary payments scheduled.',
        ),
      ),
    );
  }

  void _show13thMonth() {
    final currentYear = DateTime.now().year;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('13th month pay for $currentYear will be available at the end of the year')),
    );
  }
}

// Generic detail list screen for showing various conductor data
class _DetailListScreen extends StatefulWidget {
  final String title;
  final Map<String, dynamic> conductor;
  final Future<List<Map<String, dynamic>>> Function() fetchData;
  final Widget Function(BuildContext, Map<String, dynamic>) itemBuilder;
  final String emptyMessage;

  const _DetailListScreen({
    Key? key,
    required this.title,
    required this.conductor,
    required this.fetchData,
    required this.itemBuilder,
    this.emptyMessage = 'No data found',
  }) : super(key: key);

  @override
  State<_DetailListScreen> createState() => _DetailListScreenState();
}

class _DetailListScreenState extends State<_DetailListScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _data = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final data = await widget.fetchData();
      setState(() {
        _data = data;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.conductor['profiles'];
    final fullName = '${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}';
    
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.title} - $fullName'),
        backgroundColor: const Color(0xFF2F27CE),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _data.isEmpty
              ? Center(child: Text(widget.emptyMessage))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _data.length,
                  itemBuilder: (context, index) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: widget.itemBuilder(context, _data[index]),
                    );
                  },
                ),
    );
  }
}