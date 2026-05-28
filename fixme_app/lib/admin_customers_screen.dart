////////////////////////////////////////////////////////////
/// ADMIN CUSTOMERS SCREEN
////////////////////////////////////////////////////////////

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'admin_customer_detail_screen.dart';

class AdminCustomersScreen
    extends StatefulWidget {

  const AdminCustomersScreen({
    super.key,
  });

  @override
  State<AdminCustomersScreen>
      createState() =>
          _AdminCustomersScreenState();
}

class _AdminCustomersScreenState
    extends State<AdminCustomersScreen> {

  final TextEditingController _searchController =
      TextEditingController();

  ////////////////////////////////////////////////////////////
  /// DELETE CUSTOMER
  ////////////////////////////////////////////////////////////

  Future<void> _deleteCustomer(
    String uid,
  ) async {

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .delete();

    await FirebaseFirestore.instance
        .collection('publicUsers')
        .doc(uid)
        .delete();

    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(

        const SnackBar(
          content:
              Text('Customer deleted'),
        ),
      );
  }

  ////////////////////////////////////////////////////////////
  /// ACTION SHEET
  ////////////////////////////////////////////////////////////

  void _showActions({

    required BuildContext context,

    required String uid,

    required Map<String, dynamic> data,
  }) {

    showModalBottomSheet(

      context: context,

      backgroundColor:
          Colors.white,

      shape:
          const RoundedRectangleBorder(

        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),

      builder: (_) {

        return SafeArea(

          child: Padding(

            padding:
                const EdgeInsets.all(12),

            child: Wrap(

              children: [

                ListTile(

                  leading: Container(

                    width: 50,
                    height: 50,

                    decoration: BoxDecoration(

                      color:
                          const Color(0xFF2563EB)
                              .withOpacity(0.12),

                      borderRadius:
                          BorderRadius.circular(18),
                    ),

                    child: const Icon(

                      Icons.visibility_rounded,

                      color:
                          Color(0xFF2563EB),
                    ),
                  ),

                  title: const Text(
                    'View Details',
                  ),

                  subtitle: const Text(
                    'Open customer profile',
                  ),

                  onTap: () {

                    Navigator.pop(context);

                    Navigator.push(

                      context,

                      MaterialPageRoute(

                        builder: (_) =>
                            AdminCustomerDetailScreen(

                          docId: uid,

                          data: data,
                        ),
                      ),
                    );
                  },
                ),

                ListTile(

                  leading: Container(

                    width: 50,
                    height: 50,

                    decoration: BoxDecoration(

                      color:
                          Colors.red
                              .withOpacity(0.12),

                      borderRadius:
                          BorderRadius.circular(18),
                    ),

                    child: const Icon(

                      Icons.delete_rounded,

                      color: Colors.red,
                    ),
                  ),

                  title: const Text(
                    'Delete Customer',
                  ),

                  subtitle: const Text(
                    'Remove permanently',
                  ),

                  onTap: () async {

                    Navigator.pop(context);

                    await _deleteCustomer(
                      uid,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  ////////////////////////////////////////////////////////////
  /// CUSTOMER CARD
  ////////////////////////////////////////////////////////////

  Widget _customerCard({

    required String uid,

    required Map<String, dynamic> data,

    required int index,
  }) {

    final name =
        (data['name'] ??
                'No Name')
            .toString();

    final email =
        (data['email'] ??
                'No Email')
            .toString();

    final phone =
        (data['phone'] ??
                'No Phone')
            .toString();

    final city =
        (data['city'] ??
                'Unknown')
            .toString();

    final gradients = [

      [
        const Color(0xFF2563EB),
        const Color(0xFF1D4ED8),
      ],

      [
        const Color(0xFF10B981),
        const Color(0xFF059669),
      ],

      [
        const Color(0xFFF59E0B),
        const Color(0xFFD97706),
      ],

      [
        const Color(0xFF8B5CF6),
        const Color(0xFF7C3AED),
      ],
    ];

    final colors =
        gradients[index %
            gradients.length];

    return GestureDetector(

      onTap: () {

        _showActions(

          context: context,

          uid: uid,

          data: data,
        );
      },

      child: Container(

        margin:
            const EdgeInsets.only(
          bottom: 18,
        ),

        decoration: BoxDecoration(

          color: Colors.white,

          borderRadius:
              BorderRadius.circular(30),

          boxShadow: [

            BoxShadow(

              color:
                  colors.first
                      .withOpacity(0.12),

              blurRadius: 18,

              offset:
                  const Offset(0, 6),
            ),
          ],
        ),

        child: Padding(

          padding:
              const EdgeInsets.all(18),

          child: Row(

            children: [

              //////////////////////////////////////////////////
              /// AVATAR
              //////////////////////////////////////////////////

              Container(

                width: 76,
                height: 76,

                decoration: BoxDecoration(

                  gradient:
                      LinearGradient(
                    colors: colors,
                  ),

                  borderRadius:
                      BorderRadius.circular(24),
                ),

                child: Center(

                  child: Text(

                    name.isNotEmpty
                        ? name[0]
                              .toUpperCase()
                        : '?',

                    style:
                        const TextStyle(

                      color: Colors.white,

                      fontSize: 34,

                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 18),

              //////////////////////////////////////////////////
              /// INFO
              //////////////////////////////////////////////////

              Expanded(

                child: Column(

                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [

                    Text(

                      name,

                      style:
                          const TextStyle(

                        fontSize: 20,

                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Row(

                      children: [

                        Icon(

                          Icons.email_rounded,

                          size: 18,

                          color:
                              Colors.grey[600],
                        ),

                        const SizedBox(width: 8),

                        Expanded(

                          child: Text(

                            email,

                            overflow:
                                TextOverflow.ellipsis,

                            style:
                                TextStyle(

                              color:
                                  Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    Row(

                      children: [

                        Icon(

                          Icons.phone_rounded,

                          size: 18,

                          color:
                              Colors.grey[600],
                        ),

                        const SizedBox(width: 8),

                        Expanded(

                          child: Text(

                            phone,

                            overflow:
                                TextOverflow.ellipsis,

                            style:
                                TextStyle(

                              color:
                                  Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Container(

                      padding:
                          const EdgeInsets.symmetric(

                        horizontal: 14,

                        vertical: 8,
                      ),

                      decoration: BoxDecoration(

                        color:
                            colors.first
                                .withOpacity(0.12),

                        borderRadius:
                            BorderRadius.circular(24),
                      ),

                      child: Text(

                        city.toUpperCase(),

                        style:
                            TextStyle(

                          color:
                              colors.first,

                          fontWeight:
                              FontWeight.bold,

                          fontSize: 11,

                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              //////////////////////////////////////////////////
              /// MENU
              //////////////////////////////////////////////////

              IconButton(

                onPressed: () {

                  _showActions(

                    context: context,

                    uid: uid,

                    data: data,
                  );
                },

                icon: const Icon(
                  Icons.more_vert_rounded,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor:
          const Color(0xFFF4F7FC),

      body: CustomScrollView(

        slivers: [

          //////////////////////////////////////////////////////
          /// APP BAR
          //////////////////////////////////////////////////////

          SliverAppBar(

            expandedHeight: 290,

            pinned: true,

            elevation: 0,

            backgroundColor:
                const Color(0xFF2563EB),

            flexibleSpace:
                FlexibleSpaceBar(

              background: Container(

                decoration: const BoxDecoration(

                  gradient:
                      LinearGradient(

                    begin:
                        Alignment.topLeft,

                    end:
                        Alignment.bottomRight,

                    colors: [

                      Color(0xFF2563EB),

                      Color(0xFF1E3A8A),
                    ],
                  ),
                ),

                child: SafeArea(

                  child: Padding(

                    padding:
                        const EdgeInsets.all(24),

                    child: Column(

                      crossAxisAlignment:
                          CrossAxisAlignment.start,

                      mainAxisAlignment:
                          MainAxisAlignment.end,

                      children: [

                        Container(

                          width: 90,
                          height: 90,

                          decoration: BoxDecoration(

                            color:
                                Colors.white
                                    .withOpacity(0.16),

                            borderRadius:
                                BorderRadius.circular(28),
                          ),

                          child: const Icon(

                            Icons.people_alt_rounded,

                            color: Colors.white,

                            size: 50,
                          ),
                        ),

                        const SizedBox(height: 20),

                        const Text(

                          'Customers',

                          style:
                              TextStyle(

                            color: Colors.white,

                            fontSize: 34,

                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(

                          'Manage all registered customers.',

                          style:
                              TextStyle(

                            color:
                                Colors.white
                                    .withOpacity(0.92),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          //////////////////////////////////////////////////////
          /// SEARCH + LIST
          //////////////////////////////////////////////////////

          SliverToBoxAdapter(

            child: Column(

              children: [

                //////////////////////////////////////////////////
                /// SEARCH
                //////////////////////////////////////////////////

                Padding(

                  padding:
                      const EdgeInsets.all(18),

                  child: TextField(

                    controller:
                        _searchController,

                    onChanged: (_) {

                      setState(() {});
                    },

                    decoration: InputDecoration(

                      hintText:
                          'Search customers...',

                      prefixIcon:
                          const Icon(
                        Icons.search_rounded,
                      ),

                      filled: true,

                      fillColor: Colors.white,

                      border:
                          OutlineInputBorder(

                        borderRadius:
                            BorderRadius.circular(24),

                        borderSide:
                            BorderSide.none,
                      ),
                    ),
                  ),
                ),

                //////////////////////////////////////////////////
                /// LIST
                //////////////////////////////////////////////////

                StreamBuilder<QuerySnapshot>(

                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .where(
                        'role',
                        isEqualTo:
                            'customer',
                      )
                      .snapshots(),

                  builder: (
                    context,
                    snapshot,
                  ) {

                    if (snapshot.hasError) {

                      return Padding(

                        padding:
                            const EdgeInsets.all(30),

                        child: Text(
                          'Error: ${snapshot.error}',
                        ),
                      );
                    }

                    if (!snapshot.hasData) {

                      return const Padding(

                        padding:
                            EdgeInsets.all(40),

                        child: CircularProgressIndicator(),
                      );
                    }

                    final docs =
                        snapshot.data!.docs;

                    final filtered =
                        docs.where((doc) {

                      final data =
                          doc.data()
                              as Map<String, dynamic>;

                      final search =
                          _searchController.text
                              .trim()
                              .toLowerCase();

                      final name =
                          (data['name'] ?? '')
                              .toString()
                              .toLowerCase();

                      final email =
                          (data['email'] ?? '')
                              .toString()
                              .toLowerCase();

                      return search.isEmpty ||
                          name.contains(search) ||
                          email.contains(search);

                    }).toList();

                    if (filtered.isEmpty) {

                      return const Padding(

                        padding:
                            EdgeInsets.all(40),

                        child: Text(
                          'No customers found',
                        ),
                      );
                    }

                    return ListView.builder(

                      shrinkWrap: true,

                      physics:
                          const NeverScrollableScrollPhysics(),

                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 18,
                      ),

                      itemCount:
                          filtered.length,

                      itemBuilder: (
                        context,
                        index,
                      ) {

                        final doc =
                            filtered[index];

                        final data =
                            doc.data()
                                as Map<String, dynamic>;

                        return _customerCard(

                          uid: doc.id,

                          data: data,

                          index: index,
                        );
                      },
                    );
                  },
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }
}