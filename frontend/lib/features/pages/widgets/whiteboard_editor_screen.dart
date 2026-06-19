import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/workspace_page.dart';
import '../providers/pages_providers.dart';

enum _Tool { select, pen }

const List<int> _palette = <int>[
  0xFFFDE68A, // amber
  0xFFA7F3D0, // green
  0xFFBFDBFE, // blue
  0xFFFBCFE8, // pink
  0xFFE9D5FF, // violet
  0xFF111827, // ink
];

/// A freeform whiteboard: draggable sticky notes plus freehand pen strokes,
/// persisted as JSON in the page body. Pushed via [Navigator] (AGENTS.md §9).
class WhiteboardEditorScreen extends ConsumerStatefulWidget {
  const WhiteboardEditorScreen({super.key, required this.pageId});

  final int pageId;

  @override
  ConsumerState<WhiteboardEditorScreen> createState() =>
      _WhiteboardEditorScreenState();
}

class _WhiteboardEditorScreenState
    extends ConsumerState<WhiteboardEditorScreen> {
  final TextEditingController _title = TextEditingController();
  final List<_Note> _notes = <_Note>[];
  final List<_Stroke> _strokes = <_Stroke>[];
  _Stroke? _current;
  _Tool _tool = _Tool.select;
  int _color = _palette.first;
  int _penColor = 0xFF111827;
  WorkspacePage? _page;
  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  int _noteSeq = 0;

  bool get _canEdit => _page?.canEdit ?? true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final WorkspacePage page = await ref
          .read(pagesRepositoryProvider)
          .get(widget.pageId);
      _title.text = page.title;
      _parse(page.body);
      if (mounted) {
        setState(() {
          _page = page;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _parse(String body) {
    if (body.trim().isEmpty) {
      return;
    }
    try {
      final Map<String, dynamic> data =
          jsonDecode(body) as Map<String, dynamic>;
      for (final dynamic n in data['notes'] as List<dynamic>? ?? <dynamic>[]) {
        final Map<String, dynamic> m = n as Map<String, dynamic>;
        _notes.add(
          _Note(
            id: m['id'] as String? ?? 'n${_noteSeq++}',
            x: (m['x'] as num?)?.toDouble() ?? 40,
            y: (m['y'] as num?)?.toDouble() ?? 40,
            text: m['text'] as String? ?? '',
            color: m['color'] as int? ?? _palette.first,
          ),
        );
      }
      for (final dynamic s
          in data['strokes'] as List<dynamic>? ?? <dynamic>[]) {
        final Map<String, dynamic> m = s as Map<String, dynamic>;
        final List<Offset> pts = <Offset>[
          for (final dynamic p in m['points'] as List<dynamic>? ?? <dynamic>[])
            Offset(
              ((p as List<dynamic>)[0] as num).toDouble(),
              (p[1] as num).toDouble(),
            ),
        ];
        _strokes.add(
          _Stroke(
            color: m['color'] as int? ?? 0xFF111827,
            width: (m['width'] as num?)?.toDouble() ?? 3,
            points: pts,
          ),
        );
      }
    } catch (_) {
      // Ignore malformed boards; start fresh.
    }
  }

  String _serialize() => jsonEncode(<String, dynamic>{
    'notes': <Map<String, dynamic>>[
      for (final _Note n in _notes)
        <String, dynamic>{
          'id': n.id,
          'x': n.x,
          'y': n.y,
          'text': n.text,
          'color': n.color,
        },
    ],
    'strokes': <Map<String, dynamic>>[
      for (final _Stroke s in _strokes)
        <String, dynamic>{
          'color': s.color,
          'width': s.width,
          'points': <List<double>>[
            for (final Offset p in s.points) <double>[p.dx, p.dy],
          ],
        },
    ],
  });

  Future<bool> _save({bool silent = false}) async {
    if (_page == null || !_canEdit) {
      return true;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(pagesRepositoryProvider)
          .update(widget.pageId, title: _title.text.trim(), body: _serialize());
      if (mounted) {
        setState(() {
          _saving = false;
          _dirty = false;
        });
        if (!silent) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Saved')));
        }
      }
      return true;
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
      return false;
    }
  }

  void _addNote() {
    setState(() {
      _notes.add(
        _Note(
          id: 'n${_noteSeq++}',
          x: 60 + (_notes.length % 5) * 24,
          y: 60 + (_notes.length % 5) * 24,
          text: '',
          color: _color,
        ),
      );
      _dirty = true;
    });
  }

  Future<void> _editNote(_Note note) async {
    final TextEditingController c = TextEditingController(text: note.text);
    final String? text = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Note'),
        content: TextField(
          controller: c,
          autofocus: true,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(hintText: 'Write something…'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, c.text),
            child: const Text('Done'),
          ),
        ],
      ),
    );
    c.dispose();
    if (text != null) {
      setState(() {
        note.text = text;
        _dirty = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, _) async {
        if (didPop) {
          return;
        }
        final NavigatorState nav = Navigator.of(context);
        if (_dirty && _canEdit) {
          await _save(silent: true);
        }
        if (mounted) {
          nav.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: _loading
              ? const Text('Whiteboard')
              : TextField(
                  controller: _title,
                  readOnly: !_canEdit,
                  onChanged: (_) => setState(() => _dirty = true),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Untitled board',
                  ),
                ),
          actions: <Widget>[
            if (_saving)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (_canEdit)
              TextButton.icon(
                onPressed: _dirty ? () => _save() : null,
                icon: const Icon(Icons.save_outlined, size: 18),
                label: const Text('Save'),
              ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: <Widget>[
                  if (_canEdit) _toolbar(),
                  Expanded(child: _canvas()),
                ],
              ),
      ),
    );
  }

  Widget _toolbar() {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: <Widget>[
            SegmentedButton<_Tool>(
              segments: const <ButtonSegment<_Tool>>[
                ButtonSegment<_Tool>(
                  value: _Tool.select,
                  icon: Icon(Icons.back_hand_outlined, size: 18),
                  label: Text('Move'),
                ),
                ButtonSegment<_Tool>(
                  value: _Tool.pen,
                  icon: Icon(Icons.edit_outlined, size: 18),
                  label: Text('Pen'),
                ),
              ],
              selected: <_Tool>{_tool},
              showSelectedIcon: false,
              onSelectionChanged: (Set<_Tool> s) =>
                  setState(() => _tool = s.first),
            ),
            const SizedBox(width: 16),
            for (final int c in _palette)
              GestureDetector(
                onTap: () => setState(() {
                  if (_tool == _Tool.pen) {
                    _penColor = c;
                  } else {
                    _color = c;
                  }
                }),
                child: Container(
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: Color(c),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: (_tool == _Tool.pen ? _penColor : _color) == c
                          ? scheme.primary
                          : scheme.outlineVariant,
                      width: (_tool == _Tool.pen ? _penColor : _color) == c
                          ? 3
                          : 1,
                    ),
                  ),
                ),
              ),
            const Spacer(),
            TextButton.icon(
              onPressed: _addNote,
              icon: const Icon(Icons.sticky_note_2_outlined, size: 18),
              label: const Text('Note'),
            ),
            IconButton(
              tooltip: 'Clear drawing',
              icon: const Icon(Icons.cleaning_services_outlined),
              onPressed: _strokes.isEmpty
                  ? null
                  : () => setState(() {
                      _strokes.clear();
                      _dirty = true;
                    }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _canvas() {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.surface,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: CustomPaint(
              painter: _StrokePainter(strokes: _strokes, current: _current),
            ),
          ),
          for (final _Note n in _notes)
            Positioned(
              left: n.x,
              top: n.y,
              child: _NoteCard(
                note: n,
                editable: _canEdit && _tool == _Tool.select,
                onMove: (Offset d) => setState(() {
                  n.x += d.dx;
                  n.y += d.dy;
                  _dirty = true;
                }),
                onTap: () => _editNote(n),
                onDelete: () => setState(() {
                  _notes.remove(n);
                  _dirty = true;
                }),
              ),
            ),
          if (_canEdit && _tool == _Tool.pen)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (DragStartDetails d) => setState(() {
                  _current = _Stroke(
                    color: _penColor,
                    width: 3,
                    points: <Offset>[d.localPosition],
                  );
                }),
                onPanUpdate: (DragUpdateDetails d) =>
                    setState(() => _current?.points.add(d.localPosition)),
                onPanEnd: (_) => setState(() {
                  if (_current != null) {
                    _strokes.add(_current!);
                    _current = null;
                    _dirty = true;
                  }
                }),
              ),
            ),
        ],
      ),
    );
  }
}

class _Note {
  _Note({
    required this.id,
    required this.x,
    required this.y,
    required this.text,
    required this.color,
  });

  final String id;
  double x;
  double y;
  String text;
  int color;
}

class _Stroke {
  _Stroke({required this.color, required this.width, required this.points});

  final int color;
  final double width;
  final List<Offset> points;
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.note,
    required this.editable,
    required this.onMove,
    required this.onTap,
    required this.onDelete,
  });

  final _Note note;
  final bool editable;
  final ValueChanged<Offset> onMove;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: editable ? onTap : null,
      onPanUpdate: editable ? (DragUpdateDetails d) => onMove(d.delta) : null,
      child: Container(
        width: 168,
        constraints: const BoxConstraints(minHeight: 110),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Color(note.color),
          borderRadius: BorderRadius.circular(6),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Colors.black26,
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (editable)
              Align(
                alignment: Alignment.topRight,
                child: GestureDetector(
                  onTap: onDelete,
                  child: const Icon(
                    Icons.close,
                    size: 16,
                    color: Colors.black54,
                  ),
                ),
              ),
            Text(
              note.text.isEmpty ? 'Tap to edit' : note.text,
              style: TextStyle(
                color: note.text.isEmpty ? Colors.black45 : Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StrokePainter extends CustomPainter {
  _StrokePainter({required this.strokes, required this.current});

  final List<_Stroke> strokes;
  final _Stroke? current;

  @override
  void paint(Canvas canvas, Size size) {
    for (final _Stroke s in <_Stroke>[...strokes, ?current]) {
      if (s.points.length < 2) {
        if (s.points.length == 1) {
          canvas.drawCircle(
            s.points.first,
            s.width / 2,
            Paint()..color = Color(s.color),
          );
        }
        continue;
      }
      final Paint paint = Paint()
        ..color = Color(s.color)
        ..strokeWidth = s.width
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      final Path path = Path()..moveTo(s.points.first.dx, s.points.first.dy);
      for (final Offset p in s.points.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_StrokePainter oldDelegate) => true;
}
