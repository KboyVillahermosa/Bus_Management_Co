import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/driver.dart';

class DriverDetailScreen extends StatefulWidget {
  final Driver driver;
  
  const DriverDetailScreen({Key? key, required this.driver}) : super(key: key);

  @override
  _DriverDetailScreenState createState() => _DriverDetailScreenState();
}

class _DriverDetailScreenState extends State<DriverDetailScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  
  // Add these controllers for forms
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _dateController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String _selectedDeductionType = 'SSS';
  String _selectedBonusType = 'Performance';
  String _selectedCashAdvanceStatus = 'Pending';
  
  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _dateController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.driver.name),
        backgroundColor: const Color(0xFF2F27CE),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Driver Info Card
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
                          widget.driver.name.substring(0, 1),
                          style: const TextStyle(
                            fontSize: 40,
                            color: Color(0xFF2F27CE),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _infoRow('Name', widget.driver.name),
                    _infoRow('Contact', widget.driver.contactNumber),
                    _infoRow('License No', widget.driver.licenseNumber),
                    _infoRow('License Expiry', 
                        DateFormat('MMM dd, yyyy').format(widget.driver.licenseExpiry)),
                    _infoRow('Base Salary', 
                        NumberFormat.currency(symbol: '₱').format(widget.driver.baseSalary)),
                    _infoRow('Hire Date', 
                        DateFormat('MMM dd, yyyy').format(widget.driver.hireDate)),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            const Text(
              'Driver Actions',
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
                _actionCard('Salary History', Icons.history, Colors.blue, () => _viewSalaryHistory()),
                _actionCard('Bus Assignments', Icons.directions_bus, Colors.green, () => _viewBusAssignments()),
                _actionCard('Upcoming Salary', Icons.calendar_today, Colors.orange, () => _viewUpcomingSalary()),
                _actionCard('Cash Advances', Icons.money, Colors.red, () => _viewCashAdvances()),
                _actionCard('Deductions', Icons.remove_circle, Colors.purple, () => _viewDeductions()),
                _actionCard('Bonuses', Icons.add_circle, Colors.teal, () => _viewBonuses()),
                _actionCard('13th Month', Icons.card_giftcard, Colors.amber, () => _view13thMonth()),
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

  // Action methods
  void _viewSalaryHistory() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final data = await _supabase
          .from('salary_payments')  // Changed from driver_salaries
          .select()
          .eq('driver_id', widget.driver.id)
          .order('payment_date', ascending: false);  // Changed from pay_period_end
      
      if (!mounted) return;
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => _DetailListScreen(
            title: 'Salary History',
            driverName: widget.driver.name,
            data: data,
            itemBuilder: (context, item) {
              final paymentDate = DateFormat('MMM dd, yyyy').format(DateTime.parse(item['payment_date']));
              
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: const Icon(Icons.payment, color: Colors.white),
                ),
                title: Text('₱${item['amount'].toStringAsFixed(2)}'),
                subtitle: Text('Payment on $paymentDate\n${item['payment_type'] ?? ''}'),
                isThreeLine: true,
                trailing: Text(item['payment_type'] ?? 'Salary'),
              );
            },
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading salary history: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _viewBusAssignments() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final data = await _supabase
          .from('bus_assignments')  // Changed from driver_assignments
          .select('*, bus_units(*)')
          .eq('driver_id', widget.driver.id)
          .order('assignment_date', ascending: false);
      
      if (!mounted) return;
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => _DetailListScreen(
            title: 'Bus Assignments',
            driverName: widget.driver.name,
            data: data,
            itemBuilder: (context, item) {
              final bus = item['bus_units'];
              final period = item['end_date'] != null 
                  ? '${DateFormat('MMM dd, yyyy').format(DateTime.parse(item['assignment_date']))} - ${DateFormat('MMM dd, yyyy').format(DateTime.parse(item['end_date']))}'
                  : 'Since ${DateFormat('MMM dd, yyyy').format(DateTime.parse(item['assignment_date']))}';
              
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: item['is_active'] ? Colors.green : Colors.grey,
                  child: const Icon(Icons.directions_bus, color: Colors.white),
                ),
                title: Text('Bus #${bus['id']} - ${bus['plate_number']}'),
                subtitle: Text(period),
                trailing: item['is_active'] ? const Text('Active') : const Text('Inactive'),
              );
            },
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading bus assignments: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _viewUpcomingSalary() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get current date
      final now = DateTime.now();
      // Calculate 15 days from now
      final fifteenDaysFromNow = DateTime(now.year, now.month, now.day + 15);
      
      // Format dates for query
      final nowStr = DateFormat('yyyy-MM-dd').format(now);
      final futureStr = DateFormat('yyyy-MM-dd').format(fifteenDaysFromNow);
      
      final data = await _supabase
          .from('salary_payments')  // Changed from driver_salaries
          .select()
          .eq('driver_id', widget.driver.id)
          .gte('payment_date', nowStr)
          .lte('payment_date', futureStr)
          .order('payment_date');
      
      if (!mounted) return;
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => _DetailListScreen(
            title: '15-Day Upcoming Salary',
            driverName: widget.driver.name,
            data: data,
            emptyMessage: 'No upcoming salary payments in the next 15 days.',
            itemBuilder: (context, item) {
              final paymentDate = DateFormat('MMM dd, yyyy').format(DateTime.parse(item['payment_date']));
              
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.orange,
                  child: const Icon(Icons.calendar_today, color: Colors.white),
                ),
                title: Text('₱${item['amount'].toStringAsFixed(2)}'),
                subtitle: Text('Payment on $paymentDate'),
                trailing: Text(item['payment_type'] ?? 'Salary'),
              );
            },
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading upcoming salary: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _viewCashAdvances() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final data = await _supabase
          .from('cash_advances')  // Changed from driver_cash_advances
          .select()
          .eq('driver_id', widget.driver.id)
          .order('request_date', ascending: false);  // Changed from date_requested
      
      if (!mounted) return;
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => _DetailListScreen(
            title: 'Cash Advances',
            driverName: widget.driver.name,
            data: data,
            itemBuilder: (context, item) {
              final requestDate = DateFormat('MMM dd, yyyy').format(DateTime.parse(item['request_date']));
              
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getStatusColor(item['status']),
                  child: const Icon(Icons.attach_money, color: Colors.white),
                ),
                title: Text('₱${item['amount'].toStringAsFixed(2)}'),
                subtitle: Text('Requested on $requestDate\n${item['description'] ?? ''}'),
                isThreeLine: true,
                trailing: Text(item['status']),
              );
            },
            // Add this action button
            actionButton: FloatingActionButton(
              onPressed: () => _showAddCashAdvanceForm(),
              child: const Icon(Icons.add),
              backgroundColor: Colors.blue,
            ),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading cash advances: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _viewDeductions() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final data = await _supabase
          .from('deductions')
          .select()
          .eq('driver_id', widget.driver.id)
          .order('deduction_date', ascending: false);
      
      if (!mounted) return;
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => _DetailListScreen(
            title: 'Deductions',
            driverName: widget.driver.name,
            data: data,
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
            // Add this action button
            actionButton: FloatingActionButton(
              onPressed: () => _showAddDeductionForm(),
              child: const Icon(Icons.add),
              backgroundColor: Colors.red,
            ),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading deductions: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _viewBonuses() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final data = await _supabase
          .from('bonuses')
          .select()
          .eq('driver_id', widget.driver.id)
          .order('bonus_date', ascending: false);
      
      if (!mounted) return;
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => _DetailListScreen(
            title: 'Bonuses & Incentives',
            driverName: widget.driver.name,
            data: data,
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
            // Add this action button
            actionButton: FloatingActionButton(
              onPressed: () => _showAddBonusForm(),
              child: const Icon(Icons.add),
              backgroundColor: Colors.green,
            ),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading bonuses: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _view13thMonth() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final currentYear = DateTime.now().year;
      final data = await _supabase
          .from('thirteenth_month_pay')  // Changed from driver_13th_month
          .select()
          .eq('driver_id', widget.driver.id)
          .order('year', ascending: false);
      
      if (!mounted) return;
      
      if (data.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('13th month pay for $currentYear will be available at the end of the year')),
        );
        return;
      }
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => _DetailListScreen(
            title: '13th Month Summary',
            driverName: widget.driver.name,
            data: data,
            itemBuilder: (context, item) {
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.amber,
                  child: Text(
                    item['year'].toString().substring(2),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text('₱${item['amount'].toStringAsFixed(2)}'),
                subtitle: Text('Year: ${item['year']}\nStatus: ${item['status']}'),
                trailing: Text(
                  DateFormat('MMM dd, yyyy').format(DateTime.parse(item['payment_date'])),
                ),
              );
            },
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading 13th month data: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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

  // Add these form dialog methods
  Future<void> _showAddDeductionForm() async {
    // Reset form values
    _amountController.text = '';
    _descriptionController.text = '';
    _dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _selectedDate = DateTime.now();
    _selectedDeductionType = 'SSS';

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add New Deduction'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _amountController,
                  decoration: const InputDecoration(
                    labelText: 'Amount (₱)',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedDeductionType,
                  decoration: const InputDecoration(
                    labelText: 'Deduction Type',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'SSS', child: Text('SSS')),
                    DropdownMenuItem(value: 'PhilHealth', child: Text('PhilHealth')),
                    DropdownMenuItem(value: 'Pag-IBIG', child: Text('Pag-IBIG')),
                    DropdownMenuItem(value: 'Tax', child: Text('Tax')),
                    DropdownMenuItem(value: 'Loan Repayment', child: Text('Loan Repayment')),
                    DropdownMenuItem(value: 'Cash Advance', child: Text('Cash Advance')),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                  ],
                  onChanged: (value) {
                    _selectedDeductionType = value!;
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _dateController,
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  readOnly: true,
                  onTap: () async {
                    final DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2101),
                    );
                    if (pickedDate != null) {
                      _selectedDate = pickedDate;
                      _dateController.text = DateFormat('yyyy-MM-dd').format(pickedDate);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                  ),
                  maxLines: 2,
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
              onPressed: () {
                _addDeduction();
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAddBonusForm() async {
    // Reset form values
    _amountController.text = '';
    _descriptionController.text = '';
    _dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _selectedDate = DateTime.now();
    _selectedBonusType = 'Performance';

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add New Bonus/Incentive'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _amountController,
                  decoration: const InputDecoration(
                    labelText: 'Amount (₱)',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedBonusType,
                  decoration: const InputDecoration(
                    labelText: 'Bonus Type',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Performance', child: Text('Performance')),
                    DropdownMenuItem(value: 'Attendance', child: Text('Attendance')),
                    DropdownMenuItem(value: 'Holiday', child: Text('Holiday')),
                    DropdownMenuItem(value: 'Year-end', child: Text('Year-end')),
                    DropdownMenuItem(value: 'Special', child: Text('Special')),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                  ],
                  onChanged: (value) {
                    _selectedBonusType = value!;
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _dateController,
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  readOnly: true,
                  onTap: () async {
                    final DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2101),
                    );
                    if (pickedDate != null) {
                      _selectedDate = pickedDate;
                      _dateController.text = DateFormat('yyyy-MM-dd').format(pickedDate);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                  ),
                  maxLines: 2,
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
              onPressed: () {
                _addBonus();
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAddCashAdvanceForm() async {
    // Reset form values
    _amountController.text = '';
    _descriptionController.text = '';
    _dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _selectedDate = DateTime.now();
    _selectedCashAdvanceStatus = 'Pending';

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add New Cash Advance'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _amountController,
                  decoration: const InputDecoration(
                    labelText: 'Amount (₱)',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _dateController,
                  decoration: const InputDecoration(
                    labelText: 'Request Date',
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  readOnly: true,
                  onTap: () async {
                    final DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2101),
                    );
                    if (pickedDate != null) {
                      _selectedDate = pickedDate;
                      _dateController.text = DateFormat('yyyy-MM-dd').format(pickedDate);
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedCashAdvanceStatus,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                    DropdownMenuItem(value: 'Approved', child: Text('Approved')),
                    DropdownMenuItem(value: 'Rejected', child: Text('Rejected')),
                    DropdownMenuItem(value: 'Paid', child: Text('Paid')),
                  ],
                  onChanged: (value) {
                    _selectedCashAdvanceStatus = value!;
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                  ),
                  maxLines: 2,
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
              onPressed: () {
                _addCashAdvance();
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  // Add these submission methods
  void _addDeduction() async {
    if (_amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an amount')),
      );
      return;
    }

    try {
      final amount = double.parse(_amountController.text);
      
      await _supabase.from('deductions').insert({
        'driver_id': widget.driver.id,
        'amount': amount,
        'deduction_type': _selectedDeductionType,
        'deduction_date': _dateController.text,
        'description': _descriptionController.text,
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deduction added successfully')),
      );
      
      // Refresh the list if we're on the deductions page
      if (mounted) {
        _viewDeductions();
      }
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding deduction: $e')),
      );
    }
  }

  void _addBonus() async {
    if (_amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an amount')),
      );
      return;
    }

    try {
      final amount = double.parse(_amountController.text);
      
      await _supabase.from('bonuses').insert({
        'driver_id': widget.driver.id,
        'amount': amount,
        'bonus_type': _selectedBonusType,
        'bonus_date': _dateController.text,
        'description': _descriptionController.text,
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bonus added successfully')),
      );
      
      // Refresh the list if we're on the bonuses page
      if (mounted) {
        _viewBonuses();
      }
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding bonus: $e')),
      );
    }
  }

  void _addCashAdvance() async {
    if (_amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an amount')),
      );
      return;
    }

    try {
      final amount = double.parse(_amountController.text);
      
      await _supabase.from('cash_advances').insert({
        'driver_id': widget.driver.id,
        'amount': amount,
        'request_date': _dateController.text,
        'status': _selectedCashAdvanceStatus,
        'description': _descriptionController.text,
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cash advance added successfully')),
      );
      
      // Refresh the list if we're on the cash advances page
      if (mounted) {
        _viewCashAdvances();
      }
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding cash advance: $e')),
      );
    }
  }
}

// Modify the _DetailListScreen class to accept an action button
class _DetailListScreen extends StatelessWidget {
  final String title;
  final String driverName;
  final List<dynamic> data;
  final Widget Function(BuildContext, Map<String, dynamic>) itemBuilder;
  final String emptyMessage;
  final Widget? actionButton; // Add this parameter

  const _DetailListScreen({
    Key? key,
    required this.title,
    required this.driverName,
    required this.data,
    required this.itemBuilder,
    this.emptyMessage = 'No data found',
    this.actionButton, // Add this parameter
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$title - $driverName'),
        backgroundColor: const Color(0xFF2F27CE),
        foregroundColor: Colors.white,
      ),
      body: data.isEmpty
          ? Center(child: Text(emptyMessage))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: data.length,
              itemBuilder: (context, index) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: itemBuilder(context, data[index]),
                );
              },
            ),
      floatingActionButton: actionButton, // Add this line
    );
  }
}