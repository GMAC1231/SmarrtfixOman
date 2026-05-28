import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'chat_screen.dart';
import 'map_screen.dart';

import 'shared/models/service_request.dart';
import 'shared/services/chat_service.dart';
import 'shared/services/request_service.dart';

class ActiveJobTab extends StatelessWidget {
  const ActiveJobTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(
        child: Text('Please sign in'),
      );
    }

    return StreamBuilder<List<ServiceRequestModel>>(
      stream: RequestService.providerJobsStream(user.uid),
      builder: (context, snapshot) {

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              snapshot.error.toString(),
            ),
          );
        }

        final jobs = snapshot.data ?? [];

        if (jobs.isEmpty) {
          return const _EmptyState(
            icon: Icons.work_outline,
            title: 'Waiting for job',
            subtitle: 'Accept a request to start working',
          );
        }

        ServiceRequestModel? activeJob;

        for (final job in jobs) {
          if (job.isAccepted || job.isOngoing) {
            activeJob = job;
            break;
          }
        }

        if (activeJob == null) {
          return const _EmptyState(
            icon: Icons.access_time,
            title: 'No active jobs',
            subtitle: 'You currently have no ongoing work',
          );
        }

        return _ActiveJobCard(
          job: activeJob,
          providerId: user.uid,
        );
      },
    );
  }
}

///////////////////////////////////////////////////////////////
/// ACTIVE JOB CARD
///////////////////////////////////////////////////////////////

class _ActiveJobCard extends StatelessWidget {
  final ServiceRequestModel job;
  final String providerId;

  const _ActiveJobCard({
    required this.job,
    required this.providerId,
  });

  @override
  Widget build(BuildContext context) {

    final lat = job.customerLat;
    final lng = job.customerLng;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: LinearGradient(
            colors: [
              const Color(0xFF01411C),
              Colors.green.shade600,
            ],
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: 24,
              color: Colors.black.withOpacity(0.25),
              offset: const Offset(0, 10),
            ),
          ],
        ),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            //////////////////////////////////////////////////////
            /// HEADER
            //////////////////////////////////////////////////////

            Row(
              children: [

                Expanded(
                  child: Text(
                    job.serviceType,
                    style: const TextStyle(
                      fontSize: 24,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                _StatusChip(status: job.status),
              ],
            ),

            const SizedBox(height: 14),

            //////////////////////////////////////////////////////
            /// CUSTOMER
            //////////////////////////////////////////////////////

            Text(
              'Customer: ${job.customerName}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              'Fare: OMR ${job.displayFare.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),

            const SizedBox(height: 22),

            //////////////////////////////////////////////////////
            /// ACTION BUTTONS
            //////////////////////////////////////////////////////

            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [

                //////////////////////////////////////////////////
                /// ROUTE
                //////////////////////////////////////////////////

                ElevatedButton.icon(
                  onPressed: () {

                    if (lat == null || lng == null) return;

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MapScreen(
                          requestId: job.id,
                          providerId: providerId,
                          customerLat: lat,
                          customerLng: lng,
                          trackLiveDriver: true,
                          listenToAssignedRequest: true,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.route),
                  label: const Text('Route'),
                ),

                //////////////////////////////////////////////////
                /// CHAT
                //////////////////////////////////////////////////

                ElevatedButton.icon(
                  onPressed: () async {

                    final chatId =
                        await ChatService.ensureChat(
                      customerId: job.customerId,
                      employeeId: providerId,
                      requestId: job.id,
                    );

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          chatId: chatId,
                          otherUserId: job.customerId,
                          title: job.customerName,
                          requestId: job.id,
                          iAmCustomer: false,
                          providerId: providerId,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.chat),
                  label: const Text('Chat'),
                ),
              ],
            ),

            const SizedBox(height: 24),

            //////////////////////////////////////////////////////
            /// START JOB
            //////////////////////////////////////////////////////

            if (job.isAccepted)
              _PrimaryButton(
                text: 'Start Job',
                color: Colors.white,
                textColor: Colors.green.shade900,
                onTap: () async {

                  await RequestService.startJob(job.id);
                },
              ),

            //////////////////////////////////////////////////////
            /// COMPLETE JOB
            //////////////////////////////////////////////////////

            if (job.isOngoing)
              _PrimaryButton(
                text: 'Complete Job',
                color: Colors.white,
                textColor: Colors.green.shade900,
                onTap: () async {

                  await RequestService.completeJob(job.id);

                  if (context.mounted) {

                    ScaffoldMessenger.of(context)
                        .showSnackBar(
                      const SnackBar(
                        content:
                            Text('Job completed successfully'),
                      ),
                    );
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}

///////////////////////////////////////////////////////////////
/// STATUS CHIP
///////////////////////////////////////////////////////////////

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({
    required this.status,
  });

  @override
  Widget build(BuildContext context) {

    Color color;

    switch (status) {

      case ServiceRequestModel.statusAccepted:
        color = Colors.orange;
        break;

      case ServiceRequestModel.statusOngoing:
        color = Colors.greenAccent;
        break;

      case ServiceRequestModel.statusCompleted:
        color = Colors.blue;
        break;

      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        status.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

///////////////////////////////////////////////////////////////
/// BUTTON
///////////////////////////////////////////////////////////////

class _PrimaryButton extends StatelessWidget {

  final String text;
  final VoidCallback onTap;

  final Color color;
  final Color textColor;

  const _PrimaryButton({
    required this.text,
    required this.onTap,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          padding: const EdgeInsets.symmetric(
            vertical: 18,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        onPressed: onTap,
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

///////////////////////////////////////////////////////////////
/// EMPTY STATE
///////////////////////////////////////////////////////////////

class _EmptyState extends StatelessWidget {

  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [

          Icon(
            icon,
            size: 72,
            color: Colors.grey,
          ),

          const SizedBox(height: 16),

          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}