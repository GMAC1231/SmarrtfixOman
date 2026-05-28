import 'package:cloud_firestore/cloud_firestore.dart';

class ServiceRequestModel {
  final String id;
  final String customerId;
  final String customerName;
  final String customerEmail;
  final String customerPhone;
  final String serviceType;
  final String status;
  final double? priceOffer;
  final double? agreedFare;
  final double? customerLat;
  final double? customerLng;
  final String employeeId;
  final String employeeName;
  final String car;
  final double rating;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;
  final Map<String, dynamic> raw;

  const ServiceRequestModel({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.customerEmail,
    required this.customerPhone,
    required this.serviceType,
    required this.status,
    required this.priceOffer,
    required this.agreedFare,
    required this.customerLat,
    required this.customerLng,
    required this.employeeId,
    required this.employeeName,
    required this.car,
    required this.rating,
    required this.createdAt,
    required this.updatedAt,
    required this.raw,
  });

  String get assignedWorkerId => employeeId;
  String get assignedWorkerName => employeeName;
  double? get displayFare => agreedFare ?? priceOffer;

  bool get isOpen => status == 'bidding';
  bool get isActive => status == 'accepted' || status == 'ongoing';

  factory ServiceRequestModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    double? asDouble(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}');

    return ServiceRequestModel(
      id: doc.id,
      customerId: (data['customerId'] ?? '').toString(),
      customerName: (data['customerName'] ?? 'Customer').toString(),
      customerEmail: (data['customerEmail'] ?? '').toString(),
      customerPhone: (data['customerPhone'] ?? '').toString(),
      serviceType: (data['serviceType'] ?? 'Service').toString(),
      status: (data['status'] ?? 'bidding').toString(),
      priceOffer: asDouble(data['priceOffer']),
      agreedFare: asDouble(data['agreedFare']),
      customerLat: asDouble(data['customerLat']),
      customerLng: asDouble(data['customerLng']),
      employeeId: (data['employeeId'] ?? '').toString(),
      employeeName: (data['employeeName'] ?? '').toString(),
      car: (data['car'] ?? 'N/A').toString(),
      rating: asDouble(data['rating']) ?? 0,
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
      raw: Map<String, dynamic>.from(data),
    );
  }
}