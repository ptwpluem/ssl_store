// lib/widgets/owner_metric_card.dart
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

  // Slightly darken a color for gradient end-stop
  Color _darken(Color c, [double amount = 0.18]) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: isHero
            ? LinearGradient(
                colors: [color, _darken(color)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isHero ? null : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isHero
                ? color.withValues(alpha: 0.35)
                : Colors.black.withValues(alpha: 0.06),
            blurRadius: isHero ? 16 : 10,
            offset: Offset(0, isHero ? 8 : 4),
          ),
        ],
        border: isHero
            ? null
            : Border.all(color: const Color(0xFFF0F1F3), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: isHero
              ? Colors.white.withValues(alpha: 0.10)
              : color.withValues(alpha: 0.05),
          highlightColor: isHero
              ? Colors.white.withValues(alpha: 0.05)
              : color.withValues(alpha: 0.03),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 14.0,
              vertical: isHero ? 14.0 : 10.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: isHero
                  ? MainAxisAlignment.spaceBetween
                  : MainAxisAlignment.center,
              children: [
                // ── Top row: icon + optional arrow ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: isHero
                            ? Colors.white.withValues(alpha: 0.20)
                            : color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        icon,
                        color: isHero ? Colors.white : color,
                        size: isHero ? 22 : 17,
                      ),
                    ),
                    if (onTap != null)
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: isHero
                              ? Colors.white.withValues(alpha: 0.15)
                              : const Color(0xFFF5F7FA),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 10,
                          color: isHero
                              ? Colors.white.withValues(alpha: 0.80)
                              : Colors.grey[400],
                        ),
                      ),
                  ],
                ),

                SizedBox(height: isHero ? 0 : 6),

                // ── Bottom: value + subtitle + label ──
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main value stream
                    if (stream != null) ...[
                      StreamBuilder<String>(
                        stream: stream,
                        builder: (context, snapshot) {
                          final isLoading =
                              snapshot.connectionState ==
                              ConnectionState.waiting;

                          if (isLoading) {
                            // Skeleton placeholder while loading
                            return Container(
                              height: isHero ? 26 : 22,
                              width: 64,
                              decoration: BoxDecoration(
                                color: isHero
                                    ? Colors.white.withValues(alpha: 0.25)
                                    : Colors.grey[200],
                                borderRadius: BorderRadius.circular(6),
                              ),
                            );
                          }

                          final value = snapshot.hasError
                              ? 'Error'
                              : (snapshot.data ?? '—');

                          return Text(
                            value,
                            style: TextStyle(
                              fontSize: isHero ? 22 : 18,
                              fontWeight: FontWeight.bold,
                              color: isHero
                                  ? Colors.white
                                  : const Color(0xFF1A1A2E),
                              letterSpacing: -0.5,
                              height: 1.1,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 2),
                    ],

                    // Subtitle stream (e.g. overdue/near-due alerts)
                    if (subtitleStream != null) ...[
                      StreamBuilder<String>(
                        stream: subtitleStream,
                        builder: (context, snapshot) {
                          final text = snapshot.data ?? '';
                          if (text.isEmpty) return const SizedBox.shrink();

                          Color textColor = Colors.grey[600]!;
                          if (text.contains('ค้างชำระ')) {
                            textColor = Colors.red[700]!;
                          } else if (text.contains('ใกล้ครบกำหนด')) {
                            textColor = Colors.orange[800]!;
                          }

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              text,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: isHero
                                    ? Colors.white.withValues(alpha: 0.85)
                                    : textColor,
                              ),
                            ),
                          );
                        },
                      ),
                    ],

                    // Card title / label
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: isHero ? 12 : 11,
                        fontWeight: FontWeight.w500,
                        color: isHero
                            ? Colors.white.withValues(alpha: 0.72)
                            : Colors.grey[500],
                        letterSpacing: 0.1,
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
