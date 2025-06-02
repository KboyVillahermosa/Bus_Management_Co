import 'package:flutter/material.dart';
import 'package:bus_management/config/supabase_config.dart';
import 'package:bus_management/screens/login_screen.dart';
import 'package:bus_management/screens/profile_screen.dart';
import 'package:bus_management/screens/bus_units/bus_units_screen.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _userName = '';
  bool _isLoading = true;
  
  // Dashboard metrics
  int _activeDrivers = 0;
  int _totalBuses = 0;
  double _monthlyRevenue = 0;
  double _monthlyExpenses = 0;
  double _netProfit = 0;
  int _completedTrips = 0;
  int _upcomingTrips = 0;
  List<Map<String, dynamic>> _upcomingPayouts = [];
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadDashboardData();
  }
  
  Future<void> _loadUserData() async {
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
        });
      } else {
        setState(() {
          _userName = 'User';
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _userName = 'User';
      });
    }
  }

  Future<void> _loadDashboardData() async {
    try {
      // In a real app, these would be actual database queries
      // For now, let's just simulate loading with dummy data
      await Future.delayed(const Duration(seconds: 1));
      
      setState(() {
        _activeDrivers = 12;
        _totalBuses = 25;
        _monthlyRevenue = 32500.00;
        _monthlyExpenses = 18750.00;
        _netProfit = _monthlyRevenue - _monthlyExpenses;
        _completedTrips = 283;
        _upcomingTrips = 47;
        _upcomingPayouts = [
          {'title': 'Driver Salaries', 'amount': 12000.00, 'dueDate': DateTime.now().add(const Duration(days: 3))},
          {'title': 'Fuel Payment', 'amount': 3500.00, 'dueDate': DateTime.now().add(const Duration(days: 5))},
        ];
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading dashboard data: $e');
      setState(() {
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
      backgroundColor: const Color(0xFFFBFBFE), // --background
      appBar: AppBar(
        title: const Text(
          'Bus Management',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: const Color(0xFF2F27CE), // --primary
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh',
            onPressed: () {
              setState(() {
                _isLoading = true;
              });
              _loadDashboardData();
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle, color: Colors.white),
            tooltip: 'Profile',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Logout',
            onPressed: _signOut,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2F27CE)))
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Welcome header
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
                    decoration: const BoxDecoration(
                      color: Color(0xFF2F27CE), // --primary
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome, $_userName',
                          style: const TextStyle(
                            fontSize: 24, 
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Here\'s your fleet overview',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Overview Panels
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Fleet Status',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF050315),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Active Drivers & Total Buses
                        Row(
                          children: [
                            Expanded(
                              child: _buildMetricCard(
                                title: 'Active Drivers',
                                value: _activeDrivers.toString(),
                                icon: Icons.people,
                                iconColor: const Color(0xFF2F27CE),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildMetricCard(
                                title: 'Total Buses',
                                value: _totalBuses.toString(),
                                icon: Icons.directions_bus,
                                iconColor: const Color(0xFF433BFF),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        const Text(
                          'Financial Overview',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF050315),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Revenue & Expenses
                        Row(
                          children: [
                            Expanded(
                              child: _buildMetricCard(
                                title: 'Monthly Revenue',
                                value: '\$${NumberFormat('#,##0').format(_monthlyRevenue)}',
                                icon: Icons.arrow_upward,
                                iconColor: Colors.green,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildMetricCard(
                                title: 'Monthly Expenses',
                                value: '\$${NumberFormat('#,##0').format(_monthlyExpenses)}',
                                icon: Icons.arrow_downward,
                                iconColor: Colors.red,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        
                        // Net Profit
                        _buildMetricCard(
                          title: 'Net Profit',
                          value: '\$${NumberFormat('#,##0').format(_netProfit)}',
                          icon: Icons.account_balance_wallet,
                          iconColor: _netProfit >= 0 ? Colors.green : Colors.red,
                          fullWidth: true,
                        ),
                        const SizedBox(height: 24),
                        
                        // Trip Summary
                        const Text(
                          'Trip Summary',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF050315),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                spreadRadius: 1,
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildTripSummaryItem(
                                    title: 'Completed',
                                    count: _completedTrips,
                                    icon: Icons.check_circle,
                                    color: Colors.green,
                                  ),
                                  _buildTripSummaryItem(
                                    title: 'Upcoming',
                                    count: _upcomingTrips,
                                    icon: Icons.schedule,
                                    color: const Color(0xFF2F27CE),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () {
                                  // Navigate to detailed trip view
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFDEDCFF),
                                  foregroundColor: const Color(0xFF2F27CE),
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                child: const Text('View Trip Details'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Upcoming Payouts
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Upcoming Payouts',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF050315),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                // View all payouts
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF2F27CE),
                              ),
                              child: const Text('View All'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ..._upcomingPayouts.map((payout) => _buildPayoutItem(payout)).toList(),
                        
                        // Navigation Section - Main Features
                        const SizedBox(height: 24),
                        const Text(
                          'Quick Access',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF050315),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildQuickAccessButton(
                              icon: Icons.directions_bus,
                              label: 'Buses',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const BusUnitsScreen()),
                                );
                              },
                            ),
                            _buildQuickAccessButton(
                              icon: Icons.people,
                              label: 'Employees',
                              onTap: () {
                                // Navigate to Employees page
                              },
                            ),
                            _buildQuickAccessButton(
                              icon: Icons.assignment,
                              label: 'Assignments',
                              onTap: () {
                                // Navigate to Assignments page
                              },
                            ),
                            _buildQuickAccessButton(
                              icon: Icons.settings,
                              label: 'Settings',
                              onTap: () {
                                // Navigate to Settings page
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    bool fullWidth = false,
  }) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF050315),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF050315),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripSummaryItem({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF050315),
                fontWeight: FontWeight.w400,
              ),
            ),
            Text(
              count.toString(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF050315),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPayoutItem(Map<String, dynamic> payout) {
    final formatter = DateFormat('MMM dd, yyyy');
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFDEDCFF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.account_balance_wallet,
              color: Color(0xFF2F27CE),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payout['title'],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF050315),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Due: ${formatter.format(payout['dueDate'])}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '\$${NumberFormat('#,##0.00').format(payout['amount'])}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF050315),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAccessButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFDEDCFF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 24,
              color: const Color(0xFF2F27CE),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF050315),
            ),
          ),
        ],
      ),
    );
  }
}