import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Prompts the browser to pick a screen/window/tab via getDisplayMedia, grabs a
/// single frame, and returns it as PNG bytes. Returns null if the user cancels
/// or capture is unavailable.
Future<Uint8List?> captureScreen() async {
  try {
    final web.MediaStream stream = await web.window.navigator.mediaDevices
        .getDisplayMedia(web.DisplayMediaStreamOptions(video: true.toJS))
        .toDart;

    final web.HTMLVideoElement video = web.HTMLVideoElement()
      ..srcObject = stream
      ..muted = true;
    await video.play().toDart;
    // Give the stream a moment to deliver a frame.
    await Future<void>.delayed(const Duration(milliseconds: 350));

    final int w = video.videoWidth;
    final int h = video.videoHeight;
    final web.HTMLCanvasElement canvas = web.HTMLCanvasElement()
      ..width = w
      ..height = h;
    final web.CanvasRenderingContext2D ctx =
        canvas.getContext('2d')! as web.CanvasRenderingContext2D;
    ctx.drawImage(video, 0, 0);

    // Stop sharing immediately after the snapshot.
    final JSArray<web.MediaStreamTrack> tracks = stream.getTracks();
    for (int i = 0; i < tracks.length; i++) {
      tracks[i].stop();
    }

    final String dataUrl = canvas.toDataURL('image/png');
    final int comma = dataUrl.indexOf(',');
    if (comma < 0) {
      return null;
    }
    return base64Decode(dataUrl.substring(comma + 1));
  } catch (_) {
    return null;
  }
}
