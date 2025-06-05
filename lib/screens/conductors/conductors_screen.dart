import 'package:flutter/material.dart';
import 'package:bus_management/config/supabase_config.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class ConductorsScreen extends StatefulWidget {
  const ConductorsScreen({super.key});

  @override
  State<ConductorsScreen> createState() => _ConductorsScreenState();
}

class _ConductorsScreenState extends State<ConductorsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _conductors = [];
  List<Map<String, dynamic>> _salaryForecast = [];
  List<Map<String, dynamic>> _assignments = [];
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _licenseController = TextEditingController();
  final _salaryController = TextEditingController();
  DateTime _employmentDate = DateTime.now();
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadConductors();
    _loadUpcomingSalaries();
    _loadAssignments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _licenseController.dispose();
    _salaryController.dispose();
    super.dispose();
  }

  Future<void> _loadConductors() async {
    try {
      final data = await supabase
          .from('conductors')
          .select('*, profiles(*)')
          .order('created_at', ascending: false);
      
      setState(() {
        _conductors = data;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading conductors: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUpcomingSalaries() async {
    try {
      // Get current date
      final now = DateTime.now();
      // Calculate 15 days from now
      final fifteenDaysFromNow = DateTime(now.year, now.month, now.day + 15);
      
      // Format dates for query
      final nowStr = DateFormat('yyyy-MM-dd').format(now);
      final futureStr = DateFormat('yyyy-MM-dd').format(fifteenDaysFromNow);

      final data = await supabase
          .from('conductor_salaries')
          .select('*, conductors(*, profiles(*))')
          .gte('payment_date', nowStr)
          .lte('payment_date', futureStr)
          .eq('payment_status', 'Pending')
          .order('payment_date');
      
      setState(() {
        _salaryForecast = data;
      });
    } catch (e) {
      print('Error loading upcoming salaries: $e');
    }
  }

  Future<void> _loadAssignments() async {
    try {
      final data = await supabase
          .from('conductor_assignments')
          .select('*, conductors(*, profiles(*)), buses(*), drivers(*, profiles(*))')
          .eq('is_active', true)
          .order('assignment_date', ascending: false);
      
      setState(() {
        _assignments = data;
      });
    } catch (e) {
      print('Error loading assignments: $e');
    }
  }

  Future<void> _addConductor(Map<String, dynamic> conductorData) async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      // Create a new auth user
      final email = '${conductorData['first_name'].toLowerCase()}.${conductorData['last_name'].toLowerCase()}.${DateTime.now().millisecondsSinceEpoch}@example.com';
      final password = 'Conductor${DateTime.now().millisecondsSinceEpoch}';
      
      final authResponse = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'first_name': conductorData['first_name'],
          'last_name': conductorData['last_name'],
          'role': 'conductor'
        },
      );
      
      if (authResponse.user == null) {
        throw Exception('Failed to create user account');
      }
      
      // The profile will be created automatically by the database trigger
      final userId = authResponse.user!.id;
      
      // Get the profile_id
      final profileData = await supabase
          .from('profiles')
          .select('id')
          .eq('id', userId)
          .single();
      
      // Then create the conductor with the user ID and profile ID
      final newConductor = {
        'id': userId,
        'profile_id': profileData['id'],
        'license_number': conductorData['license_number'],
        'employment_date': conductorData['employment_date'],
        'employment_status': 'Active',
        'base_salary': conductorData['base_salary'],
        'phone_number': conductorData['phone_number'],
      };
      
      await supabase
          .from('conductors')
          .insert(newConductor);
      
      // Refresh the list
      _loadConductors();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conductor added successfully!')),
      );
    } catch (e) {
      print('Error adding conductor: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding conductor: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateConductor(String id, Map<String, dynamic> data) async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      // Update the conductor
      await supabase
          .from('conductors')
          .update({
            'license_number': data['license_number'],
            'employment_status': data['employment_status'],
            'base_salary': data['base_salary'],
            'phone_number': data['phone_number'],
          })
          .eq('id', id);
      
      // If there's a profile update
      if (data['profile_id'] != null) {
        await supabase
            .from('profiles')
            .update({
              'first_name': data['first_name'],
              'last_name': data['last_name'],
            })
            .eq('id', data['profile_id']);
      }
      
      // Refresh the list
      _loadConductors();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conductor updated successfully!')),
      );
    } catch (e) {
      print('Error updating conductor: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating conductor: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _loadSalaryHistory(String conductorId) async {
    try {
      final data = await supabase
          .from('conductor_salaries')
          .select()
          .eq('conductor_id', conductorId)
          .order('pay_period_end', ascending: false);
      
      return data;
    } catch (e) {
      print('Error loading salary history: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _loadConductorAssignments(String conductorId) async {
    try {
      final data = await supabase
          .from('conductor_assignments')
          .select('*, buses(*)')
          .eq('conductor_id', conductorId)
          .order('assignment_date', ascending: false);
      
      return data;
    } catch (e) {
      print('Error loading conductor assignments: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _loadCashAdvances(String conductorId) async {
    try {
      final data = await supabase
          .from('conductor_cash_advances')
          .select()
          .eq('conductor_id', conductorId)
          .order('date_requested', ascending: false);
      
      return data;
    } catch (e) {
      print('Error loading cash advances: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _loadDeductions(String conductorId) async {
    try {
      final data = await supabase
          .from('conductor_deductions')
          .select()
          .eq('conductor_id', conductorId)
          .order('deduction_date', ascending: false);
      
      return data;
    } catch (e) {
      print('Error loading deductions: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _loadBonuses(String conductorId) async {
    try {
      final data = await supabase
          .from('conductor_bonuses')
          .select()
          .eq('conductor_id', conductorId)
          .order('bonus_date', ascending: false);
      
      return data;
    } catch (e) {
      print('Error loading bonuses: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> _load13thMonthSummary(String conductorId, int year) async {
    try {
      final data = await supabase
          .from('conductor_13th_month')
          .select()
          .eq('conductor_id', conductorId)
          .eq('year', year)
          .maybeSingle();
      
      return data;
    } catch (e) {
      print('Error loading 13th month summary: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Conductors Management',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: const Color(0xFF2F27CE),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'All Conductors'),
            Tab(text: 'Financial'),
            Tab(text: 'Assignments'),
          ],
          labelColor: Colors.white,
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddConductorDialog,
        backgroundColor: const Color(0xFF2F27CE),
        child: const Icon(Icons.add),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildConductorsList(),
          _buildFinancialTab(),
          _buildAssignmentsTab(),
        ],
      ),
    );
  }

  Widget _buildConductorsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_conductors.isEmpty) {
      return const Center(
        child: Text('No conductors found. Add your first conductor!'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _conductors.length,
      itemBuilder: (context, index) {
        final conductor = _conductors[index];
        // Add null check before accessing profile
        final profile = conductor['profiles'] ?? {};
        // Use safe null-aware operators for first_name and last_name
        final fullName = '${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}';
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFDEDCFF),
              child: Text(
                fullName.isNotEmpty ? fullName[0] : '?',
                style: const TextStyle(color: Color(0xFF2F27CE)),
              ),
            ),
            title: Text(fullName),
            subtitle: Text(conductor['phone_number'] ?? 'No phone number'),
            trailing: PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Text('Edit'),
                ),
                const PopupMenuItem(
                  value: 'view_salary',
                  child: Text('View Salary History'),
                ),
                const PopupMenuItem(
                  value: 'view_assignments',
                  child: Text('View Assignments'),
                ),
                const PopupMenuItem(
                  value: 'cash_advance',
                  child: Text('Cash Advance'),
                ),
                const PopupMenuItem(
                  value: 'deductions',
                  child: Text('Deductions'),
                ),
                const PopupMenuItem(
                  value: 'bonuses',
                  child: Text('Bonuses'),
                ),
              ],
              onSelected: (value) {
                _handleConductorAction(value, conductor);
              },
            ),
            onTap: () {
              _showConductorDetails(conductor);
            },
          ),
        );
      },
    );
  }

  Widget _buildFinancialTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.calendar_today, color: Color(0xFF2F27CE)),
              title: const Text('15-Day Upcoming Salaries'),
              subtitle: const Text('View upcoming payments'),
              onTap: () {
                _showUpcomingSalaries();
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.attach_money, color: Color(0xFF2F27CE)),
              title: const Text('Cash Advances'),
              subtitle: const Text('Manage cash advances'),
              onTap: () {
                _showAllCashAdvances();
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.money_off, color: Color(0xFF2F27CE)),
              title: const Text('Deductions'),
              subtitle: const Text('Manage salary deductions'),
              onTap: () {
                _showAllDeductions();
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.card_giftcard, color: Color(0xFF2F27CE)),
              title: const Text('Bonuses & Incentives'),
              subtitle: const Text('Manage bonuses and incentives'),
              onTap: () {
                _showAllBonuses();
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.summarize, color: Color(0xFF2F27CE)),
              title: const Text('13th Month Summary'),
              subtitle: const Text('View 13th month payment summary'),
              onTap: () {
                _show13thMonthSummary();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentsTab() {
    if (_assignments.isEmpty) {
      return const Center(
        child: Text('No active assignments found.'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _assignments.length,
      itemBuilder: (context, index) {
        final assignment = _assignments[index];
        final conductor = assignment['conductors']['profiles'];
        final bus = assignment['buses'];
        final driver = assignment['drivers']?['profiles'];
        
        final conductorName = '${conductor['first_name'] ?? ''} ${conductor['last_name'] ?? ''}';
        final driverName = driver != null ? 
            '${driver['first_name'] ?? ''} ${driver['last_name'] ?? ''}' : 
            'Not assigned';
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFDEDCFF),
              child: Icon(Icons.directions_bus, color: Color(0xFF2F27CE)),
            ),
            title: Text('Bus ${bus['bus_number']} - ${bus['plate_number']}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Conductor: $conductorName'),
                Text('Driver: $driverName'),
                Text('Assigned: ${DateFormat('MMM dd, yyyy').format(DateTime.parse(assignment['assignment_date']))}'),
              ],
            ),
            isThreeLine: true,
            onTap: () {
              _showAssignmentDetails(assignment);
            },
          ),
        );
      },
    );
  }

  void _showAddConductorDialog() {
    _nameController.clear();
    _phoneController.clear();
    _licenseController.clear();
    _salaryController.clear();
    _employmentDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add New Conductor'),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Full Name'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter the conductor\'s name';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(labelText: 'Phone Number'),
                    keyboardType: TextInputType.phone,
                  ),
                  TextFormField(
                    controller: _licenseController,
                    decoration: const InputDecoration(labelText: 'License Number'),
                  ),
                  TextFormField(
                    controller: _salaryController,
                    decoration: const InputDecoration(labelText: 'Base Salary'),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter base salary';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('Employment Date'),
                    subtitle: Text(DateFormat('MMM dd, yyyy').format(_employmentDate)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _employmentDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() {
                          _employmentDate = date;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  final name = _nameController.text.trim();
                  final nameParts = name.split(' ');
                  final firstName = nameParts.first;
                  final lastName = nameParts.length > 1 
                      ? nameParts.sublist(1).join(' ') 
                      : '';
                  
                  final conductorData = {
                    'first_name': firstName,
                    'last_name': lastName,
                    'phone_number': _phoneController.text.trim(),
                    'license_number': _licenseController.text.trim(),
                    'base_salary': double.parse(_salaryController.text.trim()),
                    'employment_date': DateFormat('yyyy-MM-dd').format(_employmentDate),
                  };
                  
                  _addConductor(conductorData);
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _showConductorDetails(Map<String, dynamic> conductor) {
    final profile = conductor['profiles'];
    final fullName = '${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}';
    final employmentDate = conductor['employment_date'] != null 
        ? DateFormat('MMM dd, yyyy').format(DateTime.parse(conductor['employment_date'])) 
        : 'Not set';
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(fullName),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                leading: const Icon(Icons.phone),
                title: const Text('Phone'),
                subtitle: Text(conductor['phone_number'] ?? 'Not provided'),
              ),
              ListTile(
                leading: const Icon(Icons.badge),
                title: const Text('License'),
                subtitle: Text(conductor['license_number'] ?? 'Not provided'),
              ),
              ListTile(
                leading: const Icon(Icons.work),
                title: const Text('Employment Date'),
                subtitle: Text(employmentDate),
              ),
              ListTile(
                leading: const Icon(Icons.attach_money),
                title: const Text('Base Salary'),
                subtitle: Text('₱${conductor['base_salary'].toStringAsFixed(2)}'),
              ),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Status'),
                subtitle: Text(conductor['employment_status'] ?? 'Active'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showEditConductorDialog(conductor);
              },
              child: const Text('Edit'),
            ),
          ],
        );
      },
    );
  }
  
  void _showEditConductorDialog(Map<String, dynamic> conductor) {
    final profile = conductor['profiles'];
    _nameController.text = '${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}';
    _phoneController.text = conductor['phone_number'] ?? '';
    _licenseController.text = conductor['license_number'] ?? '';
    _salaryController.text = conductor['base_salary'].toString();
    _employmentDate = conductor['employment_date'] != null 
        ? DateTime.parse(conductor['employment_date']) 
        : DateTime.now();

    final employmentStatus = conductor['employment_status'] ?? 'Active';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Conductor'),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Full Name'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter the conductor\'s name';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(labelText: 'Phone Number'),
                    keyboardType: TextInputType.phone,
                  ),
                  TextFormField(
                    controller: _licenseController,
                    decoration: const InputDecoration(labelText: 'License Number'),
                  ),
                  TextFormField(
                    controller: _salaryController,
                    decoration: const InputDecoration(labelText: 'Base Salary'),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter base salary';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                  ),
                  DropdownButtonFormField<String>(
                    value: employmentStatus,
                    decoration: const InputDecoration(labelText: 'Employment Status'),
                    items: ['Active', 'Inactive', 'On Leave', 'Terminated']
                        .map((status) => DropdownMenuItem(
                              value: status,
                              child: Text(status),
                            ))
                        .toList(),
                    onChanged: (value) {},
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  final name = _nameController.text.trim();
                  final nameParts = name.split(' ');
                  final firstName = nameParts.first;
                  final lastName = nameParts.length > 1 
                      ? nameParts.sublist(1).join(' ') 
                      : '';
                  
                  final conductorData = {
                    'profile_id': profile['id'],
                    'first_name': firstName,
                    'last_name': lastName,
                    'phone_number': _phoneController.text.trim(),
                    'license_number': _licenseController.text.trim(),
                    'base_salary': double.parse(_salaryController.text.trim()),
                    'employment_status': employmentStatus,
                  };
                  
                  _updateConductor(conductor['id'], conductorData);
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _handleConductorAction(String action, Map<String, dynamic> conductor) {
    final profile = conductor['profiles'];
    final fullName = '${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}';

    switch (action) {
      case 'edit':
        _showEditConductorDialog(conductor);
        break;
      case 'view_salary':
        _showSalaryHistory(conductor['id'], fullName);
        break;
      case 'view_assignments':
        _showConductorAssignments(conductor['id'], fullName);
        break;
      case 'cash_advance':
        _showCashAdvances(conductor['id'], fullName);
        break;
      case 'deductions':
        _showDeductions(conductor['id'], fullName);
        break;
      case 'bonuses':
        _showBonuses(conductor['id'], fullName);
        break;
    }
  }

  void _showSalaryHistory(String conductorId, String conductorName) async {
    // Show a loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    
    final salaryHistory = await _loadSalaryHistory(conductorId);
    
    // Pop the loading dialog
    if (context.mounted) Navigator.of(context).pop();
    
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Salary History - $conductorName'),
          content: SizedBox(
            width: double.maxFinite,
            child: salaryHistory.isEmpty
                ? const Center(child: Text('No salary records found.'))
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: salaryHistory.length,
                    itemBuilder: (context, index) {
                      final salary = salaryHistory[index];
                      final period = '${DateFormat('MMM dd').format(DateTime.parse(salary['pay_period_start']))} - ${DateFormat('MMM dd, yyyy').format(DateTime.parse(salary['pay_period_end']))}';
                      
                      return ListTile(
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
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showAddSalaryDialog(conductorId, conductorName);
              },
              child: const Text('Add Salary Entry'),
            ),
          ],
        );
      },
    );
  }

  void _showConductorAssignments(String conductorId, String conductorName) async {
    // Show a loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    
    final assignments = await _loadConductorAssignments(conductorId);
    
    // Pop the loading dialog
    if (context.mounted) Navigator.of(context).pop();
    
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Bus Assignments - $conductorName'),
          content: SizedBox(
            width: double.maxFinite,
            child: assignments.isEmpty
                ? const Center(child: Text('No assignments found.'))
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: assignments.length,
                    itemBuilder: (context, index) {
                      final assignment = assignments[index];
                      final bus = assignment['buses'];
                      final period = assignment['end_date'] != null 
                          ? '${DateFormat('MMM dd, yyyy').format(DateTime.parse(assignment['assignment_date']))} - ${DateFormat('MMM dd, yyyy').format(DateTime.parse(assignment['end_date']))}'
                          : 'Since ${DateFormat('MMM dd, yyyy').format(DateTime.parse(assignment['assignment_date']))}';
                      
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: assignment['is_active'] ? Colors.green : Colors.grey,
                          child: const Icon(Icons.directions_bus, color: Colors.white),
                        ),
                        title: Text('Bus ${bus['bus_number']} - ${bus['plate_number']}'),
                        subtitle: Text(period),
                        trailing: assignment['is_active'] ? const Text('Active') : const Text('Inactive'),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showCashAdvances(String conductorId, String conductorName) async {
    // Show a loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    
    final cashAdvances = await _loadCashAdvances(conductorId);
    
    // Pop the loading dialog
    if (context.mounted) Navigator.of(context).pop();
    
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Cash Advances - $conductorName'),
          content: SizedBox(
            width: double.maxFinite,
            child: cashAdvances.isEmpty
                ? const Center(child: Text('No cash advances found.'))
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: cashAdvances.length,
                    itemBuilder: (context, index) {
                      final cashAdvance = cashAdvances[index];
                      final requestDate = DateFormat('MMM dd, yyyy').format(DateTime.parse(cashAdvance['date_requested']));
                      
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getStatusColor(cashAdvance['status']),
                          child: const Icon(Icons.attach_money, color: Colors.white),
                        ),
                        title: Text('₱${cashAdvance['amount'].toStringAsFixed(2)}'),
                        subtitle: Text('Requested on $requestDate'),
                        trailing: Text(cashAdvance['status']),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showAddCashAdvanceDialog(conductorId, conductorName);
              },
              child: const Text('Add Cash Advance'),
            ),
          ],
        );
      },
    );
  }

  void _showDeductions(String conductorId, String conductorName) async {
    // Show a loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    
    final deductions = await _loadDeductions(conductorId);
    
    // Pop the loading dialog
    if (context.mounted) Navigator.of(context).pop();
    
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Deductions - $conductorName'),
          content: SizedBox(
            width: double.maxFinite,
            child: deductions.isEmpty
                ? const Center(child: Text('No deductions found.'))
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: deductions.length,
                    itemBuilder: (context, index) {
                      final deduction = deductions[index];
                      final deductionDate = DateFormat('MMM dd, yyyy').format(DateTime.parse(deduction['deduction_date']));
                      
                      return ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.red,
                          child: Icon(Icons.money_off, color: Colors.white),
                        ),
                        title: Text('₱${deduction['amount'].toStringAsFixed(2)} - ${deduction['deduction_type']}'),
                        subtitle: Text('$deductionDate\n${deduction['description']}'),
                        isThreeLine: true,
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showAddDeductionDialog(conductorId, conductorName);
              },
              child: const Text('Add Deduction'),
            ),
          ],
        );
      },
    );
  }

  void _showBonuses(String conductorId, String conductorName) async {
    // Show a loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    
    final bonuses = await _loadBonuses(conductorId);
    
    // Pop the loading dialog
    if (context.mounted) Navigator.of(context).pop();
    
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Bonuses & Incentives - $conductorName'),
          content: SizedBox(
            width: double.maxFinite,
            child: bonuses.isEmpty
                ? const Center(child: Text('No bonuses found.'))
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: bonuses.length,
                    itemBuilder: (context, index) {
                      final bonus = bonuses[index];
                      final bonusDate = DateFormat('MMM dd, yyyy').format(DateTime.parse(bonus['bonus_date']));
                      
                      return ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.green,
                          child: Icon(Icons.card_giftcard, color: Colors.white),
                        ),
                        title: Text('₱${bonus['amount'].toStringAsFixed(2)} - ${bonus['bonus_type']}'),
                        subtitle: Text('$bonusDate\n${bonus['description']}'),
                        isThreeLine: true,
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showAddBonusDialog(conductorId, conductorName);
              },
              child: const Text('Add Bonus'),
            ),
          ],
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _loadAllBonuses() async {
    try {
      final data = await supabase
          .from('conductor_bonuses')
          .select('*, conductors(*, profiles(*))')
          .order('bonus_date', ascending: false);
      
      return data;
    } catch (e) {
      print('Error loading all bonuses: $e');
      return [];
    }
  }

  void _showUpcomingSalaries() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('15-Day Upcoming Salaries'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: _salaryForecast.isEmpty
                ? const Center(child: Text('No upcoming salary payments scheduled.'))
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _salaryForecast.length,
                    itemBuilder: (context, index) {
                      final salary = _salaryForecast[index];
                      final conductor = salary['conductors'];
                      final profile = conductor['profiles'];
                      final fullName = '${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}';
                      final paymentDate = DateFormat('MMM dd, yyyy').format(DateTime.parse(salary['payment_date']));
                      
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFDEDCFF),
                          child: Text(
                            fullName.isNotEmpty ? fullName[0] : '?',
                            style: const TextStyle(color: Color(0xFF2F27CE)),
                          ),
                        ),
                        title: Text(fullName),
                        subtitle: Text('Payment Date: $paymentDate'),
                        trailing: Text('₱${salary['net_amount'].toStringAsFixed(2)}'),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // Add this method to load all deductions
  Future<List<Map<String, dynamic>>> _loadAllDeductions() async {
    try {
      final data = await supabase
          .from('conductor_deductions')
          .select('*, conductors(*, profiles(*))')
          .order('deduction_date', ascending: false);
      
      return data;
    } catch (e) {
      print('Error loading all deductions: $e');
      return [];
    }
  }

  // Replace the existing _showAllDeductions method with this one
  void _showAllDeductions() async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    
    // Load all deductions
    final allDeductions = await _loadAllDeductions();
    
    // Dismiss loading indicator
    if (context.mounted) Navigator.of(context).pop();
    
    if (!context.mounted) return;
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('All Deductions'),
          content: SizedBox(
            width: double.maxFinite,
            height: 500,
            child: allDeductions.isEmpty
                ? const Center(child: Text('No deductions found.'))
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: allDeductions.length,
                    itemBuilder: (context, index) {
                      final deduction = allDeductions[index];
                      final conductor = deduction['conductors'];
                      final profile = conductor['profiles'];
                      final fullName = '${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}';
                      final deductionDate = DateFormat('MMM dd, yyyy').format(DateTime.parse(deduction['deduction_date']));
                      
                      return ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.red,
                          child: Icon(Icons.money_off, color: Colors.white),
                        ),
                        title: Text('₱${deduction['amount'].toStringAsFixed(2)} - ${deduction['deduction_type']}'),
                        subtitle: Text('$fullName\n$deductionDate\n${deduction['description'] ?? ''}'),
                        isThreeLine: true,
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showAllBonuses() async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    
    // Load all bonuses
    final allBonuses = await _loadAllBonuses();
    
    // Dismiss loading indicator
    if (context.mounted) Navigator.of(context).pop();
    
    if (!context.mounted) return;
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('All Bonuses'),
          content: SizedBox(
            width: double.maxFinite,
            height: 500,
            child: allBonuses.isEmpty
                ? const Center(child: Text('No bonuses found.'))
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: allBonuses.length,
                    itemBuilder: (context, index) {
                      final bonus = allBonuses[index];
                      final conductor = bonus['conductors'];
                      final profile = conductor['profiles'];
                      final fullName = '${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}';
                      final bonusDate = DateFormat('MMM dd, yyyy').format(DateTime.parse(bonus['bonus_date']));
                      
                      return ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.green,
                          child: Icon(Icons.card_giftcard, color: Colors.white),
                        ),
                        title: Text('₱${bonus['amount'].toStringAsFixed(2)} - ${bonus['bonus_type']}'),
                        subtitle: Text('$fullName\n$bonusDate\n${bonus['description'] ?? ''}'),
                        isThreeLine: true,
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _show13thMonthSummary() {
    final currentYear = DateTime.now().year;
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('13th Month Summary - $currentYear'),
          content: const Center(
            child: Text('13th month pay calculation will be available at the end of the year.'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showAssignmentDetails(Map<String, dynamic> assignment) {
    final conductor = assignment['conductors']['profiles'];
    final bus = assignment['buses'];
    final driver = assignment['drivers']?['profiles'];
    
    final conductorName = '${conductor['first_name'] ?? ''} ${conductor['last_name'] ?? ''}';
    final driverName = driver != null ? 
        '${driver['first_name'] ?? ''} ${driver['last_name'] ?? ''}' : 
        'Not assigned';
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Assignment Details'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                leading: const Icon(Icons.directions_bus),
                title: const Text('Bus'),
                subtitle: Text('${bus['bus_number']} - ${bus['plate_number']}'),
              ),
              ListTile(
                leading: const Icon(Icons.person_add),
                title: const Text('Conductor'),
                subtitle: Text(conductorName),
              ),
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('Driver'),
                subtitle: Text(driverName),
              ),
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Assignment Date'),
                subtitle: Text(DateFormat('MMM dd, yyyy').format(DateTime.parse(assignment['assignment_date']))),
              ),
              if (assignment['end_date'] != null)
                ListTile(
                  leading: const Icon(Icons.event),
                  title: const Text('End Date'),
                  subtitle: Text(DateFormat('MMM dd, yyyy').format(DateTime.parse(assignment['end_date']))),
                ),
              ListTile(
                leading: Icon(
                  assignment['is_active'] ? Icons.check_circle : Icons.cancel,
                  color: assignment['is_active'] ? Colors.green : Colors.red,
                ),
                title: const Text('Status'),
                subtitle: Text(assignment['is_active'] ? 'Active' : 'Inactive'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showAddSalaryDialog(String conductorId, String conductorName) {
    final _startDateController = TextEditingController();
    final _endDateController = TextEditingController();
    final _baseAmountController = TextEditingController();
    final _bonusAmountController = TextEditingController(text: '0.00');
    final _deductionAmountController = TextEditingController(text: '0.00');
    final _netAmountController = TextEditingController();
    final _notesController = TextEditingController();
    
    DateTime _startDate = DateTime.now().subtract(const Duration(days: 14));
    DateTime _endDate = DateTime.now();
    DateTime _paymentDate = DateTime.now().add(const Duration(days: 1));
    String _paymentMethod = 'Cash';
    
    _startDateController.text = DateFormat('MMM dd, yyyy').format(_startDate);
    _endDateController.text = DateFormat('MMM dd, yyyy').format(_endDate);
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add Salary Entry - $conductorName'),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text('Pay Period Start'),
                    subtitle: Text(_startDateController.text),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _startDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        _startDate = date;
                        _startDateController.text = DateFormat('MMM dd, yyyy').format(_startDate);
                      }
                    },
                  ),
                  ListTile(
                    title: const Text('Pay Period End'),
                    subtitle: Text(_endDateController.text),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _endDate,
                        firstDate: _startDate,
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        _endDate = date;
                        _endDateController.text = DateFormat('MMM dd, yyyy').format(_endDate);
                      }
                    },
                  ),
                  TextFormField(
                    controller: _baseAmountController,
                    decoration: const InputDecoration(labelText: 'Base Amount'),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter base amount';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      _calculateNetAmount(
                        _baseAmountController.text,
                        _bonusAmountController.text,
                        _deductionAmountController.text,
                        _netAmountController,
                      );
                    },
                  ),
                  TextFormField(
                    controller: _bonusAmountController,
                    decoration: const InputDecoration(labelText: 'Bonus Amount'),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter bonus amount';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      _calculateNetAmount(
                        _baseAmountController.text,
                        _bonusAmountController.text,
                        _deductionAmountController.text,
                        _netAmountController,
                      );
                    },
                  ),
                  TextFormField(
                    controller: _deductionAmountController,
                    decoration: const InputDecoration(labelText: 'Deduction Amount'),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter deduction amount';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      _calculateNetAmount(
                        _baseAmountController.text,
                        _bonusAmountController.text,
                        _deductionAmountController.text,
                        _netAmountController,
                      );
                    },
                  ),
                  TextFormField(
                    controller: _netAmountController,
                    decoration: const InputDecoration(labelText: 'Net Amount'),
                    keyboardType: TextInputType.number,
                    readOnly: true,
                  ),
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(labelText: 'Notes'),
                    maxLines: 2,
                  ),
                  ListTile(
                    title: const Text('Payment Date'),
                    subtitle: Text(DateFormat('MMM dd, yyyy').format(_paymentDate)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _paymentDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2030),
                      );
                      if (date != null) {
                        _paymentDate = date;
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_formKey.currentState!.validate() && _baseAmountController.text.isNotEmpty) {
                  try {
                    // Convert strings to proper types
                    final baseAmount = double.parse(_baseAmountController.text);
                    final bonusAmount = double.parse(_bonusAmountController.text);
                    final deductionAmount = double.parse(_deductionAmountController.text);
                    final netAmount = double.parse(_netAmountController.text);
                    
                    // Format dates for database
                    final startDateStr = DateFormat('yyyy-MM-dd').format(_startDate);
                    final endDateStr = DateFormat('yyyy-MM-dd').format(_endDate);
                    final paymentDateStr = DateFormat('yyyy-MM-dd').format(_paymentDate);
                    
                    // Create the salary data
                    final salaryData = {
                      'conductor_id': conductorId,
                      'pay_period_start': startDateStr,
                      'pay_period_end': endDateStr,
                      'base_amount': baseAmount,
                      'bonus_amount': bonusAmount,
                      'deduction_amount': deductionAmount,
                      'net_amount': netAmount,
                      'payment_date': paymentDateStr,
                      'payment_status': 'Pending',
                      'payment_method': _paymentMethod,
                      'notes': _notesController.text,
                    };
                    
                    // Show a loading indicator
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const Center(child: CircularProgressIndicator()),
                    );
                    
                    // Insert into database
                    await supabase
                      .from('conductor_salaries')
                      .insert(salaryData);
                    
                    // Close loading indicator and dialog
                    if (context.mounted) Navigator.of(context).pop();
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Salary entry added successfully!')),
                    );
                    
                    // Close the form dialog
                    if (context.mounted) Navigator.of(context).pop();
                    
                    // Reload the history data if viewing history
                    _loadUpcomingSalaries();
                  } catch (e) {
                    // Close loading indicator if there's an error
                    if (context.mounted) Navigator.of(context).pop();
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error adding salary entry: $e')),
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
  }

  void _showAddCashAdvanceDialog(String conductorId, String conductorName) {
    final _amountController = TextEditingController();
    final _reasonController = TextEditingController();
    DateTime _requestDate = DateTime.now();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add Cash Advance - $conductorName'),
          content: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _amountController,
                  decoration: const InputDecoration(labelText: 'Amount'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter amount';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _reasonController,
                  decoration: const InputDecoration(labelText: 'Reason for Cash Advance'),
                  maxLines: 2,
                ),
                ListTile(
                  title: const Text('Request Date'),
                  subtitle: Text(DateFormat('MMM dd, yyyy').format(_requestDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _requestDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      _requestDate = date;
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  try {
                    // Show loading indicator
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const Center(child: CircularProgressIndicator()),
                    );
                    
                    // Format the date
                    final requestDateStr = DateFormat('yyyy-MM-dd').format(_requestDate);
                    
                    // Create the cash advance data
                    final cashAdvanceData = {
                      'conductor_id': conductorId,
                      'amount': double.parse(_amountController.text),
                      'date_requested': requestDateStr,
                      'status': 'Pending',
                      'notes': _reasonController.text,
                    };
                    
                    // Insert into database
                    await supabase
                      .from('conductor_cash_advances')
                      .insert(cashAdvanceData);
                    
                    // Close loading indicator
                    if (context.mounted) Navigator.of(context).pop();
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Cash advance request submitted successfully!')),
                    );
                    
                    // Close the form dialog
                    if (context.mounted) Navigator.of(context).pop();
                  } catch (e) {
                    // Close loading indicator if there's an error
                    if (context.mounted) Navigator.of(context).pop();
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error submitting cash advance: $e')),
                    );
                  }
                }
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  void _showAddDeductionDialog(String conductorId, String conductorName) {
    final _amountController = TextEditingController();
    final _typeController = TextEditingController();
    final _descriptionController = TextEditingController();
    DateTime _deductionDate = DateTime.now();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add Deduction - $conductorName'),
          content: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _typeController,
                  decoration: const InputDecoration(labelText: 'Deduction Type'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter deduction type';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _amountController,
                  decoration: const InputDecoration(labelText: 'Amount'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter amount';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 2,
                ),
                ListTile(
                  title: const Text('Deduction Date'),
                  subtitle: Text(DateFormat('MMM dd, yyyy').format(_deductionDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _deductionDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      _deductionDate = date;
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  try {
                    // Show loading indicator
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const Center(child: CircularProgressIndicator()),
                    );
                    
                    // Format the date
                    final deductionDateStr = DateFormat('yyyy-MM-dd').format(_deductionDate);
                    
                    // Create the deduction data
                    final deductionData = {
                      'conductor_id': conductorId,
                      'deduction_type': _typeController.text.trim(),
                      'amount': double.parse(_amountController.text),
                      'deduction_date': deductionDateStr,
                      'description': _descriptionController.text,
                    };
                    
                    // Insert into database
                    await supabase
                      .from('conductor_deductions')
                      .insert(deductionData);
                    
                    // Close loading indicator
                    if (context.mounted) Navigator.of(context).pop();
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Deduction added successfully!')),
                    );
                    
                    // Close the form dialog
                    if (context.mounted) Navigator.of(context).pop();
                  } catch (e) {
                    // Close loading indicator if there's an error
                    if (context.mounted) Navigator.of(context).pop();
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error adding deduction: $e')),
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
  }

  void _showAddBonusDialog(String conductorId, String conductorName) {
    final _amountController = TextEditingController();
    final _typeController = TextEditingController();
    final _descriptionController = TextEditingController();
    DateTime _bonusDate = DateTime.now();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add Bonus - $conductorName'),
          content: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _typeController,
                  decoration: const InputDecoration(labelText: 'Bonus Type'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter bonus type';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _amountController,
                  decoration: const InputDecoration(labelText: 'Amount'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter amount';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 2,
                ),
                ListTile(
                  title: const Text('Bonus Date'),
                  subtitle: Text(DateFormat('MMM dd, yyyy').format(_bonusDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _bonusDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      _bonusDate = date;
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  try {
                    // Show loading indicator
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const Center(child: CircularProgressIndicator()),
                    );
                    
                    // Format the date
                    final bonusDateStr = DateFormat('yyyy-MM-dd').format(_bonusDate);
                    
                    // Create the bonus data
                    final bonusData = {
                      'conductor_id': conductorId,
                      'bonus_type': _typeController.text.trim(),
                      'amount': double.parse(_amountController.text),
                      'bonus_date': bonusDateStr,
                      'description': _descriptionController.text,
                    };
                    
                    // Insert into database
                    await supabase
                      .from('conductor_bonuses')
                      .insert(bonusData);
                    
                    // Close loading indicator
                    if (context.mounted) Navigator.of(context).pop();
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Bonus added successfully!')),
                    );
                    
                    // Close the form dialog
                    if (context.mounted) Navigator.of(context).pop();
                  } catch (e) {
                    // Close loading indicator if there's an error
                    if (context.mounted) Navigator.of(context).pop();
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error adding bonus: $e')),
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
  }

  // Helper method to calculate net amount
  void _calculateNetAmount(
    String baseAmount,
    String bonusAmount,
    String deductionAmount,
    TextEditingController netController,
  ) {
    final base = double.tryParse(baseAmount) ?? 0;
    final bonus = double.tryParse(bonusAmount) ?? 0;
    final deduction = double.tryParse(deductionAmount) ?? 0;
    
    final net = base + bonus - deduction;
    netController.text = net.toStringAsFixed(2);
  }

  // Helper method to get status color
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

  // Add this method to load all cash advances
  Future<List<Map<String, dynamic>>> _loadAllCashAdvances() async {
    try {
      final data = await supabase
          .from('conductor_cash_advances')
          .select('*, conductors(*, profiles(*))')
          .order('date_requested', ascending: false);
      
      return data;
    } catch (e) {
      print('Error loading all cash advances: $e');
      return [];
    }
  }

 // Replace both implementations with this one
void _showAllCashAdvances() async {
  try {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    
    // Load all cash advances
    final allCashAdvances = await _loadAllCashAdvances();
    
    // Dismiss loading indicator
    if (context.mounted) Navigator.of(context).pop();
    
    if (!context.mounted) return;
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('All Cash Advances'),
          content: SizedBox(
            width: double.maxFinite,
            height: 500,
            child: allCashAdvances.isEmpty
                ? const Center(child: Text('No cash advances found.'))
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: allCashAdvances.length,
                    itemBuilder: (context, index) {
                      final advance = allCashAdvances[index];
                      final conductor = advance['conductors'];
                      final profile = conductor['profiles'];
                      final fullName = '${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}';
                      final requestDate = DateFormat('MMM dd, yyyy').format(DateTime.parse(advance['date_requested']));
                      
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getStatusColor(advance['status']),
                          child: const Icon(Icons.attach_money, color: Colors.white),
                        ),
                        title: Text('₱${advance['amount'].toStringAsFixed(2)} - ${advance['status']}'),
                        subtitle: Text('$fullName\n$requestDate\n${advance['notes'] ?? ''}'),
                        isThreeLine: true,
                        trailing: advance['status'] == 'Pending' 
                            ? IconButton(
                                icon: const Icon(Icons.check_circle_outline),
                                onPressed: () => _showApproveAdvanceDialog(advance),
                              )
                            : null,
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  } catch (e) {
    // Handle any errors by dismissing loading dialog and showing error
    if (context.mounted) Navigator.of(context).pop(); // Dismiss loading dialog
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error loading cash advances: $e')),
    );
  }
}

  // Add this method to approve cash advances
  void _showApproveAdvanceDialog(Map<String, dynamic> advance) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Approve Cash Advance'),
          content: const Text('Do you want to approve this cash advance request?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  // Show loading indicator
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const Center(child: CircularProgressIndicator()),
                  );
                  
                  // Update the cash advance status
                  await supabase
                    .from('conductor_cash_advances')
                    .update({
                      'status': 'Approved',
                      'date_approved': DateFormat('yyyy-MM-dd').format(DateTime.now()),
                      'approved_by': supabase.auth.currentUser!.id,
                    })
                    .eq('id', advance['id']);
                  
                  // Close loading indicator
                  if (context.mounted) Navigator.of(context).pop();
                  if (context.mounted) Navigator.of(context).pop();
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cash advance approved successfully!')),
                  );
                  
                  // Refresh the cash advances list
                  _showAllCashAdvances();
                  
                } catch (e) {
                  // Close loading indicator if there's an error
                  if (context.mounted) Navigator.of(context).pop();
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error approving cash advance: $e')),
                  );
                }
              },
              child: const Text('Approve'),
            ),
          ],
        );
      },
    );
  }
}