import 'package:flutter/material.dart';
import 'package:bus_management/config/supabase_config.dart';
import 'package:bus_management/screens/bus_units/permit_detail_screen.dart';
import 'package:intl/intl.dart';

class AppStyles {
  static const Color primary = Color(0xFF2F27CE);
  static const Color primaryLight = Color(0xFFE8E8FF);
  static const Color background = Color(0xFFF8F9FC);
  static const Color cardBg = Colors.white;
  static const Color textDark = Color(0xFF050315);
  static const Color textMedium = Color(0xFF6B7280);
  static const Color textLight = Color(0xFF9CA3AF);
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFFACC15);
  static const Color error = Color(0xFFEF4444);
  static const Color border = Color(0xFFE5E7EB);
  
  static final elevatedButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: primary,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(vertical: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    elevation: 0,
  );
  
  static final inputDecoration = InputDecoration(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: border, width: 1),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: border, width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: primary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: error, width: 1),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    labelStyle: const TextStyle(color: textMedium),
    hintStyle: const TextStyle(color: textLight),
    floatingLabelBehavior: FloatingLabelBehavior.auto,
  );
}

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
      
      // Use Future.microtask to ensure setState happens after build
      Future.microtask(() {
        if (mounted) {
          setState(() {
            _isLoadingPermits = true;
          });
          _loadPermits();
        }
      });
    }
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
      // Create a timer to ensure loading shows for at least 1 second
      final loadingStart = DateTime.now();
      
      final data = await supabase
          .from('bus_permits')
          .select('*')
          .eq('bus_id', widget.busData!['id'])
          .order('expiration_date', ascending: true);
      
      // Ensure loading indicator shows for at least 800ms for better UX
      final loadingElapsed = DateTime.now().difference(loadingStart).inMilliseconds;
      if (loadingElapsed < 800) {
        await Future.delayed(Duration(milliseconds: 800 - loadingElapsed));
      }
      
      if (mounted) {
        setState(() {
          _permits = List<Map<String, dynamic>>.from(data);
          _isLoadingPermits = false;
        });
      }
    } catch (e) {
      print('Error loading permits: $e');
      if (mounted) {
        setState(() {
          _isLoadingPermits = false;
        });
      }
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
      
      if (widget.isEditing) {
        await supabase
            .from('bus_units')
            .update(busData)
            .eq('id', widget.busData!['id']);
      } else {
        await supabase
            .from('bus_units')
            .insert(busData)
            .select();
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
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(e.toString())),
            ],
          ),
          backgroundColor: AppStyles.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Future<void> _deleteBus() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppStyles.error),
            const SizedBox(width: 12),
            const Text('Delete Bus?'),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete this bus? This will also delete all associated permits and cannot be undone.'
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_forever, size: 18),
            label: const Text('Delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppStyles.error,
              foregroundColor: Colors.white,
            ),
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
        SnackBar(
          content: Text('Error deleting bus: $e'),
          backgroundColor: AppStyles.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyles.background,
      appBar: AppBar(
        title: Text(
          widget.isEditing ? 'Edit Bus Details' : 'Add New Bus',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppStyles.primary,
        elevation: 0,
        actions: [
          if (widget.isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              tooltip: 'Delete',
              onPressed: _deleteBus,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppStyles.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bus Information Form Card
                  _buildCard(
                    title: 'Bus Information',
                    icon: Icons.directions_bus_outlined,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Status Indicator - only show in edit mode
                          if (widget.isEditing) _buildStatusBadge(_status),
                          const SizedBox(height: 16),
                          
                          // Plate Number
                          TextFormField(
                            controller: _plateNumberController,
                            decoration: AppStyles.inputDecoration.copyWith(
                              labelText: 'Plate Number',
                              hintText: 'Enter plate number',
                              prefixIcon: const Icon(Icons.credit_card_outlined, color: AppStyles.primary),
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
                            decoration: AppStyles.inputDecoration.copyWith(
                              labelText: 'Bus Model',
                              hintText: 'Enter bus model',
                              prefixIcon: const Icon(Icons.commute_outlined, color: AppStyles.primary),
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
                                  decoration: AppStyles.inputDecoration.copyWith(
                                    labelText: 'Year',
                                    hintText: 'YYYY',
                                    prefixIcon: const Icon(Icons.date_range_outlined, color: AppStyles.primary),
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
                                  decoration: AppStyles.inputDecoration.copyWith(
                                    labelText: 'Capacity',
                                    hintText: 'Seats',
                                    prefixIcon: const Icon(Icons.event_seat_outlined, color: AppStyles.primary),
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
                            decoration: AppStyles.inputDecoration.copyWith(
                              labelText: 'Status',
                              prefixIcon: const Icon(Icons.troubleshoot_outlined, color: AppStyles.primary),
                            ),
                            items: <String>['active', 'maintenance', 'inactive']
                                .map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: _getStatusColor(value),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(value.capitalize()),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                _status = newValue!;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // Acquisition Date - Modern design
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _acquisitionDate ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime.now(),
                                builder: (context, child) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: const ColorScheme.light(
                                        primary: AppStyles.primary,
                                        onPrimary: Colors.white,
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              
                              if (picked != null) {
                                setState(() {
                                  _acquisitionDate = picked;
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppStyles.border),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today_outlined, color: AppStyles.primary),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Acquisition Date',
                                        style: TextStyle(
                                          color: AppStyles.textMedium,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        _acquisitionDate != null
                                            ? DateFormat('MMMM dd, yyyy').format(_acquisitionDate!)
                                            : 'Select date',
                                        style: TextStyle(
                                          color: _acquisitionDate != null 
                                              ? AppStyles.textDark 
                                              : AppStyles.textLight,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  const Icon(Icons.arrow_drop_down, color: AppStyles.textMedium),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Notes
                          TextFormField(
                            controller: _notesController,
                            decoration: AppStyles.inputDecoration.copyWith(
                              labelText: 'Notes',
                              hintText: 'Enter any additional information about this bus',
                              prefixIcon: const Icon(Icons.note_alt_outlined, color: AppStyles.primary),
                              alignLabelWithHint: true,
                            ),
                            maxLines: 3,
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saveBus,
                      icon: Icon(widget.isEditing ? Icons.update : Icons.add),
                      label: Text(
                        widget.isEditing ? 'Update Bus Details' : 'Add New Bus',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      style: AppStyles.elevatedButtonStyle,
                    ),
                  ),
                  
                  // Permits Section (only for editing)
                  if (widget.isEditing) ...[
                    const SizedBox(height: 32),
                    
                    // Section header with action button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.fact_check_outlined, 
                                color: AppStyles.primary, size: 24),
                            const SizedBox(width: 12),
                            const Text(
                              'Permits & Certifications',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppStyles.textDark,
                              ),
                            ),
                          ],
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
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Permit'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppStyles.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            textStyle: const TextStyle(fontWeight: FontWeight.w500),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Permits list
                    _isLoadingPermits
                        ? Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(
                                    width: 40, 
                                    height: 40, 
                                    child: CircularProgressIndicator(
                                      color: AppStyles.primary,
                                      strokeWidth: 3,
                                    )
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    "Loading permit data...",
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : _permits.isEmpty
                            ? _buildEmptyPermitsState()
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _permits.length,
                                itemBuilder: (context, index) {
                                  return _buildPermitCard(_permits[index]);
                                },
                              ),
                  ],
                ],
              ),
            ),
    );
  }
  
  // Helper method to build consistent cards for sections
  Widget _buildCard({required String title, required IconData icon, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppStyles.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: AppStyles.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppStyles.textDark,
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Divider(height: 30),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: child,
          ),
        ],
      ),
    );
  }
  
  // Status badge for bus status
  Widget _buildStatusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _getStatusColor(status).withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _getStatusColor(status),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            status.capitalize(),
            style: TextStyle(
              color: _getStatusColor(status),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
  
  // Helper method to get status color
  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return AppStyles.success;
      case 'maintenance':
        return AppStyles.warning;
      case 'inactive':
        return AppStyles.error;
      default:
        return AppStyles.textMedium;
    }
  }
  
  // Enhanced empty state for permits
  Widget _buildEmptyPermitsState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppStyles.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppStyles.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.fact_check_outlined,
              color: AppStyles.primary,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Permits Added Yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppStyles.textDark,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Add permits and certifications to track their expiration dates and keep your fleet compliant.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppStyles.textMedium),
          ),
          const SizedBox(height: 16),
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
            label: const Text('Add First Permit'),
            style: AppStyles.elevatedButtonStyle,
          ),
        ],
      ),
    );
  }

  // Enhanced permit card design
  Widget _buildPermitCard(Map<String, dynamic> permit) {
    final formatter = DateFormat('MMM dd, yyyy');
    final expiration = DateTime.parse(permit['expiration_date']);
    final now = DateTime.now();
    final daysLeft = expiration.difference(now).inDays;
    
    Color statusColor;
    String statusText;
    
    if (daysLeft < 0) {
      statusColor = AppStyles.error;
      statusText = 'Expired';
    } else if (daysLeft <= 7) {
      statusColor = AppStyles.error;
      statusText = 'Expires in $daysLeft days';
    } else if (daysLeft <= 30) {
      statusColor = AppStyles.warning;
      statusText = 'Expires in $daysLeft days';
    } else {
      statusColor = AppStyles.success;
      statusText = 'Active';
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: statusColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _editPermit(permit),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getPermitIcon(permit['permit_type']),
                      color: statusColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatPermitType(permit['permit_type']),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppStyles.textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: statusColor,
                              ),
                            ),
                            const SizedBox(width: 6),
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
                          color: AppStyles.textLight,
                        ),
                      ),
                      Text(
                        formatter.format(expiration),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              if (permit['document_url'] != null) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.file_present_outlined,
                      size: 16,
                      color: AppStyles.textMedium,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Document uploaded',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppStyles.textMedium,
                      ),
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: () {
                        // Open the document
                      },
                      icon: const Icon(Icons.visibility_outlined, size: 16),
                      label: const Text('View'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppStyles.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        visualDensity: VisualDensity.compact,
                        side: const BorderSide(color: AppStyles.primary, width: 1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _editPermit(permit),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppStyles.primary,
                      visualDensity: VisualDensity.compact,
                      textStyle: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getPermitIcon(String permitType) {
    switch (permitType) {
      case 'ltfrb_cpc':
        return Icons.card_membership_outlined;
      case 'lto_registration':
        return Icons.fact_check_outlined;
      case 'emission_test':
        return Icons.eco_outlined;
      case 'business_permit':
        return Icons.business_outlined;
      default:
        return Icons.description_outlined;
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
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}