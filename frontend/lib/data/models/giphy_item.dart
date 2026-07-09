/// A single GIF or sticker from Giphy. [preview] is a small looping URL for the
/// grid; [url] is the one to send. Manual JSON per AGENTS.md §9.
class GiphyItem {
  final String id;
  final String url;
  final String preview;

  const GiphyItem({required this.id, this.url = '', this.preview = ''});

  factory GiphyItem.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> images =
        (json['images'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    String pick(String key) {
      final Map<String, dynamic>? img = images[key] as Map<String, dynamic>?;
      return (img?['url'] as String?) ?? '';
    }

    final String full = pick('fixed_height').isNotEmpty
        ? pick('fixed_height')
        : pick('original');
    final String small = pick('fixed_height_small').isNotEmpty
        ? pick('fixed_height_small')
        : full;
    return GiphyItem(
      id: json['id'] as String? ?? '',
      url: full,
      preview: small,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'url': url,
    'preview': preview,
  };

  @override
  String toString() => 'GiphyItem($id)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GiphyItem &&
          other.id == id &&
          other.url == url &&
          other.preview == preview;

  @override
  int get hashCode => Object.hash(id, url, preview);
}
