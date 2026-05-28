// lib/firestore_keys.dart
class FSKeys {
  // ──────────── Collections ────────────
  static const String users = 'users';
  static const String liveLocations = 'liveLocations';
  static const String serviceRequests = 'serviceRequests';
  static const String bids = 'bids';

  // ──────────── Common Fields ────────────
  static const String id = 'id';
  static const String createdAt = 'createdAt';
  static const String updatedAt = 'updatedAt';

  // ──────────── User Fields ────────────
  static const String role = 'role';                   // customer | employee
  static const String email = 'email';
  static const String name = 'name';
  static const String phone = 'phone';
  static const String profession = 'profession';
  static const String fare = 'fare';
  static const String carPlate = 'carPlateNumber';
  static const String address = 'address';
  static const String profileComplete = 'profileComplete';
  static const String employeeApproved = 'employee_approved'; // ✅ approval flag
  static const String photoUrl = 'photoUrl';

  // ──────────── Live Location Fields ────────────
  static const String userId = 'userId';
  static const String lat = 'lat';
  static const String lng = 'lng';
  static const String mode = 'mode';                   // idle | job | offline
  static const String lastUpdated = 'lastUpdated';

  // ──────────── Service Request Fields ────────────
  static const String requestId = 'requestId';
  static const String customerId = 'customerId';
  static const String serviceType = 'serviceType';     // plumber | electrician etc.
  static const String status = 'status';               // pending | accepted | completed | cancelled
  static const String location = 'location';
  static const String description = 'description';
  static const String scheduledAt = 'scheduledAt';

  // ──────────── Bid Fields ────────────
  static const String bidId = 'bidId';
  static const String employeeId = 'employeeId';
  static const String priceOffer = 'priceOffer';
  static const String etaMinutes = 'etaMinutes';
  static const String bidStatus = 'bidStatus';         // pending | accepted | rejected
}
