import 'dart:io';
import 'package:flutter/material.dart';
import 'package:bus_management/config/supabase_config.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;

class PermitDetailScreen extends StatefulWidget {
  final String busId;
  final String busPlateNumber;
  final Map<String, dynamic>? permitData;
  final bool isEditing;

  const PermitDetailScreen({
    super.key,
    required this.busId,
    required this.busPlateNumber,
    this.permitData,
    this.isEditing = false,
  });

  @override
  State<PermitDetailScreen> createState() => _PermitDetailScreenState();
}

class _PermitDetailScreenState extends State<PermitDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _fileErrorText;
  
  // Form data
  String _permitType = 'ltfrb_cpc';
  DateTime _issueDate = DateTime.now();
  DateTime _expirationDate = DateTime.now().add(const Duration(days: 365));
  final _notesController = TextEditingController();
  
  // File upload
  File? _selectedFile;
  String? _existingFileUrl;
  bool _isFileChanged = false;

  @override
  void initState() {
    super.initState();
    
    if (widget.isEditing && widget.permitData != null) {
      _permitType = widget.permitData!['permit_type'];
      _issueDate = DateTime.parse(widget.permitData!['issue_date']);
      _expirationDate = DateTime.parse(widget.permitData!['expiration_date']);
      _notesController.text = widget.permitData!['notes'] ?? '';
      _existingFileUrl = widget.permitData!['document_url'];
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
          _isFileChanged = true;
          _fileErrorText = null;
        });
      }
    } catch (e) {
      print('Error picking file: $e');
      setState(() {
        _fileErrorText = 'Error selecting file: $e';
      });
    }
  }

  Future<String?> _uploadFile() async {
    if (_selectedFile == null) return _existingFileUrl;
    
    try {
      final fileName = '${widget.busId}/${_permitType}_${DateTime.now().millisecondsSinceEpoch}${path.extension(_selectedFile!.path)}';
      
      final response = await supabase
          .storage
          .from('bus_permits')
          .upload(fileName, _selectedFile!);
      
      // Get public URL
      final publicUrl = supabase
          .storage
          .from('bus_permits')
          .getPublicUrl(fileName);
      
      return publicUrl;
    } catch (e) {
      print('Error uploading file: $e');
      throw Exception('Failed to upload document: $e');
    }
  }

  Future<void> _savePermit() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedFile == null && _existingFileUrl == null) {
      setState(() {
        _fileErrorText = 'Please upload a document file';
      });
      return;
    }
    
    try {
      setState(() {
        _isLoading = true;
      });
      
      String? documentUrl = _existingFileUrl;
      
      if (_isFileChanged) {
        documentUrl = await _uploadFile();
      }
      
      final permitData = {
        'bus_id': widget.busId,
        'permit_type': _permitType,
        'issue_date': _issueDate.toIso8601String(),
        'expiration_date': _expirationDate.toIso8601String(),
        'notes': _notesController.text,
        'document_url': documentUrl,
      };
      
      if (widget.isEditing) {
        await supabase
            .from('bus_permits')
            .update(permitData)
            .eq('id', widget.permitData!['id']);
      } else {
        await supabase
            .from('bus_permits')
            .insert(permitData);
      }
      
      if (!mounted) return;
      
      Navigator.pop(context, true);
    } catch (e) {
      print('Error saving permit: $e');
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving permit: $e')),
      );
    }
  }

  Future<void> _deletePermit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Permit?'),
        content: const Text(
          'Are you sure you want to delete this permit? This action cannot be undone.'
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
          .from('bus_permits')
          .delete()
          .eq('id', widget.permitData!['id']);
      
      if (!mounted) return;
      
      Navigator.pop(context, true);
    } catch (e) {
      print('Error deleting permit: $e');
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting permit: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing ? 'Edit Permit' : 'Add New Permit',
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
              onPressed: _deletePermit,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2F27CE)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Bus Info (read-only)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.directions_bus,
                            color: Color(0xFF2F27CE),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Adding permit for:',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                widget.busPlateNumber,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF050315),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Permit Information
                    const Text(
                      'Permit Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF050315),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Permit Type
                    DropdownButtonFormField<String>(
                      value: _permitType,
                      decoration: const InputDecoration(
                        labelText: 'Permit Type',
                        border: OutlineInputBorder(),
                      ),
                      items: <Map<String, String>>[
                        {'value': 'ltfrb_cpc', 'label': 'LTFRB CPC'},
                        {'value': 'lto_registration', 'label': 'LTO Registration'},
                        {'value': 'emission_test', 'label': 'Emission Test'},
                        {'value': 'business_permit', 'label': 'Business Permit'},
                      ].map<DropdownMenuItem<String>>((Map<String, String> item) {
                        return DropdownMenuItem<String>(
                          value: item['value'],
                          child: Text(item['label']!),
                        );
                      }).toList(),
                      onChanged: widget.isEditing
                          ? null // Disable changing permit type when editing
                          : (String? newValue) {
                              setState(() {
                                _permitType = newValue!;
                              });
                            },
                    ),
                    const SizedBox(height: 16),
                    
                    // Issue Date & Expiration Date
                    Row(
                      children: [
                        Expanded(
                          child: _buildDateField(
                            label: 'Issue Date',
                            date: _issueDate,
                            onChanged: (date) {
                              setState(() {
                                _issueDate = date;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildDateField(
                            label: 'Expiration Date',
                            date: _expirationDate,
                            onChanged: (date) {
                              setState(() {
                                _expirationDate = date;
                              });
                            },
                            validator: (date) {
                              if (date.isBefore(_issueDate)) {
                                return 'Must be after issue date';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Document Upload
                    const Text(
                      'Document Upload',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF050315),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Upload a scanned copy or photo of the permit document.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    InkWell(
                      onTap: _selectFile,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _fileErrorText != null ? Colors.red : Colors.grey[300]!,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.upload_file,
                                color: Color(0xFF2F27CE),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedFile != null
                                        ? path.basename(_selectedFile!.path)
                                        : _existingFileUrl != null
                                            ? 'Document Uploaded'
                                            : 'Select a file',
                                    style: TextStyle(
                                      fontWeight: _selectedFile != null || _existingFileUrl != null
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (_fileErrorText != null)
                                    Text(
                                      _fileErrorText!,
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const Icon(Icons.touch_app),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Notes
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        border: OutlineInputBorder(),
                        hintText: 'Add any additional information, violations, or penalties',
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),
                    
                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _savePermit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2F27CE),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          widget.isEditing ? 'Update Permit' : 'Save Permit',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime date,
    required Function(DateTime) onChanged,
    String? Function(DateTime)? validator,
  }) {
    final formatter = DateFormat('MMM dd, yyyy');
    String? errorText;
    
    if (validator != null) {
      errorText = validator(date);
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: date,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            
            if (picked != null) {
              onChanged(picked);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(
                color: errorText != null ? Colors.red : Colors.grey[400]!,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  formatter.format(date),
                  style: const TextStyle(
                    fontSize: 16,
                  ),
                ),
                const Icon(Icons.calendar_today, size: 18),
              ],
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 12),
            child: Text(
              errorText,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}