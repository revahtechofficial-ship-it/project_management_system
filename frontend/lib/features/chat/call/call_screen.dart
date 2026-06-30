import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../../core/widgets/user_avatar.dart';

/// A full-screen LiveKit call: a participant grid plus mic/camera/screen-share
/// and hang-up controls. Works for 1:1 and group, audio or video.
class CallScreen extends StatefulWidget {
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
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final Room _room = Room();
  bool _inLobby = true;
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
      await _room.localParticipant?.setMicrophoneEnabled(
        _micOn,
        audioCaptureOptions:
            _micId != null ? AudioCaptureOptions(deviceId: _micId) : null,
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
      if (mounted) {
        setState(() => _connecting = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _connecting = false;
          _error = '$e';
        });
      }
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

  Future<void> _hangUp() async {
    await _room.disconnect();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _stopPreview();
    _stopMicMeter();
    _nameController.dispose();
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
      onTap: () => setState(
        () => _pinnedKey = _pinnedKey == key ? null : key,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_inLobby) {
      return _lobby();
    }
    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _header(),
            Expanded(child: _stage()),
            _controls(),
          ],
        ),
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
                          ? VideoTrackRenderer(_preview!, fit: VideoViewFit.cover)
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
                                              color: Colors.white54,
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
                        active: _micOn,
                        onTap: () => setState(() => _micOn = !_micOn),
                      ),
                      const SizedBox(width: 16),
                      _RoundButton(
                        icon: _camOn ? Icons.videocam : Icons.videocam_off,
                        active: _camOn,
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
                  const SizedBox(height: 14),
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
                  const SizedBox(height: 22),
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
    final bool hasSelected =
        devices.any((MediaDevice d) => d.deviceId == selected);
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

  Widget _header() => Padding(
    padding: const EdgeInsets.all(16),
    child: Row(
      children: <Widget>[
        const Icon(Icons.videocam, color: Colors.white70, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            widget.title.isEmpty ? 'Call' : widget.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          '${_participants.length} in call',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    ),
  );

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
    _VideoSource? featured = _findKey(sources, _pinnedKey) ?? _firstScreen(sources);
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
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          _RoundButton(
            icon: _micOn ? Icons.mic : Icons.mic_off,
            active: _micOn,
            onTap: _toggleMic,
          ),
          const SizedBox(width: 16),
          _RoundButton(
            icon: _camOn ? Icons.videocam : Icons.videocam_off,
            active: _camOn,
            onTap: _toggleCam,
          ),
          const SizedBox(width: 16),
          _RoundButton(
            icon: Icons.screen_share,
            active: _screenOn,
            onTap: _toggleScreen,
          ),
          const SizedBox(width: 16),
          _RoundButton(
            icon: _gridView ? Icons.view_sidebar_outlined : Icons.grid_view,
            active: false,
            onTap: () => setState(() => _gridView = !_gridView),
          ),
          const SizedBox(width: 16),
          _RoundButton(
            icon: Icons.tune,
            active: false,
            onTap: _showDeviceSheet,
          ),
          const SizedBox(width: 16),
          _RoundButton(
            icon: Icons.call_end,
            active: true,
            danger: true,
            onTap: _hangUp,
          ),
        ],
      ),
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

class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile({
    required this.participant,
    required this.video,
    required this.isScreen,
    this.mirror = false,
    this.pinned = false,
    this.onTap,
  });
  final Participant participant;
  final VideoTrack? video;
  final bool isScreen;
  final bool mirror;
  final bool pinned;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final String baseName = participant.name.isNotEmpty
        ? participant.name
        : participant.identity;
    final String name = isScreen ? '$baseName · Screen' : baseName;
    final Color? border = participant.isSpeaking
        ? const Color(0xFF22C55E)
        : pinned
        ? const Color(0xFF6366F1)
        : null;
    Widget tile = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF1A2238),
        borderRadius: BorderRadius.circular(14),
        border: border != null ? Border.all(color: border, width: 2) : null,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (video != null)
            VideoTrackRenderer(
              video!,
              fit: isScreen ? VideoViewFit.contain : VideoViewFit.cover,
              mirrorMode: mirror
                  ? VideoViewMirrorMode.mirror
                  : VideoViewMirrorMode.off,
            )
          else
            Center(child: UserAvatar(name: baseName, radius: 34)),
          if (!isScreen)
            Positioned(
              top: 8,
              right: 8,
              child: _QualityBars(quality: participant.connectionQuality),
            ),
          if (pinned)
            const Positioned(
              top: 8,
              left: 8,
              child: Icon(Icons.push_pin, color: Colors.white, size: 16),
            ),
          Positioned(
            left: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (participant.isMuted)
                    const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Icon(
                        Icons.mic_off,
                        color: Colors.redAccent,
                        size: 14,
                      ),
                    ),
                  Text(
                    name,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    if (onTap != null) {
      tile = MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(onTap: onTap, child: tile),
      );
    }
    return tile;
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

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.active,
    required this.onTap,
    this.danger = false,
  });
  final IconData icon;
  final bool active;
  final bool danger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color bg = danger
        ? Colors.red
        : active
        ? Colors.white
        : Colors.white24;
    final Color fg = danger || !active ? Colors.white : Colors.black87;
    return Material(
      color: bg,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Icon(icon, color: fg),
        ),
      ),
    );
  }
}
