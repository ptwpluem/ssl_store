import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/news_item.dart';

class NewsCard extends StatelessWidget {
  final NewsItem newsItem;
  final VoidCallback? onTap;

  const NewsCard({super.key, required this.newsItem, this.onTap});

  Future<void> _launchUrl() async {
    if (newsItem.url != null) {
      final Uri url = Uri.parse(newsItem.url!);
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch ${newsItem.url}');
      }
    } else {
      onTap?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shadowColor: const Color(0xFF800000).withOpacity(0.2),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: _launchUrl,
        borderRadius: BorderRadius.circular(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              child: SizedBox(
                width: 120,
                height: 120,
                child: newsItem.imageUrl.startsWith('assets/')
                    ? Image.asset(
                        newsItem.imageUrl,
                        fit: BoxFit.cover,
                      )
                    : Image.network(
                        newsItem.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.article_outlined, color: Colors.grey, size: 40),
                          );
                        },
                      ),
              ),
            ),
            
            // Text Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      newsItem.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF800000), // Maroon Title
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      newsItem.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey[800],
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${newsItem.date.day}/${newsItem.date.month}/${newsItem.date.year}',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Icon(
                          Icons.open_in_new,
                          size: 14,
                          color: Color(0xFF800000),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
