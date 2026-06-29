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
  });

  final String url;
  final String token;
  final String mode;
  final String title;

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
  String? _cameraId;
  String? _micId;
  LocalVideoTrack? _preview;

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
    if (_camOn) {
      await _startPreview();
    }
    await _refreshDevices();
  }

  Future<void> _refreshDevices() async {
    try {
      _cameras = await Hardware.instance.videoInputs();
      _mics = await Hardware.instance.audioInputs();
      _cameraId ??= _cameras.isNotEmpty ? _cameras.first.deviceId : null;
      _micId ??= _mics.isNotEmpty ? _mics.first.deviceId : null;
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
      // Device labels become available once permission is granted.
      await _refreshDevices();
    } catch (_) {
      _camOn = false;
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
    if (!_inLobby && _micOn) {
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
      await _room.localParticipant?.setScreenShareEnabled(_screenOn);
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
      out.add(_VideoSource(participant: p, video: camera, isScreen: false));
      if (screen != null) {
        out.add(_VideoSource(participant: p, video: screen, isScreen: true));
      }
    }
    return out;
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
                          : const Center(
                              child: Icon(
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
                  const SizedBox(height: 18),
                  _deviceDropdown(
                    Icons.videocam_outlined,
                    _cameras,
                    _cameraId,
                    _selectCamera,
                  ),
                  _deviceDropdown(Icons.mic_none, _mics, _micId, _selectMic),
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

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Devices',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _deviceDropdown(
                    Icons.videocam_outlined,
                    _cameras,
                    _cameraId,
                    pickCam,
                  ),
                  _deviceDropdown(Icons.mic_none, _mics, _micId, pickMic),
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

    // When someone is sharing their screen, feature it as the main stage and
    // drop everyone else into a thumbnail strip below — far clearer than an
    // equal grid where the screen is just another small tile.
    _VideoSource? screen;
    for (final _VideoSource s in sources) {
      if (s.isScreen) {
        screen = s;
        break;
      }
    }
    if (screen != null) {
      final _VideoSource featured = screen;
      final List<_VideoSource> thumbs = <_VideoSource>[
        for (final _VideoSource s in sources)
          if (!identical(s, featured)) s,
      ];
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: <Widget>[
            Expanded(
              child: _ParticipantTile(
                participant: featured.participant,
                video: featured.video,
                isScreen: true,
              ),
            ),
            if (thumbs.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              SizedBox(
                height: 112,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: thumbs.length,
                  separatorBuilder: (BuildContext context, int i) =>
                      const SizedBox(width: 12),
                  itemBuilder: (BuildContext context, int i) => AspectRatio(
                    aspectRatio: 4 / 3,
                    child: _ParticipantTile(
                      participant: thumbs[i].participant,
                      video: thumbs[i].video,
                      isScreen: thumbs[i].isScreen,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

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
        children: <Widget>[
          for (final _VideoSource s in sources)
            _ParticipantTile(
              participant: s.participant,
              video: s.video,
              isScreen: s.isScreen,
            ),
        ],
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
  });
  final Participant participant;
  final VideoTrack? video;
  final bool isScreen;

  @override
  Widget build(BuildContext context) {
    final String baseName = participant.name.isNotEmpty
        ? participant.name
        : participant.identity;
    final String name = isScreen ? '$baseName · Screen' : baseName;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF1A2238),
        borderRadius: BorderRadius.circular(14),
        border: participant.isSpeaking
            ? Border.all(color: const Color(0xFF22C55E), width: 2)
            : null,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (video != null)
            VideoTrackRenderer(
              video!,
              fit: isScreen ? VideoViewFit.contain : VideoViewFit.cover,
            )
          else
            Center(child: UserAvatar(name: baseName, radius: 34)),
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
