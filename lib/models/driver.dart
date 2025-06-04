class Driver {
  final String id; // Change from int to String since Supabase uses UUID
  final String name;
  final String contactNumber;
  final String address;
  final String licenseNumber;
  final DateTime licenseExpiry;
  final double baseSalary;
  final DateTime hireDate;
  final String? photo;

  Driver({
    required this.id,
    required this.name,
    required this.contactNumber,
    required this.address,
    required this.licenseNumber,
    required this.licenseExpiry,
    required this.baseSalary,
    required this.hireDate,
    this.photo,
  });

  factory Driver.fromJson(Map<String, dynamic> json) {
    return Driver(
      id: json['id'],
      name: json['name'],
      contactNumber: json['contact_number'],
      address: json['address'],
      licenseNumber: json['license_number'],
      licenseExpiry: DateTime.parse(json['license_expiry']),
      baseSalary: json['base_salary'].toDouble(),
      hireDate: DateTime.parse(json['hire_date']),
      photo: json['photo'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'contact_number': contactNumber,
      'address': address,
      'license_number': licenseNumber,
      'license_expiry': licenseExpiry.toIso8601String(),
      'base_salary': baseSalary,
      'hire_date': hireDate.toIso8601String(),
      'photo': photo,
    };
  }
}