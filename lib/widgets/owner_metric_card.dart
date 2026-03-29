import 'package:flutter/material.dart';

class OwnerMetricCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Stream<String>? stream;
  final Stream<String>? subtitleStream;
  final VoidCallback? onTap;
  final bool isHero;

  const OwnerMetricCard({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    this.stream,
    this.subtitleStream,
    this.onTap,
    this.isHero = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isHero ? color : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(isHero ? 0.3 : 0.1),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
        border: !isHero ? Border.all(color: Colors.grey[200]!) : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: isHero ? 16.0 : 8.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: isHero 
                  ? MainAxisAlignment.spaceBetween 
                  : MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: (isHero ? Colors.white : color).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        icon,
                        color: isHero ? Colors.white : color,
                        size: isHero ? 24 : 18,
                      ),
                    ),
                    if (onTap != null)
                      Icon(
                        Icons.chevron_right,
                        color: (isHero ? Colors.white : Colors.grey).withOpacity(0.5),
                        size: 16,
                      ),
                  ],
                ),
                SizedBox(height: isHero ? 0 : 4),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (stream != null) ...[
                      StreamBuilder<String>(
                        stream: stream,
                        builder: (context, snapshot) {
                          String data = snapshot.data ?? '0';
                          if (snapshot.hasError) data = 'Error';
                          return Text(
                            data,
                            style: TextStyle(
                              fontSize: isHero ? 22 : 18,
                              fontWeight: FontWeight.bold,
                              color: isHero ? Colors.white : Colors.black87,
                              letterSpacing: -0.5,
                              height: 1.1,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 1),
                    ],
                    if (subtitleStream != null) ...[
                      StreamBuilder<String>(
                        stream: subtitleStream,
                        builder: (context, snapshot) {
                          final text = snapshot.data ?? '';
                          if (text.isEmpty) return const SizedBox.shrink();
                          
                          Color textColor = Colors.grey[600]!;
                          if (text.contains('ค้างชำระ')) textColor = Colors.red[700]!;
                          else if (text.contains('ใกล้ครบกำหนด')) textColor = Colors.orange[800]!;

                          return Text(
                            text,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: isHero ? Colors.white.withOpacity(0.9) : textColor,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 1),
                    ],
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: isHero ? 13 : 11,
                        fontWeight: FontWeight.w600,
                        color: (isHero ? Colors.white : Colors.grey[600])!.withOpacity(0.8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
