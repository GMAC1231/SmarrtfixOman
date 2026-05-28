import 'package:flutter/material.dart';

class EmployeeRequestCard extends StatelessWidget {

  //////////////////////////////////////////////////////////////
  /// BASIC
  //////////////////////////////////////////////////////////////

  final String title;
  final String subtitle;

  final double price;

  //////////////////////////////////////////////////////////////
  /// CUSTOMER
  //////////////////////////////////////////////////////////////

  final String customerPhone;
  final String customerLocation;

  final String? customerImage;

  //////////////////////////////////////////////////////////////
  /// REQUEST
  //////////////////////////////////////////////////////////////

  final String status;

  final String notes;

  final String eta;
  final String distance;

  //////////////////////////////////////////////////////////////
  /// ACTIONS
  //////////////////////////////////////////////////////////////

  final VoidCallback? onOffer;
  final VoidCallback? onWithdraw;

  final VoidCallback? onTrack;
  final VoidCallback? onChat;

  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  final VoidCallback? onComplete;

  const EmployeeRequestCard({

    super.key,

    ////////////////////////////////////////////////////////////
    /// BASIC
    ////////////////////////////////////////////////////////////

    required this.title,
    required this.subtitle,
    required this.price,

    ////////////////////////////////////////////////////////////
    /// CUSTOMER
    ////////////////////////////////////////////////////////////

    this.customerPhone = '',
    this.customerLocation = '',
    this.customerImage,

    ////////////////////////////////////////////////////////////
    /// REQUEST
    ////////////////////////////////////////////////////////////

    this.status = 'pending',

    this.notes = '',

    this.eta = '',
    this.distance = '',

    ////////////////////////////////////////////////////////////
    /// ACTIONS
    ////////////////////////////////////////////////////////////

    this.onOffer,
    this.onWithdraw,

    this.onTrack,
    this.onChat,

    this.onAccept,
    this.onReject,

    this.onComplete,
  });

  //////////////////////////////////////////////////////////////
  /// STATUS COLOR
  //////////////////////////////////////////////////////////////

  Color _statusColor() {

    switch (status.toLowerCase()) {

      case 'pending':
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
  /// ACTION BUTTON
  //////////////////////////////////////////////////////////////

  Widget _action({

    required IconData icon,

    required String label,

    required Color color,

    required VoidCallback? onTap,
  }) {

    return Expanded(

      child: InkWell(

        borderRadius:
            BorderRadius.circular(18),

        onTap: onTap,

        child: Ink(

          padding:
              const EdgeInsets.symmetric(
            vertical: 14,
          ),

          decoration:
              BoxDecoration(

            color:
                color.withOpacity(0.10),

            borderRadius:
                BorderRadius.circular(
              18,
            ),
          ),

          child: Column(

            children: [

              Icon(
                icon,
                color: color,
              ),

              const SizedBox(
                height: 8,
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
            BorderRadius.circular(28),

        boxShadow: [

          BoxShadow(

            color:
                Colors.black.withOpacity(
              0.05,
            ),

            blurRadius: 12,

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
          /// TOP ROW
          //////////////////////////////////////////////////////

          Row(
            children: [

              ////////////////////////////////////////////////////
              /// CUSTOMER IMAGE
              ////////////////////////////////////////////////////

              CircleAvatar(

                radius: 34,

                backgroundImage:
                    customerImage != null
                        ? NetworkImage(
                            customerImage!,
                          )
                        : null,

                child:
                    customerImage == null
                        ? const Icon(
                            Icons.person,
                            size: 34,
                          )
                        : null,
              ),

              const SizedBox(width: 16),

              ////////////////////////////////////////////////////
              /// CUSTOMER INFO
              ////////////////////////////////////////////////////

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
                      height: 4,
                    ),

                    Text(
                      subtitle,
                      style: TextStyle(
                        color:
                            Colors.grey.shade700,
                      ),
                    ),

                    const SizedBox(
                      height: 6,
                    ),

                    if (customerPhone
                        .isNotEmpty)

                      Text(
                        "📞 $customerPhone",
                      ),

                    if (customerLocation
                        .isNotEmpty)

                      Text(
                        "📍 $customerLocation",
                      ),

                    if (distance.isNotEmpty)

                      Text(
                        "🛣 $distance away",
                      ),

                    if (eta.isNotEmpty)

                      Text(
                        "⏱ ETA $eta",
                      ),
                  ],
                ),
              ),

              ////////////////////////////////////////////////////
              /// PRICE + STATUS
              ////////////////////////////////////////////////////

              Column(
                crossAxisAlignment:
                    CrossAxisAlignment.end,

                children: [

                  Container(

                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),

                    decoration:
                        BoxDecoration(

                      color:
                          Colors.green
                              .withOpacity(
                        0.12,
                      ),

                      borderRadius:
                          BorderRadius.circular(
                        999,
                      ),
                    ),

                    child: Text(

                      'OMR ${price.toStringAsFixed(2)}',

                      style:
                          const TextStyle(

                        color:
                            Colors.green,

                        fontWeight:
                            FontWeight.bold,

                        fontSize: 17,
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 10,
                  ),

                  Container(

                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),

                    decoration:
                        BoxDecoration(

                      color:
                          statusColor
                              .withOpacity(
                        0.12,
                      ),

                      borderRadius:
                          BorderRadius.circular(
                        999,
                      ),
                    ),

                    child: Text(

                      status
                          .toUpperCase(),

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
            ],
          ),

          //////////////////////////////////////////////////////
          /// NOTES
          //////////////////////////////////////////////////////

          if (notes.isNotEmpty) ...[

            const SizedBox(height: 18),

            Container(

              width: double.infinity,

              padding:
                  const EdgeInsets.all(14),

              decoration:
                  BoxDecoration(

                color:
                    const Color(
                  0xFFF5F7FB,
                ),

                borderRadius:
                    BorderRadius.circular(
                  18,
                ),
              ),

              child: Text(
                notes,
              ),
            ),
          ],

          const SizedBox(height: 24),

          //////////////////////////////////////////////////////
          /// PENDING → OFFER
          //////////////////////////////////////////////////////

          if (status == 'pending')

            Row(
              children: [

                _action(

                  icon:
                      Icons.local_offer_outlined,

                  label: 'Offer',

                  color: Colors.orange,

                  onTap: onOffer,
                ),

                if (onWithdraw != null)
                  const SizedBox(
                    width: 12,
                  ),

                if (onWithdraw != null)

                  _action(

                    icon: Icons.close,

                    label: 'Withdraw',

                    color: Colors.red,

                    onTap: onWithdraw,
                  ),
              ],
            ),

          //////////////////////////////////////////////////////
          /// ACCEPTED / ONGOING
          //////////////////////////////////////////////////////

          if (status == 'accepted' ||
              status == 'ongoing')

            Row(
              children: [

                _action(

                  icon:
                      Icons.map_outlined,

                  label: 'Track',

                  color: Colors.blue,

                  onTap: onTrack,
                ),

                const SizedBox(
                  width: 12,
                ),

                _action(

                  icon:
                      Icons.chat_bubble_outline,

                  label: 'Chat',

                  color: Colors.green,

                  onTap: onChat,
                ),
              ],
            ),

          //////////////////////////////////////////////////////
          /// COMPLETE JOB
          //////////////////////////////////////////////////////

          if (status == 'ongoing') ...[

            const SizedBox(height: 14),

            SizedBox(

              width: double.infinity,

              child: ElevatedButton.icon(

                style:
                    ElevatedButton.styleFrom(

                  backgroundColor:
                      Colors.green,

                  foregroundColor:
                      Colors.white,

                  padding:
                      const EdgeInsets.symmetric(
                    vertical: 16,
                  ),

                  shape:
                      RoundedRectangleBorder(

                    borderRadius:
                        BorderRadius.circular(
                      18,
                    ),
                  ),
                ),

                onPressed:
                    onComplete,

                icon:
                    const Icon(
                  Icons.check_circle,
                ),

                label:
                    const Text(
                  'Complete Job',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}