import 'package:flutter/material.dart';
import 'package:bus_management/config/supabase_config.dart';
import 'package:bus_management/screens/bus_units/permit_detail_screen.dart';
import 'package:intl/intl.dart';

class BusDetailScreen extends StatefulWidget {
  final bool isEditing;
  final Map<String, dynamic>? busData;

  const BusDetailScreen({
    super.key,
    required this.isEditing,
    this.busData,
  });

  @override
  State<BusDetailScreen> createState() => _BusDetailScreenState();
}

class _BusDetailScreenState extends State<BusDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isLoadingPermits = true;
  List<Map<String, dynamic>> _permits = [];

  // Form controllers
  final _plateNumberController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _capacityController = TextEditingController();
  final _notesController = TextEditingController();
  String _status = 'active';
  DateTime? _acquisitionDate;

  @override
  void initState() {
    super.initState();
    
    if (widget.isEditing && widget.busData != null) {
      _plateNumberController.text = widget.busData!['plate_number'];
      _modelController.text = widget.busData!['model'];
      _yearController.text = widget.busData!['year'].toString();
      _capacityController.text = widget.busData!['capacity'].toString();
      _notesController.text = widget.busData!['notes'] ?? '';
      _status = widget.busData!['status'];
      
      if (widget.busData!['acquisition_date'] != null) {
        _acquisitionDate = DateTime.parse(widget.busData!['acquisition_date']);
      }
      
      _loadPermits();
    }
    
    _fetchPermits();
  }

  @override
  void dispose() {
    _plateNumberController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _capacityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadPermits() async {
    if (!widget.isEditing || widget.busData == null) return;
    
    try {
      setState(() {
        _isLoadingPermits = true;
      });
      
      final data = await supabase
          .from('bus_permits')
          .select('*')
          .eq('bus_id', widget.busData!['id'])
          .order('expiration_date', ascending: true);
      
      setState(() {
        _permits = List<Map<String, dynamic>>.from(data);
        _isLoadingPermits = false;
      });
    } catch (e) {
      print('Error loading permits: $e');
      setState(() {
        _isLoadingPermits = false;
      });
    }
  }

  Future<void> _fetchPermits() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final response = await supabase
          .from('permits')
          .select('*')
          .eq('bus_id', widget.busData!['id'])
          .order('expiration_date');
      
      print('Fetched permits: ${response.length}');
      
      setState(() {
        _permits = response;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching permits: $e');
      setState(() {
        _isLoading = false;
        // _error = 'Failed to load permits: $e'; // Uncomment if you have an error handling mechanism
      });
    }
  }

  Future<void> _saveBus() async {
    if (!_formKey.currentState!.validate()) return;
    
    try {
      setState(() {
        _isLoading = true;
      });
      
      final busData = {
        'plate_number': _plateNumberController.text.trim(),
        'model': _modelController.text.trim(),
        'year': int.parse(_yearController.text.trim()),
        'capacity': int.parse(_capacityController.text.trim()),
        'status': _status,
        'notes': _notesController.text,
        'acquisition_date': _acquisitionDate?.toIso8601String(),
      };
      
      // For debugging - check what's being sent
      print('Saving bus data: $busData');
      
      if (widget.isEditing) {
        final response = await supabase
            .from('bus_units')
            .update(busData)
            .eq('id', widget.busData!['id']);
        
        print('Update response: $response');
      } else {
        final response = await supabase
            .from('bus_units')
            .insert(busData)
            .select();
        
        print('Insert response: $response');
      }
      
      if (!mounted) return;
      
      Navigator.pop(context, true);
    } catch (e) {
      print('Error saving bus: $e');
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteBus() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Bus?'),
        content: const Text(
          'Are you sure you want to delete this bus? This will also delete all associated permits and cannot be undone.'
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
      
      await supabase
          .from('bus_units')
          .delete()
          .eq('id', widget.busData!['id']);
      
      if (!mounted) return;
      
      Navigator.pop(context, true);
    } catch (e) {
      print('Error deleting bus: $e');
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting bus: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing ? 'Edit Bus' : 'Add New Bus',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: const Color(0xFF2F27CE),
        elevation: 0,
        actions: [
          if (widget.isEditing)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.white),
              tooltip: 'Delete',
              onPressed: _deleteBus,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2F27CE)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bus Information Form
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bus Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF050315),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Plate Number
                        TextFormField(
                          controller: _plateNumberController,
                          decoration: const InputDecoration(
                            labelText: 'Plate Number *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter plate number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // Model
                        TextFormField(
                          controller: _modelController,
                          decoration: const InputDecoration(
                            labelText: 'Bus Model *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter bus model';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // Year and Capacity (side by side)
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _yearController,
                                decoration: const InputDecoration(
                                  labelText: 'Year *',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Required';
                                  }
                                  if (int.tryParse(value) == null) {
                                    return 'Enter a valid year';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _capacityController,
                                decoration: const InputDecoration(
                                  labelText: 'Capacity *',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Required';
                                  }
                                  if (int.tryParse(value) == null) {
                                    return 'Enter a valid number';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Status dropdown
                        DropdownButtonFormField<String>(
                          value: _status,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                            border: OutlineInputBorder(),
                          ),
                          items: <String>['active', 'maintenance', 'inactive']
                              .map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value.capitalize()),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _status = newValue!;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // Acquisition Date
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Acquisition Date'),
                          subtitle: Text(
                            _acquisitionDate != null
                                ? DateFormat('MMMM dd, yyyy').format(_acquisitionDate!)
                                : 'Not set',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.calendar_today),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _acquisitionDate ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime.now(),
                              );
                              
                              if (picked != null) {
                                setState(() {
                                  _acquisitionDate = picked;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Notes
                        TextFormField(
                          controller: _notesController,
                          decoration: const InputDecoration(
                            labelText: 'Notes',
                            border: OutlineInputBorder(),
                            hintText: 'Enter any additional information about this bus',
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 24),
                        
                        // Save Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _saveBus,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2F27CE),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              widget.isEditing ? 'Update Bus' : 'Add Bus',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Permits Section (only for editing)
                  if (widget.isEditing) ...[
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Permits',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF050315),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PermitDetailScreen(
                                  busId: widget.busData!['id'],
                                  busPlateNumber: widget.busData!['plate_number'],
                                ),
                              ),
                            );
                            
                            if (result == true) {
                              _loadPermits();
                            }
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Add Permit'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2F27CE),
                            foregroundColor: Colors.white,
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    _isLoadingPermits
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFF2F27CE)))
                        : _permits.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 24),
                                  child: Text(
                                    'No permits added yet. Add a permit to track its expiration.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: NeverScrollableScrollPhysics(),
                                itemCount: _permits.length,
                                itemBuilder: (context, index) {
                                  final permit = _permits[index];
                                  final isExpiring = DateTime.parse(permit['expiration_date'])
                                      .difference(DateTime.now())
                                      .inDays < 30;
                                  
                                  return ListTile(
                                    title: Text(_getPermitTypeLabel(permit['permit_type'])),
                                    subtitle: Text('Expires: ${DateFormat('MMM dd, yyyy').format(
                                      DateTime.parse(permit['expiration_date'])
                                    )}'),
                                    trailing: Icon(
                                      Icons.warning,
                                      color: isExpiring ? Colors.orange : Colors.transparent,
                                    ),
                                    onTap: () => _editPermit(permit),
                                  );
                                },
                              ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildPermitCard(Map<String, dynamic> permit) {
    final formatter = DateFormat('MMM dd, yyyy');
    final expiration = DateTime.parse(permit['expiration_date']);
    final now = DateTime.now();
    final daysLeft = expiration.difference(now).inDays;
    
    Color statusColor;
    String statusText;
    
    if (daysLeft < 0) {
      statusColor = Colors.red;
      statusText = 'Expired';
    } else if (daysLeft <= 7) {
      statusColor = Colors.red;
      statusText = 'Expires in $daysLeft days';
    } else if (daysLeft <= 15) {
      statusColor = Colors.orange;
      statusText = 'Expires in $daysLeft days';
    } else if (daysLeft <= 30) {
      statusColor = Colors.amber;
      statusText = 'Expires in $daysLeft days';
    } else {
      statusColor = Colors.green;
      statusText = 'Active';
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: statusColor.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PermitDetailScreen(
                busId: widget.busData!['id'],
                busPlateNumber: widget.busData!['plate_number'],
                permitData: permit,
                isEditing: true,
              ),
            ),
          );
          
          if (result == true) {
            _loadPermits();
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getPermitIcon(permit['permit_type']),
                      color: statusColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatPermitType(permit['permit_type']),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Expires on',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        formatter.format(expiration),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              if (permit['document_url'] != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.file_present,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Document uploaded',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        // Open the document
                        // Use url_launcher package to open the URL
                      },
                      icon: const Icon(Icons.visibility, size: 16),
                      label: const Text('View'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF2F27CE),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData _getPermitIcon(String permitType) {
    switch (permitType) {
      case 'ltfrb_cpc':
        return Icons.card_membership;
      case 'lto_registration':
        return Icons.fact_check;
      case 'emission_test':
        return Icons.eco;
      case 'business_permit':
        return Icons.business;
      default:
        return Icons.description;
    }
  }

  String _formatPermitType(String permitType) {
    switch (permitType) {
      case 'ltfrb_cpc':
        return 'LTFRB CPC';
      case 'lto_registration':
        return 'LTO Registration';
      case 'emission_test':
        return 'Emission Test';
      case 'business_permit':
        return 'Business Permit';
      default:
        return permitType.replaceAll('_', ' ').capitalize();
    }
  }

  String _getPermitTypeLabel(String type) {
  switch (type) {
    case 'ltfrb_cpc': return 'LTFRB CPC';
    case 'lto_registration': return 'LTO Registration';
    case 'emission_test': return 'Emission Test';
    case 'business_permit': return 'Business Permit';
    default: return type;
  }
}

  void _editPermit(Map<String, dynamic> permit) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PermitDetailScreen(
          busId: widget.busData!['id'],
          busPlateNumber: widget.busData!['plate_number'],
          permitData: permit,
          isEditing: true,
        ),
      ),
    );
    
    if (result == true) {
      _loadPermits();
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}