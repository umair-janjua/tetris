// Renders the app icon and splash artwork with Flutter's own canvas, so the
// marks use exactly the same crystal-cell styling as the game board.
//
// Run with:
//   flutter test tool/generate_icons.dart
//
// Outputs (all regenerated from scratch):
//   assets/icon/app_icon.png              1024²  opaque   – iOS/web/macOS/store
//   assets/icon/app_icon_foreground.png   1024²  alpha    – Android adaptive fg
//   assets/icon/splash_logo.png           1024²  alpha    – legacy splash
//   assets/icon/splash_logo_android12.png 1152²  alpha    – Android 12 splash

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// ── Brand palette (mirrors lib/theme/app_theme.dart) ─────────────────────────
const _cyan    = Color(0xFF00E5FF); // I
const _purple  = Color(0xFFD500F9); // T
const _emerald = Color(0xFF00E676); // S
const _amber   = Color(0xFFFF9100); // L
const _deepTop = Color(0xFF131F3A);
const _deepBot = Color(0xFF080D1A);

// ═════════════════════════════════════════════════════════════════════════════
// DRAWING
// ═════════════════════════════════════════════════════════════════════════════

/// One isometric neon cube, anchored by the centre of its top face.
///
/// Light reads from the upper left: the top face is brightest, the left face
/// mid-tone and the right face deepest, which is what gives the mark its
/// solidity at small sizes.
void _drawIsoCube(Canvas canvas, Offset c, double hw, double dz, Color color) {
  final hh = hw / 2; // 2:1 isometric

  Path face(List<Offset> pts) {
    final p = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final o in pts.skip(1)) {
      p.lineTo(o.dx, o.dy);
    }
    return p..close();
  }

  final topFace = face([
    Offset(c.dx, c.dy - hh),
    Offset(c.dx + hw, c.dy),
    Offset(c.dx, c.dy + hh),
    Offset(c.dx - hw, c.dy),
  ]);
  final leftFace = face([
    Offset(c.dx - hw, c.dy),
    Offset(c.dx, c.dy + hh),
    Offset(c.dx, c.dy + hh + dz),
    Offset(c.dx - hw, c.dy + dz),
  ]);
  final rightFace = face([
    Offset(c.dx + hw, c.dy),
    Offset(c.dx, c.dy + hh),
    Offset(c.dx, c.dy + hh + dz),
    Offset(c.dx + hw, c.dy + dz),
  ]);

  final silhouette = Path.combine(
    PathOperation.union,
    topFace,
    Path.combine(PathOperation.union, leftFace, rightFace),
  );

  // Neon bloom radiating from the whole cube.
  canvas.drawPath(
    silhouette,
    Paint()
      ..color = color.withValues(alpha: 0.80)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, hw * 0.42),
  );

  Color lift(double t) => Color.lerp(color, Colors.white, t)!;
  Color drop(double t) => Color.lerp(color, Colors.black, t)!;

  // Faces, brightest to deepest.
  canvas.drawPath(
    topFace,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [lift(0.46), lift(0.10)],
      ).createShader(topFace.getBounds()),
  );
  canvas.drawPath(
    leftFace,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [drop(0.04), drop(0.30)],
      ).createShader(leftFace.getBounds()),
  );
  canvas.drawPath(
    rightFace,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [drop(0.34), drop(0.60)],
      ).createShader(rightFace.getBounds()),
  );

  // Bright rim around the silhouette plus the three edges meeting at the
  // front corner — this is what makes it read as neon rather than as a flat
  // shaded polygon.
  final edge = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = hw * 0.042
    ..strokeJoin = StrokeJoin.round
    ..color = lift(0.60).withValues(alpha: 0.92);
  canvas.drawPath(silhouette, edge);
  canvas.drawPath(topFace, edge);
  canvas.drawLine(
    Offset(c.dx, c.dy + hh),
    Offset(c.dx, c.dy + hh + dz),
    edge,
  );

  // Glass highlight sliding across the top face.
  canvas.drawPath(
    face([
      Offset(c.dx, c.dy - hh * 0.72),
      Offset(c.dx + hw * 0.66, c.dy - hh * 0.04),
      Offset(c.dx + hw * 0.40, c.dy + hh * 0.20),
      Offset(c.dx - hw * 0.26, c.dy - hh * 0.42),
    ]),
    Paint()..color = Colors.white.withValues(alpha: 0.20),
  );
}

/// The Cubicles mark: four isometric cubes stacked as a 2x2 plate, which reads
/// as a single solid diamond. Centred horizontally on [center], spanning
/// [size] across.
void _drawMark(
  Canvas canvas,
  Offset center,
  double size, {
  double bloom = 0.5,
  bool halo = true,
}) {
  // Cubes sit on an isometric grid stretched by [spread] so they float apart
  // as four distinct cubes instead of fusing into a single slab.
  const spread = 1.30;
  final hw = size / (2 * (spread + 1));
  final hh = hw / 2;
  final dz = hw * 0.92;

  // Total height of the cluster, used to centre it vertically.
  final height = hh * (2 * spread + 1) + dz;
  final originY = center.dy - height / 2 + hh;

  // Wide ambient halo so the cluster sits in its own light. Only worth it on
  // the opaque tile: on a transparent export it reads as a faint grey disc,
  // and its huge low-contrast gradient roughly triples the PNG size.
  if (halo) {
    canvas.drawCircle(
      center,
      size * 0.52,
      Paint()
        ..color = const Color(0xFF0EA5E9).withValues(alpha: bloom * 0.30)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size * 0.26),
    );
  }

  // Painter's algorithm: back (col+row smallest) to front.
  const cells = [
    (0, 0, _cyan),    // back
    (0, 1, _emerald), // left
    (1, 0, _purple),  // right
    (1, 1, _amber),   // front
  ];
  for (final (col, row, color) in cells) {
    _drawIsoCube(
      canvas,
      Offset(
        center.dx + (col - row) * hw * spread,
        originY + (col + row) * hh * spread,
      ),
      hw,
      dz,
      color,
    );
  }
}

/// Dark navy ground with a soft accent halo and a faint 12-column board grid.
void _drawBackground(Canvas canvas, double s) {
  final full = Rect.fromLTWH(0, 0, s, s);

  canvas.drawRect(
    full,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_deepTop, _deepBot],
      ).createShader(full),
  );

  // Accent halo behind the mark.
  canvas.drawRect(
    full,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.10),
        radius: 0.85,
        colors: [
          const Color(0xFF0EA5E9).withValues(alpha: 0.26),
          Colors.transparent,
        ],
      ).createShader(full),
  );

  // Faint board grid — 12 columns, echoing the playfield.
  final grid = Paint()
    ..color = Colors.white.withValues(alpha: 0.030)
    ..strokeWidth = s * 0.0022;
  final step = s / 12;
  for (int i = 1; i < 12; i++) {
    canvas.drawLine(Offset(i * step, 0), Offset(i * step, s), grid);
    canvas.drawLine(Offset(0, i * step), Offset(s, i * step), grid);
  }
}

/// The CUBICLES wordmark, gradient-filled and centred on [center].
void _drawWordmark(Canvas canvas, Offset center, double fontSize) {
  final painter = TextPainter(
    text: TextSpan(
      text: 'CUBICLES',
      style: TextStyle(
        fontFamily: 'Outfit',
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        letterSpacing: fontSize * 0.14,
        color: Colors.white,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  // letterSpacing pads the trailing glyph, so trim it when centring.
  final w = painter.width - fontSize * 0.14;
  final origin = Offset(center.dx - w / 2, center.dy - painter.height / 2);
  final bounds = origin & Size(w, painter.height);

  // Glow pass behind the letters.
  canvas.saveLayer(
    bounds.inflate(fontSize),
    Paint()
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, fontSize * 0.22)
      ..colorFilter = ColorFilter.mode(
        _cyan.withValues(alpha: 0.55),
        BlendMode.srcIn,
      ),
  );
  painter.paint(canvas, origin);
  canvas.restore();

  // Gradient fill pass.
  canvas.saveLayer(bounds, Paint());
  painter.paint(canvas, origin);
  canvas.drawRect(
    bounds,
    Paint()
      ..blendMode = BlendMode.srcIn
      ..shader = const LinearGradient(
        colors: [_cyan, Color(0xFF22C55E), _cyan],
      ).createShader(bounds),
  );
  canvas.restore();
}

// ═════════════════════════════════════════════════════════════════════════════
// OUTPUT
// ═════════════════════════════════════════════════════════════════════════════

Future<void> _render(
  String path,
  double size,
  void Function(Canvas canvas) draw,
) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size, size));
  draw(canvas);
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.round(), size.round());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
  final kb = (File(path).lengthSync() / 1024).toStringAsFixed(0);
  // ignore: avoid_print
  print('  wrote $path  (${size.round()}², ${kb}KB)');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generate icon and splash artwork', () async {
    // The wordmark needs the bundled family; tests don't load assets by default.
    final ttf = File('assets/fonts/Outfit-900.ttf').readAsBytesSync();
    await (FontLoader('Outfit')
          ..addFont(Future.value(ByteData.view(ttf.buffer))))
        .load();

    // ── App icon: opaque, mark at 60% ─────────────────────────────────────
    await _render('assets/icon/app_icon.png', 1024, (canvas) {
      _drawBackground(canvas, 1024);
      _drawMark(canvas, const Offset(512, 512), 1024 * 0.72);
    });

    // ── Adaptive foreground: transparent.
    // flutter_launcher_icons wraps this in `<inset android:inset="16%">`, so
    // the art only covers the middle 68% of the 108dp layer. To land the mark
    // at ~44dp — just inside the 66dp safe circle, whose inscribed square is
    // 46.7dp — it has to be 60% of this canvas, not 46%.
    await _render('assets/icon/app_icon_foreground.png', 1024, (canvas) {
      _drawMark(canvas, const Offset(512, 512), 1024 * 0.60, bloom: 0.42, halo: false);
    });

    // ── Legacy splash: mark + wordmark, transparent ───────────────────────
    await _render('assets/icon/splash_logo.png', 1024, (canvas) {
      _drawMark(canvas, const Offset(512, 400), 1024 * 0.52, halo: false);
      _drawWordmark(canvas, const Offset(512, 790), 108);
    });

    // ── Android 12 splash: mark only. 1152² with content inside a 768px
    // circle → a square mark may be at most ~47% wide.
    await _render('assets/icon/splash_logo_android12.png', 1152, (canvas) {
      _drawMark(canvas, const Offset(576, 576), 1152 * 0.45, bloom: 0.42, halo: false);
    });
  });
}
