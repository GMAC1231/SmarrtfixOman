import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DashboardHomeTab extends StatelessWidget {
  final VoidCallback onRecenterMap;
  final VoidCallback onProfile;

  final int activeJobs;
  final int completedJobs;
  final double rating;
  final int reviews;
  final double earnings;

  const DashboardHomeTab({
    super.key,
    required this.onRecenterMap,
    required this.onProfile,
    required this.activeJobs,
    required this.completedJobs,
    required this.earnings,
    required this.rating,
    required this.reviews,
  });

  ////////////////////////////////////////////////////////////
  /// STAT CARD
  ////////////////////////////////////////////////////////////

  Widget _statCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(24),
      ),

      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          //////////////////////////////////////////////////////
          /// ICON
          //////////////////////////////////////////////////////

          Container(
            width: 50,
            height: 50,

            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),

            child: Icon(
              icon,
              color: color,
              size: 26,
            ),
          ),

          //////////////////////////////////////////////////////
          /// VALUE + TITLE
          //////////////////////////////////////////////////////

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,

                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                title,

                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  ////////////////////////////////////////////////////////////
  /// QUICK ACTION
  ////////////////////////////////////////////////////////////

  Widget _quickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,

      borderRadius: BorderRadius.circular(24),

      child: Container(
        width: 160,

        padding: const EdgeInsets.all(18),

        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(24),
        ),

        child: Column(
          children: [

            Container(
              width: 56,
              height: 56,

              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(18),
              ),

              child: Icon(
                icon,
                color: color,
                size: 30,
              ),
            ),

            const SizedBox(height: 14),

            Text(
              label,
              textAlign: TextAlign.center,

              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    final user =
        FirebaseAuth.instance.currentUser;

    final uid = user?.uid;

    final name =
        user?.displayName ??
        user?.email?.split('@').first ??
        'Provider';

    ////////////////////////////////////////////////////////////
    /// MAIN UI
    ////////////////////////////////////////////////////////////

    return ListView(

      padding: const EdgeInsets.fromLTRB(
        18,
        18,
        18,
        120,
      ),

      children: [

        ////////////////////////////////////////////////////////
        /// HEADER CARD
        ////////////////////////////////////////////////////////

        Container(

          padding: const EdgeInsets.all(26),

          decoration: BoxDecoration(

            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,

              colors: [
                Color(0xFF2563EB),
                Color(0xFF1E40AF),
              ],
            ),

            borderRadius:
                BorderRadius.circular(34),

            boxShadow: [

              BoxShadow(
                color: Colors.blue.withOpacity(0.22),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),

          child: Row(
            children: [

              //////////////////////////////////////////////////
              /// AVATAR
              //////////////////////////////////////////////////

              CircleAvatar(
                radius: 34,
                backgroundColor: Colors.white,

                child: Text(
                  name.isNotEmpty
                      ? name[0].toUpperCase()
                      : 'P',

                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),

              const SizedBox(width: 16),

              //////////////////////////////////////////////////
              /// NAME
              //////////////////////////////////////////////////

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [

                    Text(
                      'Welcome back',

                      style: TextStyle(
                        color:
                            Colors.white.withOpacity(0.80),

                        fontSize: 15,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      name,

                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 30),

        ////////////////////////////////////////////////////////
        /// TITLE
        ////////////////////////////////////////////////////////

        const Text(
          'Performance Stats',

          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 18),

        ////////////////////////////////////////////////////////
        /// REALTIME STATS
        ////////////////////////////////////////////////////////

        StreamBuilder<QuerySnapshot>(

          stream: FirebaseFirestore.instance
              .collection('serviceRequests')
              .where(
                'employeeId',
                isEqualTo: uid,
              )
              .snapshots(),

          builder: (context, snapshot) {

            if (snapshot.connectionState ==
                ConnectionState.waiting) {

              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            ////////////////////////////////////////////////////
            /// JOBS
            ////////////////////////////////////////////////////

            final jobDocs =
                snapshot.data?.docs ?? [];

            ////////////////////////////////////////////////////
            /// CALCULATE VALUES
            ////////////////////////////////////////////////////

            double totalEarnings = 0;

            double totalRating = 0;

            int reviewCount = 0;

            for (final doc in jobDocs) {

              final data =
                  doc.data()
                      as Map<String, dynamic>;

              //////////////////////////////////////////////////
              /// FARE
              //////////////////////////////////////////////////

              final fare =
                  data['fare'] ??
                  data['priceOffer'] ??
                  data['agreedFare'] ??
                  0;

              if (fare is num) {

                totalEarnings +=
                    fare.toDouble();
              }

              //////////////////////////////////////////////////
              /// RATING
              //////////////////////////////////////////////////

              final rating =
                  data['customerRating'];

              if (rating is num &&
                  rating > 0) {

                totalRating +=
                    rating.toDouble();

                reviewCount++;
              }
            }

            ////////////////////////////////////////////////////
            /// AVERAGE RATING
            ////////////////////////////////////////////////////

            final avgRating =

                reviewCount > 0

                    ? totalRating / reviewCount

                    : 0.0;

            ////////////////////////////////////////////////////
            /// COMPLETED JOBS
            ////////////////////////////////////////////////////

            final completedJobs =
                jobDocs.length;

            ////////////////////////////////////////////////////
            /// SAVE TO USERS
            ////////////////////////////////////////////////////

            FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .set({

              'totalEarnings':
                  totalEarnings,

              'totalJobs':
                  completedJobs,

              'totalReviews':
                  reviewCount,

              'rating':
                  avgRating,

            }, SetOptions(
              merge: true,
            ));

            ////////////////////////////////////////////////////
            /// GRID
            ////////////////////////////////////////////////////

            return GridView.count(

              crossAxisCount: 2,

              shrinkWrap: true,

              physics:
                  const NeverScrollableScrollPhysics(),

              crossAxisSpacing: 16,

              mainAxisSpacing: 16,

              childAspectRatio: 1.15,

              children: [

                _statCard(
                  icon: Icons.star_rounded,
                  title: 'Rating',
                  value: avgRating.toStringAsFixed(1),
                  color: Colors.amber,
                ),

                _statCard(
                  icon: Icons.reviews_rounded,
                  title: 'Reviews',
                  value: '$reviewCount',
                  color: Colors.blue,
                ),

                _statCard(
                  icon: Icons.account_balance_wallet,
                  title: 'Earnings',
                  value:
                      'OMR ${totalEarnings.toStringAsFixed(2)}',
                  color: Colors.green,
                ),

                _statCard(
                  icon: Icons.task_alt_rounded,
                  title: 'Completed',
                  value: '$completedJobs',
                  color: Colors.purple,
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 30),

        ////////////////////////////////////////////////////////
        /// QUICK ACTIONS
        ////////////////////////////////////////////////////////

        const Text(
          'Quick Actions',

          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 18),

        Wrap(

          spacing: 14,
          runSpacing: 14,

          children: [

            _quickAction(
              icon: Icons.my_location_rounded,
              label: 'Recenter Map',
              color: Colors.blue,
              onTap: onRecenterMap,
            ),

            _quickAction(
              icon: Icons.person_outline_rounded,
              label: 'Profile Settings',
              color: Colors.green,
              onTap: onProfile,
            ),
          ],
        ),
      ],
    );
  }
}