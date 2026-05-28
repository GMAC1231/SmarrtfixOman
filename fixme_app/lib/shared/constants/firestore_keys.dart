class FirestoreCollections {
  FirestoreCollections._();

  static const String users = 'users';
  static const String publicUsers = 'publicUsers';
  static const String chats = 'chats';
  static const String messages = 'messages';
  static const String serviceRequests = 'serviceRequests';
  static const String offers = 'offers';
  static const String liveLocations = 'liveLocations';
  static const String ratings = 'ratings';
}

class FirestoreFields {
  FirestoreFields._();

  static const String createdAt = 'createdAt';
  static const String updatedAt = 'updatedAt';
  static const String status = 'status';
  static const String customerId = 'customerId';
  static const String employeeId = 'employeeId';
  static const String providerId = 'providerId';
  static const String requestId = 'requestId';
  static const String lat = 'lat';
  static const String lng = 'lng';
  static const String isOnline = 'isOnline';
}
