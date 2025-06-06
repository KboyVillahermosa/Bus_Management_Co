import 'package:flutter/material.dart';
import 'package:bus_management/config/supabase_config.dart';
import 'package:intl/intl.dart';

class BusAssignmentScreen extends StatefulWidget {
  final Map<String, dynamic> bus;
  
  const BusAssignmentScreen({Key? key, required this.bus}) : super(key: key);

  @override
  State<BusAssignmentScreen> createState() => _BusAssignmentScreenState();
}

class _BusAssignmentScreenState extends State<BusAssignmentScreen> {
  final _formKey = GlobalKey<FormState>();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  Map<String, dynamic>? _selectedDriver;
  Map<String, dynamic>? _selectedConductor;
  List<Map<String, dynamic>> _drivers = [];
  List<Map<String, dynamic>> _conductors = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Get all drivers
      final driversData = await supabase.from('drivers').select('*');
      
      // Get all conductors
      final conductorsData = await supabase.from('conductors').select('*');
  
      setState(() {
        _drivers = List<Map<String, dynamic>>.from(driversData);
        _conductors = List<Map<String, dynamic>>.from(conductorsData);
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Assign Staff - ${widget.bus['plate_number']}'),
        backgroundColor: const Color(0xFF2F27CE),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2F27CE)))
          : _drivers.isEmpty || _conductors.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 64),
                      const SizedBox(height: 16),
                      const Text(
                        'No available drivers or conductors found',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text('Please add drivers and conductors first'),
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
              : Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDEDCFF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.directions_bus, color: Color(0xFF2F27CE)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Bus Details',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF2F27CE),
                                      ),
                                    ),
                                    Text('Plate: ${widget.bus['plate_number']}'),
                                    Text('Model: ${widget.bus['model']} (${widget.bus['year_manufactured']})'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Driver Selection
                        const Text('Driver', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                        const SizedBox(height: 8),
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
                        const SizedBox(height: 24),
                        
                        // Conductor Selection
                        const Text('Conductor', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                        const SizedBox(height: 8),
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
                              String displayName;
                              
                              if (conductor['first_name'] != null) {
                                displayName = '${conductor['first_name']} ${conductor['last_name'] ?? ''}';
                              }
                              else if (conductor['name'] != null) {
                                displayName = conductor['name'];
                              }
                              else if (conductor['contact_number'] != null) {
                                displayName = 'Conductor (${conductor['contact_number']})';
                              }
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
                        
                        // Assignment Period
                        const Text('Assignment Period', 
                          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)
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
                                      // If end date is before new start date, update it
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
                        
                        const SizedBox(height: 32),
                        
                        // Save Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _saveAssignment,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2F27CE),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Assign Staff',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
  
  Future<void> _saveAssignment() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Deactivate any current active assignments for this bus
      await supabase
        .from('bus_assignments')
        .update({
          'is_active': false, 
          'end_date': DateFormat('yyyy-MM-dd').format(DateTime.now())
        })
        .eq('bus_id', widget.bus['id'])
        .eq('is_active', true);
      
      // Create new assignment
      final assignmentData = {
        'bus_id': widget.bus['id'],
        'driver_id': _selectedDriver!['id'],
        'conductor_id': _selectedConductor!['id'],
        'assignment_date': DateFormat('yyyy-MM-dd').format(_startDate),
        'end_date': DateFormat('yyyy-MM-dd').format(_endDate),
        'is_active': true,
        'created_by': supabase.auth.currentUser!.id,
        'created_at': DateTime.now().toIso8601String(),
      };
      
      await supabase.from('bus_assignments').insert(assignmentData);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Staff assigned successfully!'),
            backgroundColor: Color(0xFF2F27CE),
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      print('Error assigning staff: $e');
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error assigning staff: $e')),
        );
      }
    }
  }
}