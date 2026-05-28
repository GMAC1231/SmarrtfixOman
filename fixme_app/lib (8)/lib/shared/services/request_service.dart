import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/service_request.dart';

class RequestService {
  RequestService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static CollectionReference<Map<String, dynamic>> get _requests =>
      _db.collection('serviceRequests');

  static DocumentReference<Map<String, dynamic>> requestRef(String requestId) =>
      _requests.doc(requestId);

  static CollectionReference<Map<String, dynamic>> offersRef(String requestId) =>
      requestRef(requestId).collection('offers');

  static User get _requireUser {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not signed in');
    }
    return user;
  }

  static Future<Map<String, dynamic>> currentUserProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data() ?? <String, dynamic>{};
  }

  static Future<String> _currentUserName() async {
    final user = _requireUser;
    final profile = await currentUserProfile(user.uid);

    final raw = profile['name'] ??
        profile['fullName'] ??
        profile['username'] ??
        user.displayName ??
        'User';

    final name = raw.toString().trim();
    return name.isEmpty ? 'User' : name;
  }

  static Stream<List<ServiceRequestModel>> customerRequestsStream(
    String customerId,
  ) {
    if (customerId.trim().isEmpty) {
      return const Stream<List<ServiceRequestModel>>.empty();
    }

    return _requests
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(ServiceRequestModel.fromDoc).toList());
  }

  static Stream<List<ServiceRequestModel>> openRequestsStream({
    String? serviceType,
  }) {
    Query<Map<String, dynamic>> query =
        _requests.where('status', isEqualTo: 'bidding');

    if (serviceType != null && serviceType.trim().isNotEmpty) {
      query = query.where('serviceType', isEqualTo: serviceType.trim());
    }

    return query
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(ServiceRequestModel.fromDoc).toList());
  }

  static Stream<List<ServiceRequestModel>> providerJobsStream(String employeeId) {
    if (employeeId.trim().isEmpty) {
      return const Stream<List<ServiceRequestModel>>.empty();
    }

    return _requests
        .where('employeeId', isEqualTo: employeeId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(ServiceRequestModel.fromDoc).toList());
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> offersStream(
    String requestId,
  ) {
    return offersRef(requestId)
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>> requestStream(
    String requestId,
  ) {
    return requestRef(requestId).snapshots();
  }

  static Future<String> createRequest({
    required String serviceType,
    required double fare,
    double? lat,
    double? lng,
    String? note,
  }) async {
    final user = _requireUser;
    final customerName = await _currentUserName();
    final now = FieldValue.serverTimestamp();

    final data = <String, dynamic>{
      'customerId': user.uid,
      'customerName': customerName,
      'customerEmail': user.email ?? '',
      'customerPhone': user.phoneNumber ?? '',
      'serviceType': serviceType.trim(),
      'priceOffer': fare,
      'agreedFare': null,
      'status': 'bidding',
      'customerNote': (note ?? '').trim().isEmpty ? null : note!.trim(),

      // assigned provider
      'employeeId': '',
      'employeeName': '',
      'providerId': '',
      'providerName': '',
      'assignedWorkerId': '',
      'assignedWorkerName': '',

      // timestamps
      'createdAt': now,
      'updatedAt': now,
      'acceptedAt': null,
      'startedAt': null,
      'completedAt': null,
      'cancelledAt': null,

      // location
      'customerLat': lat,
      'customerLng': lng,
      'customerLocation': (lat != null && lng != null) ? GeoPoint(lat, lng) : null,

      // housekeeping
      'offersCount': 0,
      'lastOfferAt': null,
    };

    final doc = await _requests.add(data);
    return doc.id;
  }

  static Future<void> sendOffer({
    required String requestId,
    required double fare,
    int? etaMinutes,
    double? distanceKm,
    String? note,
  }) async {
    final user = _requireUser;
    final providerName = await _currentUserName();

    await _db.runTransaction((tx) async {
      final reqRef = requestRef(requestId);
      final reqSnap = await tx.get(reqRef);

      if (!reqSnap.exists) {
        throw Exception('Request not found');
      }

      final reqData = reqSnap.data() ?? <String, dynamic>{};
      final status = (reqData['status'] ?? '').toString();

      if (status != 'bidding') {
        throw Exception('This request is no longer open for offers');
      }

      final offerRef = offersRef(requestId).doc(user.uid);
      final existingOfferSnap = await tx.get(offerRef);
      final isNewOffer = !existingOfferSnap.exists;

      final offerData = <String, dynamic>{
        'employeeId': user.uid,
        'employeeName': providerName,
        'providerId': user.uid,
        'providerName': providerName,
        'proposedFare': fare,
        'etaMinutes': etaMinutes,
        'distanceKm': distanceKm,
        'note': (note ?? '').trim(),
        'status': 'pending',
        'createdAt': existingOfferSnap.exists
            ? (existingOfferSnap.data()?['createdAt'] ?? FieldValue.serverTimestamp())
            : FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      tx.set(offerRef, offerData, SetOptions(merge: true));

      final requestUpdate = <String, dynamic>{
        'lastOfferAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (isNewOffer) {
        requestUpdate['offersCount'] = FieldValue.increment(1);
      }

      tx.update(reqRef, requestUpdate);
    });
  }

  static Future<void> acceptOffer({
    required String requestId,
    required String employeeId,
  }) async {
    await _db.runTransaction((tx) async {
      final reqRef = requestRef(requestId);
      final reqSnap = await tx.get(reqRef);

      if (!reqSnap.exists) {
        throw Exception('Request not found');
      }

      final req = reqSnap.data() ?? <String, dynamic>{};
      final currentStatus = (req['status'] ?? '').toString();

      if (currentStatus != 'bidding') {
        throw Exception('Request has already been assigned');
      }

      final selectedOfferRef = offersRef(requestId).doc(employeeId);
      final selectedOfferSnap = await tx.get(selectedOfferRef);

      if (!selectedOfferSnap.exists) {
        throw Exception('Selected offer not found');
      }

      final offer = selectedOfferSnap.data() ?? <String, dynamic>{};
      final providerName = (offer['employeeName'] ?? offer['providerName'] ?? 'Provider')
          .toString();
      final proposedFare = (offer['proposedFare'] as num?)?.toDouble();

      tx.update(reqRef, {
        'status': 'accepted',
        'employeeId': employeeId,
        'employeeName': providerName,
        'providerId': employeeId,
        'providerName': providerName,
        'assignedWorkerId': employeeId,
        'assignedWorkerName': providerName,
        'agreedFare': proposedFare,
        'acceptedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      tx.set(
        selectedOfferRef,
        {
          'status': 'accepted',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });

    final allOffers = await offersRef(requestId).get();
    final batch = _db.batch();

    for (final doc in allOffers.docs) {
      if (doc.id == employeeId) continue;

      batch.set(
        doc.reference,
        {
          'status': 'rejected',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  static Future<void> quickAcceptRequest(String requestId) async {
    final user = _requireUser;
    final providerName = await _currentUserName();

    await _db.runTransaction((tx) async {
      final reqRef = requestRef(requestId);
      final reqSnap = await tx.get(reqRef);

      if (!reqSnap.exists) {
        throw Exception('Request not found');
      }

      final req = reqSnap.data() ?? <String, dynamic>{};
      final currentStatus = (req['status'] ?? '').toString();

      if (currentStatus != 'bidding') {
        throw Exception('Request has already been taken');
      }

      final offerRef = offersRef(requestId).doc(user.uid);
      final existingOfferSnap = await tx.get(offerRef);

      tx.update(reqRef, {
        'status': 'accepted',
        'employeeId': user.uid,
        'employeeName': providerName,
        'providerId': user.uid,
        'providerName': providerName,
        'assignedWorkerId': user.uid,
        'assignedWorkerName': providerName,
        'agreedFare': (req['priceOffer'] as num?)?.toDouble(),
        'acceptedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      tx.set(
        offerRef,
        {
          'employeeId': user.uid,
          'employeeName': providerName,
          'providerId': user.uid,
          'providerName': providerName,
          'proposedFare': (req['priceOffer'] as num?)?.toDouble(),
          'status': 'accepted',
          'createdAt': existingOfferSnap.exists
              ? (existingOfferSnap.data()?['createdAt'] ?? FieldValue.serverTimestamp())
              : FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });

    final allOffers = await offersRef(requestId).get();
    final batch = _db.batch();

    for (final doc in allOffers.docs) {
      if (doc.id == user.uid) continue;

      batch.set(
        doc.reference,
        {
          'status': 'rejected',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

static Future<void> rejectOwnOffer(String requestId) async {
  final user = _requireUser;
  final reqRef = requestRef(requestId);
  final offerRef = offersRef(requestId).doc(user.uid);

  await _db.runTransaction((tx) async {
    final reqSnap = await tx.get(reqRef);
    if (!reqSnap.exists) {
      throw Exception('Request not found');
    }

    final req = reqSnap.data() ?? <String, dynamic>{};
    final status = (req['status'] ?? '').toString();

    if (status != 'bidding') {
      throw Exception('This request is no longer open');
    }

    tx.set(
      offerRef,
      {
        'employeeId': user.uid,
        'status': 'rejected',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  });
}

  static Future<void> rejectRequest(String requestId) async {
    await rejectOwnOffer(requestId);
  }

  static Future<void> updateStatus(String requestId, String status) async {
    final allowed = <String>{
      'bidding',
      'accepted',
      'ongoing',
      'completed',
      'cancelled',
      'rejected',
    };

    if (!allowed.contains(status)) {
      throw Exception('Invalid status: $status');
    }

    final payload = <String, dynamic>{
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (status == 'ongoing') {
      payload['startedAt'] = FieldValue.serverTimestamp();
    }
    if (status == 'completed') {
      payload['completedAt'] = FieldValue.serverTimestamp();
    }
    if (status == 'cancelled') {
      payload['cancelledAt'] = FieldValue.serverTimestamp();
    }

    await requestRef(requestId).update(payload);
  }

  static Future<void> cancelRequest(String requestId) async {
    await _db.runTransaction((tx) async {
      final reqRef = requestRef(requestId);
      final reqSnap = await tx.get(reqRef);

      if (!reqSnap.exists) {
        throw Exception('Request not found');
      }

      final req = reqSnap.data() ?? <String, dynamic>{};
      final currentStatus = (req['status'] ?? '').toString();

      if (currentStatus == 'completed') {
        throw Exception('Completed requests cannot be cancelled');
      }

      tx.update(reqRef, {
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    final allOffers = await offersRef(requestId).get();
    final batch = _db.batch();

    for (final doc in allOffers.docs) {
      batch.set(
        doc.reference,
        {
          'status': 'cancelled',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  static Future<void> setProviderOnline(bool isOnline) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _db.collection('users').doc(user.uid).set(
      {
        'isOnline': isOnline,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  static Future<void> publishLiveLocation({
    required double lat,
    required double lng,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _db.collection('liveLocations').doc(user.uid).set(
      {
        'lat': lat,
        'lng': lng,
        'role': 'employee',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}