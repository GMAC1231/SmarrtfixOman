import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'shared/widgets/metric_card.dart';

class DashboardHomeTab extends StatelessWidget {
  final VoidCallback onRecenterMap;
  final VoidCallback onProfile;
  final VoidCallback onToggleOnline;
  final int activeJobs;
  final int completedJobs;
  final double earnings;
  final bool isOnline;

  const DashboardHomeTab({
    super.key,
    required this.onRecenterMap,
    required this.onProfile,
    required this.onToggleOnline,
    required this.activeJobs,
    required this.completedJobs,
    required this.earnings,
    required this.isOnline,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName ?? user?.email?.split('@').first ?? 'Provider';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF01411C),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back, $name',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isOnline ? 'You are online and visible to customers.' : 'You are offline right now.',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: onToggleOnline,
                icon: Icon(isOnline ? Icons.toggle_on : Icons.toggle_off),
                label: Text(isOnline ? 'Go offline' : 'Go online'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.2,
          children: [
            MetricCard(
              title: 'Active jobs',
              value: '$activeJobs',
              icon: Icons.work_outline,
              color: Colors.blue,
            ),
            MetricCard(
              title: 'Completed jobs',
              value: '$completedJobs',
              icon: Icons.task_alt,
              color: Colors.green,
            ),
            MetricCard(
              title: 'Estimated earnings',
              value: 'OMR ${earnings.toStringAsFixed(2)}',
              icon: Icons.account_balance_wallet_outlined,
              color: Colors.orange,
            ),
            MetricCard(
              title: 'Availability',
              value: isOnline ? 'Online' : 'Offline',
              icon: isOnline ? Icons.wifi_tethering : Icons.wifi_off,
              color: isOnline ? Colors.teal : Colors.grey,
            ),
          ],
        ),
        const SizedBox(height: 18),
        const Text(
          'Quick actions',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _QuickAction(
              icon: Icons.my_location,
              label: 'Recenter map',
              color: Colors.blue,
              onTap: onRecenterMap,
            ),
            _QuickAction(
              icon: Icons.person_outline,
              label: 'Profile settings',
              color: Colors.green,
              onTap: onProfile,
            ),
            _QuickAction(
              icon: Icons.sync,
              label: 'Toggle visibility',
              color: Colors.teal,
              onTap: onToggleOnline,
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
