import 'package:flutter/material.dart';

class RequestCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final double price;

  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onOffer;
  final VoidCallback? onChat;
  final VoidCallback? onRoute;

  const RequestCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.price,
    this.onAccept,
    this.onReject,
    this.onOffer,
    this.onChat,
    this.onRoute,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(subtitle),
            const SizedBox(height: 6),
            Text("OMR ${price.toStringAsFixed(2)}"),

            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (onRoute != null)
                  ElevatedButton.icon(
                    onPressed: onRoute,
                    icon: const Icon(Icons.map),
                    label: const Text("Route"),
                  ),

                if (onAccept != null)
                  ElevatedButton(
                    onPressed: onAccept,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green),
                    child: const Text("Accept"),
                  ),

                if (onReject != null)
                  ElevatedButton(
                    onPressed: onReject,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red),
                    child: const Text("Reject"),
                  ),

                if (onOffer != null)
                  ElevatedButton(
                    onPressed: onOffer,
                    child: const Text("Offer"),
                  ),

                if (onChat != null)
                  ElevatedButton(
                    onPressed: onChat,
                    child: const Text("Chat"),
                  ),
              ],
            )
          ],
        ),
      ),
    );
  }
}