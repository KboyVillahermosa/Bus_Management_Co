import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/driver.dart';

// Enhanced theme colors for a more professional look
class AppColors {
  static const Color primary = Color(0xFF4444E5);
  static const Color primaryLight = Color(0xFFE8E8FF);
  static const Color background = Color(0xFFF5F7FF);
  static const Color cardBackground = Colors.white;
  static const Color textPrimary = Color(0xFF333333);
  static const Color textSecondary = Color(0xFF666666);
  static const Color border = Color(0xFFE0E0E0);
  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF388E3C);
}

class AddEditDriverScreen extends StatefulWidget {
  final Driver? driver;

  const AddEditDriverScreen({Key? key, this.driver}) : super(key: key);

  @override
  _AddEditDriverScreenState createState() => _AddEditDriverScreenState();
}

class _AddEditDriverScreenState extends State<AddEditDriverScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;

  // Form fields
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _contactController;
  late TextEditingController _addressController;
  late TextEditingController _licenseController;
  late TextEditingController _licenseExpiryController;
  late TextEditingController _baseSalaryController;
  late TextEditingController _hireDateController;
  String? _photoUrl;

  DateTime? _licenseExpiry;
  DateTime? _hireDate;

  @override
  void initState() {
    super.initState();
    
    _firstNameController = TextEditingController(text: widget.driver?.firstName ?? '');
    _lastNameController = TextEditingController(text: widget.driver?.lastName ?? '');
    _contactController = TextEditingController(text: widget.driver?.contactNumber ?? '');
    _addressController = TextEditingController(text: widget.driver?.address ?? '');
    _licenseController = TextEditingController(text: widget.driver?.licenseNumber ?? '');
    _licenseExpiryController = TextEditingController(
      text: widget.driver?.licenseExpiry != null 
        ? DateFormat('yyyy-MM-dd').format(widget.driver!.licenseExpiry)
        : ''
    );
    _baseSalaryController = TextEditingController(
      text: widget.driver?.baseSalary != null 
        ? widget.driver!.baseSalary.toString()
        : ''
    );
    _hireDateController = TextEditingController(
      text: widget.driver?.hireDate != null 
        ? DateFormat('yyyy-MM-dd').format(widget.driver!.hireDate)
        : ''
    );
    
    _licenseExpiry = widget.driver?.licenseExpiry;
    _hireDate = widget.driver?.hireDate;
    _photoUrl = widget.driver?.photo;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _contactController.dispose();
    _addressController.dispose();
    _licenseController.dispose();
    _licenseExpiryController.dispose();
    _baseSalaryController.dispose();
    _hireDateController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isLicenseExpiry) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isLicenseExpiry ? (_licenseExpiry ?? DateTime.now()) : (_hireDate ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.cardBackground,
              onSurface: AppColors.textPrimary,
            ),
            dialogBackgroundColor: AppColors.cardBackground,
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        if (isLicenseExpiry) {
          _licenseExpiry = picked;
          _licenseExpiryController.text = DateFormat('yyyy-MM-dd').format(picked);
        } else {
          _hireDate = picked;
          _hireDateController.text = DateFormat('yyyy-MM-dd').format(picked);
        }
      });
    }
  }

  Future<void> _saveDriver() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final driverData = {
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'contact_number': _contactController.text.trim(),
        'address': _addressController.text.trim(),
        'license_number': _licenseController.text.trim(),
        'license_expiry': _licenseExpiryController.text,
        'base_salary': double.parse(_baseSalaryController.text),
        'hire_date': _hireDateController.text,
        'photo': _photoUrl,
      };

      if (widget.driver == null) {
        // Add new driver
        await _supabase.from('drivers').insert(driverData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Driver added successfully'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        // Update existing driver 
        await _supabase
            .from('drivers')
            .update(driverData)
            .eq('id', widget.driver!.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Driver updated successfully'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
      
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Enhanced input decoration for consistency and professionalism
    final inputDecoration = InputDecoration(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      errorStyle: const TextStyle(color: AppColors.error),
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
      floatingLabelBehavior: FloatingLabelBehavior.auto,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.driver == null ? 'Add Driver' : 'Edit Driver',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Personal Information Card
                    _buildCard(
                      title: 'Driver Information',
                      icon: Icons.person,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _firstNameController,
                                decoration: inputDecoration.copyWith(
                                  labelText: 'First Name',
                                  prefixIcon: const Icon(Icons.person_outline, color: AppColors.primary, size: 20),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Required';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _lastNameController,
                                decoration: inputDecoration.copyWith(
                                  labelText: 'Last Name',
                                  prefixIcon: const Icon(Icons.person_outline, color: AppColors.primary, size: 20),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Required';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _contactController,
                          decoration: inputDecoration.copyWith(
                            labelText: 'Contact Number',
                            prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.primary, size: 20),
                          ),
                          keyboardType: TextInputType.phone,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _addressController,
                          decoration: inputDecoration.copyWith(
                            labelText: 'Address',
                            prefixIcon: const Icon(Icons.home_outlined, color: AppColors.primary, size: 20),
                            alignLabelWithHint: true,
                          ),
                          maxLines: 3,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Required';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // License & Employment Details Card
                    _buildCard(
                      title: 'License & Employment',
                      icon: Icons.badge,
                      children: [
                        TextFormField(
                          controller: _licenseController,
                          decoration: inputDecoration.copyWith(
                            labelText: 'License Number',
                            prefixIcon: const Icon(Icons.credit_card, color: AppColors.primary, size: 20),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _licenseExpiryController,
                          decoration: inputDecoration.copyWith(
                            labelText: 'License Expiry Date',
                            prefixIcon: const Icon(Icons.calendar_today, color: AppColors.primary, size: 20),
                            hintText: 'YYYY-MM-DD',
                          ),
                          readOnly: true,
                          onTap: () => _selectDate(context, true),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _baseSalaryController,
                          decoration: inputDecoration.copyWith(
                            labelText: 'Base Salary',
                            prefixIcon: const Icon(Icons.attach_money, color: AppColors.primary, size: 20),
                            prefixText: '₱ ',
                            prefixStyle: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Required';
                            }
                            try {
                              double.parse(value);
                            } catch (e) {
                              return 'Enter valid number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _hireDateController,
                          decoration: inputDecoration.copyWith(
                            labelText: 'Hire Date',
                            prefixIcon: const Icon(Icons.event, color: AppColors.primary, size: 20),
                            hintText: 'YYYY-MM-DD',
                          ),
                          readOnly: true,
                          onTap: () => _selectDate(context, false),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Required';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Optional Information Card
                    _buildCard(
                      title: 'Additional Information',
                      icon: Icons.info_outline,
                      children: [
                        TextFormField(
                          initialValue: _photoUrl,
                          decoration: inputDecoration.copyWith(
                            labelText: 'Photo URL (Optional)',
                            prefixIcon: const Icon(Icons.photo_outlined, color: AppColors.primary, size: 20),
                            helperText: 'Enter a URL for driver\'s photo',
                            helperStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.7)),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _photoUrl = value.isEmpty ? null : value;
                            });
                          },
                        ),
                        if (_photoUrl != null && _photoUrl!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                _photoUrl!,
                                height: 120,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    height: 120,
                                    width: double.infinity,
                                    color: Colors.grey.shade200,
                                    child: const Center(
                                      child: Icon(Icons.broken_image, color: Colors.grey),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _saveDriver,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          widget.driver == null ? 'Add Driver' : 'Update Driver',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  // Helper method to create consistent card styling
  Widget _buildCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 1,
      shadowColor: Colors.black12,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            ...children,
          ],
        ),
      ),
    );
  }
}