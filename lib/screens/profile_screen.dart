import 'package:flutter/material.dart';
import 'package:bus_management/config/supabase_config.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Theme.of(context).primaryColor,
                      child: Text(
                        _userData['first_name']?.isNotEmpty == true
                            ? _userData['first_name'][0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 40,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ProfileInfoTile(
                    label: 'First Name',
                    value: _userData['first_name'] ?? 'Not set',
                  ),
                  ProfileInfoTile(
                    label: 'Middle Name',
                    value: _userData['middle_name'] ?? 'Not set',
                  ),
                  ProfileInfoTile(
                    label: 'Last Name',
                    value: _userData['last_name'] ?? 'Not set',
                  ),
                  ProfileInfoTile(
                    label: 'Email',
                    value: _userData['email'] ?? 'Not set',
                  ),
                  ProfileInfoTile(
                    label: 'Member Since',
                    value: _userData['created_at'] != null
                        ? DateTime.parse(_userData['created_at']).toString().split('.')[0]
                        : 'Not available',
                  ),
                ],
              ),
            ),
    );
  }
}

class ProfileInfoTile extends StatelessWidget {
  final String label;
  final String value;

  const ProfileInfoTile({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Divider(),
        ],
      ),
    );
  }
}