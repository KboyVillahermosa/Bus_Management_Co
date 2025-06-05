import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/driver.dart';
import 'driver_detail_screen.dart';
import 'add_edit_driver_screen.dart';

class DriversScreen extends StatefulWidget {
  static const routeName = '/drivers';

  const DriversScreen({Key? key}) : super(key: key);

  @override
  _DriversScreenState createState() => _DriversScreenState();
}

class _DriversScreenState extends State<DriversScreen> {
  final _supabase = Supabase.instance.client;
  List<Driver> _drivers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  Future<void> _loadDrivers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _supabase
          .from('drivers')
          .select('*')
          .order('last_name'); // Changed from 'name' to 'last_name'

      final List<dynamic> data = response;
      setState(() {
        _drivers = data.map((json) => Driver.fromJson(json)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading drivers: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Drivers Management')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDrivers,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'All Drivers',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (ctx) => const AddEditDriverScreen(),
                              ),
                            ).then((_) => _loadDrivers());
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Add Driver'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _drivers.isEmpty
                          ? const Center(child: Text('No drivers found'))
                          : ListView.builder(
                              itemCount: _drivers.length,
                              itemBuilder: (ctx, i) => Card(
                                margin: const EdgeInsets.only(bottom: 16),
                                elevation: 4,
                                child: ListTile(
                                  leading: CircleAvatar(
                                    child: Text(_drivers[i].name.substring(0, 1)),
                                  ),
                                  title: Text(_drivers[i].name),
                                  subtitle: Text('ID: ${_drivers[i].id}'),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.more_vert),
                                    onPressed: () {
                                      showModalBottomSheet(
                                        context: context,
                                        builder: (ctx) => _buildActionsSheet(i),
                                      );
                                    },
                                  ),
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (ctx) => DriverDetailScreen(driver: _drivers[i]),
                                      ),
                                    ).then((_) => _loadDrivers());
                                  },
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => const AddEditDriverScreen(),
            ),
          ).then((_) => _loadDrivers());
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildActionsSheet(int index) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Edit Driver'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => AddEditDriverScreen(driver: _drivers[index]),
                ),
              ).then((_) => _loadDrivers());
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('Delete Driver'),
            onTap: () async {
              Navigator.of(context).pop();
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Confirm Delete'),
                  content: Text('Delete ${_drivers[index].firstName} ${_drivers[index].lastName}?'), // Changed from name
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              
              if (confirm == true) {
                try {
                  await _supabase
                      .from('drivers')
                      .delete()
                      .eq('id', _drivers[index].id);
                  
                  _loadDrivers();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Driver deleted')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}