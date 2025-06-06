import 'package:flutter/material.dart';
import 'package:bus_management/config/supabase_config.dart';
import 'package:intl/intl.dart';

class AddTripLogScreen extends StatefulWidget {
  final Map<String, dynamic> bus;
  
  const AddTripLogScreen({Key? key, required this.bus}) : super(key: key);

  @override
  State<AddTripLogScreen> createState() => _AddTripLogScreenState();
}

class _AddTripLogScreenState extends State<AddTripLogScreen> {
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
  
  @override
  void initState() {
    super.initState();
    _loadAssignment();
  }
  
  @override
  void dispose() {
    _fareController.dispose();
    _expensesController.dispose();
    _notesController.dispose();
    super.dispose();
  }
  
  Future<void> _loadAssignment() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      // Check if there's an active assignment for this bus
      final activeAssignment = await supabase
          .from('bus_assignments')
          .select('''
            *,
            drivers(*),
            conductors(*)
          ''')
          .eq('bus_id', widget.bus['id'])
          .eq('is_active', true)
          .maybeSingle();
    
      setState(() {
        _currentAssignment = activeAssignment;
      
        if (_currentAssignment != null) {
          _selectedDriver = _currentAssignment!['drivers'];
          _selectedConductor = _currentAssignment!['conductors'];
        }
        
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading assignment: $e');
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading assignment data: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Trip Log - ${widget.bus['plate_number']}'),
        backgroundColor: const Color(0xFF2F27CE),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2F27CE)))
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Bus Info Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDEDCFF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.directions_bus, color: Color(0xFF2F27CE), size: 36),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.bus['plate_number'],
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${widget.bus['model']} (${widget.bus['year_manufactured']})',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Trip Date Section
                    const Text('Trip Date', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _tripDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 30)),
                          lastDate: DateTime.now(),
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
                            _tripDate = date;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, color: Color(0xFF2F27CE)),
                            const SizedBox(width: 12),
                            Text(
                              DateFormat('EEEE, MMM dd, yyyy').format(_tripDate),
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Assigned Staff Section
                    if (_currentAssignment != null) ...[
                      const Text('Assigned Staff', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.person, color: Colors.blue),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Driver', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                      Text(
                                        '${_selectedDriver!['first_name']} ${_selectedDriver!['last_name']}',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.person_outline, color: Colors.orange),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Conductor', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                      Text(
                                        '${_selectedConductor!['first_name']} ${_selectedConductor!['last_name']}',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3DC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFFB648)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 36),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'No Active Assignment',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFD32F2F),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Please assign a driver and conductor to this bus first before adding trip logs.',
                                    style: TextStyle(color: Color(0xFFD32F2F)),
                                  ),
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                    },
                                    style: TextButton.styleFrom(
                                      backgroundColor: const Color(0xFF2F27CE),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    ),
                                    child: const Text('Go Back & Assign Staff'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    
                    if (_currentAssignment != null) ...[
                      // Financial Details Section
                      const Text('Financial Details', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                      const SizedBox(height: 16),
                      
                      // Fare Collected
                      TextFormField(
                        controller: _fareController,
                        decoration: InputDecoration(
                          labelText: 'Fare Collected (₱)',
                          prefixIcon: const Icon(Icons.payments, color: Color(0xFF2F27CE)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF2F27CE)),
                          ),
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
                        decoration: InputDecoration(
                          labelText: 'Expenses (₱)',
                          prefixIcon: const Icon(Icons.money_off, color: Color(0xFF2F27CE)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF2F27CE)),
                          ),
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
                      const SizedBox(height: 24),
                      
                      // Bus Status Section
                      const Text('Bus Status', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                      const SizedBox(height: 16),
                      
                      // Bus Condition
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Bus Condition',
                          prefixIcon: const Icon(Icons.health_and_safety, color: Color(0xFF2F27CE)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF2F27CE)),
                          ),
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
                        decoration: InputDecoration(
                          labelText: 'Notes/Remarks',
                          prefixIcon: const Icon(Icons.note, color: Color(0xFF2F27CE)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF2F27CE)),
                          ),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 32),
                      
                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _saveTrip,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2F27CE),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Save Trip Log',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
  
  Future<void> _saveTrip() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Create trip log
      final tripData = {
        'bus_id': widget.bus['id'],
        'driver_id': _selectedDriver!['id'],
        'conductor_id': _selectedConductor!['id'],
        'trip_date': DateFormat('yyyy-MM-dd').format(_tripDate),
        'fare_collected': double.parse(_fareController.text),
        'expenses': double.parse(_expensesController.text),
        'bus_condition': _busCondition,
        'notes': _notesController.text,
        'created_by': supabase.auth.currentUser!.id,
        'created_at': DateTime.now().toIso8601String(),
      };
      
      await supabase.from('bus_trip_logs').insert(tripData);
      
      // Update bus status if condition is poor or needs maintenance
      if (_busCondition == 'Poor' || _busCondition == 'Needs Maintenance') {
        await supabase
          .from('bus_units')
          .update({'status': 'maintenance'})
          .eq('id', widget.bus['id']);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trip log added successfully!'),
            backgroundColor: Color(0xFF2F27CE),
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      print('Error adding trip log: $e');
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding trip log: $e')),
        );
      }
    }
  }
}