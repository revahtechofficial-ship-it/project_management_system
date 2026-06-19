import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/workspace_page.dart';
import '../../tasks/providers/tasks_providers.dart';
import '../providers/pages_providers.dart';

enum _Tool { move, pen, connect }

const List<int> _palette = <int>[
  0xFFFDE68A, // amber
  0xFFA7F3D0, // green
  0xFFBFDBFE, // blue
  0xFFFBCFE8, // pink
  0xFFE9D5FF, // violet
  0xFF111827, // ink
];

/// A freeform whiteboard for brainstorming: sticky notes, flowchart shapes
/// (rectangle / decision / terminator), connectors and freehand pen — plus
/// turning any element into a task. Persisted as JSON in the page body.
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
  final List<_Element> _elements = <_Element>[];
  final List<_Stroke> _strokes = <_Stroke>[];
  final List<_Connector> _connectors = <_Connector>[];
  _Stroke? _current;
  _Tool _tool = _Tool.move;
  int _color = _palette.first;
  int _penColor = 0xFF111827;
  String? _connectFrom;
  WorkspacePage? _page;
  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  int _seq = 0;

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
      // Back-compat: an older board stored sticky notes under "notes".
      for (final dynamic n in data['notes'] as List<dynamic>? ?? <dynamic>[]) {
        _elements.add(_Element.fromJson(n as Map<String, dynamic>, 'note'));
      }
      for (final dynamic e
          in data['elements'] as List<dynamic>? ?? <dynamic>[]) {
        _elements.add(_Element.fromJson(e as Map<String, dynamic>, 'note'));
      }
      for (final _Element e in _elements) {
        final int n = int.tryParse(e.id.replaceAll(RegExp(r'\D'), '')) ?? 0;
        if (n >= _seq) {
          _seq = n + 1;
        }
      }
      for (final dynamic c
          in data['connectors'] as List<dynamic>? ?? <dynamic>[]) {
        final Map<String, dynamic> m = c as Map<String, dynamic>;
        _connectors.add(
          _Connector(from: m['from'] as String, to: m['to'] as String),
        );
      }
      for (final dynamic s
          in data['strokes'] as List<dynamic>? ?? <dynamic>[]) {
        final Map<String, dynamic> m = s as Map<String, dynamic>;
        _strokes.add(
          _Stroke(
            color: m['color'] as int? ?? 0xFF111827,
            width: (m['width'] as num?)?.toDouble() ?? 3,
            points: <Offset>[
              for (final dynamic p
                  in m['points'] as List<dynamic>? ?? <dynamic>[])
                Offset(
                  ((p as List<dynamic>)[0] as num).toDouble(),
                  (p[1] as num).toDouble(),
                ),
            ],
          ),
        );
      }
    } catch (_) {
      // Ignore malformed boards; start fresh.
    }
  }

  String _serialize() => jsonEncode(<String, dynamic>{
    'elements': <Map<String, dynamic>>[
      for (final _Element e in _elements) e.toJson(),
    ],
    'connectors': <Map<String, dynamic>>[
      for (final _Connector c in _connectors)
        <String, dynamic>{'from': c.from, 'to': c.to},
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

  void _add(String type) {
    setState(() {
      _elements.add(
        _Element(
          id: 'n${_seq++}',
          type: type,
          x: 80 + (_elements.length % 6) * 26,
          y: 80 + (_elements.length % 6) * 26,
          text: '',
          color: _color,
        ),
      );
      _dirty = true;
    });
  }

  Future<void> _editText(_Element e) async {
    final TextEditingController c = TextEditingController(text: e.text);
    final String? text = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Text'),
        content: TextField(
          controller: c,
          autofocus: true,
          minLines: 2,
          maxLines: 5,
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
        e.text = text;
        _dirty = true;
      });
    }
  }

  Future<void> _createTask(_Element e) async {
    final String title = e.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add text first to make a task.')),
      );
      return;
    }
    try {
      await ref.read(tasksRepositoryProvider).create(title: title);
      ref.invalidate(tasksProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Task created: $title')));
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not create task: $err')));
      }
    }
  }

  void _elementActions(_Element e) {
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit text'),
              onTap: () {
                Navigator.pop(context);
                _editText(e);
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_task),
              title: const Text('Create task'),
              onTap: () {
                Navigator.pop(context);
                _createTask(e);
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: <Widget>[
                  for (final int c in _palette)
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
                          e.color = c;
                          _dirty = true;
                        });
                      },
                      child: Container(
                        width: 28,
                        height: 28,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: Color(c),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black26),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: Colors.redAccent,
              ),
              title: const Text('Delete'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _elements.remove(e);
                  _connectors.removeWhere(
                    (_Connector c) => c.from == e.id || c.to == e.id,
                  );
                  _dirty = true;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  void _tapElement(_Element e) {
    if (_tool == _Tool.connect) {
      setState(() {
        if (_connectFrom == null) {
          _connectFrom = e.id;
        } else if (_connectFrom != e.id) {
          _connectors.add(_Connector(from: _connectFrom!, to: e.id));
          _connectFrom = null;
          _dirty = true;
        } else {
          _connectFrom = null;
        }
      });
    } else {
      _elementActions(e);
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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: <Widget>[
              SegmentedButton<_Tool>(
                segments: const <ButtonSegment<_Tool>>[
                  ButtonSegment<_Tool>(
                    value: _Tool.move,
                    icon: Icon(Icons.back_hand_outlined, size: 18),
                    label: Text('Move'),
                  ),
                  ButtonSegment<_Tool>(
                    value: _Tool.pen,
                    icon: Icon(Icons.edit_outlined, size: 18),
                    label: Text('Pen'),
                  ),
                  ButtonSegment<_Tool>(
                    value: _Tool.connect,
                    icon: Icon(Icons.timeline, size: 18),
                    label: Text('Connect'),
                  ),
                ],
                selected: <_Tool>{_tool},
                showSelectedIcon: false,
                onSelectionChanged: (Set<_Tool> s) => setState(() {
                  _tool = s.first;
                  _connectFrom = null;
                }),
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
              const SizedBox(width: 16),
              _addButton(),
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
      ),
    );
  }

  Widget _addButton() => PopupMenuButton<String>(
    tooltip: 'Add element',
    onSelected: _add,
    itemBuilder: (BuildContext context) => const <PopupMenuEntry<String>>[
      PopupMenuItem<String>(
        value: 'note',
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.sticky_note_2_outlined),
          title: Text('Sticky note'),
        ),
      ),
      PopupMenuItem<String>(
        value: 'rect',
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.crop_square),
          title: Text('Process (box)'),
        ),
      ),
      PopupMenuItem<String>(
        value: 'diamond',
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.change_history),
          title: Text('Decision'),
        ),
      ),
      PopupMenuItem<String>(
        value: 'ellipse',
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.circle_outlined),
          title: Text('Start / end'),
        ),
      ),
    ],
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.add, size: 18),
          SizedBox(width: 6),
          Text('Add'),
          Icon(Icons.arrow_drop_down, size: 18),
        ],
      ),
    ),
  );

  Widget _canvas() {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Map<String, Offset> centers = <String, Offset>{
      for (final _Element e in _elements) e.id: e.center,
    };
    return Container(
      color: scheme.surface,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: CustomPaint(
              painter: _CanvasPainter(
                strokes: _strokes,
                current: _current,
                connectors: _connectors,
                centers: centers,
                connectorColor: scheme.onSurfaceVariant,
              ),
            ),
          ),
          for (final _Element e in _elements)
            Positioned(
              left: e.x,
              top: e.y,
              child: _ElementWidget(
                element: e,
                interactive: _canEdit,
                highlighted: _connectFrom == e.id,
                onMove: _tool == _Tool.move
                    ? (Offset d) => setState(() {
                        e.x += d.dx;
                        e.y += d.dy;
                        _dirty = true;
                      })
                    : null,
                onTap: _canEdit ? () => _tapElement(e) : null,
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

class _Element {
  _Element({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.text,
    required this.color,
  });

  final String id;
  final String type;
  double x;
  double y;
  String text;
  int color;

  Size get size => switch (type) {
    'note' => const Size(168, 100),
    'diamond' => const Size(120, 120),
    _ => const Size(150, 86),
  };

  Offset get center => Offset(x + size.width / 2, y + size.height / 2);

  factory _Element.fromJson(Map<String, dynamic> m, String fallbackType) =>
      _Element(
        id: m['id'] as String? ?? 'n0',
        type: m['type'] as String? ?? fallbackType,
        x: (m['x'] as num?)?.toDouble() ?? 40,
        y: (m['y'] as num?)?.toDouble() ?? 40,
        text: m['text'] as String? ?? '',
        color: m['color'] as int? ?? _palette.first,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'type': type,
    'x': x,
    'y': y,
    'text': text,
    'color': color,
  };
}

class _Connector {
  const _Connector({required this.from, required this.to});
  final String from;
  final String to;
}

class _Stroke {
  _Stroke({required this.color, required this.width, required this.points});
  final int color;
  final double width;
  final List<Offset> points;
}

class _ElementWidget extends StatelessWidget {
  const _ElementWidget({
    required this.element,
    required this.interactive,
    required this.highlighted,
    required this.onMove,
    required this.onTap,
  });

  final _Element element;
  final bool interactive;
  final bool highlighted;
  final ValueChanged<Offset>? onMove;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Size s = element.size;
    return GestureDetector(
      onTap: interactive ? onTap : null,
      onPanUpdate: onMove == null
          ? null
          : (DragUpdateDetails d) => onMove!(d.delta),
      child: Container(
        decoration: highlighted
            ? BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(8),
              )
            : null,
        child: SizedBox(
          width: s.width,
          height: s.height,
          child: _shape(context),
        ),
      ),
    );
  }

  Widget _shape(BuildContext context) {
    final Color c = Color(element.color);
    final Widget label = Center(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          element.text.isEmpty ? 'Tap to edit' : element.text,
          textAlign: TextAlign.center,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: element.text.isEmpty ? Colors.black45 : Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
    switch (element.type) {
      case 'note':
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(6),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Colors.black26,
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.topLeft,
          child: Text(
            element.text.isEmpty ? 'Tap to edit' : element.text,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: element.text.isEmpty ? Colors.black45 : Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      case 'ellipse':
        return Container(
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(60),
            border: Border.all(color: c, width: 2),
          ),
          child: label,
        );
      case 'diamond':
        return Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Transform.rotate(
              angle: math.pi / 4,
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.18),
                  border: Border.all(color: c, width: 2),
                ),
              ),
            ),
            label,
          ],
        );
      case 'rect':
      default:
        return Container(
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: c, width: 2),
          ),
          child: label,
        );
    }
  }
}

class _CanvasPainter extends CustomPainter {
  _CanvasPainter({
    required this.strokes,
    required this.current,
    required this.connectors,
    required this.centers,
    required this.connectorColor,
  });

  final List<_Stroke> strokes;
  final _Stroke? current;
  final List<_Connector> connectors;
  final Map<String, Offset> centers;
  final Color connectorColor;

  @override
  void paint(Canvas canvas, Size size) {
    // Connectors (behind strokes/elements).
    final Paint cp = Paint()
      ..color = connectorColor
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;
    for (final _Connector c in connectors) {
      final Offset? a = centers[c.from];
      final Offset? b = centers[c.to];
      if (a == null || b == null) {
        continue;
      }
      canvas.drawLine(a, b, cp);
      _arrowHead(canvas, a, b, connectorColor);
    }
    // Strokes.
    for (final _Stroke s in <_Stroke>[...strokes, ?current]) {
      if (s.points.isEmpty) {
        continue;
      }
      if (s.points.length == 1) {
        canvas.drawCircle(
          s.points.first,
          s.width / 2,
          Paint()..color = Color(s.color),
        );
        continue;
      }
      final Paint paint = Paint()
        ..color = Color(s.color)
        ..strokeWidth = s.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final Path path = Path()..moveTo(s.points.first.dx, s.points.first.dy);
      for (final Offset p in s.points.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  void _arrowHead(Canvas canvas, Offset a, Offset b, Color color) {
    final double angle = math.atan2(b.dy - a.dy, b.dx - a.dx);
    // Pull the tip back so it sits near the target element's edge.
    final Offset tip = b - Offset(math.cos(angle) * 40, math.sin(angle) * 40);
    const double len = 12;
    final Paint p = Paint()..color = color;
    final Path path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(
        tip.dx - len * math.cos(angle - 0.5),
        tip.dy - len * math.sin(angle - 0.5),
      )
      ..lineTo(
        tip.dx - len * math.cos(angle + 0.5),
        tip.dy - len * math.sin(angle + 0.5),
      )
      ..close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_CanvasPainter old) => true;
}
