import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/driver.dart';

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
    
    // Initialize controllers with firstName and lastName instead of splitting name
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
        'first_name': _firstNameController.text.trim(),  // Changed from 'name' to 'first_name'
        'last_name': _lastNameController.text.trim(),    // Added 'last_name' 
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Driver added successfully')),
        );
      } else {
        // Update existing driver 
        await _supabase
            .from('drivers')
            .update(driverData)
            .eq('id', widget.driver!.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Driver updated successfully')),
        );
      }
      
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.driver == null ? 'Add Driver' : 'Edit Driver'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _firstNameController,
                      decoration: const InputDecoration(
                        labelText: 'First Name *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter first name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _lastNameController,
                      decoration: const InputDecoration(
                        labelText: 'Last Name *', 
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter last name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _contactController,
                      decoration: const InputDecoration(
                        labelText: 'Contact Number *',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter contact number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                        labelText: 'Address *',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _licenseController,
                      decoration: const InputDecoration(
                        labelText: 'License Number *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter license number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _licenseExpiryController,
                      decoration: const InputDecoration(
                        labelText: 'License Expiry Date *',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      readOnly: true,
                      onTap: () => _selectDate(context, true),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select license expiry date';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _baseSalaryController,
                      decoration: const InputDecoration(
                        labelText: 'Base Salary *',
                        border: OutlineInputBorder(),
                        prefixText: '₱ ',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter base salary';
                        }
                        try {
                          double.parse(value);
                        } catch (e) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _hireDateController,
                      decoration: const InputDecoration(
                        labelText: 'Hire Date *',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      readOnly: true,
                      onTap: () => _selectDate(context, false),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select hire date';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Photo URL field
                    TextFormField(
                      initialValue: _photoUrl,
                      decoration: const InputDecoration(
                        labelText: 'Photo URL (Optional)',
                        border: OutlineInputBorder(),
                        helperText: 'Enter a URL for the driver\'s photo',
                      ),
                      onChanged: (value) {
                        setState(() {
                          _photoUrl = value.isEmpty ? null : value;
                        });
                      },
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _saveDriver,
                        child: Text(
                          widget.driver == null ? 'Add Driver' : 'Update Driver',
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
}