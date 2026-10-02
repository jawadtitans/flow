import 'dart:convert';
import 'dart:io';

import 'package:flow_app/app/router/app_router.dart';
import 'package:flow_app/app/theme/app_theme.dart';
import 'package:flow_app/core/network/api_client.dart';
import 'package:flow_app/features/auth/auth_controller.dart';
import 'package:flow_app/features/auth/presentation/onboarding_pages.dart';
import 'package:flow_app/features/settings/settings_controller.dart';
import 'package:flow_app/shared/widgets/flow_notification.dart';
import 'package:flutter/material.dart';
import 'package:flow_app/l10n/app_localizations.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_auth_api.dart';

void main() {
  testWidgets('intro words reveal once and do not replay on rebuild', (
    tester,
  ) async {
    var completed = 0;
    Widget page() => MaterialApp(
      home: Scaffold(
        body: WordReveal(
          text: 'Hello Amina Ahmadi',
          onComplete: () => completed++,
        ),
      ),
    );
    await tester.pumpWidget(page());
    final text = find.descendant(
      of: find.byType(WordReveal),
      matching: find.byType(Text),
    );
    List<InlineSpan> words() =>
        (tester.widget<Text>(text).textSpan as TextSpan).children!;
    expect(words().first.style!.color!.a, 0);
    await tester.pump(const Duration(milliseconds: 160));
    expect(words().first.style!.color!.a, greaterThan(0));
    expect(words().last.style!.color!.a, 0);
    await tester.pump(const Duration(seconds: 2));
    expect(completed, 1);
    await tester.pumpWidget(page());
    await tester.pump(const Duration(seconds: 2));
    expect(completed, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  Future<ProviderContainer> open(
    WidgetTester tester,
    FakeAuthApi api,
    String route, {
    Size size = const Size(390, 844),
    double textScale = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    late ProviderContainer container;
    await tester.runAsync(() async {
      final client = api.client();
      container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(client),
          settingsStorageProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(client.close);
      final auth = container.read(authControllerProvider.notifier);
      await auth.requestAccess('hello@flow.example');
      await auth.verifyOtp('123456');
    });
    final router = createAppRouter(
      initialLocation: route,
      redirect: (_, state) =>
          authRedirect(container.read(authControllerProvider), state.uri.path),
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: flowLightTheme,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: true,
              textScaler: TextScaler.linear(textScale),
            ),
            child: FlowNotificationHost(child: child!),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.pump();
    if (finder.evaluate().isEmpty) await tester.scrollUntilVisible(finder, 120);
    await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
    await tester.runAsync(() async {
      await tester.tap(finder);
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pumpAndSettle();
  }

  testWidgets('signup password confirmation saves only matching passwords', (
    tester,
  ) async {
    final api = FakeAuthApi(onboardingCompleted: false);
    final container = await open(tester, api, '/auth/set-password');
    Finder input(String key) => find.descendant(
      of: find.byKey(ValueKey(key)),
      matching: find.byType(TextField),
    );
    await tester.enterText(input('signup-password'), 'my-long-password');
    await tester.enterText(input('signup-confirm-password'), 'does-not-match');
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
          .onPressed,
      isNull,
    );
    await tester.enterText(
      input('signup-confirm-password'),
      'my-long-password',
    );
    await tap(tester, find.widgetWithText(FilledButton, 'Continue'));
    expect(container.read(authControllerProvider).user!.hasPassword, isTrue);
    expect(find.text('Finish creating your account'), findsOneWidget);
    expect(api.requests.where((r) => r.path == 'auth/set-password').length, 1);
    await tester.enterText(input('profile-first-name'), 'Amina');
    await tester.enterText(input('profile-last-name'), 'Ahmadi');
    await tap(tester, input('profile-birthday'));
    expect(find.byType(CupertinoDatePicker), findsOneWidget);
    await tap(tester, find.text('Done'));
    await tap(tester, find.widgetWithText(FilledButton, 'Confirm'));
    expect(find.text('How did you find us?'), findsOneWidget);
    expect(
      container.read(authControllerProvider).user!.onboardingCompleted,
      isFalse,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'discovery and interests persist then introductions lead through getting ready',
    (tester) async {
      final api = FakeAuthApi(
        hasPassword: true,
        profileCompleted: true,
        onboardingCompleted: false,
      );
      api.user['first_name'] = 'Amina';
      api.user['last_name'] = 'Ahmadi';
      final container = await open(tester, api, '/auth/onboarding');
      await tap(tester, find.text('Instagram'));
      await tap(tester, find.widgetWithText(FilledButton, 'Continue'));
      expect(find.text('What catches your interest?'), findsOneWidget);
      expect(interestChoices.length, 16);
      await tap(tester, find.text('Technology'));
      await tap(tester, find.text('Other'));
      await tester.enterText(
        find.byKey(const ValueKey('other-interest')),
        'Architecture',
      );
      await tap(tester, find.widgetWithText(FilledButton, 'Continue'));
      expect(api.user['discovery_source'], 'Instagram');
      expect(api.user['interests'], ['Technology', 'Other']);
      expect(api.user['other_interest'], 'Architecture');
      expect(api.user['onboarding_completed'], isFalse);
      expect(find.byType(WordReveal), findsOneWidget);
      expect(
        tester.widget<WordReveal>(find.byType(WordReveal)).text,
        contains('Amina Ahmadi'),
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      await tap(tester, find.text("Let's get started"));
      expect(
        container.read(authControllerProvider).user!.onboardingCompleted,
        isTrue,
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.byType(IntroductionPage), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'logout can be cancelled and deletion requires all three confirmations',
    (tester) async {
      final api = FakeAuthApi(hasPassword: true, profileCompleted: true);
      final container = await open(tester, api, '/settings');
      await tap(tester, find.text('Log out'));
      expect(find.text('Log out of Flow?'), findsOneWidget);
      await tap(tester, find.text('Cancel'));
      expect(api.requests.where((r) => r.path == 'auth/logout'), isEmpty);
      await tap(tester, find.text('Delete account'));
      await tap(tester, find.text('Delete'));
      await tester.enterText(
        find.byKey(const ValueKey('delete-account-confirmation')),
        'delete',
      );
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Continue deletion'),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(
        find.byKey(const ValueKey('delete-account-confirmation')),
        'Delete',
      );
      await tap(tester, find.text('Continue deletion'));
      expect(api.requests.where((r) => r.method == 'DELETE'), isEmpty);
      expect(find.text('Confirm permanent deletion'), findsOneWidget);
      await tap(tester, find.text('Delete permanently'));
      expect(api.requests.where((r) => r.method == 'DELETE').length, 1);
      expect(container.read(authControllerProvider).user, isNull);
      expect(find.text('Welcome to Flow'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('Accounts Center displays and removes the saved profile photo', (
    tester,
  ) async {
    final api = FakeAuthApi(hasPassword: true, profileCompleted: true);
    final bytes = await tester.runAsync(
      () => File('assets/welcome/flow-avatar.jpg').readAsBytes(),
    );
    api.user['profile_photo'] = base64Encode(bytes!);
    final container = await open(tester, api, '/settings/accounts');
    expect(find.byTooltip('Change profile photo'), findsOneWidget);
    expect(find.text('Change photo'), findsOneWidget);
    expect(find.text('Remove photo'), findsOneWidget);
    await tap(tester, find.text('Remove photo'));
    expect(api.requests.lastWhere((r) => r.path == 'me/photo').data, {
      'photo': null,
    });
    expect(container.read(authControllerProvider).user!.profilePhoto, isNull);
    expect(find.text('Remove photo'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final size in [
    const Size(320, 640),
    const Size(844, 390),
    const Size(1440, 900),
  ]) {
    testWidgets('interest choices fit $size with large text', (tester) async {
      final api = FakeAuthApi(
        hasPassword: true,
        profileCompleted: true,
        onboardingCompleted: false,
      );
      await open(tester, api, '/auth/onboarding', size: size, textScale: 1.8);
      await tap(tester, find.text('Instagram'));
      await tap(tester, find.widgetWithText(FilledButton, 'Continue'));
      await tap(tester, find.text('Other'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
