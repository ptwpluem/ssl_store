import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class StoreInfoCard extends StatelessWidget {
  const StoreInfoCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Interactive Map Image
          GestureDetector(
            onTap: () async {
              final Uri url = Uri.parse(
                'https://maps.app.goo.gl/zo5SvJGdGuUG2Ui27',
              );
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: Image.asset(
                'assets/images/store_map.png',
                height: 150,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 150,
                  color: Colors.grey[200],
                  child: const Center(
                    child: Icon(Icons.map, size: 50, color: Colors.grey),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ห้างทองสุ้นเซ่งหลี',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF800000),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: const [
                    Icon(Icons.location_on, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '999 ถนนจันดี-สวนขัน, อำเภอฉวาง, จังหวัดนครศรีธรรมราช, 80250',
                        style: TextStyle(color: Colors.black87),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: const [
                    Icon(Icons.access_time, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'จันทร์ - เสาร์: 09:00 - 17:00 (ปิดทุกวันอาทิตย์)',
                      style: TextStyle(color: Colors.black87),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final Uri url = Uri.parse('tel:0968688998');
                          try {
                            await launchUrl(url);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Could not launch dialer'),
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.call, color: Color(0xFF800000)),
                        label: const Text(
                          'โทร',
                          style: TextStyle(color: Color(0xFF800000)),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF800000)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final Uri url = Uri.parse(
                            'https://maps.app.goo.gl/zo5SvJGdGuUG2Ui27',
                          );
                          try {
                            await launchUrl(
                              url,
                              mode: LaunchMode.externalApplication,
                            );
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Could not launch maps'),
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.map, color: Colors.black),
                        label: const Text(
                          'แผนที่ร้าน',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFD700),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
