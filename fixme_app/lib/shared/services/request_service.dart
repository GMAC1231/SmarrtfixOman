import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/service_request.dart';

class RequestService {
  RequestService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static CollectionReference<Map<String, dynamic>> get _requests =>
      _db.collection('serviceRequests');

  static User get _user {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('User not logged in');
    }
    return user;
  }

  static DocumentReference<Map<String, dynamic>> requestRef(String requestId) {
    return _requests.doc(requestId);
  }

  static CollectionReference<Map<String, dynamic>> offersRef(String requestId) {
    return requestRef(requestId).collection('offers');
  }

  static Future<String> _currentUserName() async {
    final user = _user;

    try {
      final userDoc = await _db.collection('users').doc(user.uid).get();
      final data = userDoc.data() ?? {};

      final name = data['name'] ??
          data['fullName'] ??
          data['displayName'] ??
          data['username'] ??
          user.displayName ??
          'User';

      final cleaned = name.toString().trim();
      return cleaned.isEmpty ? 'User' : cleaned;
    } catch (_) {
      return user.displayName ?? 'User';
    }
  }

  static Stream<List<ServiceRequestModel>> customerRequestsStream(
    String customerId,
  ) {
    return _requests
        .where('customerId', isEqualTo: customerId)
        .where(
          'status',
          whereIn: const [
            ServiceRequestModel.statusBidding,
            ServiceRequestModel.statusAccepted,
            ServiceRequestModel.statusOngoing,
          ],
        )
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map(ServiceRequestModel.fromDoc).toList(),
        );
  }

  static Stream<List<ServiceRequestModel>> customerCompletedRequestsStream(
    String customerId,
  ) {
    return _requests
        .where('customerId', isEqualTo: customerId)
        .where('status', isEqualTo: ServiceRequestModel.statusCompleted)
        .orderBy('completedAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map(ServiceRequestModel.fromDoc).toList(),
        );
  }

  static Stream<List<ServiceRequestModel>> openRequestsStream({
    String? serviceType,
  }) {
    Query<Map<String, dynamic>> query = _requests.where(
      'status',
      isEqualTo: ServiceRequestModel.statusBidding,
    );

    if (serviceType != null && serviceType.trim().isNotEmpty) {
      query = query.where('serviceType', isEqualTo: serviceType.trim());
    }

    return query.orderBy('createdAt', descending: true).snapshots().map(
          (snap) => snap.docs.map(ServiceRequestModel.fromDoc).toList(),
        );
  }

  static Stream<List<ServiceRequestModel>> providerJobsStream(
    String employeeId,
  ) {
    return _requests
        .where('employeeId', isEqualTo: employeeId)
        .where(
          'status',
          whereIn: const [
            ServiceRequestModel.statusAccepted,
            ServiceRequestModel.statusOngoing,
          ],
        )
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map(ServiceRequestModel.fromDoc).toList(),
        );
  }

  static Stream<List<ServiceRequestModel>> providerCompletedJobsStream(
    String employeeId,
  ) {
    return _requests
        .where('employeeId', isEqualTo: employeeId)
        .where('status', isEqualTo: ServiceRequestModel.statusCompleted)
        .orderBy('completedAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map(ServiceRequestModel.fromDoc).toList(),
        );
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> offersStream(
    String requestId,
  ) {
    return offersRef(requestId)
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }

  static Future<String> createRequest({
    required String serviceType,
    required double priceOffer,
    double? customerLat,
    double? customerLng,
    String? note,
    String? address,
  }) async {
    final user = _user;
    final customerName = await _currentUserName();
    final doc = _requests.doc();
    final now = Timestamp.now();

    await doc.set({
      'id': doc.id,
      'customerId': user.uid,
      'customerName': customerName,
      'customerEmail': user.email ?? '',
      'customerPhone': user.phoneNumber ?? '',
      'employeeId': '',
      'employeeName': '',
      'providerId': '',
      'providerName': '',
      'serviceType': serviceType.trim(),
      'status': ServiceRequestModel.statusBidding,
      'priceOffer': priceOffer,
      'fare': priceOffer,
      'agreedFare': null,
      'note': (note ?? '').trim(),
      'customerLat': customerLat,
      'customerLng': customerLng,
      'providerLat': null,
      'providerLng': null,
      'offersCount': 0,
      'isRated': false,
      'customerRating': null,
      'customerReview': '',
      'createdAt': now,
      'address': address ?? '',
      'updatedAt': now,
      'acceptedAt': null,
      'startedAt': null,
      'completedAt': null,
      'cancelledAt': null,
    });

    return doc.id;
  }

  static Future<void> sendOffer({
    required String requestId,
    required double price,
    String? note,
    int? etaMinutes,
  }) async {
    final user = _user;
    final employeeName = await _currentUserName();

    final offerRef = offersRef(requestId).doc(user.uid);
    final reqRef = requestRef(requestId);

    await _db.runTransaction((tx) async {
      final reqSnap = await tx.get(reqRef);

      if (!reqSnap.exists) {
        throw StateError('Request not found');
      }

      final reqData = reqSnap.data() ?? {};
      final status = (reqData['status'] ?? '').toString();

      if (status != ServiceRequestModel.statusBidding) {
        throw StateError('Request is closed');
      }

      final offerSnap = await tx.get(offerRef);
      final isNewOffer = !offerSnap.exists;
      final now = Timestamp.now();

      tx.set(
        offerRef,
        {
          'employeeId': user.uid,
          'providerId': user.uid,
          'employeeName': employeeName,
          'providerName': employeeName,
          'price': price,
          'proposedFare': price,
          'note': (note ?? '').trim(),
          'etaMinutes': etaMinutes,
          'status': 'pending',
          'createdAt': offerSnap.data()?['createdAt'] ?? now,
          'updatedAt': now,
        },
        SetOptions(merge: true),
      );

      tx.set(
        reqRef,
        {
          'updatedAt': now,
          if (isNewOffer) 'offersCount': FieldValue.increment(1),
        },
        SetOptions(merge: true),
      );
    });
  }

  static Future<void> withdrawOffer(String requestId) async {
    final user = _user;
    final offerRef = offersRef(requestId).doc(user.uid);
    final reqRef = requestRef(requestId);

    await _db.runTransaction((tx) async {
      final offerSnap = await tx.get(offerRef);

      if (!offerSnap.exists) return;

      final status = (offerSnap.data()?['status'] ?? '').toString();
      if (status != 'pending') return;

      final now = Timestamp.now();

      tx.set(
        offerRef,
        {
          'status': 'withdrawn',
          'updatedAt': now,
        },
        SetOptions(merge: true),
      );

      tx.set(
        reqRef,
        {
          'offersCount': FieldValue.increment(-1),
          'updatedAt': now,
        },
        SetOptions(merge: true),
      );
    });
  }

  static Future<void> acceptOffer({
    required String requestId,
    required String employeeId,
  }) async {
    final reqRef = requestRef(requestId);
    final selectedOfferRef = offersRef(requestId).doc(employeeId);

    await _db.runTransaction((tx) async {
      final reqSnap = await tx.get(reqRef);

      if (!reqSnap.exists) {
        throw StateError('Request not found');
      }

      final reqData = reqSnap.data() ?? {};
      final status = (reqData['status'] ?? '').toString();

      if (status != ServiceRequestModel.statusBidding) {
        throw StateError('Request already assigned');
      }

      final offerSnap = await tx.get(selectedOfferRef);

      if (!offerSnap.exists) {
        throw StateError('Offer not found');
      }

      final offer = offerSnap.data() ?? {};
      final providerName =
          (offer['employeeName'] ?? offer['providerName'] ?? 'Provider')
              .toString();

      final proposedFare =
          ((offer['price'] ?? offer['proposedFare'] ?? 0) as num).toDouble();

      final now = Timestamp.now();

      tx.set(
        reqRef,
        {
          'status': ServiceRequestModel.statusAccepted,
          'employeeId': employeeId,
          'employeeName': providerName,
          'providerId': employeeId,
          'providerName': providerName,
          'agreedFare': proposedFare,
          'acceptedAt': now,
          'updatedAt': now,
        },
        SetOptions(merge: true),
      );

      tx.set(
        selectedOfferRef,
        {
          'status': 'accepted',
          'updatedAt': now,
        },
        SetOptions(merge: true),
      );
    });

    final offers = await offersRef(requestId).get();
    final batch = _db.batch();
    final now = Timestamp.now();

    for (final offer in offers.docs) {
      if (offer.id == employeeId) continue;

      batch.set(
        offer.reference,
        {
          'status': 'rejected',
          'updatedAt': now,
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  static Future<void> startJob(String requestId) async {
    await requestRef(requestId).set(
      {
        'status': ServiceRequestModel.statusOngoing,
        'startedAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      },
      SetOptions(merge: true),
    );
  }

  static Future<void> completeJob(
    String requestId,
  ) async {
    final requestRef =
        FirebaseFirestore.instance.collection('serviceRequests').doc(requestId);

    await requestRef.set(
        {
          ////////////////////////////////////////////////////////////
          /// IMPORTANT
          ////////////////////////////////////////////////////////////

          'status': ServiceRequestModel.statusCompleted,

          'completedAt': FieldValue.serverTimestamp(),

          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(
          merge: true,
        ));

    debugPrint(
      "JOB COMPLETED SUCCESSFULLY",
    );
  }

  static Future<void> cancelRequest(String requestId) async {
    await requestRef(requestId).set(
      {
        'status': ServiceRequestModel.statusCancelled,
        'cancelledAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      },
      SetOptions(merge: true),
    );

    final offers = await offersRef(requestId).get();
    final batch = _db.batch();
    final now = Timestamp.now();

    for (final offer in offers.docs) {
      batch.set(
        offer.reference,
        {
          'status': 'cancelled',
          'updatedAt': now,
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  static Future<void> rateProvider({
    required String employeeId,
    required String providerName,
    required String requestId,
    required double rating,
    required String review,
  }) async {
    final customerId = _user.uid;

    ////////////////////////////////////////////////////////////
    /// SAVE RATING DOCUMENT
    ////////////////////////////////////////////////////////////

    await FirebaseFirestore.instance.collection('ratings').add({
      'employeeId': employeeId,
      'providerId': employeeId,
      'providerName': providerName,
      'customerId': customerId,
      'requestId': requestId,
      'rating': rating,
      'review': review,
      'createdAt': FieldValue.serverTimestamp(),
    });

    ////////////////////////////////////////////////////////////
    /// UPDATE REQUEST
    ////////////////////////////////////////////////////////////

    await FirebaseFirestore.instance
        .collection('serviceRequests')
        .doc(requestId)
        .update({
      'isRated': true,
      'customerRating': rating,
      'customerReview': review,
      'ratedAt': FieldValue.serverTimestamp(),
    });

    ////////////////////////////////////////////////////////////
    /// SUCCESS
    ////////////////////////////////////////////////////////////

    debugPrint(
      "RATING SAVED SUCCESSFULLY",
    );
  }
}
