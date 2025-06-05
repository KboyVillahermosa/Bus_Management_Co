class Driver {
  final String id;
  final String firstName; 
  final String lastName;
  final String contactNumber;
  final String address;
  final String licenseNumber;
  final DateTime licenseExpiry;
  final double baseSalary;
  final DateTime hireDate;
  final String? photo;

  Driver({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.contactNumber,
    required this.address,
    required this.licenseNumber,
    required this.licenseExpiry,
    required this.baseSalary,
    required this.hireDate,
    this.photo,
  });

  // Helper property to get full name
  String get name => '$firstName $lastName';

  factory Driver.fromJson(Map<String, dynamic> json) {
    return Driver(
      id: json['id'],
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      contactNumber: json['contact_number'],
      address: json['address'],
      licenseNumber: json['license_number'],
      licenseExpiry: DateTime.parse(json['license_expiry']),
      baseSalary: json['base_salary'].toDouble(),
      hireDate: DateTime.parse(json['hire_date']),
      photo: json['photo'],
    );
  }
}