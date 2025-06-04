import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/driver.dart';

class DriverDetailScreen extends StatefulWidget {
  final Driver driver;
  
  const DriverDetailScreen({Key? key, required this.driver}) : super(key: key);

  @override
  _DriverDetailScreenState createState() => _DriverDetailScreenState();
}

class _DriverDetailScreenState extends State<DriverDetailScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.driver.name),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Driver Info Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: CircleAvatar(
                        radius: 50,
                        backgroundImage: widget.driver.photo != null
                            ? NetworkImage(widget.driver.photo!)
                            : null,
                        child: widget.driver.photo == null
                            ? Text(
                                widget.driver.name.substring(0, 1),
                                style: const TextStyle(fontSize: 40),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _infoRow('Name', widget.driver.name),
                    _infoRow('Contact', widget.driver.contactNumber),
                    _infoRow('License No', widget.driver.licenseNumber),
                    _infoRow('License Expiry', 
                        DateFormat('MMM dd, yyyy').format(widget.driver.licenseExpiry)),
                    _infoRow('Base Salary', 
                        NumberFormat.currency(symbol: '₱').format(widget.driver.baseSalary)),
                    _infoRow('Hire Date', 
                        DateFormat('MMM dd, yyyy').format(widget.driver.hireDate)),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            const Text(
              'Driver Actions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Action Cards
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.5,
              children: [
                _actionCard('Salary History', Icons.history, Colors.blue),
                _actionCard('Bus Assignments', Icons.directions_bus, Colors.green),
                _actionCard('Upcoming Salary', Icons.calendar_today, Colors.orange),
                _actionCard('Cash Advances', Icons.money, Colors.red),
                _actionCard('Deductions', Icons.remove_circle, Colors.purple),
                _actionCard('Bonuses', Icons.add_circle, Colors.teal),
                _actionCard('13th Month', Icons.card_giftcard, Colors.amber),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _actionCard(String title, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: () {
          // Will implement navigation to specific screens
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$title coming soon')),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 36,
                color: color,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}