class NewsItem {
  final String id;
  final String title;
  final String summary;
  final String imageUrl;
  final DateTime date;
  final String content;
  final String? url;

  NewsItem({
    required this.id,
    required this.title,
    required this.summary,
    required this.imageUrl,
    required this.date,
    required this.content,
    this.url,
  });
}
