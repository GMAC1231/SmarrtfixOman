import 'package:flutter/material.dart';

class AdminRequestDetailScreen extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;

  const AdminRequestDetailScreen({
    super.key,
    required this.docId,
    required this.data,
  });

  Widget rowItem(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text((value ?? 'N/A').toString()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                rowItem('Request ID', docId),
                rowItem('Service Type', data['serviceType']),
                rowItem('Customer ID', data['customerId']),
                rowItem('Employee ID', data['employeeId']),
                rowItem('Status', data['status']),
                rowItem('Price Offer', data['priceOffer']),
                rowItem('Created At', data['createdAt']),
                rowItem('Latitude', data['lat']),
                rowItem('Longitude', data['lng']),
                rowItem('Address', data['address']),
                rowItem('Description', data['description']),
              ],
            ),
          ),
        ),
      ),
    );
  }
}