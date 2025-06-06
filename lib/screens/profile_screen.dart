import 'package:flutter/material.dart';
import 'package:bus_management/config/supabase_config.dart';
import 'package:intl/intl.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _userData = {};

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = supabase.auth.currentUser!.id;
      final data = await supabase
          .from('profiles')
          .select('*')
          .eq('id', userId)
          .single();

      setState(() {
        _userData = data;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading profile: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fullName = [
      _userData['first_name'] ?? '',
      _userData['middle_name'] ?? '',
      _userData['last_name'] ?? '',
    ].where((name) => name.isNotEmpty).join(' ');

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFC),
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: const Color(0xFF2F27CE),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              // Handle edit profile
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with profile avatar
                  Container(
                    color: const Color(0xFF2F27CE),
                    padding: const EdgeInsets.only(bottom: 24.0),
                    child: Center(
                      child: Column(
                        children: [
                          Hero(
                            tag: 'profile-avatar',
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                              ),
                              child: CircleAvatar(
                                radius: 50,
                                backgroundColor: Colors.white,
                                child: Text(
                                  _userData['first_name']?.isNotEmpty == true
                                      ? _userData['first_name'][0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    fontSize: 40,
                                    color: const Color(0xFF2F27CE),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            fullName.isNotEmpty ? fullName : 'User',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _userData['email'] ?? 'No email',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Profile details section
                  Container(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Personal Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2F27CE),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        Card(
                          elevation: 2,
                          shadowColor: Colors.black12,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              ProfileInfoTile(
                                icon: Icons.person_outline,
                                label: 'First Name',
                                value: _userData['first_name'] ?? 'Not set',
                                showDivider: true,
                              ),
                              ProfileInfoTile(
                                icon: Icons.person_outline,
                                label: 'Middle Name',
                                value: _userData['middle_name'] ?? 'Not set',
                                showDivider: true,
                              ),
                              ProfileInfoTile(
                                icon: Icons.person_outline,
                                label: 'Last Name',
                                value: _userData['last_name'] ?? 'Not set',
                                showDivider: false,
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        const Text(
                          'Account Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2F27CE),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        Card(
                          elevation: 2,
                          shadowColor: Colors.black12,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              ProfileInfoTile(
                                icon: Icons.email_outlined,
                                label: 'Email',
                                value: _userData['email'] ?? 'Not set',
                                showDivider: true,
                              ),
                              ProfileInfoTile(
                                icon: Icons.calendar_today_outlined,
                                label: 'Member Since',
                                value: _userData['created_at'] != null
                                    ? DateFormat('MMMM dd, yyyy').format(DateTime.parse(_userData['created_at']))
                                    : 'Not available',
                                showDivider: false,
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 30),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () {
                              // Handle logout
                              supabase.auth.signOut();
                              Navigator.of(context).pushReplacementNamed('/login');
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: BorderSide(color: Colors.red.shade300),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Sign Out',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class ProfileInfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool showDivider;

  const ProfileInfoTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF2F27CE).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: const Color(0xFF2F27CE),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(
            height: 1,
            indent: 60,
          ),
      ],
    );
  }
}