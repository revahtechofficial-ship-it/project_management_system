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
  bool _connecting = true;
  String? _error;
  bool _micOn = true;
  bool _camOn = false;
  bool _screenOn = false;

  @override
  void initState() {
    super.initState();
    _room.addListener(_onChange);
    _connect();
  }

  void _onChange() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _connect() async {
    try {
      await _room.connect(widget.url, widget.token);
      await _room.localParticipant?.setMicrophoneEnabled(true);
      if (widget.mode == 'video') {
        await _room.localParticipant?.setCameraEnabled(true);
        _camOn = true;
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
    await _room.localParticipant?.setMicrophoneEnabled(_micOn);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _toggleCam() async {
    _camOn = !_camOn;
    await _room.localParticipant?.setCameraEnabled(_camOn);
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
    _room.removeListener(_onChange);
    _room.dispose();
    super.dispose();
  }

  List<Participant> get _participants => <Participant>[
        if (_room.localParticipant != null) _room.localParticipant!,
        ..._room.remoteParticipants.values,
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _header(),
            Expanded(child: _grid()),
            _controls(),
          ],
        ),
      ),
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
                    fontWeight: FontWeight.w700),
              ),
            ),
            Text('${_participants.length} in call',
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
      );

  Widget _grid() {
    if (_connecting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Could not join the call.\n$_error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70)),
        ),
      );
    }
    final List<Participant> people = _participants;
    final int cols = people.length <= 1
        ? 1
        : people.length <= 4
            ? 2
            : 3;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: GridView.count(
        crossAxisCount: cols,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 4 / 3,
        children: <Widget>[
          for (final Participant p in people) _ParticipantTile(participant: p),
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

class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile({required this.participant});
  final Participant participant;

  VideoTrack? get _videoTrack {
    for (final TrackPublication<Track> pub
        in participant.videoTrackPublications) {
      final Track? t = pub.track;
      if (t is VideoTrack) {
        return t;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final VideoTrack? video = _videoTrack;
    final String name =
        participant.name.isNotEmpty ? participant.name : participant.identity;
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
            VideoTrackRenderer(video, fit: VideoViewFit.cover)
          else
            Center(child: UserAvatar(name: name, radius: 34)),
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
                      child: Icon(Icons.mic_off,
                          color: Colors.redAccent, size: 14),
                    ),
                  Text(name,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12)),
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
