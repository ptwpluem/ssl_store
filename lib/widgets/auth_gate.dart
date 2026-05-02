import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../pages/main_screen.dart';
import '../pages/owner/owner_dashboard_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final user = authSnapshot.data;
        if (user == null) {
          return const MainScreen(); // Unauthenticated sees user view
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where('uid', isEqualTo: user.uid)
              .snapshots(),
          builder: (context, querySnapshot) {
            if (querySnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            // If no doc found by UID, we need to try finding by email as well.
            // Since we can't easily chain async queries in a StreamBuilder's stream property,
            // we'll use FutureBuilder or a nested StreamBuilder if UID is missing,
            // but here we can just check the data we have.
            
            List<DocumentSnapshot> docs = querySnapshot.data?.docs ?? [];
            
            if (docs.isEmpty && user.email != null) {
              // Fallback to searching by email if UID query yields nothing
              return FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .where('email', isEqualTo: user.email)
                    .limit(1)
                    .get(),
                builder: (context, emailSnapshot) {
                   if (emailSnapshot.connectionState == ConnectionState.waiting) {
                     return const Scaffold(body: Center(child: CircularProgressIndicator()));
                   }
                   
                   final emailDocs = emailSnapshot.data?.docs ?? [];
                   if (emailDocs.isEmpty) {
                     return const MainScreen();
                   }
                   
                   return _buildPlatformByRole(emailDocs.first);
                },
              );
            }

            if (docs.isEmpty) {
              return const MainScreen();
            }

            // Prefer 'owner' role if multiple documents exist (unlikely but safe)
            // Using a simple loop to avoid type inference issues with firstWhere's orElse
            DocumentSnapshot userDoc = docs.first;
            for (final doc in docs) {
              final data = doc.data() as Map<String, dynamic>?;
              if (data?['role'] == 'owner') {
                userDoc = doc;
                break;
              }
            }

            return _buildPlatformByRole(userDoc);
          },
        );
      },
    );
  }

  Widget _buildPlatformByRole(DocumentSnapshot userSnapshot) {
    final data = userSnapshot.data() as Map<String, dynamic>?;
    final role = data?['role'] ?? 'user';
    final email = data?['email'] ?? 'unknown';

    if (role == 'owner') {
      return const OwnerDashboardPage();
    }

    return const MainScreen();
  }
}
