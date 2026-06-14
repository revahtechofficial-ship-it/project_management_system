/// Open Graph metadata for a URL, from `GET /api/v1/link-preview`.
/// Manual JSON serialization per AGENTS.md §9.
class LinkPreview {
  final String url;
  final String title;
  final String description;
  final String image;
  final String site;

  const LinkPreview({
    this.url = '',
    this.title = '',
    this.description = '',
    this.image = '',
    this.site = '',
  });

  /// Whether there is anything worth showing.
  bool get hasContent => title.isNotEmpty || image.isNotEmpty;

  factory LinkPreview.fromJson(Map<String, dynamic> json) => LinkPreview(
        url: json['url'] as String? ?? '',
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        image: json['image'] as String? ?? '',
        site: json['site'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'url': url,
        'title': title,
        'description': description,
        'image': image,
        'site': site,
      };

  @override
  String toString() => 'LinkPreview(url: $url, title: $title)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LinkPreview &&
          other.url == url &&
          other.title == title &&
          other.description == description &&
          other.image == image &&
          other.site == site;

  @override
  int get hashCode => Object.hash(url, title, description, image, site);
}
