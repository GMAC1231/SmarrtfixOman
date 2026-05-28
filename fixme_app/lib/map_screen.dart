import 'dart:ui';
import 'package:flutter/material.dart';
import 'map_tab.dart';

class MapScreen extends StatelessWidget {
  final String? requestId;
  final String? providerId;
  final double? customerLat;
  final double? customerLng;
  final bool trackLiveDriver;
  final bool listenToAssignedRequest;
  final bool showTopOverlay;
  final bool showBottomCard;

  const MapScreen({
    super.key,
    this.requestId,
    this.providerId,
    this.customerLat,
    this.customerLng,
    this.trackLiveDriver = true,
    this.listenToAssignedRequest = true,
    this.showTopOverlay = true,
    this.showBottomCard = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MapTab(
            requestId: requestId,
            providerId: providerId,
            customerLat: customerLat,
            customerLng: customerLng,
            trackLiveDriver: trackLiveDriver,
            listenToAssignedRequest: listenToAssignedRequest,
            showInternalTopCard: !showTopOverlay,
            showInternalBottomCard: !showBottomCard,
          ),

          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: _GlassIconButton(
              icon: Icons.arrow_back,
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),

          if (showTopOverlay)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 80,
              right: 16,
              child: const _GlassInfoCard(
                title: 'Live Tracking',
                subtitle: 'Driver is on the way',
              ),
            ),
        ],
      ),
    );
  }
}

class _GlassInfoCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const _GlassInfoCard({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.24),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.82),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.26),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.10)),
              ),
              child: Icon(icon, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}