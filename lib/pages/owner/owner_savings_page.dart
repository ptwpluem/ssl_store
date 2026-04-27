import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class OwnerSavingsPage extends StatelessWidget {
  const OwnerSavingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gold Savings Details')),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('market')
            .doc('gold_rate')
            .get(),
        builder: (context, rateSnapshot) {
          if (rateSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final sellPrice =
              (rateSnapshot.data?.data() as Map<String, dynamic>?)?['sellPrice']
                  ?.toDouble() ??
              40000.0;
          final formatter = NumberFormat('#,##0.00');

          return StreamBuilder<List<DocumentSnapshot>>(
            stream: FirebaseFirestore.instance
                .collectionGroup('savings')
                .snapshots()
                .map(
                  (snap) =>
                      snap.docs.where((doc) => doc.id == 'account').toList(),
                ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No gold savings found.'));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.data![index];
                  final data = doc.data() as Map<String, dynamic>;
                  final totalWeight =
                      (data['totalWeightSaved'] as num?)?.toDouble() ?? 0.0;
                  final totalInvested =
                      (data['totalAmountInvested'] as num?)?.toDouble() ?? 0.0;
                  final currentLiability = totalWeight * sellPrice;

                  // The document path for collectionGroup 'savings' where docId='account' is users/UID/savings/account.
                  // We can extract UID from reference path.
                  final uid = doc.reference.parent.parent?.id ?? 'Unknown UID';

                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.savings)),
                      title: Text(
                        'User ID: $uid\n${totalWeight.toStringAsFixed(4)} Baht Saved',
                      ),
                      isThreeLine: true,
                      subtitle: Text(
                        'Invested: ฿${formatter.format(totalInvested)}\nCurrent Value: ฿${formatter.format(currentLiability)}',
                      ),
                      trailing: Text(
                        '฿${formatter.format(currentLiability)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.teal,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
