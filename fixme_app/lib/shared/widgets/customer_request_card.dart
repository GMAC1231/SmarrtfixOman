import 'package:flutter/material.dart';

class CustomerRequestCard extends StatelessWidget {

  final String requestId;

  final String title;
  final String subtitle;
  final String status;

  final double price;

  //////////////////////////////////////////////////////////////
  /// PROVIDER INFO
  //////////////////////////////////////////////////////////////

final String? providerImage;
final String? carImage;

final String providerPhone;
final String carPlate;
final String carModel;

final double providerRating;
final int providerReviews;

  //////////////////////////////////////////////////////////////
  /// RATING
  //////////////////////////////////////////////////////////////

  final bool isRated;

  //////////////////////////////////////////////////////////////
  /// ACTIONS
  //////////////////////////////////////////////////////////////

  final VoidCallback? onTrack;
  final VoidCallback? onChat;
  final VoidCallback? onOffers;
  final VoidCallback? onRateProvider;
  final VoidCallback? onCancel;

  const CustomerRequestCard({

    super.key,

    required this.requestId,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.price,
    required this.isRated,

    ////////////////////////////////////////////////////////////
    /// PROVIDER
    ////////////////////////////////////////////////////////////

    this.providerImage,
    this.carImage,

    this.providerPhone = '',
    this.carPlate = '',
    this.carModel = '',

    this.providerRating = 0,
    this.providerReviews = 0,

    ////////////////////////////////////////////////////////////
    /// ACTIONS
    ////////////////////////////////////////////////////////////

    this.onTrack,
    this.onChat,
    this.onOffers,
    this.onRateProvider,
    this.onCancel,
  });

  //////////////////////////////////////////////////////////////
  /// STATES
  //////////////////////////////////////////////////////////////

  bool get isBidding =>
      status == 'bidding';

  bool get isAccepted =>
      status == 'accepted';

  bool get isOngoing =>
      status == 'ongoing';

  bool get isCompleted =>
      status == 'completed';

  //////////////////////////////////////////////////////////////
  /// STATUS COLOR
  //////////////////////////////////////////////////////////////

  Color _statusColor() {

    switch (status) {

      case 'bidding':
        return Colors.orange;

      case 'accepted':
        return Colors.blue;

      case 'ongoing':
        return Colors.green;

      case 'completed':
        return Colors.purple;

      case 'cancelled':
        return Colors.red;

      default:
        return Colors.grey;
    }
  }

  //////////////////////////////////////////////////////////////
  /// BUTTON
  //////////////////////////////////////////////////////////////

  Widget _button({

    required BuildContext context,

    required IconData icon,

    required String label,

    required VoidCallback? onTap,

    required Color color,
  }) {

    return Expanded(

      child: InkWell(

        onTap: onTap,

        borderRadius:
            BorderRadius.circular(14),

        child: Ink(

          padding:
              const EdgeInsets.symmetric(
            vertical: 12,
          ),

          decoration:
              BoxDecoration(

            color:
                color.withOpacity(0.10),

            borderRadius:
                BorderRadius.circular(
              14,
            ),
          ),

          child: Column(

            mainAxisSize:
                MainAxisSize.min,

            children: [

              Icon(
                icon,
                color: color,
              ),

              const SizedBox(
                height: 6,
              ),

              Text(

                label,

                style: TextStyle(

                  color: color,

                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  //////////////////////////////////////////////////////////////
  /// BUILD
  //////////////////////////////////////////////////////////////

  @override
  Widget build(BuildContext context) {

    final statusColor =
        _statusColor();

    return Container(

      padding:
          const EdgeInsets.all(18),

      decoration:
          BoxDecoration(

        color: Colors.white,

        borderRadius:
            BorderRadius.circular(24),

        boxShadow: [

          BoxShadow(

            color:
                Colors.black.withOpacity(
              0.05,
            ),

            blurRadius: 14,

            offset:
                const Offset(0, 6),
          ),
        ],
      ),

      child: Column(

        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [

          //////////////////////////////////////////////////////
          /// HEADER
          //////////////////////////////////////////////////////

          Row(

            children: [

              Expanded(

                child: Column(

                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [

                    Text(

                      title,

                      style:
                          const TextStyle(

                        fontSize: 18,

                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height: 6,
                    ),

                    Text(
                      subtitle,
                    ),
                  ],
                ),
              ),

              ////////////////////////////////////////////////////
              /// STATUS
              ////////////////////////////////////////////////////

              Container(

                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),

                decoration:
                    BoxDecoration(

                  color:
                      statusColor
                          .withOpacity(0.12),

                  borderRadius:
                      BorderRadius.circular(
                    999,
                  ),
                ),

                child: Text(

                  status.toUpperCase(),

                  style: TextStyle(

                    color:
                        statusColor,

                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          //////////////////////////////////////////////////////
          /// PROVIDER CARD
          //////////////////////////////////////////////////////

          if (providerImage != null) ...[

            const SizedBox(height: 18),

            Container(

              padding:
                  const EdgeInsets.all(14),

              decoration:
                  BoxDecoration(

                color:
                    const Color(0xFFF7F9F8),

                borderRadius:
                    BorderRadius.circular(
                  20,
                ),
              ),

              child: Column(

                children: [

                  //////////////////////////////////////////////////
                  /// PROVIDER ROW
                  //////////////////////////////////////////////////

                  Row(
                    children: [

                      CircleAvatar(
                        radius: 34,

                        backgroundImage:
                            NetworkImage(
                          providerImage!,
                        ),
                      ),

                      const SizedBox(width: 14),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,

                          children: [

                            Text(
                              subtitle,
                              style:
                                  const TextStyle(
                                fontSize: 16,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),

                            const SizedBox(
                              height: 4,
                            ),

                            Text(
                              "⭐ ${providerRating.toStringAsFixed(1)} ($providerReviews reviews)",
                              style:
                                  TextStyle(
                                color: Colors
                                    .grey.shade700,
                              ),
                            ),

                            const SizedBox(
                              height: 4,
                            ),

                            Text(
                              "📞 $providerPhone",
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  //////////////////////////////////////////////////
                  /// CAR IMAGE
                  //////////////////////////////////////////////////

                  if (carImage != null) ...[

                    const SizedBox(height: 16),

                    ClipRRect(

                      borderRadius:
                          BorderRadius.circular(
                        18,
                      ),

                      child: Image.network(

                        carImage!,

                        height: 150,

                        width: double.infinity,

                        fit: BoxFit.cover,
                      ),
                    ),
                  ],

                  //////////////////////////////////////////////////
                  /// CAR INFO
                  //////////////////////////////////////////////////

                  const SizedBox(height: 14),

                  Row(
                    children: [

                      Expanded(

                        child: Container(

                          padding:
                              const EdgeInsets.all(
                            12,
                          ),

                          decoration:
                              BoxDecoration(

                            color:
                                Colors.white,

                            borderRadius:
                                BorderRadius.circular(
                              16,
                            ),
                          ),

                          child: Column(

                            crossAxisAlignment:
                                CrossAxisAlignment.start,

                            children: [

                              const Text(
                                "Vehicle",
                                style: TextStyle(
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),

                              const SizedBox(
                                height: 6,
                              ),

                              Text(
                                "🚗 $carModel",
                              ),

                              Text(
                                "🔢 $carPlate",
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(
            height: 18,
          ),

          //////////////////////////////////////////////////////
          /// PRICE
          //////////////////////////////////////////////////////

          Text(

            'OMR ${price.toStringAsFixed(2)}',

            style: const TextStyle(

              fontSize: 22,

              color: Colors.green,

              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 18,
          ),

          //////////////////////////////////////////////////////
          /// BIDDING
          //////////////////////////////////////////////////////

          if (isBidding)
            Row(

              children: [

                _button(

                  context: context,

                  icon:
                      Icons.local_offer_outlined,

                  label: 'Offers',

                  onTap: onOffers,

                  color: Colors.orange,
                ),

                const SizedBox(
                  width: 10,
                ),

                _button(

                  context: context,

                  icon: Icons.close,

                  label: 'Cancel',

                  onTap: onCancel,

                  color: Colors.red,
                ),
              ],
            ),

          //////////////////////////////////////////////////////
          /// ACTIVE JOB
          //////////////////////////////////////////////////////

          if (status.trim().toLowerCase() !=
                  'completed' &&
              status.trim().toLowerCase() !=
                  'cancelled' &&
              !isRated &&
              onTrack != null)

            Row(
              children: [

                _button(

                  context: context,

                  icon:
                      Icons.map_outlined,

                  label: 'Track',

                  onTap: onTrack,

                  color: Colors.blue,
                ),

                const SizedBox(
                  width: 10,
                ),

                _button(

                  context: context,

                  icon:
                      Icons.chat_bubble_outline,

                  label: 'Chat',

                  onTap: onChat,

                  color: Colors.green,
                ),
              ],
            ),

          //////////////////////////////////////////////////////
          /// COMPLETED → RATE
          //////////////////////////////////////////////////////

          if (status.trim().toLowerCase() ==
                  'completed' &&
              !isRated)

            SizedBox(

              width: double.infinity,

              child: ElevatedButton.icon(

                style:
                    ElevatedButton.styleFrom(

                  backgroundColor:
                      Colors.amber,

                  foregroundColor:
                      Colors.black,

                  padding:
                      const EdgeInsets.symmetric(
                    vertical: 16,
                  ),

                  shape:
                      RoundedRectangleBorder(

                    borderRadius:
                        BorderRadius.circular(
                      16,
                    ),
                  ),
                ),

                onPressed:
                    onRateProvider,

                icon:
                    const Icon(Icons.star),

                label:
                    const Text(
                  'Rate Provider',
                ),
              ),
            ),

          //////////////////////////////////////////////////////
          /// ALREADY RATED
          //////////////////////////////////////////////////////

          if (status.trim().toLowerCase() ==
                  'completed' &&
              isRated)

            Container(

              width: double.infinity,

              padding:
                  const EdgeInsets.symmetric(
                vertical: 16,
              ),

              decoration:
                  BoxDecoration(

                color:
                    Colors.green
                        .withOpacity(0.10),

                borderRadius:
                    BorderRadius.circular(
                  14,
                ),
              ),

              child: const Center(

                child: Row(

                  mainAxisSize:
                      MainAxisSize.min,

                  children: [

                    Icon(

                      Icons.check_circle,

                      color: Colors.green,
                    ),

                    SizedBox(width: 8),

                    Text(

                      'Job Completed',

                      style: TextStyle(

                        color: Colors.green,

                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}