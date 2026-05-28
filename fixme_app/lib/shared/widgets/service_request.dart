import 'package:cloud_firestore/cloud_firestore.dart';

class ServiceRequestModel {
  final String id;
  final String customerId;
  final String employeeId;

  final String serviceType;
  final String status;

  final double fare;
  final String note;

  final String customerName;
  final String workerName;

  final double? customerLat;
  final double? customerLng;

  final double? providerLat;
  final double? providerLng;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ServiceRequestModel({
    required this.id,
    required this.customerId,
    required this.employeeId,
    required this.serviceType,
    required this.status,
    required this.fare,
    required this.note,
    required this.customerName,
    required this.workerName,
    this.customerLat,
    this.customerLng,
    this.providerLat,
    this.providerLng,
    this.createdAt,
    this.updatedAt,
  });

  // ===============================
  // 🔥 STATUS CONSTANTS
  // ===============================
static const String statusPending = 'pending';
static const String statusBidding = 'bidding';
static const String statusAccepted = 'accepted';
static const String statusOngoing = 'ongoing';
static const String statusCompleted = 'completed';
static const String statusCancelled = 'cancelled';

  // ===============================
  // 🔥 HELPERS
  // ===============================
  bool get isPending => status == statusPending;
  bool get isAccepted => status == statusAccepted;
  bool get isOngoing => status == statusOngoing;
 bool get isCompleted =>
    status == statusCompleted;
  bool get isCancelled => status == statusCancelled;

  bool get isActive => isAccepted || isOngoing;

  // ===============================
  // 🔥 FIRESTORE PARSER
  // ===============================
  factory ServiceRequestModel.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    double? asDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    DateTime? asDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      return null;
    }

    // 🔥 Normalize old fields
    final employeeId =
        (data['employeeId'] ?? data['assignedWorkerId'] ?? '')
            .toString()
            .trim();

    final workerName =
        (data['workerName'] ?? data['assignedWorkerName'] ?? '')
            .toString()
            .trim();

    final fare =
        asDouble(data['fare'] ?? data['priceOffer'] ?? data['displayFare']) ??
            0.0;

    String normalizeStatus(String raw) {
      final s = raw.toLowerCase().trim();

      switch (s) {
        case 'assigned':
          return statusAccepted;
        case 'in_progress':
          return statusOngoing;
        case '':
          return statusPending;
        default:
          return s;
      }
    }

    return ServiceRequestModel(
      id: doc.id,
      customerId: (data['customerId'] ?? '').toString(),
      employeeId: employeeId,
      serviceType: (data['serviceType'] ?? 'Service').toString(),
      status: normalizeStatus((data['status'] ?? '').toString()),
      fare: fare,
      note: (data['note'] ?? '').toString(),
      customerName: (data['customerName'] ?? '').toString(),
      workerName: workerName,
      customerLat: asDouble(data['customerLat']),
      customerLng: asDouble(data['customerLng']),
      providerLat: asDouble(data['providerLat']),
      providerLng: asDouble(data['providerLng']),
      createdAt: asDate(data['createdAt']),
      updatedAt: asDate(data['updatedAt']),
    );
  }

  // ===============================
  // 🔥 TO MAP
  // ===============================
  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'employeeId': employeeId,
      'serviceType': serviceType,
      'status': status,
      'fare': fare,
      'note': note,
      'customerName': customerName,
      'workerName': workerName,
      'customerLat': customerLat,
      'customerLng': customerLng,
      'providerLat': providerLat,
      'providerLng': providerLng,
      'createdAt':
          createdAt == null ? null : Timestamp.fromDate(createdAt!),
      'updatedAt':
          updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
    };
  }
}