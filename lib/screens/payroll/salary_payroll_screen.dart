import 'package:flutter/material.dart';
import 'package:bus_management/config/supabase_config.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:io';

class SalaryPayrollScreen extends StatefulWidget {
  const SalaryPayrollScreen({super.key});

  @override
  State<SalaryPayrollScreen> createState() => _SalaryPayrollScreenState();
}

class _SalaryPayrollScreenState extends State<SalaryPayrollScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  List<Map<String, dynamic>> _drivers = [];
  List<Map<String, dynamic>> _payrollRecords = [];
  
  @override
  void initState() {
    super.initState();
    _loadDrivers();
    _loadPayrollData();
  }
  
  Future<void> _loadDrivers() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    
    try {
      final response = await supabase
          .from('drivers')
          .select('id, first_name, last_name, base_salary')
          .order('last_name', ascending: true);
      
      setState(() {
        _drivers = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
      
      if (_drivers.isEmpty) {
        setState(() {
          _hasError = true;
          _errorMessage = 'No drivers found in the database. Please add drivers first.';
        });
      }
    } catch (e) {
      print('Error loading drivers: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Failed to load drivers: ${e.toString()}';
      });
    }
  }
  
  Future<void> _loadPayrollData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final response = await supabase
          .from('payroll')
          .select('''
            id, 
            driver_id,
            period_start,
            period_end, 
            base_salary, 
            cash_advance, 
            sss, 
            philhealth, 
            pagibig, 
            bonus, 
            net_salary, 
            status, 
            payment_date,
            drivers(first_name, last_name)
          ''')
          .order('period_end', ascending: false);
      
      List<Map<String, dynamic>> formattedRecords = [];
      
      for (var record in response) {
        Map<String, dynamic> formattedRecord = {
          'id': record['id'],
          'driver_id': record['driver_id'],
          'driver_name': '${record['drivers']['first_name']} ${record['drivers']['last_name']}',
          'period': '${DateFormat('MMM d').format(DateTime.parse(record['period_start']))} - ${DateFormat('MMM d, yyyy').format(DateTime.parse(record['period_end']))}',
          'period_start': DateTime.parse(record['period_start']),
          'period_end': DateTime.parse(record['period_end']),
          'base_salary': record['base_salary'] is String ? double.parse(record['base_salary']) : record['base_salary'].toDouble(),
          'cash_advance': record['cash_advance'] is String ? double.parse(record['cash_advance']) : record['cash_advance'].toDouble(),
          'sss': record['sss'] is String ? double.parse(record['sss']) : record['sss'].toDouble(),
          'philhealth': record['philhealth'] is String ? double.parse(record['philhealth']) : record['philhealth'].toDouble(),
          'pagibig': record['pagibig'] is String ? double.parse(record['pagibig']) : record['pagibig'].toDouble(),
          'bonus': record['bonus'] is String ? double.parse(record['bonus']) : record['bonus'].toDouble(),
          'net_salary': record['net_salary'] is String ? double.parse(record['net_salary']) : record['net_salary'].toDouble(),
          'status': record['status'],
          'payment_date': record['payment_date'] != null ? DateTime.parse(record['payment_date']) : null,
        };
        
        formattedRecords.add(formattedRecord);
      }
      
      setState(() {
        _payrollRecords = formattedRecords;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading payroll data: $e');
      setState(() {
        _isLoading = false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading payroll data: ${e.toString()}')),
        );
      });
    }
  }

  Future<void> _generateSalary(Map<String, dynamic> driver) async {
    // Show dialog to generate salary
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _buildGenerateSalaryDialog(driver),
    );
    
    if (result != null) {
      try {
        // Calculate net salary
        final double baseSalary = driver['base_salary'] is String 
            ? double.parse(driver['base_salary']) 
            : driver['base_salary'].toDouble();
        final double cashAdvance = result['cash_advance'];
        final double sss = result['sss'];
        final double philhealth = result['philhealth'];
        final double pagibig = result['pagibig'];
        final double bonus = result['bonus'];
        
        final double netSalary = baseSalary - cashAdvance - sss - philhealth - pagibig + bonus;
        
        // Period dates
        final DateTime periodStart = result['period_start'];
        final DateTime periodEnd = result['period_end'];
        
        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
        
        // Save to Supabase
        await supabase.from('payroll').insert({
          'driver_id': driver['id'],
          'period_start': periodStart.toIso8601String(),
          'period_end': periodEnd.toIso8601String(),
          'base_salary': baseSalary,
          'cash_advance': cashAdvance,
          'sss': sss,
          'philhealth': philhealth,
          'pagibig': pagibig,
          'bonus': bonus,
          'net_salary': netSalary,
          'status': 'Unpaid',
        });
        
        // Close loading dialog
        if (context.mounted) Navigator.pop(context);
        
        // Reload payroll data
        await _loadPayrollData();
        
        // Show success message
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Salary generated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        // Close loading dialog
        if (context.mounted) Navigator.pop(context);
        
        print('Error saving payroll record: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Widget _buildGenerateSalaryDialog(Map<String, dynamic> driver) {
    final TextEditingController cashAdvanceController = TextEditingController(text: '0.00');
    final TextEditingController sssController = TextEditingController(text: '1200.00');
    final TextEditingController philhealthController = TextEditingController(text: '300.00');
    final TextEditingController pagibigController = TextEditingController(text: '100.00');
    final TextEditingController bonusController = TextEditingController(text: '0.00');
    
    // Default period (current pay period)
    final DateTime now = DateTime.now();
    DateTime periodStart;
    DateTime periodEnd;
    
    // If first half of month (1-15)
    if (now.day <= 15) {
      periodStart = DateTime(now.year, now.month, 1);
      periodEnd = DateTime(now.year, now.month, 15);
    } else {
      periodStart = DateTime(now.year, now.month, 16);
      periodEnd = DateTime(now.year, now.month + 1, 0); // Last day of current month
    }
    
    return StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: Text('Generate Salary for ${driver['first_name']} ${driver['last_name']}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Base Salary: ₱${NumberFormat('#,##0.00').format(driver['base_salary'])}'),
                const SizedBox(height: 16),
                
                // Pay Period
                const Text('Pay Period:'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: periodStart,
                            firstDate: DateTime(now.year - 1),
                            lastDate: DateTime(now.year + 1),
                          );
                          if (picked != null) {
                            setState(() {
                              periodStart = picked;
                            });
                          }
                        },
                        child: Text(DateFormat('MMM d, yyyy').format(periodStart)),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text('to'),
                    ),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: periodEnd,
                            firstDate: DateTime(now.year - 1),
                            lastDate: DateTime(now.year + 1),
                          );
                          if (picked != null) {
                            setState(() {
                              periodEnd = picked;
                            });
                          }
                        },
                        child: Text(DateFormat('MMM d, yyyy').format(periodEnd)),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                const Text('Deductions:'),
                const SizedBox(height: 8),
                TextField(
                  controller: cashAdvanceController,
                  decoration: const InputDecoration(
                    labelText: 'Cash Advance',
                    prefixText: '₱',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: sssController,
                  decoration: const InputDecoration(
                    labelText: 'SSS',
                    prefixText: '₱',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: philhealthController,
                  decoration: const InputDecoration(
                    labelText: 'PhilHealth',
                    prefixText: '₱',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: pagibigController,
                  decoration: const InputDecoration(
                    labelText: 'Pag-IBIG',
                    prefixText: '₱',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: bonusController,
                  decoration: const InputDecoration(
                    labelText: 'Bonus',
                    prefixText: '₱',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2F27CE),
              ),
              onPressed: () {
                // Validate inputs
                if (periodEnd.isBefore(periodStart)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('End date cannot be before start date'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                
                // Return values
                Navigator.pop(context, {
                  'cash_advance': double.tryParse(cashAdvanceController.text) ?? 0.0,
                  'sss': double.tryParse(sssController.text) ?? 0.0,
                  'philhealth': double.tryParse(philhealthController.text) ?? 0.0,
                  'pagibig': double.tryParse(pagibigController.text) ?? 0.0,
                  'bonus': double.tryParse(bonusController.text) ?? 0.0,
                  'period_start': periodStart,
                  'period_end': periodEnd,
                });
              },
              child: const Text('Generate'),
            ),
          ],
        );
      }
    );
  }
  
  Future<void> _exportPayslip(Map<String, dynamic> record) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      // Create PDF document
      final pdf = pw.Document();
      
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text('BUS MANAGEMENT SYSTEM', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 5),
                      pw.Text('PAYSLIP', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 5),
                      pw.Text('Pay Period: ${record['period']}'),
                    ],
                  ),
                ),
                
                pw.SizedBox(height: 20),
                
                // Employee Details
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Employee: ${record['driver_name']}'),
                            pw.SizedBox(height: 5),
                            pw.Text('Position: Driver'),
                          ],
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Status: ${record['status']}'),
                            if (record['payment_date'] != null)
                              pw.Text('Payment Date: ${DateFormat('MMM dd, yyyy').format(record['payment_date'])}'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                pw.SizedBox(height: 20),
                
                // Earnings and Deductions
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Earnings
                    pw.Expanded(
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(10),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('EARNINGS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                            pw.Divider(),
                            _buildPdfSalaryRow('Base Salary', record['base_salary']),
                            _buildPdfSalaryRow('Bonus', record['bonus']),
                            pw.Divider(),
                            _buildPdfSalaryRow('Total Earnings', record['base_salary'] + record['bonus'], isBold: true),
                          ],
                        ),
                      ),
                    ),
                    
                    pw.SizedBox(width: 10),
                    
                    // Deductions
                    pw.Expanded(
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(10),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('DEDUCTIONS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                            pw.Divider(),
                            _buildPdfSalaryRow('Cash Advance', record['cash_advance']),
                            _buildPdfSalaryRow('SSS', record['sss']),
                            _buildPdfSalaryRow('PhilHealth', record['philhealth']),
                            _buildPdfSalaryRow('Pag-IBIG', record['pagibig']),
                            pw.Divider(),
                            _buildPdfSalaryRow('Total Deductions', 
                              record['cash_advance'] + record['sss'] + record['philhealth'] + record['pagibig'], 
                              isBold: true
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                
                pw.SizedBox(height: 20),
                
                // Net Pay
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(),
                    color: const PdfColor(0.9, 0.9, 0.9),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('NET PAY:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('₱${NumberFormat('#,##0.00').format(record['net_salary'])}', 
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ),
                
                pw.SizedBox(height: 40),
                
                // Signatures
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Container(
                            width: 200,
                            decoration: const pw.BoxDecoration(
                              border: pw.Border(top: pw.BorderSide()),
                            ),
                            padding: const pw.EdgeInsets.only(top: 5),
                            child: pw.Text('Employee Signature'),
                          ),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Container(
                            width: 200,
                            decoration: const pw.BoxDecoration(
                              border: pw.Border(top: pw.BorderSide()),
                            ),
                            padding: const pw.EdgeInsets.only(top: 5),
                            child: pw.Text('Authorized Signature'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                // Footer with date and time
                pw.Positioned(
                  bottom: 20,
                  right: 20,
                  child: pw.Text(
                    'Generated on: ${DateFormat('MMM dd, yyyy hh:mm a').format(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColor(0.5, 0.5, 0.5)),
                  ),
                ),
              ],
            );
          },
        ),
      );
      
      // Save PDF
      final output = await getTemporaryDirectory();
      final fileName = 'payslip_${record['driver_name'].replaceAll(' ', '_')}_${DateFormat('yyyyMMdd').format(record['period_end'])}.pdf';
      final file = File('${output.path}/$fileName');
      await file.writeAsBytes(await pdf.save());
      
      // Close loading dialog
      if (context.mounted) Navigator.pop(context);
      
      // Modified section: Safer file opening with error handling
      try {
        // Try to open the file
        final result = await OpenFilex.open(file.path);
        
        if (result.type != ResultType.done) {
          // If file couldn't be opened automatically, show a message with the file path
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('PDF saved but could not be opened automatically.'),
                  Text('Location: ${file.path}', style: const TextStyle(fontSize: 12)),
                ],
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 10),
              action: SnackBarAction(
                label: 'DISMISS',
                onPressed: () {},
              ),
            ),
          );
        } else {
          // Success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payslip exported successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        // Fall back to just showing the file path
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('PDF generated successfully but cannot be opened automatically'),
                Text('Location: ${file.path}', style: const TextStyle(fontSize: 12)),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 10),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (context.mounted) Navigator.pop(context);
      
      print('Error exporting payslip: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting payslip: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  pw.Widget _buildPdfSalaryRow(String label, double amount, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: isBold ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null),
          pw.Text('₱${NumberFormat('#,##0.00').format(amount)}', 
            style: isBold ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null),
        ],
      ),
    );
  }
  
  Future<void> _togglePaymentStatus(Map<String, dynamic> record) async {
    try {
      String newStatus;
      DateTime? paymentDate;
      
      if (record['status'] == 'Paid') {
        newStatus = 'Unpaid';
        paymentDate = null;
      } else {
        newStatus = 'Paid';
        paymentDate = DateTime.now();
      }
      
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      // Update in Supabase
      await supabase
          .from('payroll')
          .update({
            'status': newStatus,
            'payment_date': paymentDate?.toIso8601String(),
          })
          .eq('id', record['id']);
      
      // Close loading dialog
      if (context.mounted) Navigator.pop(context);
      
      // Update local state
      setState(() {
        record['status'] = newStatus;
        record['payment_date'] = paymentDate;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment status updated to $newStatus'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Close loading dialog
      if (context.mounted) Navigator.pop(context);
      
      print('Error updating payment status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating payment status: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Salary & Payroll',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor: const Color(0xFF2F27CE),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () {
                _loadDrivers();
                _loadPayrollData();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Refreshing data...')),
                );
              },
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            tabs: [
              Tab(text: 'Generate Salary'),
              Tab(text: 'Payroll History'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Generate Salary Tab
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _hasError
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: Colors.red),
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.red),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                              onPressed: _loadDrivers,
                            ),
                          ],
                        ),
                      )
                    : _buildGenerateSalaryTab(),
            
            // Payroll History Tab
            _buildPayrollHistoryTab(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildGenerateSalaryTab() {
    return _drivers.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.person_off, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'No drivers found',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Add drivers to generate salaries',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                  onPressed: _loadDrivers,
                ),
              ],
            ),
          )
        : RefreshIndicator(
            onRefresh: _loadDrivers,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _drivers.length,
              itemBuilder: (context, index) {
                final driver = _drivers[index];
                final baseSalary = driver['base_salary'] is String 
                    ? double.parse(driver['base_salary']) 
                    : driver['base_salary'].toDouble();
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF2F27CE),
                      child: Text(
                        '${driver['first_name'][0]}${driver['last_name'][0]}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(
                      '${driver['first_name']} ${driver['last_name']}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Base Salary: ₱${NumberFormat('#,##0.00').format(baseSalary)}',
                        style: const TextStyle(color: Colors.green),
                      ),
                    ),
                    trailing: ElevatedButton.icon(
                      icon: const Text(
                        '₱',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      label: const Text('Generate'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2F27CE),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      onPressed: () => _generateSalary(driver),
                    ),
                  ),
                );
              },
            ),
          );
  }
  
  Widget _buildPayrollHistoryTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_payrollRecords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_long, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No payroll records found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Generate salaries to see records here',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              onPressed: _loadPayrollData,
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadPayrollData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _payrollRecords.length,
        itemBuilder: (context, index) {
          final record = _payrollRecords[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: record['status'] == 'Paid' ? Colors.green.shade300 : Colors.grey.shade300,
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              record['driver_name'],
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              record['period'],
                              style: const TextStyle(
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: record['status'] == 'Paid' ? Colors.green.shade100 : Colors.red.shade100,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: record['status'] == 'Paid' ? Colors.green.shade400 : Colors.red.shade400,
                          ),
                        ),
                        child: Text(
                          record['status'],
                          style: TextStyle(
                            color: record['status'] == 'Paid' ? Colors.green.shade800 : Colors.red.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  _buildSalaryDetailRow('Base Salary', record['base_salary']),
                  _buildSalaryDetailRow('Cash Advance', -record['cash_advance']),
                  _buildSalaryDetailRow('SSS', -record['sss']),
                  _buildSalaryDetailRow('PhilHealth', -record['philhealth']),
                  _buildSalaryDetailRow('Pag-IBIG', -record['pagibig']),
                  _buildSalaryDetailRow('Bonus', record['bonus']),
                  const Divider(),
                  _buildSalaryDetailRow('Net Salary', record['net_salary'], isBold: true),
                  if (record['status'] == 'Paid' && record['payment_date'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Paid on: ${DateFormat('MMM dd, yyyy').format(record['payment_date'])}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.print),
                        label: const Text('Export Payslip'),
                        onPressed: () => _exportPayslip(record),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: Icon(record['status'] == 'Paid' ? Icons.cancel : Icons.check_circle),
                        label: Text(record['status'] == 'Paid' ? 'Mark as Unpaid' : 'Mark as Paid'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: record['status'] == 'Paid' ? Colors.red : Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _togglePaymentStatus(record),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildSalaryDetailRow(String label, double amount, {bool isBold = false}) {
    final isNegative = amount < 0;
    final displayAmount = isNegative ? -amount : amount;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 16 : 14,
            ),
          ),
          Text(
            '${isNegative ? '-' : ''}₱${NumberFormat('#,##0.00').format(displayAmount)}',
            style: TextStyle(
              color: isNegative ? Colors.red : (amount > 0 && !isBold ? Colors.green : null),
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }
}