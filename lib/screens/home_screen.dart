import 'package:flutter/material.dart';
import 'package:bus_management/config/supabase_config.dart';
import 'package:bus_management/screens/login_screen.dart';
import 'package:bus_management/screens/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _userName = '';
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }
  
  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final userId = supabase.auth.currentUser!.id;
      final userData = await supabase.auth.currentUser?.userMetadata;
      
      if (userData != null) {
        String firstName = userData['first_name'] ?? '';
        String lastName = userData['last_name'] ?? '';
        
        if (firstName.isEmpty || lastName.isEmpty) {
          // Try to get from profiles table if not in metadata
          final data = await supabase
              .from('profiles')
              .select('first_name, last_name')
              .eq('id', userId)
              .maybeSingle();
              
          if (data != null) {
            firstName = data['first_name'] ?? '';
            lastName = data['last_name'] ?? '';
          }
        }
        
        setState(() {
          _userName = '$firstName $lastName';
          _isLoading = false;
        });
      } else {
        setState(() {
          _userName = 'User';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _userName = 'User';
        _isLoading = false;
      });
    }
  }

  Future<void> _signOut() async {
    await supabase.auth.signOut();
    if (!mounted) return;
    
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bus Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            tooltip: 'Profile',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _signOut,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Welcome, $_userName',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'You are logged in successfully',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 40),
                  // Add your bus management app content here
                ],
              ),
            ),
    );
  }
}