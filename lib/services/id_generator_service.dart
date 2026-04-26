import 'package:cloud_firestore/cloud_firestore.dart';

class IdGeneratorService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Prefix mappings for best practice naming
  static const Map<String, String> _prefixMap = {
    'receipts': 'RCT',
    'invoices': 'INV',
    'quotations': 'QTN',
    'users': 'CST',
    'products': 'PRD',
    'suppliers': 'SUP',
    'transactions': 'TXN',
    'promotions': 'PRM',
    'appointments': 'APT',
    'assets': 'AST',
    'notifications': 'NTF',
    'news': 'NEW',
    'deposits': 'TOP',
    'withdrawals': 'WDL',
  };


  /// Generates a unique ID using a prefix and Firestore's auto-generated document ID.
  /// Format: PREFIX-AutoID (e.g., CST-vH9kL2m3n...)
  Future<String> generateId(String collectionName, {String? prefixOverride}) async {
    final prefix = prefixOverride ?? 
                   _prefixMap[collectionName] ?? 
                   collectionName.substring(0, 3).toUpperCase();

    final autoId = _firestore.collection(collectionName).doc().id;
    return '$prefix-$autoId';
  }
}
