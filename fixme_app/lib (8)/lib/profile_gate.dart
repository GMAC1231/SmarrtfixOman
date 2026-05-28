// lib/profile_gate.dart

/// Helper to check whether an employee's profile is complete.
/// This works in two ways:
/// 1. Trusts an explicit backend flag (`profileComplete`).
/// 2. Falls back to checking required fields (profession, car plate, address, fare).
bool isEmployeeProfileComplete(Map<String, dynamic>? d) {
  if (d == null) return false;

  // Required fields
  final profession = (d['profession'] ?? '').toString().trim();
  final plate = (d['carPlateNumber'] ?? '').toString().trim();
  final address = (d['address'] ?? '').toString().trim();

  // Parse fare safely
  final fareRaw = d['fare'];
  final fare = (fareRaw is num)
      ? fareRaw.toDouble()
      : double.tryParse('$fareRaw') ?? 0.0;

  // Explicit backend flag
  final backendFlag = d['profileComplete'] == true;

  // Check all required fields
  final hasRequiredFields =
      profession.isNotEmpty && plate.isNotEmpty && address.isNotEmpty && fare > 0;

  // Return true if either flag is set or all required fields are valid
  return backendFlag || hasRequiredFields;
}
