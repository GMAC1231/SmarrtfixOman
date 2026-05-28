import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'admin_employee_detail_screen.dart';

class AdminEmployeesScreen
    extends StatefulWidget {

  const AdminEmployeesScreen({
    super.key,
  });

  @override
  State<AdminEmployeesScreen>
      createState() =>
          _AdminEmployeesScreenState();
}

class _AdminEmployeesScreenState
    extends State<AdminEmployeesScreen> {

  final TextEditingController _searchController =
      TextEditingController();

  ////////////////////////////////////////////////////////////
  /// UPDATE STATUS
  ////////////////////////////////////////////////////////////

  Future<void> _setEmployeeStatus({

    required String uid,

    required String status,
  }) async {

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .set({

      'accountStatus': status,

    }, SetOptions(merge: true));

    await FirebaseFirestore.instance
        .collection('publicUsers')
        .doc(uid)
        .set({

      'accountStatus': status,

    }, SetOptions(merge: true));

    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(

        SnackBar(
          content:
              Text(
            'Employee marked as $status',
          ),
        ),
      );
  }

  ////////////////////////////////////////////////////////////
  /// DELETE EMPLOYEE
  ////////////////////////////////////////////////////////////

  Future<void> _deleteEmployee(
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
              Text('Employee deleted'),
        ),
      );
  }

  ////////////////////////////////////////////////////////////
  /// ACTION SHEET
  ////////////////////////////////////////////////////////////

  void _showActions({

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

                //////////////////////////////////////////////////
                /// VIEW
                //////////////////////////////////////////////////

                ListTile(

                  leading: Container(

                    width: 52,
                    height: 52,

                    decoration: BoxDecoration(

                      color:
                          const Color(0xFF10B981)
                              .withOpacity(0.12),

                      borderRadius:
                          BorderRadius.circular(18),
                    ),

                    child: const Icon(

                      Icons.visibility_rounded,

                      color:
                          Color(0xFF10B981),
                    ),
                  ),

                  title: const Text(
                    'View Details',
                  ),

                  subtitle: const Text(
                    'Open employee profile',
                  ),

                  onTap: () {

                    Navigator.pop(context);

                    Navigator.push(

                      context,

                      MaterialPageRoute(

                        builder: (_) =>
                            AdminEmployeeDetailScreen(

                          docId: uid,

                            employeeId: uid,
                        ),
                      ),
                    );
                  },
                ),

                //////////////////////////////////////////////////
                /// SUSPEND
                //////////////////////////////////////////////////

                ListTile(

                  leading: Container(

                    width: 52,
                    height: 52,

                    decoration: BoxDecoration(

                      color:
                          Colors.orange
                              .withOpacity(0.12),

                      borderRadius:
                          BorderRadius.circular(18),
                    ),

                    child: const Icon(

                      Icons.block_rounded,

                      color: Colors.orange,
                    ),
                  ),

                  title: const Text(
                    'Suspend Employee',
                  ),

                  subtitle: const Text(
                    'Disable employee account',
                  ),

                  onTap: () async {

                    Navigator.pop(context);

                    await _setEmployeeStatus(

                      uid: uid,

                      status:
                          'suspended',
                    );
                  },
                ),

                //////////////////////////////////////////////////
                /// ACTIVATE
                //////////////////////////////////////////////////

                ListTile(

                  leading: Container(

                    width: 52,
                    height: 52,

                    decoration: BoxDecoration(

                      color:
                          const Color(0xFF2563EB)
                              .withOpacity(0.12),

                      borderRadius:
                          BorderRadius.circular(18),
                    ),

                    child: const Icon(

                      Icons.check_circle_rounded,

                      color:
                          Color(0xFF2563EB),
                    ),
                  ),

                  title: const Text(
                    'Activate Employee',
                  ),

                  subtitle: const Text(
                    'Enable employee account',
                  ),

                  onTap: () async {

                    Navigator.pop(context);

                    await _setEmployeeStatus(

                      uid: uid,

                      status:
                          'active',
                    );
                  },
                ),

                //////////////////////////////////////////////////
                /// DELETE
                //////////////////////////////////////////////////

                ListTile(

                  leading: Container(

                    width: 52,
                    height: 52,

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
                    'Delete Employee',
                  ),

                  subtitle: const Text(
                    'Remove permanently',
                  ),

                  onTap: () async {

                    Navigator.pop(context);

                    await _deleteEmployee(
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
  /// STATUS CHIP
  ////////////////////////////////////////////////////////////

  Widget _statusChip(
    String status,
  ) {

    final isActive =
        status == 'active';

    return Container(

      padding:
          const EdgeInsets.symmetric(

        horizontal: 12,

        vertical: 8,
      ),

      decoration: BoxDecoration(

        color: isActive
            ? const Color(0xFF10B981)
                .withOpacity(0.12)
            : Colors.orange
                .withOpacity(0.12),

        borderRadius:
            BorderRadius.circular(24),
      ),

      child: Text(

        status.toUpperCase(),

        style:
            TextStyle(

          color: isActive
              ? const Color(0xFF10B981)
              : Colors.orange,

          fontWeight:
              FontWeight.bold,

          fontSize: 11,

          letterSpacing: 0.7,
        ),
      ),
    );
  }

  ////////////////////////////////////////////////////////////
  /// EMPLOYEE CARD
  ////////////////////////////////////////////////////////////

  Widget _employeeCard({

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

    final profession =
        (data['profession'] ??
                'Unknown')
            .toString();

    final emoji =
        (data['professionEmoji'] ??
                '🛠️')
            .toString();

final totalEarnings =

    ((data['totalEarnings'] ?? 0)
        as num)
            .toDouble();

    final status =
        (data['accountStatus'] ??
                'active')
            .toString();

    final gradients = [

      [
        const Color(0xFF10B981),
        const Color(0xFF047857),
      ],

      [
        const Color(0xFF2563EB),
        const Color(0xFF1D4ED8),
      ],

      [
        const Color(0xFF8B5CF6),
        const Color(0xFF6D28D9),
      ],

      [
        const Color(0xFFF59E0B),
        const Color(0xFFD97706),
      ],
    ];

    final colors =
        gradients[index %
            gradients.length];

    return GestureDetector(

      onTap: () {

        _showActions(

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

            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [

              //////////////////////////////////////////////////
              /// AVATAR
              //////////////////////////////////////////////////

              Container(

                width: 78,
                height: 78,

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

                    emoji,

                    style:
                        const TextStyle(
                      fontSize: 36,
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

                    //////////////////////////////////////////////////
                    /// NAME
                    //////////////////////////////////////////////////

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

                    //////////////////////////////////////////////////
                    /// EMAIL
                    //////////////////////////////////////////////////

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

                    const SizedBox(height: 10),

                    //////////////////////////////////////////////////
                    /// PROFESSION
                    //////////////////////////////////////////////////

                    Row(

                      children: [

                        Icon(

                          Icons.work_rounded,

                          size: 18,

                          color:
                              Colors.grey[600],
                        ),

                        const SizedBox(width: 8),

                        Expanded(

                          child: Text(

                            profession,

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

                    const SizedBox(height: 14),

                    //////////////////////////////////////////////////
                    /// BOTTOM CHIPS
                    //////////////////////////////////////////////////

                    Wrap(

                      spacing: 10,

                      runSpacing: 10,

                      children: [

                        Container(

                          padding:
                              const EdgeInsets.symmetric(

                            horizontal: 14,

                            vertical: 8,
                          ),

                          decoration: BoxDecoration(

                            color:
                                colors.first
                                    .withOpacity(
                              0.12,
                            ),

                            borderRadius:
                                BorderRadius.circular(
                              24,
                            ),
                          ),

                          child: Text(

                            '${totalEarnings.toStringAsFixed(0)} OMR',

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

                        _statusChip(
                          status,
                        ),
                      ],
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

      //////////////////////////////////////////////////////////
      /// BODY
      //////////////////////////////////////////////////////////

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
                const Color(0xFF10B981),

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

                      Color(0xFF10B981),

                      Color(0xFF047857),
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

                            Icons.engineering_rounded,

                            color: Colors.white,

                            size: 50,
                          ),
                        ),

                        const SizedBox(height: 20),

                        const Text(

                          'Employees',

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

                          'Manage all service providers.',

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
          /// CONTENT
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
                          'Search employees...',

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
                            'employee',
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

                      final profession =
                          (data['profession'] ?? '')
                              .toString()
                              .toLowerCase();

                      return search.isEmpty ||
                          name.contains(search) ||
                          email.contains(search) ||
                          profession.contains(search);

                    }).toList();

                    if (filtered.isEmpty) {

                      return const Padding(

                        padding:
                            EdgeInsets.all(40),

                        child: Text(
                          'No employees found',
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

                        return _employeeCard(

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