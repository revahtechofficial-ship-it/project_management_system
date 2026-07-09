import 'dart:async';
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/user_avatar.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/dio_provider.dart';

/// A full-screen LiveKit call: a participant grid plus mic/camera/screen-share
/// and hang-up controls. Works for 1:1 and group, audio or video.
class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({
    super.key,
    required this.url,
    required this.token,
    required this.mode,
    this.title = '',
    this.selfName = '',
  });

  final String url;
  final String token;
  final String mode;
  final String title;
  final String selfName;

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  // Adaptive stream + dynacast let LiveKit scale quality to the network and
  // visible tiles automatically.
  final Room _room = Room(
    roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true),
  );
  bool _inLobby = true;
  DateTime? _connectedAt;
  Timer? _ticker;
  bool _lowData = false;
  bool _connecting = false;
  String? _error;
  bool _micOn = true;
  bool _camOn = false;
  bool _screenOn = false;

  // Pre-join ("green room") device selection.
  List<MediaDevice> _cameras = <MediaDevice>[];
  List<MediaDevice> _mics = <MediaDevice>[];
  List<MediaDevice> _speakers = <MediaDevice>[];
  String? _cameraId;
  String? _micId;
  String? _speakerId;
  LocalVideoTrack? _preview;

  // Lobby mic level meter, editable display name and permission state.
  late final TextEditingController _nameController = TextEditingController(
    text: widget.selfName,
  );
  LocalAudioTrack? _micPreview;
  AudioVisualizer? _visualizer;
  void Function()? _vizCancel;
  List<double> _levels = const <double>[];
  bool _cameraBlocked = false;
  bool _micBlocked = false;

  // In-call layout state.
  bool _gridView = false;
  String? _pinnedKey;
  bool _mirrorSelf = true;
  bool _hideSelf = false;

  // Participant interactions (over LiveKit data channels).
  EventsListener<RoomEvent>? _events;
  final List<_Reaction> _reactions = <_Reaction>[];
  final List<String> _handQueue =
      <String>[]; // participant sids, in raise order
  final List<_ChatMsg> _chat = <_ChatMsg>[];
  final TextEditingController _chatController = TextEditingController();
  int _unreadChat = 0;
  int _seq = 0;
  _SidePanel _panel = _SidePanel.none;
  _Poll? _poll;
  bool _pollMine = false;
  bool _reactionsOpen = false;
  bool _devicesExpanded = false;

  @override
  void initState() {
    super.initState();
    _room.addListener(_onChange);
    _camOn = widget.mode == 'video';
    _initLobby();
  }

  void _onChange() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _initLobby() async {
    await _startMicMeter();
    if (_camOn) {
      await _startPreview();
    }
    await _refreshDevices();
  }

  Future<void> _refreshDevices() async {
    try {
      _cameras = await Hardware.instance.videoInputs();
      _mics = await Hardware.instance.audioInputs();
      _speakers = await Hardware.instance.audioOutputs();
      _cameraId ??= _cameras.isNotEmpty ? _cameras.first.deviceId : null;
      _micId ??= _mics.isNotEmpty ? _mics.first.deviceId : null;
      _speakerId ??= _speakers.isNotEmpty ? _speakers.first.deviceId : null;
    } catch (_) {
      // Enumeration can fail before camera/mic permission is granted.
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _startPreview() async {
    await _stopPreview();
    try {
      _preview = await LocalVideoTrack.createCameraTrack(
        CameraCaptureOptions(deviceId: _cameraId),
      );
      _cameraBlocked = false;
      // Device labels become available once permission is granted.
      await _refreshDevices();
    } catch (_) {
      _camOn = false;
      _cameraBlocked = true;
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _stopPreview() async {
    final LocalVideoTrack? t = _preview;
    _preview = null;
    await t?.stop();
    await t?.dispose();
  }

  Future<void> _startMicMeter() async {
    await _stopMicMeter();
    try {
      _micPreview = await LocalAudioTrack.create(
        AudioCaptureOptions(deviceId: _micId),
      );
      final AudioVisualizer viz = createVisualizer(
        _micPreview!,
        options: const AudioVisualizerOptions(
          barCount: 14,
          centeredBands: false,
        ),
      );
      _visualizer = viz;
      _vizCancel = viz.events.listen((AudioVisualizerEvent e) {
        if (!mounted) {
          return;
        }
        setState(() {
          _levels = <double>[
            for (final Object? v in e.event) (v as num?)?.toDouble() ?? 0.0,
          ];
        });
      });
      await viz.start();
      _micBlocked = false;
    } catch (_) {
      _micBlocked = true;
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _stopMicMeter() async {
    _vizCancel?.call();
    _vizCancel = null;
    await _visualizer?.stop();
    await _visualizer?.dispose();
    _visualizer = null;
    final LocalAudioTrack? t = _micPreview;
    _micPreview = null;
    await t?.stop();
    await t?.dispose();
    _levels = const <double>[];
  }

  Future<void> _selectSpeaker(String id) async {
    _speakerId = id;
    for (final MediaDevice d in _speakers) {
      if (d.deviceId == id) {
        try {
          await Hardware.instance.selectAudioOutput(d);
        } catch (_) {
          // Output selection is desktop-only; a harmless no-op on web.
        }
        break;
      }
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _lobbyToggleCam() async {
    _camOn = !_camOn;
    if (_camOn) {
      await _startPreview();
    } else {
      await _stopPreview();
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _selectCamera(String id) async {
    _cameraId = id;
    if (_inLobby) {
      if (_camOn) {
        await _startPreview();
      }
    } else if (_camOn) {
      await _room.localParticipant?.setCameraEnabled(
        true,
        cameraCaptureOptions: CameraCaptureOptions(deviceId: id),
      );
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _selectMic(String id) async {
    _micId = id;
    if (_inLobby) {
      await _startMicMeter();
    } else if (_micOn) {
      await _room.localParticipant?.setMicrophoneEnabled(
        true,
        audioCaptureOptions: AudioCaptureOptions(deviceId: id),
      );
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _join() async {
    await _stopPreview();
    await _stopMicMeter();
    setState(() {
      _inLobby = false;
      _connecting = true;
    });
    try {
      await _room.connect(widget.url, widget.token);
      _events = _room.createListener();
      _events!.on<DataReceivedEvent>(_onData);
      await _room.localParticipant?.setMicrophoneEnabled(
        _micOn,
        audioCaptureOptions: _micId != null
            ? AudioCaptureOptions(deviceId: _micId)
            : null,
      );
      if (_camOn) {
        await _room.localParticipant?.setCameraEnabled(
          true,
          cameraCaptureOptions: _cameraId != null
              ? CameraCaptureOptions(deviceId: _cameraId)
              : null,
        );
      }
      final String name = _nameController.text.trim();
      if (name.isNotEmpty && name != widget.selfName) {
        await _room.localParticipant?.setName(name);
      }
      _connectedAt = DateTime.now();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() {});
        }
      });
      if (mounted) {
        setState(() => _connecting = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _connecting = false;
          _error =
              "Couldn't reach the call server. Check your connection and try "
              'again.';
        });
      }
    }
  }

  String _elapsed() {
    if (_connectedAt == null) {
      return '';
    }
    final Duration d = DateTime.now().difference(_connectedAt!);
    final String m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final String s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }

  Future<void> _toggleLowData() async {
    _lowData = !_lowData;
    if (_lowData && _camOn) {
      _camOn = false;
      await _room.localParticipant?.setCameraEnabled(false);
    }
    for (final RemoteParticipant p in _room.remoteParticipants.values) {
      for (final TrackPublication<Track> pub in p.videoTrackPublications) {
        if (pub is RemoteTrackPublication) {
          if (_lowData) {
            await pub.unsubscribe();
          } else {
            await pub.subscribe();
          }
        }
      }
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _toggleMic() async {
    _micOn = !_micOn;
    await _room.localParticipant?.setMicrophoneEnabled(
      _micOn,
      audioCaptureOptions: _micOn && _micId != null
          ? AudioCaptureOptions(deviceId: _micId)
          : null,
    );
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _toggleCam() async {
    _camOn = !_camOn;
    await _room.localParticipant?.setCameraEnabled(
      _camOn,
      cameraCaptureOptions: _camOn && _cameraId != null
          ? CameraCaptureOptions(deviceId: _cameraId)
          : null,
    );
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _toggleScreen() async {
    _screenOn = !_screenOn;
    try {
      // captureScreenAudio shares tab/system audio along with the screen.
      await _room.localParticipant?.setScreenShareEnabled(
        _screenOn,
        captureScreenAudio: _screenOn,
      );
    } catch (_) {
      _screenOn = !_screenOn;
    }
    if (mounted) {
      setState(() {});
    }
  }

  // --- Participant interactions (data channel) -----------------------------

  void _send(Map<String, dynamic> msg, {bool reliable = true}) {
    _room.localParticipant?.publishData(
      utf8.encode(jsonEncode(msg)),
      reliable: reliable,
    );
  }

  void _onData(DataReceivedEvent e) {
    Map<String, dynamic> msg;
    try {
      msg = jsonDecode(utf8.decode(e.data)) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final String? sid = e.participant?.sid;
    final String from = (e.participant?.name.isNotEmpty ?? false)
        ? e.participant!.name
        : (e.participant?.identity ?? 'Someone');
    switch (msg['t']) {
      case 'reaction':
        _addReaction(msg['emoji'] as String? ?? '👍');
      case 'hand':
        if (sid != null) {
          final bool up = msg['up'] as bool? ?? false;
          setState(() {
            _handQueue.remove(sid);
            if (up) {
              _handQueue.add(sid);
            }
          });
        }
      case 'chat':
        final String text = msg['text'] as String? ?? '';
        if (text.isNotEmpty) {
          setState(() {
            _chat.add(_ChatMsg(from, text, false));
            if (_panel != _SidePanel.chat) {
              _unreadChat++;
            }
          });
        }
      case 'poll':
        final List<String> opts = <String>[
          for (final Object? o
              in (msg['options'] as List<dynamic>? ?? <Object?>[]))
            '$o',
        ];
        if (opts.isNotEmpty) {
          setState(() {
            _pollMine = false;
            _poll = _Poll(
              id: '${msg['id']}',
              question: msg['q'] as String? ?? 'Poll',
              options: opts,
            );
          });
        }
      case 'vote':
        if (sid != null && _poll != null && '${msg['id']}' == _poll!.id) {
          final int? opt = msg['opt'] as int?;
          if (opt != null) {
            setState(() => _poll!.votes[sid] = opt);
          }
        }
      case 'pollend':
        if (_poll != null && '${msg['id']}' == _poll!.id) {
          setState(() => _poll!.ended = true);
        }
    }
  }

  void _addReaction(String emoji) {
    final _Reaction r = _Reaction('${_seq++}', emoji);
    setState(() => _reactions.add(r));
  }

  void _react(String emoji) {
    _addReaction(emoji);
    _send(<String, dynamic>{'t': 'reaction', 'emoji': emoji}, reliable: false);
  }

  void _toggleHand() {
    final String? me = _room.localParticipant?.sid;
    if (me == null) {
      return;
    }
    final bool up = !_handQueue.contains(me);
    setState(() {
      _handQueue.remove(me);
      if (up) {
        _handQueue.add(me);
      }
    });
    _send(<String, dynamic>{'t': 'hand', 'up': up});
  }

  void _sendChat() {
    final String text = _chatController.text.trim();
    if (text.isEmpty) {
      return;
    }
    _chatController.clear();
    final String me = (_room.localParticipant?.name.isNotEmpty ?? false)
        ? _room.localParticipant!.name
        : 'You';
    setState(() => _chat.add(_ChatMsg(me, text, true)));
    _send(<String, dynamic>{'t': 'chat', 'text': text});
  }

  void _startPoll(String question, List<String> options) {
    final String id = '${_seq++}-${_room.localParticipant?.sid ?? ''}';
    setState(() {
      _pollMine = true;
      _poll = _Poll(id: id, question: question, options: options);
    });
    _send(<String, dynamic>{
      't': 'poll',
      'id': id,
      'q': question,
      'options': options,
    });
  }

  void _vote(int opt) {
    final String? me = _room.localParticipant?.sid;
    if (me == null || _poll == null || _poll!.ended) {
      return;
    }
    setState(() => _poll!.votes[me] = opt);
    _send(<String, dynamic>{'t': 'vote', 'id': _poll!.id, 'opt': opt});
  }

  void _endPoll() {
    if (_poll == null) {
      return;
    }
    _send(<String, dynamic>{'t': 'pollend', 'id': _poll!.id});
    setState(() => _poll!.ended = true);
  }

  void _dismissPoll() => setState(() => _poll = null);

  // --- Host (admin) moderation, run server-side via the backend -------------

  bool get _isAdmin =>
      ref.read(authControllerProvider).asData?.value.user?.isAdmin ?? false;

  Future<void> _mod(String path, Map<String, dynamic> body) async {
    try {
      await ref
          .read(dioProvider)
          .post<dynamic>('/api/v1/calls/$path', data: body);
    } catch (_) {
      // Surfaced server-side; ignore client-side to keep the call smooth.
    }
  }

  void _muteParticipant(Participant p) {
    if (p.audioTrackPublications.isEmpty) {
      return;
    }
    _mod('mute', <String, dynamic>{
      'room': _room.name,
      'identity': p.identity,
      'track_sid': p.audioTrackPublications.first.sid,
      'muted': true,
    });
  }

  void _muteAll() {
    for (final RemoteParticipant p in _room.remoteParticipants.values) {
      _muteParticipant(p);
    }
  }

  void _removeParticipant(Participant p) => _mod('remove', <String, dynamic>{
    'room': _room.name,
    'identity': p.identity,
  });

  void _setPublish(Participant p, bool canPublish) =>
      _mod('permissions', <String, dynamic>{
        'room': _room.name,
        'identity': p.identity,
        'can_publish': canPublish,
      });

  bool get _handUp => _handQueue.contains(_room.localParticipant?.sid);

  void _openPanel(_SidePanel p) {
    setState(() {
      _panel = _panel == p ? _SidePanel.none : p;
      if (_panel == _SidePanel.chat) {
        _unreadChat = 0;
      }
    });
  }

  Future<void> _renameSelf() async {
    final TextEditingController c = TextEditingController(
      text: _room.localParticipant?.name ?? '',
    );
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Your name'),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Display name'),
          onSubmitted: (String v) => Navigator.pop(context, v),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, c.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      await _room.localParticipant?.setName(name.trim());
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _hangUp() async {
    await _room.disconnect();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _stopPreview();
    _stopMicMeter();
    _nameController.dispose();
    _chatController.dispose();
    _events?.dispose();
    _room.removeListener(_onChange);
    _room.dispose();
    super.dispose();
  }

  List<Participant> get _participants => <Participant>[
    if (_room.localParticipant != null) _room.localParticipant!,
    ..._room.remoteParticipants.values,
  ];

  /// One tile per video track: a camera (or avatar) tile for each participant,
  /// plus a separate tile for anyone sharing their screen — otherwise the
  /// screen-share track is published but never shown (the camera wins).
  List<_VideoSource> _videoSources() {
    final List<_VideoSource> out = <_VideoSource>[];
    for (final Participant p in _participants) {
      VideoTrack? camera;
      VideoTrack? screen;
      for (final TrackPublication<Track> pub in p.videoTrackPublications) {
        final Track? t = pub.track;
        if (t is! VideoTrack) {
          continue;
        }
        if (pub.source == TrackSource.screenShareVideo) {
          screen = t;
        } else {
          camera ??= t;
        }
      }
      final bool isLocal = p == _room.localParticipant;
      if (!(isLocal && _hideSelf)) {
        out.add(_VideoSource(participant: p, video: camera, isScreen: false));
      }
      if (screen != null) {
        out.add(_VideoSource(participant: p, video: screen, isScreen: true));
      }
    }
    return out;
  }

  String _srcKey(_VideoSource s) => '${s.participant.sid}|${s.isScreen}';

  _VideoSource? _findKey(List<_VideoSource> srcs, String? key) {
    if (key == null) {
      return null;
    }
    for (final _VideoSource s in srcs) {
      if (_srcKey(s) == key) {
        return s;
      }
    }
    return null;
  }

  _VideoSource? _firstScreen(List<_VideoSource> srcs) {
    for (final _VideoSource s in srcs) {
      if (s.isScreen) {
        return s;
      }
    }
    return null;
  }

  _VideoSource? _activeSpeakerSource(List<_VideoSource> srcs) {
    if (_room.activeSpeakers.isEmpty) {
      return null;
    }
    final String sid = _room.activeSpeakers.first.sid;
    for (final _VideoSource s in srcs) {
      if (!s.isScreen && s.participant.sid == sid) {
        return s;
      }
    }
    return null;
  }

  /// Builds a tile, wired for click-to-pin and self-view mirroring.
  Widget _tile(_VideoSource s) {
    final bool isLocal = s.participant == _room.localParticipant;
    final String key = _srcKey(s);
    return _ParticipantTile(
      participant: s.participant,
      video: s.video,
      isScreen: s.isScreen,
      mirror: isLocal && !s.isScreen && _mirrorSelf,
      pinned: _pinnedKey == key,
      handUp: !s.isScreen && _handQueue.contains(s.participant.sid),
      onTap: () => setState(() => _pinnedKey = _pinnedKey == key ? null : key),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_inLobby) {
      return _lobby();
    }
    // On narrow screens the side panel becomes a full-screen overlay instead
    // of squeezing the call area.
    final bool wide = MediaQuery.sizeOf(context).width >= 720;
    final bool panelOpen = _panel != _SidePanel.none;
    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    children: <Widget>[
                      _header(),
                      Expanded(child: _stage()),
                      _controls(),
                    ],
                  ),
                ),
                if (panelOpen && wide) _sidePanel(),
              ],
            ),
            if (panelOpen && !wide)
              Positioned.fill(child: _sidePanel(full: true)),
            if (_poll != null) _pollCard(),
            if (_reactionsOpen) ...<Widget>[
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => setState(() => _reactionsOpen = false),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 96,
                child: Center(child: _reactionStrip()),
              ),
            ],
            IgnorePointer(
              child: Stack(
                children: <Widget>[
                  for (final _Reaction r in _reactions)
                    _FloatingReaction(
                      key: ValueKey<String>(r.id),
                      emoji: r.emoji,
                      seed: int.tryParse(r.id) ?? 0,
                      onDone: () {
                        if (mounted) {
                          setState(
                            () => _reactions.removeWhere(
                              (_Reaction x) => x.id == r.id,
                            ),
                          );
                        }
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sidePanel({bool full = false}) {
    final bool people = _panel == _SidePanel.people;
    return Container(
      width: full ? double.infinity : 320,
      decoration: const BoxDecoration(
        color: Color(0xFF11182B),
        border: Border(left: BorderSide(color: Colors.white12)),
      ),
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: <Widget>[
                Text(
                  people ? 'Participants (${_participants.length})' : 'Chat',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (people && _isAdmin && _room.remoteParticipants.isNotEmpty)
                  TextButton.icon(
                    onPressed: _muteAll,
                    icon: const Icon(Icons.mic_off, size: 16),
                    label: const Text('Mute all'),
                  ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => setState(() => _panel = _SidePanel.none),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          Expanded(child: people ? _peoplePanel() : _chatPanel()),
        ],
      ),
    );
  }

  Widget _peoplePanel() {
    final List<Participant> people = _participants;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: people.length,
      itemBuilder: (BuildContext context, int i) {
        final Participant p = people[i];
        final bool isLocal = p == _room.localParticipant;
        final String name = p.name.isNotEmpty ? p.name : p.identity;
        final bool sharing = p.videoTrackPublications.any(
          (TrackPublication<Track> pub) =>
              pub.source == TrackSource.screenShareVideo && pub.track != null,
        );
        final bool handUp = _handQueue.contains(p.sid);
        return ListTile(
          dense: true,
          leading: UserAvatar(name: name, radius: 16),
          title: Text(
            isLocal ? '$name (You)' : name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (handUp)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Text('✋', style: TextStyle(fontSize: 14)),
                ),
              if (sharing)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(
                    Icons.screen_share,
                    size: 16,
                    color: Color(0xFF0EA5E9),
                  ),
                ),
              Icon(
                p.isMuted ? Icons.mic_off : Icons.mic,
                size: 16,
                color: p.isMuted ? Colors.redAccent : Colors.white54,
              ),
              if (isLocal)
                IconButton(
                  tooltip: 'Rename',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: Colors.white54,
                  ),
                  onPressed: _renameSelf,
                ),
              if (!isLocal && _isAdmin) _hostMenu(p),
            ],
          ),
        );
      },
    );
  }

  Widget _hostMenu(Participant p) {
    return PopupMenuButton<String>(
      tooltip: 'Host actions',
      color: const Color(0xFF1A2238),
      icon: const Icon(Icons.more_vert, size: 18, color: Colors.white54),
      onSelected: (String v) {
        switch (v) {
          case 'mute':
            _muteParticipant(p);
          case 'nopublish':
            _setPublish(p, false);
          case 'publish':
            _setPublish(p, true);
          case 'remove':
            _removeParticipant(p);
        }
      },
      itemBuilder: (BuildContext context) => const <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'mute',
          child: Text('Mute', style: TextStyle(color: Colors.white)),
        ),
        PopupMenuItem<String>(
          value: 'nopublish',
          child: Text(
            'Disable camera & share',
            style: TextStyle(color: Colors.white),
          ),
        ),
        PopupMenuItem<String>(
          value: 'publish',
          child: Text(
            'Allow camera & share',
            style: TextStyle(color: Colors.white),
          ),
        ),
        PopupMenuItem<String>(
          value: 'remove',
          child: Text(
            'Remove from call',
            style: TextStyle(color: Colors.redAccent),
          ),
        ),
      ],
    );
  }

  Widget _chatPanel() {
    return Column(
      children: <Widget>[
        Expanded(
          child: _chat.isEmpty
              ? const Center(
                  child: Text(
                    'No messages yet.',
                    style: TextStyle(color: Colors.white60),
                  ),
                )
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: _chat.length,
                  itemBuilder: (BuildContext context, int i) {
                    final _ChatMsg m = _chat[_chat.length - 1 - i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        crossAxisAlignment: m.isMe
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            m.isMe ? 'You' : m.sender,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: m.isMe
                                  ? const Color(0xFF6366F1)
                                  : Colors.white12,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: _LinkText(m.text),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _chatController,
                  style: const TextStyle(color: Colors.white),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendChat(),
                  decoration: const InputDecoration(
                    hintText: 'Message…',
                    hintStyle: TextStyle(color: Colors.white38),
                    isDense: true,
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white54),
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send_rounded, color: Color(0xFF6366F1)),
                onPressed: _sendChat,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// A compact emoji popover that floats just above the control bar.
  Widget _reactionStrip() {
    const List<String> emojis = <String>[
      '👍',
      '❤️',
      '😂',
      '🎉',
      '👏',
      '😮',
      '🙏',
      '🔥',
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2238),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white12),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final String e in emojis)
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                _react(e);
                setState(() => _reactionsOpen = false);
              },
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Text(e, style: const TextStyle(fontSize: 24)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _lobby() {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Text(
                    'Ready to join?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (widget.title.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ],
                  const SizedBox(height: 18),
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A2238),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: _camOn && _preview != null
                          ? VideoTrackRenderer(
                              _preview!,
                              fit: VideoViewFit.cover,
                            )
                          : Center(
                              child: _cameraBlocked
                                  ? Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const <Widget>[
                                          Icon(
                                            Icons.videocam_off,
                                            color: Colors.white38,
                                            size: 36,
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            'Camera is blocked.\nAllow camera '
                                            'access in your browser, then tap '
                                            'the camera button to retry.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : const Icon(
                                      Icons.videocam_off,
                                      color: Colors.white38,
                                      size: 40,
                                    ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      _RoundButton(
                        icon: _micOn ? Icons.mic : Icons.mic_off,
                        off: !_micOn,
                        tooltip: _micOn ? 'Mute' : 'Unmute',
                        onTap: () => setState(() => _micOn = !_micOn),
                      ),
                      const SizedBox(width: 16),
                      _RoundButton(
                        icon: _camOn ? Icons.videocam : Icons.videocam_off,
                        tooltip: _camOn ? 'Camera off' : 'Camera on',
                        onTap: _lobbyToggleCam,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _micMeterBar(),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Your name',
                      labelStyle: TextStyle(color: Colors.white54),
                      prefixIcon: Icon(
                        Icons.badge_outlined,
                        color: Colors.white54,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white54),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () =>
                        setState(() => _devicesExpanded = !_devicesExpanded),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: <Widget>[
                          const Icon(
                            Icons.tune,
                            color: Colors.white54,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Device settings',
                            style: TextStyle(color: Colors.white70),
                          ),
                          const Spacer(),
                          AnimatedRotation(
                            turns: _devicesExpanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 150),
                            child: const Icon(
                              Icons.expand_more,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_devicesExpanded) ...<Widget>[
                    _deviceDropdown(
                      Icons.videocam_outlined,
                      _cameras,
                      _cameraId,
                      _selectCamera,
                    ),
                    _deviceDropdown(Icons.mic_none, _mics, _micId, _selectMic),
                    _deviceDropdown(
                      Icons.volume_up_outlined,
                      _speakers,
                      _speakerId,
                      _selectSpeaker,
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: _join,
                          icon: const Icon(Icons.videocam, size: 18),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          label: const Text('Join call'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _micMeterBar() {
    if (_micBlocked) {
      return const Row(
        children: <Widget>[
          Icon(Icons.mic_off, color: Colors.redAccent, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Microphone is blocked — allow access in your browser.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
        ],
      );
    }
    final List<double> levels = _levels.isEmpty
        ? List<double>.filled(14, 0)
        : _levels;
    return Row(
      children: <Widget>[
        Icon(
          _micOn ? Icons.mic : Icons.mic_off,
          color: Colors.white54,
          size: 18,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 16,
            child: Row(
              children: <Widget>[
                for (int i = 0; i < levels.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(width: 3),
                  Expanded(child: _MeterBar(level: _micOn ? levels[i] : 0)),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _deviceDropdown(
    IconData icon,
    List<MediaDevice> devices,
    String? selected,
    ValueChanged<String> onChanged,
  ) {
    if (devices.isEmpty) {
      return const SizedBox.shrink();
    }
    final bool hasSelected = devices.any(
      (MediaDevice d) => d.deviceId == selected,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Icon(icon, color: Colors.white54, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                dropdownColor: const Color(0xFF1A2238),
                value: hasSelected ? selected : null,
                hint: const Text(
                  'Default',
                  style: TextStyle(color: Colors.white54),
                ),
                style: const TextStyle(color: Colors.white),
                items: <DropdownMenuItem<String>>[
                  for (final MediaDevice d in devices)
                    DropdownMenuItem<String>(
                      value: d.deviceId,
                      child: Text(
                        d.label.isEmpty ? 'Device' : d.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                ],
                onChanged: (String? v) {
                  if (v != null) {
                    onChanged(v);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeviceSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF11182B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheet) {
            Future<void> pickCam(String id) async {
              await _selectCamera(id);
              setSheet(() {});
            }

            Future<void> pickMic(String id) async {
              await _selectMic(id);
              setSheet(() {});
            }

            Future<void> pickSpeaker(String id) async {
              await _selectSpeaker(id);
              setSheet(() {});
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Call settings',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    activeThumbColor: const Color(0xFF22C55E),
                    title: const Text(
                      'Mirror my video',
                      style: TextStyle(color: Colors.white),
                    ),
                    value: _mirrorSelf,
                    onChanged: (bool v) {
                      setState(() => _mirrorSelf = v);
                      setSheet(() {});
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    activeThumbColor: const Color(0xFF22C55E),
                    title: const Text(
                      'Hide my video',
                      style: TextStyle(color: Colors.white),
                    ),
                    value: _hideSelf,
                    onChanged: (bool v) {
                      setState(() => _hideSelf = v);
                      setSheet(() {});
                    },
                  ),
                  const SizedBox(height: 8),
                  _deviceDropdown(
                    Icons.videocam_outlined,
                    _cameras,
                    _cameraId,
                    pickCam,
                  ),
                  _deviceDropdown(Icons.mic_none, _mics, _micId, pickMic),
                  _deviceDropdown(
                    Icons.volume_up_outlined,
                    _speakers,
                    _speakerId,
                    pickSpeaker,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _pollCard() {
    final _Poll p = _poll!;
    final String? me = _room.localParticipant?.sid;
    final int? myVote = me != null ? p.votes[me] : null;
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 14),
        decoration: BoxDecoration(
          color: const Color(0xFF11182B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(
                  Icons.poll_outlined,
                  color: Colors.white70,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    p.question,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white54,
                    size: 18,
                  ),
                  onPressed: _dismissPoll,
                ),
              ],
            ),
            const SizedBox(height: 6),
            for (int i = 0; i < p.options.length; i++)
              _pollOption(p, i, myVote),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                Text(
                  '${p.total} vote${p.total == 1 ? '' : 's'}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const Spacer(),
                if (p.ended)
                  const Text(
                    'Ended',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  )
                else if (_pollMine)
                  TextButton(
                    onPressed: _endPoll,
                    child: const Text('End poll'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pollOption(_Poll p, int i, int? myVote) {
    final int count = p.countFor(i);
    final double frac = p.total == 0 ? 0 : count / p.total;
    final bool selected = myVote == i;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: p.ended ? null : () => _vote(i),
        child: Stack(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: frac,
                minHeight: 34,
                backgroundColor: Colors.white10,
                color: selected
                    ? const Color(0xFF6366F1).withValues(alpha: 0.55)
                    : Colors.white24,
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: <Widget>[
                    if (selected)
                      const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Icon(Icons.check, color: Colors.white, size: 16),
                      ),
                    Expanded(
                      child: Text(
                        p.options[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    Text(
                      '$count',
                      style: const TextStyle(color: Colors.white70),
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

  void _showCreatePoll() {
    final TextEditingController q = TextEditingController();
    final List<TextEditingController> opts = <TextEditingController>[
      TextEditingController(),
      TextEditingController(),
    ];
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setD) => AlertDialog(
          title: const Text('New poll'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: q,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Question'),
                ),
                const SizedBox(height: 8),
                for (int i = 0; i < opts.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: TextField(
                      controller: opts[i],
                      decoration: InputDecoration(labelText: 'Option ${i + 1}'),
                    ),
                  ),
                if (opts.length < 5)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () =>
                          setD(() => opts.add(TextEditingController())),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add option'),
                    ),
                  ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final String question = q.text.trim();
                final List<String> options = <String>[
                  for (final TextEditingController c in opts)
                    if (c.text.trim().isNotEmpty) c.text.trim(),
                ];
                if (question.isEmpty || options.length < 2) {
                  return;
                }
                Navigator.pop(context);
                _startPoll(question, options);
              },
              child: const Text('Start'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    final bool reconnecting =
        _room.connectionState == ConnectionState.reconnecting;
    return Column(
      children: <Widget>[
        if (reconnecting)
          Container(
            width: double.infinity,
            color: const Color(0xFFF59E0B),
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Reconnecting…',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              const Icon(Icons.videocam, color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.title.isEmpty ? 'Call' : widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_connectedAt != null) ...<Widget>[
                Text(
                  _elapsed(),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 10),
                Container(width: 1, height: 12, color: Colors.white24),
                const SizedBox(width: 10),
              ],
              Text(
                '${_participants.length} in call',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stage() {
    if (_connecting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Could not join the call.\n$_error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      );
    }
    final List<_VideoSource> sources = _videoSources();
    if (sources.isEmpty) {
      return const Center(
        child: Text(
          'Waiting for others to join…',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    // Feature one source as the main stage: an explicit pin wins, then a shared
    // screen, then (in speaker view) the active speaker. Grid view shows all
    // tiles equally unless something is pinned or being shared.
    _VideoSource? featured =
        _findKey(sources, _pinnedKey) ?? _firstScreen(sources);
    if (featured == null && !_gridView) {
      featured = _activeSpeakerSource(sources) ?? sources.first;
    }
    if (featured == null) {
      return _grid(sources);
    }

    final String fkey = _srcKey(featured);
    final List<_VideoSource> thumbs = <_VideoSource>[
      for (final _VideoSource s in sources)
        if (_srcKey(s) != fkey) s,
    ];
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: <Widget>[
          Expanded(child: _tile(featured)),
          if (thumbs.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            SizedBox(
              height: 112,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: thumbs.length,
                separatorBuilder: (BuildContext context, int i) =>
                    const SizedBox(width: 12),
                itemBuilder: (BuildContext context, int i) =>
                    AspectRatio(aspectRatio: 4 / 3, child: _tile(thumbs[i])),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _grid(List<_VideoSource> sources) {
    final int cols = sources.length <= 1
        ? 1
        : sources.length <= 4
        ? 2
        : 3;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: GridView.count(
        crossAxisCount: cols,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 16 / 10,
        children: <Widget>[for (final _VideoSource s in sources) _tile(s)],
      ),
    );
  }

  Widget _controls() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 14,
        runSpacing: 12,
        children: <Widget>[
          // Primary controls in a grouped pill.
          _ControlPill(
            children: <Widget>[
              _RoundButton(
                icon: _micOn ? Icons.mic : Icons.mic_off,
                off: !_micOn,
                tooltip: _micOn ? 'Mute' : 'Unmute',
                onTap: _toggleMic,
              ),
              _RoundButton(
                icon: _camOn ? Icons.videocam : Icons.videocam_off,
                tooltip: _camOn ? 'Stop video' : 'Start video',
                onTap: _toggleCam,
              ),
              _RoundButton(
                icon: Icons.screen_share,
                active: _screenOn,
                tooltip: _screenOn ? 'Stop sharing' : 'Share screen',
                onTap: _toggleScreen,
              ),
              _RoundButton(
                icon: Icons.add_reaction_outlined,
                active: _reactionsOpen,
                tooltip: 'Reactions',
                onTap: () => setState(() => _reactionsOpen = !_reactionsOpen),
              ),
              _RoundButton(
                icon: Icons.people_alt_outlined,
                active: _panel == _SidePanel.people,
                tooltip: 'Participants',
                onTap: () => _openPanel(_SidePanel.people),
              ),
              _RoundButton(
                icon: Icons.chat_bubble_outline,
                active: _panel == _SidePanel.chat,
                badge: _unreadChat > 0 ? '$_unreadChat' : null,
                tooltip: 'Chat',
                onTap: () => _openPanel(_SidePanel.chat),
              ),
              _RoundButton(
                icon: Icons.more_horiz,
                active: _handUp || _poll != null || _lowData,
                tooltip: 'More',
                onTap: _showMore,
              ),
            ],
          ),
          _LeaveButton(onTap: _hangUp),
        ],
      ),
    );
  }

  void _showMore() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF11182B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _moreTile(
              sheet,
              Icons.front_hand,
              _handUp ? 'Lower hand' : 'Raise hand',
              _toggleHand,
              active: _handUp,
            ),
            _moreTile(
              sheet,
              Icons.poll_outlined,
              'Create a poll',
              _showCreatePoll,
              active: _poll != null,
            ),
            _moreTile(
              sheet,
              _gridView ? Icons.grid_view : Icons.view_sidebar_outlined,
              _gridView ? 'Speaker view' : 'Grid view',
              () => setState(() => _gridView = !_gridView),
            ),
            _moreTile(
              sheet,
              Icons.data_saver_on,
              'Low-data mode',
              _toggleLowData,
              active: _lowData,
            ),
            _moreTile(
              sheet,
              Icons.tune,
              'Devices & settings',
              _showDeviceSheet,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _moreTile(
    BuildContext sheet,
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool active = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: active ? const Color(0xFF6366F1) : Colors.white70,
      ),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      trailing: active
          ? const Icon(Icons.check, color: Color(0xFF6366F1), size: 18)
          : null,
      onTap: () {
        Navigator.pop(sheet);
        onTap();
      },
    );
  }
}

/// A single video source to render: a participant's camera (or avatar when the
/// camera is off) or their shared screen.
class _VideoSource {
  const _VideoSource({
    required this.participant,
    required this.video,
    required this.isScreen,
  });

  final Participant participant;
  final VideoTrack? video;
  final bool isScreen;
}

class _ParticipantTile extends StatefulWidget {
  const _ParticipantTile({
    required this.participant,
    required this.video,
    required this.isScreen,
    this.mirror = false,
    this.pinned = false,
    this.handUp = false,
    this.onTap,
  });
  final Participant participant;
  final VideoTrack? video;
  final bool isScreen;
  final bool mirror;
  final bool pinned;
  final bool handUp;
  final VoidCallback? onTap;

  @override
  State<_ParticipantTile> createState() => _ParticipantTileState();
}

class _ParticipantTileState extends State<_ParticipantTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final Participant p = widget.participant;
    final String baseName = p.name.isNotEmpty ? p.name : p.identity;
    final String name = widget.isScreen ? '$baseName · Screen' : baseName;
    final bool clickable = widget.onTap != null;
    const Color speakingColor = Color(0xFF22C55E);
    const Color pinnedColor = Color(0xFF6366F1);
    final Color? border = p.isSpeaking
        ? speakingColor
        : widget.pinned
        ? pinnedColor
        : null;

    Widget tile = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF1A2238),
        borderRadius: BorderRadius.circular(14),
        // Speaking tiles get a solid ring plus an outer glow so an active
        // speaker reads differently from a statically-pinned tile, not just
        // by hue (green vs indigo).
        border: border != null
            ? Border.all(color: border, width: p.isSpeaking ? 3 : 2)
            : null,
        boxShadow: p.isSpeaking
            ? <BoxShadow>[
                BoxShadow(
                  color: speakingColor.withValues(alpha: 0.45),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (widget.video != null)
            VideoTrackRenderer(
              widget.video!,
              fit: widget.isScreen ? VideoViewFit.contain : VideoViewFit.cover,
              mirrorMode: widget.mirror
                  ? VideoViewMirrorMode.mirror
                  : VideoViewMirrorMode.off,
            )
          else
            Center(child: UserAvatar(name: baseName, radius: 34)),
          // Hover scrim + pin hint for click-to-pin tiles.
          if (clickable && _hover) ...<Widget>[
            Positioned.fill(
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.18)),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        widget.pinned
                            ? Icons.push_pin
                            : Icons.push_pin_outlined,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.pinned ? 'Unpin' : 'Pin',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          // One condensed bottom bar: hand · mic · name … pin · signal.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 14, 10, 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: <Color>[
                    Colors.black.withValues(alpha: 0.6),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: <Widget>[
                  if (widget.handUp)
                    const Padding(
                      padding: EdgeInsets.only(right: 5),
                      child: Text('✋', style: TextStyle(fontSize: 13)),
                    ),
                  Icon(
                    p.isMuted ? Icons.mic_off : Icons.mic,
                    size: 14,
                    color: p.isMuted ? Colors.redAccent : Colors.white70,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  if (widget.pinned)
                    const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Icon(
                        Icons.push_pin,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  if (!widget.isScreen)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: _QualityBars(quality: p.connectionQuality),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (!clickable) {
      return tile;
    }
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(onTap: widget.onTap, child: tile),
    );
  }
}

/// Small 3-bar signal indicator reflecting a participant's connection quality.
class _QualityBars extends StatelessWidget {
  const _QualityBars({required this.quality});
  final ConnectionQuality quality;

  @override
  Widget build(BuildContext context) {
    final int level = switch (quality) {
      ConnectionQuality.excellent => 3,
      ConnectionQuality.good => 2,
      ConnectionQuality.poor => 1,
      _ => 0,
    };
    final Color color = switch (quality) {
      ConnectionQuality.excellent ||
      ConnectionQuality.good => const Color(0xFF22C55E),
      ConnectionQuality.poor => const Color(0xFFF59E0B),
      ConnectionQuality.lost => Colors.redAccent,
      _ => Colors.white38,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          for (int i = 0; i < 3; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: 2),
            Container(
              width: 3,
              height: 4.0 + i * 3,
              decoration: BoxDecoration(
                color: i < level ? color : Colors.white24,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A single animated bar in the lobby mic level meter.
class _MeterBar extends StatelessWidget {
  const _MeterBar({required this.level});
  final double level;

  @override
  Widget build(BuildContext context) {
    final double v = (level.abs() * 4).clamp(0.0, 1.0);
    return Align(
      alignment: Alignment.center,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        height: 3 + v * 13,
        decoration: BoxDecoration(
          color: Color.lerp(
            const Color(0xFF3B4663),
            const Color(0xFF22C55E),
            v,
          ),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// A round call control. [active] highlights a toggled-on action (white fill);
/// [off] flags a disabled state like a muted mic (red). Adds a [tooltip] for
/// discoverability and an optional [badge].
class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.onTap,
    this.active = false,
    this.off = false,
    this.tooltip,
    this.badge,
  });
  final IconData icon;
  final bool active;
  final bool off;
  final String? tooltip;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color bg = off
        ? const Color(0xFFB91C1C)
        : active
        ? Colors.white
        : Colors.white24;
    final Color fg = active && !off ? Colors.black87 : Colors.white;
    Widget button = Material(
      color: bg,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Icon(icon, color: fg),
        ),
      ),
    );
    if (badge != null) {
      button = Badge(
        label: Text(badge!),
        backgroundColor: const Color(0xFF6366F1),
        child: button,
      );
    }
    if (tooltip != null) {
      button = Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}

/// Groups the primary call controls into a translucent rounded pill.
class _ControlPill extends StatelessWidget {
  const _ControlPill({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(40),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: children,
      ),
    );
  }
}

/// A distinct, labelled "Leave" pill set apart from the toggle controls.
class _LeaveButton extends StatelessWidget {
  const _LeaveButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Leave call',
      child: Material(
        color: const Color(0xFFDC2626),
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.call_end, color: Colors.white, size: 22),
                SizedBox(width: 8),
                Text(
                  'Leave',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Which side panel is open during a call.
enum _SidePanel { none, people, chat }

/// A transient floating reaction.
class _Reaction {
  const _Reaction(this.id, this.emoji);
  final String id;
  final String emoji;
}

/// A single in-call chat message.
class _ChatMsg {
  const _ChatMsg(this.sender, this.text, this.isMe);
  final String sender;
  final String text;
  final bool isMe;
}

/// A live in-call poll. Votes are keyed by participant sid so re-votes replace.
class _Poll {
  _Poll({required this.id, required this.question, required this.options});
  final String id;
  final String question;
  final List<String> options;
  final Map<String, int> votes = <String, int>{};
  bool ended = false;

  int countFor(int opt) => votes.values.where((int v) => v == opt).length;
  int get total => votes.length;
}

/// Renders chat text with tappable http(s) links (opens in a new tab).
class _LinkText extends StatefulWidget {
  const _LinkText(this.text);
  final String text;

  @override
  State<_LinkText> createState() => _LinkTextState();
}

class _LinkTextState extends State<_LinkText> {
  final List<TapGestureRecognizer> _recognizers = <TapGestureRecognizer>[];

  void _clear() {
    for (final TapGestureRecognizer r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _clear();
    final RegExp re = RegExp(r'(https?:\/\/[^\s]+)');
    final List<InlineSpan> spans = <InlineSpan>[];
    int last = 0;
    for (final RegExpMatch m in re.allMatches(widget.text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: widget.text.substring(last, m.start)));
      }
      final String url = m.group(0)!;
      final TapGestureRecognizer rec = TapGestureRecognizer()
        ..onTap = () => launchUrl(Uri.parse(url), webOnlyWindowName: '_blank');
      _recognizers.add(rec);
      spans.add(
        TextSpan(
          text: url,
          recognizer: rec,
          style: const TextStyle(
            color: Color(0xFF93C5FD),
            decoration: TextDecoration.underline,
          ),
        ),
      );
      last = m.end;
    }
    if (last < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(last)));
    }
    return Text.rich(
      TextSpan(
        style: const TextStyle(color: Colors.white),
        children: spans,
      ),
    );
  }
}

/// An emoji that floats up and fades out, then removes itself via [onDone].
class _FloatingReaction extends StatefulWidget {
  const _FloatingReaction({
    super.key,
    required this.emoji,
    required this.seed,
    required this.onDone,
  });
  final String emoji;
  final int seed;
  final VoidCallback onDone;

  @override
  State<_FloatingReaction> createState() => _FloatingReactionState();
}

class _FloatingReactionState extends State<_FloatingReaction>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 2200),
        )
        ..addStatusListener((AnimationStatus s) {
          if (s == AnimationStatus.completed) {
            widget.onDone();
          }
        })
        ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double dx = ((widget.seed % 5) - 2) * 26.0;
    return Align(
      alignment: Alignment.bottomCenter,
      child: AnimatedBuilder(
        animation: _c,
        builder: (BuildContext context, Widget? child) {
          final double t = _c.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 96),
            child: Transform.translate(
              offset: Offset(dx, -190 * t),
              child: Opacity(opacity: (1 - t).clamp(0.0, 1.0), child: child),
            ),
          );
        },
        child: Text(widget.emoji, style: const TextStyle(fontSize: 42)),
      ),
    );
  }
}
