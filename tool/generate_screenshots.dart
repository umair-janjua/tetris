// Renders store screenshots from the real app widgets at exact store
// dimensions, with a staged board so the stats and playfield look like a
// genuine session rather than whatever a random automated playthrough produced.
//
// Run with:
//   flutter test tool/generate_screenshots.dart
//
// Outputs into store/screenshots/play (1080x1920, the 9:16 Play Store accepts)
// and store/screenshots/ios (1290x2796, iPhone 6.7").

import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cubicles/engine/game_engine.dart';
import 'package:cubicles/models/tetromino.dart';
import 'package:cubicles/providers/game_provider.dart';
import 'package:cubicles/providers/settings_provider.dart';
import 'package:cubicles/screens/game_screen.dart';
import 'package:cubicles/screens/start_screen.dart';
import 'package:cubicles/services/audio_service.dart';
import 'package:cubicles/theme/app_theme.dart';

// ── Target devices ───────────────────────────────────────────────────────────

class _Target {
  final String dir;
  final Size pixels;
  final double dpr;
  const _Target(this.dir, this.pixels, this.dpr);
}

const _targets = [
  // Play Store phone: 9:16. A real 1080x2400 handset capture is 9:20 and is
  // rejected for aspect ratio, which is why these are rendered, not captured.
  _Target('play', Size(1080, 1920), 2.75),
  // App Store 6.7" iPhone.
  _Target('ios', Size(1290, 2796), 3.0),
];

// ── Staged game state ────────────────────────────────────────────────────────

/// Fills the engine with a convincing mid-game position: an uneven, colourful
/// stack with a deliberate one-column well, and a vertical I-piece lined up
/// over it. Column 9 is always empty, which guarantees no row is accidentally
/// complete (a full row would be inconsistent — it would have been cleared).
void _stageBoard(GameEngine e) {
  // Reset first: the engine may hold state from the previous shot, and this
  // also creates the `late` board when staging runs before the provider's
  // async _loadHighScore has initialized the engine.
  e.initialize(savedHighScore: 21350);

  const heights = [7, 8, 10, 9, 11, 9, 8, 6, 9, 0, 8, 6];
  final rng = Random(7);

  for (int c = 0; c < GameEngine.boardCols; c++) {
    for (int i = 0; i < heights[c]; i++) {
      final r = GameEngine.boardRows - 1 - i;
      e.board[r][c] = rng.nextInt(7) + 1;
    }
  }
  e.boardVersion++;

  e.score = 12480;
  e.highScore = 21350;
  e.linesCleared = 42;
  e.level = 5; // 42 ~/ 10 + 1
  e.nextPieceType = TetrominoType.T;
  e.holdPieceType = TetrominoType.O;
  e.canHold = true;

  // Vertical I: rotation 1 puts its cells at col + 2, so col 7 drops into the
  // well at column 9. The ghost renders all the way down the well.
  e.currentPiece = const ActivePiece(
    type: TetrominoType.I,
    row: 1,
    col: 7,
    rotation: 1,
  );
  e.status = GameStatus.playing;
}

// ── Harness ──────────────────────────────────────────────────────────────────

/// Mocks the plugins the widget tree touches so nothing needs a real device.
void _mockPlugins() {
  SharedPreferences.setMockInitialValues({'cubicles_high_score': 21350});

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final name in [
    'xyz.luan/audioplayers',
    'xyz.luan/audioplayers.global',
  ]) {
    messenger.setMockMethodCallHandler(MethodChannel(name), (call) async => null);
  }
}

/// One shared provider set for the whole run.
///
/// Constructed exactly once: every [AudioService] creates seven AudioPlayers
/// whose event channels have no test implementation, and constructing a second
/// batch wedges the fake-async microtask queue — `tester.idle()` never
/// returns. Staging fully overwrites the engine state between shots, so one
/// set is all that's needed.
late final SettingsProvider _settings;
late final AudioService _audio;
late final GameProvider _provider;

Future<void> _shoot(
  WidgetTester tester,
  _Target target,
  String name,
  Widget Function(GameProvider provider) home, {
  ThemeMode themeMode = ThemeMode.dark,
  void Function(GameProvider provider)? stage,
}) async {
  // ignore: avoid_print
  print('  [$name] setup');
  tester.view.physicalSize = target.pixels;
  tester.view.devicePixelRatio = target.dpr;
  addTearDown(tester.view.reset);

  final settings = _settings;
  final audio = _audio;
  final provider = _provider;

  // Stage before the first build so the tree renders the staged state without
  // needing a notification (and without starting the gravity timer).
  stage?.call(provider);

  final key = GlobalKey();
  await tester.pumpWidget(
    RepaintBoundary(
      key: key,
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<AudioService>.value(value: audio),
          ChangeNotifierProvider<GameProvider>.value(value: provider),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          home: home(provider),
        ),
      ),
    ),
  );

  // ignore: avoid_print
  print('  [$name] pumped, settling');
  // Settle entrance animations without letting any repeating animation hang.
  for (int i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }

  // ignore: avoid_print
  print('  [$name] settled, capturing');
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: target.dpr);
  // ignore: avoid_print
  print('  [$name] toImage done, encoding');
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

  final dir = Directory('store/screenshots/${target.dir}');
  dir.createSync(recursive: true);
  final file = File('${dir.path}/$name.png')
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
  // ignore: avoid_print
  print('  ${file.path}  ${image.width}x${image.height}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(_mockPlugins);

  testWidgets('generate store screenshots', (tester) async {
    final ttf = <String, ByteData>{};
    for (final w in [400, 600, 700, 800, 900]) {
      final b = File('assets/fonts/Outfit-$w.ttf').readAsBytesSync();
      ttf['$w'] = ByteData.view(b.buffer);
    }
    final loader = FontLoader('Outfit');
    for (final b in ttf.values) {
      loader.addFont(Future.value(b));
    }
    await loader.load();

    // `flutter test` runs with --disable-asset-fonts, so MaterialIcons is not
    // available and every Icon renders as a hollow box. Load it from the SDK.
    final flutterRoot = Platform.environment['FLUTTER_ROOT']!;
    final icons = File(
      '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ).readAsBytesSync();
    await (FontLoader('MaterialIcons')
          ..addFont(Future.value(ByteData.view(icons.buffer))))
        .load();

    _settings = SettingsProvider();
    _audio = AudioService(settings: _settings);
    _provider = GameProvider(audio: _audio, settings: _settings);
    // Let the providers' async init (SharedPreferences loads, engine
    // initialize) finish before any staging or rendering.
    await tester.idle();

    for (final target in _targets) {
      // ignore: avoid_print
      print('${target.dir}:');

      await _shoot(
        tester,
        target,
        '02_gameplay',
        (_) => const GameScreen(),
        stage: (p) => _stageBoard(p.engine),
      );

      await _shoot(
        tester,
        target,
        '03_gameplay_light',
        (_) => const GameScreen(),
        themeMode: ThemeMode.light,
        stage: (p) => _stageBoard(p.engine),
      );

      await _shoot(
        tester,
        target,
        '04_paused',
        (_) => const GameScreen(),
        stage: (p) {
          _stageBoard(p.engine);
          p.engine.status = GameStatus.paused;
        },
      );

      await _shoot(
        tester,
        target,
        '05_game_over',
        (_) => const GameScreen(),
        stage: (p) {
          _stageBoard(p.engine);
          p.engine.score = 21350;
          p.engine.status = GameStatus.gameOver;
          p.engine.currentPiece = null;
        },
      );

      // StartScreen last: rendering any shot after a StartScreen tree has
      // been mounted wedges the fake-async event loop (cause not yet
      // pinned down), so it must not precede the GameScreen shots.
      await _shoot(tester, target, '01_start', (_) => const StartScreen());
    }
  });
}
