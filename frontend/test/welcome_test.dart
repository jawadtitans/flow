import 'dart:async';
import 'package:flow_app/core/network/api_client.dart';
import 'package:flow_app/core/storage/session_storage.dart';

import 'package:flow_app/app/app.dart';
import 'package:flow_app/app/router/app_router.dart';
import 'package:flow_app/app/startup/startup_screen.dart';
import 'package:flow_app/features/welcome/presentation/welcome_avatar.dart';
import 'package:flow_app/features/welcome/presentation/welcome_page.dart';
import 'package:flow_app/features/welcome/welcome_controller.dart';
import 'package:flow_app/shared/widgets/flow_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

final appRouter = createAppRouter();

void main() {
  late _VideoPlatform video;
  final originalVideoPlatform = VideoPlayerPlatform.instance;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    video = _VideoPlatform();
    VideoPlayerPlatform.instance = video;
  });

  tearDown(() {
    VideoPlayerPlatform.instance = originalVideoPlatform;
  });

  Future<SharedPreferences> openWelcome(
    WidgetTester tester, {
    String route = '/welcome',
    Size size = const Size(390, 844),
    double textScale = 1,
    ValueNotifier<bool>? reducedMotion,
    SharedPreferences? storage,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    storage ??= await SharedPreferences.getInstance();
    appRouter.go(route);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          welcomeStorageProvider.overrideWithValue(storage),
          sessionStorageProvider.overrideWithValue(MemorySessionStorage()),
        ],
        child: ValueListenableBuilder<bool>(
          valueListenable: reducedMotion ?? const AlwaysStoppedAnimation(false),
          builder: (context, reduced, child) => MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(textScale),
              disableAnimations: reduced,
            ),
            child: FlowApp(router: appRouter),
          ),
        ),
      ),
    );
    await tester.pump();
    return storage;
  }

  Future<void> closeWelcome(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
  }

  Finder phrase(String text) => find.descendant(
    of: find.byType(AnimatedSwitcher),
    matching: find.text(text),
  );

  testWidgets('first launch leaves splash for welcome without internet', (
    tester,
  ) async {
    final storage = await openWelcome(tester, route: '/');
    expect(find.byType(StartupScreen), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2900));
    expect(find.byType(StartupScreen), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 101));
    await tester.pumpAndSettle();
    expect(find.byType(WelcomePage), findsOneWidget);
    expect(appRouter.routeInformationProvider.value.uri.path, '/welcome');
    expect(find.byType(FlowBottomNavigation), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(storage.getBool(WelcomeController.completedKey), isNull);
    await closeWelcome(tester);
  });

  testWidgets('Get started persists welcome completion and opens sign in', (
    tester,
  ) async {
    final storage = await openWelcome(tester);
    await tester.pumpAndSettle();
    final button = find.widgetWithText(FilledButton, 'Get started');
    expect(tester.getRect(button).bottom, closeTo(824, 1));
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(appRouter.routeInformationProvider.value.uri.path, '/auth');
    expect(find.text('Welcome to Flow'), findsOneWidget);
    expect(find.byType(FlowBottomNavigation), findsNothing);
    expect(storage.getBool(WelcomeController.completedKey), isTrue);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(video.disposed, isTrue);

    final restored = ProviderContainer(
      overrides: [
        welcomeStorageProvider.overrideWithValue(storage),
        sessionStorageProvider.overrideWithValue(MemorySessionStorage()),
      ],
    );
    expect(restored.read(welcomeControllerProvider), isTrue);
    restored.dispose();
    await closeWelcome(tester);
  });

  testWidgets(
    'a returning signed-out user opens sign in without an internet probe',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        WelcomeController.completedKey: true,
      });
      await openWelcome(tester, route: '/');
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.byType(WelcomePage), findsNothing);
      expect(find.text('Welcome to Flow'), findsOneWidget);
      expect(appRouter.routeInformationProvider.value.uri.path, '/auth');
      await closeWelcome(tester);
    },
  );

  testWidgets(
    'video loops muted, pauses in background and obeys reduced motion',
    (tester) async {
      final reduced = ValueNotifier(false);
      addTearDown(reduced.dispose);
      await openWelcome(tester, reducedMotion: reduced);
      await tester.pumpAndSettle();
      expect(video.asset, 'assets/welcome/flow-avatar.mp4');
      expect(video.looping, isTrue);
      expect(video.volume, 0);
      expect(video.playing, isTrue);
      expect(find.byType(VideoPlayer), findsOneWidget);
      final avatarTop = tester.getTopLeft(find.byType(WelcomeAvatar)).dy;

      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 450));
      expect(phrase('organizes your tasks'), findsOneWidget);
      expect(tester.getTopLeft(find.byType(WelcomeAvatar)).dy, avatarTop);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(video.playing, isFalse);
      await tester.pump(const Duration(seconds: 4));
      expect(phrase('organizes your tasks'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(video.playing, isTrue);

      reduced.value = true;
      await tester.pump();
      expect(video.playing, isFalse);
      expect(find.byType(VideoPlayer), findsNothing);
      await tester.pump(const Duration(seconds: 4));
      expect(phrase('organizes your tasks'), findsOneWidget);
      await closeWelcome(tester);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      expect(video.disposed, isTrue);
    },
  );

  testWidgets('each animated phrase ends with its matching supplied icon', (
    tester,
  ) async {
    await openWelcome(tester);
    await tester.pumpAndSettle();
    for (final entry in [
      ('plans your day', 'plans-your-day.png'),
      ('organizes your tasks', 'organizes-your-tasks.png'),
      ('keeps you focused', 'keeps-you-focused.png'),
      ('gets things done', 'gets-things-done.png'),
    ]) {
      expect(phrase(entry.$1), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AnimatedSwitcher),
          matching: find.image(AssetImage('assets/welcome/icons/${entry.$2}')),
        ),
        findsOneWidget,
      );
      if (entry.$2 != 'gets-things-done.png') {
        await tester.pump(const Duration(seconds: 3));
        await tester.pump(const Duration(milliseconds: 450));
      }
    }
    await closeWelcome(tester);
  });

  testWidgets('failed video falls back to the poster with a usable button', (
    tester,
  ) async {
    video.fail = true;
    await openWelcome(tester);
    await tester.pumpAndSettle();
    expect(find.byType(VideoPlayer), findsNothing);
    expect(
      find.image(const AssetImage('assets/welcome/flow-avatar.jpg')),
      findsOneWidget,
    );
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(appRouter.routeInformationProvider.value.uri.path, '/auth');
    await closeWelcome(tester);
  });

  testWidgets('small landscape and large text keep Get started reachable', (
    tester,
  ) async {
    final reduced = ValueNotifier(true);
    addTearDown(reduced.dispose);
    await openWelcome(
      tester,
      size: const Size(568, 320),
      textScale: 2,
      reducedMotion: reduced,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(video.asset, isNull);
    await tester.scrollUntilVisible(find.text('Get started'), 150);
    await tester.pumpAndSettle();
    expect(find.text('Get started').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(appRouter.routeInformationProvider.value.uri.path, '/auth');
    await closeWelcome(tester);
  });

  testWidgets('a failed save stays on welcome and can be retried', (
    tester,
  ) async {
    final storage = _FailingPreferences();
    await openWelcome(tester, storage: storage);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(appRouter.routeInformationProvider.value.uri.path, '/welcome');
    expect(
      find.text('Couldn’t save your progress. Try again.'),
      findsOneWidget,
    );
    expect(storage.completed, isFalse);
    storage.fail = false;
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(appRouter.routeInformationProvider.value.uri.path, '/auth');
    expect(storage.completed, isTrue);
    await closeWelcome(tester);
  });
}

class _FailingPreferences extends Fake implements SharedPreferences {
  bool fail = true;
  bool completed = false;

  @override
  bool? getBool(String key) => completed;

  @override
  Future<bool> setBool(String key, bool value) async {
    if (fail) return false;
    completed = value;
    return true;
  }
}

class _VideoPlatform extends VideoPlayerPlatform {
  late final StreamController<VideoEvent> _events;
  String? asset;
  bool fail = false;
  bool looping = false;
  bool playing = false;
  bool disposed = false;

  double volume = 1;

  @override
  Future<void> init() async {}

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    _events = StreamController<VideoEvent>();
    asset = options.dataSource.asset;
    if (fail) {
      _events.addError(
        PlatformException(code: 'video', message: 'Unavailable'),
      );
    } else {
      _events.add(
        VideoEvent(
          eventType: VideoEventType.initialized,
          duration: const Duration(seconds: 4),
          size: const Size(384, 384),
        ),
      );
    }
    return 1;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => _events.stream;

  @override
  Future<void> dispose(int playerId) async {
    disposed = true;
    await _events.close();
  }

  @override
  Future<void> play(int playerId) async => playing = true;

  @override
  Future<void> pause(int playerId) async => playing = false;

  @override
  Future<void> setLooping(int playerId, bool value) async => looping = value;

  @override
  Future<void> setVolume(int playerId, double value) async => volume = value;

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const ColoredBox(color: Colors.blue);
}
