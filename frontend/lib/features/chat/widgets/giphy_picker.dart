import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_config.dart';
import '../../../data/models/giphy_item.dart';
import '../providers/chat_providers.dart';

/// Opens the GIF / sticker picker. Returns the selected media URL to send, or
/// null if dismissed.
Future<String?> showGiphyPicker(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext _) => const _GiphyPicker(),
  );
}

class _GiphyPicker extends ConsumerStatefulWidget {
  const _GiphyPicker();

  @override
  ConsumerState<_GiphyPicker> createState() => _GiphyPickerState();
}

class _GiphyPickerState extends ConsumerState<_GiphyPicker> {
  final TextEditingController _search = TextEditingController();
  Timer? _debounce;
  bool _stickers = false;
  bool _loading = false;
  List<GiphyItem> _items = <GiphyItem>[];

  @override
  void initState() {
    super.initState();
    if (AppConfig.giphyEnabled) {
      _load();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _load);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final List<GiphyItem> items = await ref
        .read(giphyRepositoryProvider)
        .fetch(stickers: _stickers, query: _search.text);
    if (mounted) {
      setState(() {
        _items = items;
        _loading = false;
      });
    }
  }

  void _switchKind(bool stickers) {
    if (_stickers == stickers) {
      return;
    }
    setState(() => _stickers = stickers);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final double height = MediaQuery.sizeOf(context).height * 0.62;
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: !AppConfig.giphyEnabled
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'GIFs & stickers are disabled.\n\nAdd a free Giphy API key with\n'
                    'flutter run --dart-define=GIPHY_API_KEY=your_key',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              )
            : Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: _search,
                          autofocus: true,
                          onChanged: _onSearch,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: 'Search Giphy…',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SegmentedButton<bool>(
                        segments: const <ButtonSegment<bool>>[
                          ButtonSegment<bool>(
                              value: false, label: Text('GIFs')),
                          ButtonSegment<bool>(
                              value: true, label: Text('Stickers')),
                        ],
                        selected: <bool>{_stickers},
                        showSelectedIcon: false,
                        onSelectionChanged: (Set<bool> s) =>
                            _switchKind(s.first),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _items.isEmpty
                            ? Center(
                                child: Text('No results',
                                    style: TextStyle(
                                        color: scheme.onSurfaceVariant)))
                            : GridView.builder(
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  mainAxisSpacing: 6,
                                  crossAxisSpacing: 6,
                                ),
                                itemCount: _items.length,
                                itemBuilder: (BuildContext context, int i) {
                                  final GiphyItem g = _items[i];
                                  return GestureDetector(
                                    onTap: () =>
                                        Navigator.of(context).pop(g.url),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        color: scheme.surfaceContainerHighest,
                                        child: Image.network(
                                          g.preview,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) =>
                                              const Icon(Icons.broken_image),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text('Powered by GIPHY',
                        style: TextStyle(
                            fontSize: 10, color: scheme.onSurfaceVariant)),
                  ),
                ],
              ),
      ),
    );
  }
}
