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
  
  // Define consistent colors for the app
  final Color primaryColor = const Color(0xFF2F27CE);
  final Color secondaryColor = const Color(0xFF6C63FF);
  final Color successColor = const Color(0xFF4CAF50);
  final Color errorColor = const Color(0xFFE53935);
  final Color warningColor = const Color(0xFFFFA726);
  final Color surfaceColor = const Color(0xFFF5F7FA);
  final Color textPrimaryColor = const Color(0xFF303030);
  final Color textSecondaryColor = const Color(0xFF757575);
  
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
        _showSnackBar('Error loading payroll data: ${e.toString()}', errorColor);
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
          builder: (context) => _buildLoadingIndicator('Generating salary...'),
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
        _showSnackBar('Salary generated successfully', successColor);
      } catch (e) {
        // Close loading dialog
        if (context.mounted) Navigator.pop(context);
        
        print('Error saving payroll record: $e');
        _showSnackBar('Error: ${e.toString()}', errorColor);
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
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 8,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Dialog Header
                Center(
                  child: CircleAvatar(
                    radius: 32,
                    backgroundColor: primaryColor.withOpacity(0.1),
                    child: Icon(
                      Icons.person,
                      size: 32,
                      color: primaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Generate Salary',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                Text(
                  '${driver['first_name']} ${driver['last_name']}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: successColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.payment, color: successColor, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Base Salary: ₱${NumberFormat('#,##0.00').format(driver['base_salary'])}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: successColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Pay Period
                _buildDialogSectionHeader('Pay Period'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(DateFormat('MMM d, yyyy').format(periodStart)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: periodStart,
                            firstDate: DateTime(now.year - 1),
                            lastDate: DateTime(now.year + 1),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: ColorScheme.light(
                                    primary: primaryColor,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) {
                            setState(() {
                              periodStart = picked;
                            });
                          }
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: Text(
                        'to',
                        style: TextStyle(color: textSecondaryColor),
                      ),
                    ),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(DateFormat('MMM d, yyyy').format(periodEnd)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: periodEnd,
                            firstDate: DateTime(now.year - 1),
                            lastDate: DateTime(now.year + 1),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: ColorScheme.light(
                                    primary: primaryColor,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) {
                            setState(() {
                              periodEnd = picked;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Deductions
                _buildDialogSectionHeader('Deductions'),
                const SizedBox(height: 12),
                _buildMoneyTextField(cashAdvanceController, 'Cash Advance', Icons.money_off),
                const SizedBox(height: 12),
                _buildMoneyTextField(sssController, 'SSS', Icons.shield),
                const SizedBox(height: 12),
                _buildMoneyTextField(philhealthController, 'PhilHealth', Icons.local_hospital),
                const SizedBox(height: 12),
                _buildMoneyTextField(pagibigController, 'Pag-IBIG', Icons.home),
                
                const SizedBox(height: 24),
                
                // Bonuses
                _buildDialogSectionHeader('Bonuses'),
                const SizedBox(height: 12),
                _buildMoneyTextField(bonusController, 'Bonus Amount', Icons.star),
                
                const SizedBox(height: 32),
                
                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          // Validate inputs
                          if (periodEnd.isBefore(periodStart)) {
                            _showSnackBar('End date cannot be before start date', errorColor);
                            return;
                          }
                          
                          try {
                            // Validate number inputs
                            double.parse(cashAdvanceController.text);
                            double.parse(sssController.text);
                            double.parse(philhealthController.text);
                            double.parse(pagibigController.text);
                            double.parse(bonusController.text);
                            
                            // Return values
                            Navigator.pop(context, {
                              'cash_advance': double.parse(cashAdvanceController.text),
                              'sss': double.parse(sssController.text),
                              'philhealth': double.parse(philhealthController.text),
                              'pagibig': double.parse(pagibigController.text),
                              'bonus': double.parse(bonusController.text),
                              'period_start': periodStart,
                              'period_end': periodEnd,
                            });
                          } catch (e) {
                            _showSnackBar('Please enter valid numbers for all fields', errorColor);
                          }
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.savings, size: 20),
                            const SizedBox(width: 8),
                            const Text('Generate Salary'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }
    );
  }
  
  Widget _buildDialogSectionHeader(String title) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textPrimaryColor,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Divider(color: Colors.grey.shade300),
        ),
      ],
    );
  }
  
  Widget _buildMoneyTextField(
    TextEditingController controller, 
    String label, 
    IconData icon,
  ) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: primaryColor),
        prefixText: '₱',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(fontSize: 16),
    );
  }
  
  Future<void> _exportPayslip(Map<String, dynamic> record) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _buildLoadingIndicator('Exporting payslip...'),
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
                pw.SizedBox(height: 40),
                pw.Center(
                  child: pw.Text(
                    'Generated on: ${DateFormat('MMMM dd, yyyy hh:mm a').format(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColor(0.5, 0.5, 0.5)),
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
      
      // Try to open the file
      try {
        final result = await OpenFilex.open(file.path);
        
        if (result.type != ResultType.done) {
          // If file couldn't be opened automatically, show a message with the file path
          _showSnackBar(
            'PDF saved but could not be opened automatically.\nLocation: ${file.path}', 
            warningColor,
            duration: const Duration(seconds: 10),
          );
        } else {
          // Success message
          _showSnackBar('Payslip exported successfully', successColor);
        }
      } catch (e) {
        // Fall back to just showing the file path
        _showSnackBar(
          'PDF generated successfully but cannot be opened automatically.\nLocation: ${file.path}', 
          warningColor,
          duration: const Duration(seconds: 10),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (context.mounted) Navigator.pop(context);
      
      print('Error exporting payslip: $e');
      _showSnackBar('Error exporting payslip: ${e.toString()}', errorColor);
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
  
  Widget _buildLoadingIndicator(String message) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: primaryColor),
            const SizedBox(height: 24),
            Text(
              message,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
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
        builder: (context) => _buildLoadingIndicator('Updating payment status...'),
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
      
      _showSnackBar(
        'Payment status updated to $newStatus',
        newStatus == 'Paid' ? successColor : warningColor,
      );
    } catch (e) {
      // Close loading dialog
      if (context.mounted) Navigator.pop(context);
      
      print('Error updating payment status: $e');
      _showSnackBar('Error updating payment status: ${e.toString()}', errorColor);
    }
  }
  
  void _showSnackBar(String message, Color backgroundColor, {Duration? duration}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(16),
        duration: duration ?? const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'DISMISS',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: surfaceColor,
        appBar: AppBar(
          elevation: 0,
          title: const Text(
            'Salary & Payroll',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 20,
            ),
          ),
          backgroundColor: primaryColor,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              tooltip: 'Refresh Data',
              onPressed: () {
                _loadDrivers();
                _loadPayrollData();
                _showSnackBar('Refreshing data...', primaryColor);
              },
            ),
          ],
          bottom: TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
            unselectedLabelColor: Colors.white.withOpacity(0.7),
            tabs: const [
              Tab(
                icon: Icon(Icons.person),
                text: 'Generate Salary',
              ),
              Tab(
                icon: Icon(Icons.history),
                text: 'Payroll History',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Generate Salary Tab
            _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: primaryColor),
                        const SizedBox(height: 16),
                        Text(
                          'Loading drivers...',
                          style: TextStyle(color: textSecondaryColor),
                        ),
                      ],
                    ),
                  )
                : _hasError
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 64, color: errorColor),
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: errorColor),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
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
    if (_drivers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 24),
            Text(
              'No drivers found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textPrimaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add drivers to generate salaries',
              style: TextStyle(color: textSecondaryColor, fontSize: 16),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _loadDrivers,
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadDrivers,
      color: primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _drivers.length,
        itemBuilder: (context, index) {
          final driver = _drivers[index];
          final baseSalary = driver['base_salary'] is String 
              ? double.parse(driver['base_salary']) 
              : driver['base_salary'].toDouble();
          
          // Create initials for avatar
          final initials = '${driver['first_name'][0]}${driver['last_name'][0]}';
          
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Avatar with fancy gradient background
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primaryColor, secondaryColor],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // Driver info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${driver['first_name']} ${driver['last_name']}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textPrimaryColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: successColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              '₱${NumberFormat('#,##0.00').format(baseSalary)}',
                              style: TextStyle(
                                color: successColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Generate button
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Generate'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => _generateSalary(driver),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildPayrollHistoryTab() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: primaryColor),
            const SizedBox(height: 16),
            Text(
              'Loading payroll records...',
              style: TextStyle(color: textSecondaryColor),
            ),
          ],
        ),
      );
    }
    
    if (_payrollRecords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 24),
            Text(
              'No payroll records found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textPrimaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Generate salaries to see records here',
              style: TextStyle(color: textSecondaryColor, fontSize: 16),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _loadPayrollData,
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadPayrollData,
      color: primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _payrollRecords.length,
        itemBuilder: (context, index) {
          final record = _payrollRecords[index];
          final isPaid = record['status'] == 'Paid';
          
          return Card(
            margin: const EdgeInsets.only(bottom: 20),
            elevation: 3,
            shadowColor: Colors.black26,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isPaid ? successColor.withOpacity(0.3) : Colors.grey.shade300,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with gradient background
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isPaid 
                            ? [successColor.withOpacity(0.8), successColor.withOpacity(0.6)]
                            : [primaryColor.withOpacity(0.8), secondaryColor.withOpacity(0.6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.white,
                          radius: 24,
                          child: Text(
                            record['driver_name'].split(' ')[0][0] + record['driver_name'].split(' ')[1][0],
                            style: TextStyle(
                              color: isPaid ? successColor : primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                record['driver_name'],
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                record['period'],
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isPaid ? Icons.check_circle : Icons.schedule,
                                color: isPaid ? successColor : warningColor,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                record['status'],
                                style: TextStyle(
                                  color: isPaid ? successColor : warningColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Salary details
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Details grid with improved visual hierarchy
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildSalaryDetailItem('Base Salary', record['base_salary'], Icons.payment),
                                        const SizedBox(height: 12),
                                        _buildSalaryDetailItem('Bonus', record['bonus'], Icons.star, isPositive: true),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Container(
                                    width: 1,
                                    height: 100,
                                    color: Colors.grey.shade300,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildSalaryDetailItem('Cash Advance', -record['cash_advance'], Icons.money_off),
                                        const SizedBox(height: 12),
                                        _buildSalaryDetailItem('Government', 
                                          -(record['sss'] + record['philhealth'] + record['pagibig']), 
                                          Icons.account_balance),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Divider(),
                              ),
                              // Net salary
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'NET SALARY:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: textPrimaryColor,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: successColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: successColor.withOpacity(0.3)),
                                    ),
                                    child: Text(
                                      '₱${NumberFormat('#,##0.00').format(record['net_salary'])}',
                                      style: TextStyle(
                                        color: successColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        if (isPaid && record['payment_date'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Row(
                              children: [
                                Icon(Icons.event_available, size: 16, color: textSecondaryColor),
                                const SizedBox(width: 6),
                                Text(
                                  'Paid on: ${DateFormat('MMMM d, yyyy').format(record['payment_date'])}',
                                  style: TextStyle(
                                    color: textSecondaryColor,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        
                        // Actions
                        Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                icon: const Icon(Icons.receipt),
                                label: const Text('Export Payslip'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: primaryColor,
                                  side: BorderSide(color: primaryColor),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () => _exportPayslip(record),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                icon: Icon(isPaid ? Icons.cancel : Icons.check_circle),
                                label: Text(isPaid ? 'Mark as Unpaid' : 'Mark as Paid'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isPaid ? errorColor : successColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () => _togglePaymentStatus(record),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildSalaryDetailItem(String label, double amount, IconData icon, {bool isPositive = false}) {
    final isNegative = amount < 0;
    final displayAmount = isNegative ? -amount : amount;
    final Color textColor = isNegative ? errorColor : (isPositive ? successColor : textPrimaryColor);
    
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: textColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: textColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: textSecondaryColor,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${isNegative ? '-' : ''}₱${NumberFormat('#,##0.00').format(displayAmount)}',
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}