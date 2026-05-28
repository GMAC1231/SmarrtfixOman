// lib/request_tab.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart' as osm;

import 'chat_screen.dart';
import 'map_tab.dart';
import 'shared/models/service_request.dart';
import 'shared/services/chat_services.dart';
import 'shared/services/request_service.dart';

class EmployeeRequestsTab extends StatefulWidget {
  final GlobalKey<MapTabState> mapTabKey;

  const EmployeeRequestsTab({
    super.key,
    required this.mapTabKey,
  });

  @override
  State<EmployeeRequestsTab> createState() => _EmployeeRequestsTabState();
}

class _EmployeeRequestsTabState extends State<EmployeeRequestsTab> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ServiceRequestModel>>(
      stream: RequestService.openRequestsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data!;
        if (requests.isEmpty) {
          return const Center(child: Text('No open requests'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final req = requests[index];

            return _RequestCard(
              request: req,
              busy: _busy,
              onRoute: () async {
                final gp = _extractPoint(req);
                if (gp != null) {
                  await widget.mapTabKey.currentState?.setCustomerLocation(gp);
                }
              },
              onQuickAccept: () => _handleQuickAccept(req),
              onReject: () => _handleReject(req),
              onOffer: () => _showOfferDialog(req),
              onChat: req.customerId.isEmpty
                  ? null
                  : () => _openChat(
                        customerId: req.customerId,
                        requestId: req.id,
                        title: req.customerName.isEmpty
                            ? 'Customer'
                            : req.customerName,
                      ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleQuickAccept(ServiceRequestModel req) async {
    await _runBusy(() async {
      if (req.status != 'bidding') {
        throw Exception('Already taken');
      }

      await RequestService.quickAcceptRequest(req.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request accepted')),
      );
    });
  }

  Future<void> _handleReject(ServiceRequestModel req) async {
    await _runBusy(() async {
      if (req.status != 'bidding') {
        throw Exception('This request is no longer open');
      }

      await RequestService.rejectRequest(req.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request rejected')),
      );
    });
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    if (_busy) return;

    if (mounted) {
      setState(() => _busy = true);
    }

    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  osm.GeoPoint? _extractPoint(ServiceRequestModel req) {
    if (req.customerLat != null && req.customerLng != null) {
      return osm.GeoPoint(
        latitude: req.customerLat!,
        longitude: req.customerLng!,
      );
    }
    return null;
  }

  Future<void> _showOfferDialog(ServiceRequestModel req) async {
    final fareController = TextEditingController(
      text: (req.displayFare ?? 0).toStringAsFixed(2),
    );
    final noteController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        bool submitting = false;

        return StatefulBuilder(
          builder: (dialogInnerContext, setStateDialog) {
            return AlertDialog(
              title: const Text('Send offer'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: fareController,
                    enabled: !submitting,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Your fare',
                      prefixText: 'OMR ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    enabled: !submitting,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Optional note',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: submitting
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          final fare =
                              double.tryParse(fareController.text.trim());

                          if (fare == null || fare <= 0) {
                            ScaffoldMessenger.of(dialogInnerContext).showSnackBar(
                              const SnackBar(
                                content: Text('Enter a valid fare'),
                              ),
                            );
                            return;
                          }

                          setStateDialog(() => submitting = true);
                          Navigator.pop(dialogContext);

                          await _runBusy(() async {
                            if (req.status != 'bidding') {
                              throw Exception('Request already taken');
                            }

                            await RequestService.sendOffer(
                              requestId: req.id,
                              fare: fare,
                              note: noteController.text.trim().isEmpty
                                  ? null
                                  : noteController.text.trim(),
                            );

                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Offer sent')),
                            );
                          });
                        },
                  child: const Text('Send'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openChat({
    required String customerId,
    required String requestId,
    required String title,
  }) async {
    final providerId = FirebaseAuth.instance.currentUser?.uid;
    if (providerId == null) return;

    try {
      final chatId = await ChatService.ensureChat(
        customerId: customerId,
        employeeId: providerId,
        requestId: requestId,
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: chatId,
            otherUserId: customerId,
            title: title,
            requestId: requestId,
            iAmCustomer: false,
            providerId: providerId,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open chat: $e')),
      );
    }
  }
}

class _RequestCard extends StatelessWidget {
  final ServiceRequestModel request;
  final bool busy;
  final VoidCallback onRoute;
  final VoidCallback onQuickAccept;
  final VoidCallback onReject;
  final VoidCallback onOffer;
  final VoidCallback? onChat;

  const _RequestCard({
    required this.request,
    required this.busy,
    required this.onRoute,
    required this.onQuickAccept,
    required this.onReject,
    required this.onOffer,
    required this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              request.serviceType,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text('👤 ${request.customerName}'),
            Text('💰 OMR ${request.displayFare ?? 0}'),
            Text('📌 ${request.status}'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: busy ? null : onRoute,
                  icon: const Icon(Icons.map),
                  label: const Text('Route'),
                ),
                ElevatedButton.icon(
                  onPressed: busy ? null : onQuickAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  icon: const Icon(Icons.check),
                  label: const Text('Accept'),
                ),
                ElevatedButton.icon(
                  onPressed: busy ? null : onReject,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  icon: const Icon(Icons.close),
                  label: const Text('Reject'),
                ),
                ElevatedButton.icon(
                  onPressed: busy ? null : onOffer,
                  icon: const Icon(Icons.local_offer),
                  label: const Text('Offer'),
                ),
                if (onChat != null)
                  ElevatedButton.icon(
                    onPressed: busy ? null : onChat,
                    icon: const Icon(Icons.chat),
                    label: const Text('Chat'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}