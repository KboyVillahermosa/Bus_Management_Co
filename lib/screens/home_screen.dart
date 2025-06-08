import 'package:flutter/material.dart';
import 'package:bus_management/config/supabase_config.dart';
import 'package:bus_management/screens/login_screen.dart';
import 'package:bus_management/screens/profile_screen.dart';
import 'package:bus_management/screens/bus_units/bus_units_screen.dart';
import 'package:bus_management/screens/payroll/salary_payroll_screen.dart';
import 'package:bus_management/screens/drivers/drivers_screen.dart';
import 'package:bus_management/screens/conductors/conductors_screen.dart';
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
      final userData = supabase.auth.currentUser?.userMetadata;
      
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
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: Image.asset(
          'assets/images/logo2.png',
          width: 200,
          height: 150,
          fit: BoxFit.contain,
        ),
        backgroundColor: const Color(0xFF2F27CE),
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
      ),
      drawer: Drawer(
        child: Column(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Color(0xFF2F27CE),
              ),
              child: Center(
                child: Row(
                  children: [
                    // Replace text with logo image
                    Image.asset(
                      'assets/images/logo2.png',
                      width: 100,
                      height: 100,
                      fit: BoxFit.contain,
                    ),
                  ],
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.account_circle),
              title: const Text('Profile'),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const ProfileScreen()),
                );
              },
            ),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: _signOut,
            ),
            const SizedBox(height: 20),
          ],
        ),
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
                      color: Color(0xFF2F27CE),
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
                          'Dashboard Overview',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Main Dashboard Content
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Financial Cards Section
                        const Text(
                          'Financial Overview',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF050315),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Monthly Revenue & Expenses
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
                            const SizedBox(width: 16),
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
                        const SizedBox(height: 16),
                        
                        // Net Profit
                        _buildMetricCard(
                          title: 'Net Profit',
                          value: '\$${NumberFormat('#,##0').format(_netProfit)}',
                          icon: Icons.account_balance_wallet,
                          iconColor: _netProfit >= 0 ? Colors.green : Colors.red,
                          fullWidth: true,
                        ),
                        
                        // Upcoming Payouts
                        const SizedBox(height: 32),
                        const Text(
                          'Upcoming Payouts',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF050315),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ..._upcomingPayouts.map((payout) => _buildPayoutItem(payout)),
                        
                        // Quick Access Navigation
                        const SizedBox(height: 32),
                        const Text(
                          'Management',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF050315),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Grid layout for management cards
                        GridView.count(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _buildManagementCard(
                              title: 'Salary & Payroll',
                              icon: Icons.payments,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const SalaryPayrollScreen()),
                                );
                              },
                            ),
                            _buildManagementCard(
                              title: 'Buses',
                              icon: Icons.directions_bus,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const BusUnitsScreen()),
                                );
                              },
                            ),
                            _buildManagementCard(
                              title: 'Drivers',
                              icon: Icons.person,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const DriversScreen()),
                                );
                              },
                            ),
                            _buildManagementCard(
                              title: 'Conductors',
                              icon: Icons.person_add,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const ConductorsScreen()),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // Updated metric card with improved design
  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    bool fullWidth = false,
  }) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF6B7280),
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
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
        ],
      ),
    );
  }

  // Updated payout item with improved design
  Widget _buildPayoutItem(Map<String, dynamic> payout) {
    final formatter = DateFormat('MMM dd, yyyy');
    final daysLeft = payout['dueDate'].difference(DateTime.now()).inDays;
    final isUrgent = daysLeft <= 3;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isUrgent ? Border.all(color: Colors.red.shade200) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isUrgent ? Colors.red.shade50 : const Color(0xFFDEDCFF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isUrgent ? Icons.warning_amber_rounded : Icons.account_balance_wallet,
              color: isUrgent ? Colors.red : const Color(0xFF2F27CE),
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
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isUrgent ? Colors.red.shade800 : const Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Due: ${formatter.format(payout['dueDate'])}',
                  style: TextStyle(
                    fontSize: 13,
                    color: isUrgent ? Colors.red.shade400 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '\$${NumberFormat('#,##0.00').format(payout['amount'])}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isUrgent ? Colors.red.shade800 : const Color(0xFF1F2937),
            ),
          ),
        ],
      ),
    );
  }

  // New management card for grid layout
  Widget _buildManagementCard({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              spreadRadius: 0,
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFDEDCFF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 32,
                color: const Color(0xFF2F27CE),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
          ],
        ),
      ),
    );
  }
}