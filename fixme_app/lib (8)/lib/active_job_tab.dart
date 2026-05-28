import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart' as osm;

import 'chat_screen.dart';
import 'map_tab.dart';
import 'shared/models/service_request.dart';
import 'shared/services/request_service.dart';

class ActiveJobTab extends StatelessWidget {
  final GlobalKey<MapTabState>? mapTabKey;

  const ActiveJobTab({super.key, this.mapTabKey});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Please sign in'));
    }

    return StreamBuilder<List<ServiceRequestModel>>(
      stream: RequestService.providerJobsStream(user.uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final jobs = snapshot.data!;

        /// ✅ FIX: pick only active job
        final job = jobs.where((j) =>
            j.status == 'accepted' || j.status == 'ongoing').isNotEmpty
            ? jobs.firstWhere((j) =>
                j.status == 'accepted' || j.status == 'ongoing')
            : null;

        if (job == null) {
          return const Center(child: Text('No active job'));
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// TITLE
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          job.serviceType,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      _JobStatusBadge(status: job.status),
                    ],
                  ),

                  const SizedBox(height: 16),

                  /// INFO
                  Text('Customer: ${job.customerName}'),
                  Text('Fare: OMR ${(job.displayFare ?? 0).toStringAsFixed(2)}'),
                  if (job.customerPhone.isNotEmpty)
                    Text('Phone: ${job.customerPhone}'),

                  const SizedBox(height: 16),

                  /// ACTIONS
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      /// ✅ FIX: correct map call
                      OutlinedButton.icon(
                        onPressed: () {
                          if (job.customerLat != null &&
                              job.customerLng != null) {
                            mapTabKey?.currentState?.setCustomerLocation(
                              osm.GeoPoint(
                                latitude: job.customerLat!,
                                longitude: job.customerLng!,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.route),
                        label: const Text('Route'),
                      ),

                      /// CHAT
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                chatId: '${job.id}-${job.customerId}',
                                otherUserId: job.customerId,
                                title: job.customerName,
                                requestId: job.id,
                                iAmCustomer: false,
                                providerId: user.uid,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.chat),
                        label: const Text('Chat'),
                      ),
                    ],
                  ),

                  const Spacer(),

                  /// STATUS BUTTONS
                  if (job.status == 'accepted')
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => RequestService.updateStatus(
                            job.id, 'ongoing'),
                        child: const Text('Start Job'),
                      ),
                    ),

                  if (job.status == 'ongoing')
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => RequestService.updateStatus(
                            job.id, 'completed'),
                        child: const Text('Complete Job'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _JobStatusBadge extends StatelessWidget {
  final String status;

  const _JobStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;

    switch (status) {
      case 'accepted':
        color = Colors.orange;
        break;
      case 'ongoing':
        color = Colors.green;
        break;
      case 'completed':
        color = Colors.blue;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}