import 'package:cloud_firestore/cloud_firestore.dart';

class ServiceRequestModel {
  final String id;
  final String customerId;
  final String employeeId;

  final String serviceType;
  final String status;

  final double priceOffer;
  final double? agreedFare;
  final String note;

  final String customerName;
  final String employeeName;

  final double? customerLat;
  final double? customerLng;

  final double? providerLat;
  final double? providerLng;

  final bool isRated;
  final double? customerRating;
  final String customerReview;

  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? acceptedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;

  const ServiceRequestModel({
    required this.id,
    required this.customerId,
    required this.employeeId,
    required this.serviceType,
    required this.status,
    required this.priceOffer,
    required this.agreedFare,
    required this.note,
    required this.customerName,
    required this.employeeName,
    required this.customerLat,
    required this.customerLng,
    required this.providerLat,
    required this.providerLng,
    required this.isRated,
    required this.customerRating,
    required this.customerReview,
    required this.createdAt,
    required this.updatedAt,
    required this.acceptedAt,
    required this.startedAt,
    required this.completedAt,
    required this.cancelledAt,
  });

  static const String statusBidding = 'bidding';
  static const String statusAccepted = 'accepted';
  static const String statusOngoing = 'ongoing';
  static const String statusCompleted = 'completed';
  static const String statusCancelled = 'cancelled';

  bool get isBidding => status == statusBidding;
  bool get isAccepted => status == statusAccepted;
  bool get isOngoing => status == statusOngoing;
  bool get isCompleted => status == statusCompleted;
  bool get isCancelled => status == statusCancelled;

  bool get isActive => isAccepted || isOngoing;

  double get displayFare {
    if (agreedFare != null && agreedFare! > 0) {
      return agreedFare!;
    }
    return priceOffer;
  }

  factory ServiceRequestModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};

    double? asDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    DateTime? asDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      return null;
    }

    String normalizeStatus(dynamic raw) {
      final s = (raw ?? '').toString().trim().toLowerCase();

      switch (s) {
        case '':
        case 'pending':
        case 'open':
          return statusBidding;

        case 'assigned':
          return statusAccepted;

        case 'in_progress':
        case 'in-progress':
          return statusOngoing;

        default:
          return s;
      }
    }

    final employeeId = (data['employeeId'] ??
            data['providerId'] ??
            data['assignedWorkerId'] ??
            '')
        .toString()
        .trim();

    final employeeName = (data['employeeName'] ??
            data['providerName'] ??
            data['workerName'] ??
            data['assignedWorkerName'] ??
            '')
        .toString()
        .trim();

    final priceOffer = asDouble(
          data['priceOffer'] ??
              data['fare'] ??
              data['displayFare'] ??
              data['budget'],
        ) ??
        0.0;

    final agreedFare = asDouble(
      data['agreedFare'] ?? data['acceptedFare'] ?? data['finalFare'],
    );

    return ServiceRequestModel(
      id: doc.id,
      customerId: (data['customerId'] ?? '').toString().trim(),
      employeeId: employeeId,
      serviceType: (data['serviceType'] ?? 'Service').toString().trim(),
      status: normalizeStatus(data['status']),
      priceOffer: priceOffer,
      agreedFare: agreedFare,
      note: (data['note'] ?? '').toString(),
      customerName: (data['customerName'] ?? '').toString().trim(),
      employeeName: employeeName,
      customerLat: asDouble(data['customerLat']),
      customerLng: asDouble(data['customerLng']),
      providerLat: asDouble(data['providerLat']),
      providerLng: asDouble(data['providerLng']),
      isRated: data['isRated'] == true,
      customerRating: asDouble(data['customerRating']),
      customerReview: (data['customerReview'] ?? '').toString(),
      createdAt: asDate(data['createdAt']),
      updatedAt: asDate(data['updatedAt']),
      acceptedAt: asDate(data['acceptedAt']),
      startedAt: asDate(data['startedAt']),
      completedAt: asDate(data['completedAt']),
      cancelledAt: asDate(data['cancelledAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'employeeId': employeeId,
      'serviceType': serviceType,
      'status': status,
      'priceOffer': priceOffer,
      'agreedFare': agreedFare,
      'note': note,
      'customerName': customerName,
      'employeeName': employeeName,
      'customerLat': customerLat,
      'customerLng': customerLng,
      'providerLat': providerLat,
      'providerLng': providerLng,
      'isRated': isRated,
      'customerRating': customerRating,
      'customerReview': customerReview,
      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
      'acceptedAt': acceptedAt == null ? null : Timestamp.fromDate(acceptedAt!),
      'startedAt': startedAt == null ? null : Timestamp.fromDate(startedAt!),
      'completedAt':
          completedAt == null ? null : Timestamp.fromDate(completedAt!),
      'cancelledAt':
          cancelledAt == null ? null : Timestamp.fromDate(cancelledAt!),
    };
  }
}