import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'chat_screen.dart';
import 'map_tab.dart';

import 'shared/models/service_request.dart';
import 'shared/services/chat_service.dart';
import 'shared/services/request_service.dart';

import 'shared/widgets/customer_request_card.dart';

class CustomerRequestsTab extends StatelessWidget {
  final GlobalKey<MapTabState> mapTabKey;
  final VoidCallback? onOpenMapTab;

  const CustomerRequestsTab({
    super.key,
    required this.mapTabKey,
    this.onOpenMapTab,
  });

  @override
  Widget build(BuildContext context) {
    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(
        child: Text('Not logged in'),
      );
    }

    return StreamBuilder<List<ServiceRequestModel>>(
      stream:
          RequestService.customerRequestsStream(
        user.uid,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              snapshot.error.toString(),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final requests =
            snapshot.data ?? [];

        if (requests.isEmpty) {
          return const Center(
            child: Text(
              'No requests',
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            120,
          ),
          itemCount: requests.length,
          separatorBuilder: (_, __) =>
              const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final req = requests[index];

            final providerId =
                req.employeeId.trim();

            final providerName =
                req.employeeName.trim().isEmpty
                    ? 'Waiting for provider'
                    : req.employeeName.trim();

            ////////////////////////////////////////////////////
            /// TRACK
            ////////////////////////////////////////////////////

            final canTrack =
                (req.isAccepted ||
                        req.isOngoing) &&
                    providerId.isNotEmpty &&
                    req.customerLat != null &&
                    req.customerLng != null;

            ////////////////////////////////////////////////////
            /// CHAT
            ////////////////////////////////////////////////////

            final canChat =
                (req.isAccepted ||
                        req.isOngoing) &&
                    providerId.isNotEmpty;

            return CustomerRequestCard(
              requestId: req.id,

              title: req.serviceType,

              subtitle: req.isBidding
                  ? 'Waiting for offers'
                  : providerName,

              status: req.status,

              price: req.displayFare,

              isRated: req.isRated,

              //////////////////////////////////////////////////
              /// TRACK
              //////////////////////////////////////////////////

              onTrack: canTrack
                  ? () async {
                      final lat =
                          req.customerLat;

                      final lng =
                          req.customerLng;

                      if (lat == null ||
                          lng == null) {
                        return;
                      }

                      await mapTabKey
                          .currentState
                          ?.setCustomerLocation(
                        LatLng(lat, lng),
                      );

                      onOpenMapTab?.call();
                    }
                  : null,

              //////////////////////////////////////////////////
              /// CHAT
              //////////////////////////////////////////////////

              onChat: canChat
                  ? () async {
                      final chatId =
                          await ChatService
                              .ensureChat(
                        customerId:
                            user.uid,
                        employeeId:
                            providerId,
                        requestId:
                            req.id,
                      );

                      if (!context.mounted) {
                        return;
                      }

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ChatScreen(
                            chatId: chatId,
                            otherUserId:
                                providerId,
                            title:
                                providerName,
                            requestId:
                                req.id,
                            iAmCustomer:
                                true,
                            providerId:
                                providerId,
                          ),
                        ),
                      );
                    }
                  : null,

              //////////////////////////////////////////////////
              /// OFFERS
              //////////////////////////////////////////////////

              onOffers: req.isBidding
                  ? () {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Open offers page',
                          ),
                        ),
                      );
                    }
                  : null,

              //////////////////////////////////////////////////
              /// RATE
              //////////////////////////////////////////////////

              onRateProvider:
                  req.isCompleted &&
                          !req.isRated
                      ? () {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Rate provider',
                              ),
                            ),
                          );
                        }
                      : null,

              //////////////////////////////////////////////////
              /// CANCEL
              //////////////////////////////////////////////////

              onCancel: req.isBidding
                  ? () async {
                      await RequestService
                          .cancelRequest(
                        req.id,
                      );
                    }
                  : null,
            );
          },
        );
      },
    );
  }
}