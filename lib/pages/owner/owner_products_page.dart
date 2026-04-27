import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class OwnerProductsPage extends StatelessWidget {
  const OwnerProductsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Store Products')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('products')
            .orderBy('name')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No products found.'));
          }

          final formatter = NumberFormat('#,##0.00');

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final name = data['name'] ?? 'Unknown Product';
              final weight = (data['weight'] as num?)?.toDouble() ?? 0.0;
              final laborFee = (data['laborFee'] as num?)?.toDouble() ?? 0.0;
              final stock = data['stock'] ?? 0;
              final isOutOfStock = stock <= 0;

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('transactions')
                    .where('type', isEqualTo: 'restock')
                    .where('productId', isEqualTo: doc.id)
                    .snapshots(),
                builder: (context, costSnap) {
                  double totalInvestment = 0.0;
                  if (costSnap.hasData) {
                    for (var costDoc in costSnap.data!.docs) {
                      totalInvestment += (costDoc.data() as Map<String, dynamic>)['amount']?.toDouble() ?? 0.0;
                    }
                  }

                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.inventory_2)),
                      title: Text(name),
                      subtitle: Text(
                        'Weight: $weight Baht\nLabor Fee: ฿${formatter.format(laborFee)}\nTotal Investment: ฿${formatter.format(totalInvestment)}',
                      ),
                      isThreeLine: true,
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isOutOfStock ? Colors.red[50] : Colors.green[50],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isOutOfStock ? '0 Stock' : '$stock Left',
                          style: TextStyle(
                            color: isOutOfStock
                                ? Colors.red[700]
                                : Colors.green[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                }
              );
            },
          );
        },
      ),
    );
  }
}
