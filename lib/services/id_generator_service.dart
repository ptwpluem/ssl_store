import 'package:cloud_firestore/cloud_firestore.dart';

class IdGeneratorService {
  /// [firestore] is injectable for testing; defaults to the live instance.
  IdGeneratorService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

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
    'pawn_loans': 'PLN',
    'events': 'EVT',
    'gold_rates': 'GRT',
    'inventory_log': 'IVL', // ก่อนหน้านี้มี INV
    'wallets': 'WAL',
    'wallet_transactions': 'WTX',
    'savings_transactions': 'STX',
  };

  /// Generates a unique ID using a prefix and Firestore's auto-generated document ID.
  /// Format: PREFIX-AutoID (e.g., CST-vH9kL2m3n...)
  Future<String> generateId(
    String collectionName, {
    String? prefixOverride,
  }) async {
    final prefix =
        prefixOverride ??
        _prefixMap[collectionName] ??
        collectionName.substring(0, 3).toUpperCase();

    final autoId = _firestore.collection(collectionName).doc().id;
    return '$prefix-$autoId'; // Prefix ช่วยให้แยกประเภท Transaction ได้ทันที
  }
}
