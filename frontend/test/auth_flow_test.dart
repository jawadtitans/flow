import 'package:flow_app/app/app.dart';
import 'package:flow_app/app/router/app_router.dart';
import 'package:flow_app/features/auth/auth_controller.dart';
import 'package:flow_app/core/network/api_client.dart';
import 'support/fake_auth_api.dart';
import 'package:flow_app/features/auth/presentation/auth_components.dart';
import 'package:flow_app/features/settings/settings_controller.dart';
import 'package:flow_app/shared/widgets/flow_components.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

late GoRouter appRouter;
late ProviderContainer authContainer;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    flowBottomNavigationExpanded.value = false;
    flowNavigationVisible.value = true;
  });

  Future<ProviderContainer> open(
    WidgetTester tester, {
    String route = '/auth',
    Size size = const Size(390, 844),
    double textScale = 1,
    bool dark = false,
    bool hasPassword = true,
    bool profileCompleted = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'settings.appearance': dark ? 'dark' : 'light',
    });
    final storage = await SharedPreferences.getInstance();
    final api = FakeAuthApi(
      hasPassword: hasPassword,
      profileCompleted: profileCompleted,
    );
    late ProviderContainer container;
    await tester.runAsync(() async {
      final client = api.client();
      container = ProviderContainer(
        overrides: [
          settingsStorageProvider.overrideWithValue(storage),
          apiClientProvider.overrideWithValue(client),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(client.close);
      if (['/auth/code', '/auth/password', '/auth/profile'].contains(route)) {
        await container
            .read(authControllerProvider.notifier)
            .requestAccess('hello@flow.example');
        if (route == '/auth/profile') {
          await container
              .read(authControllerProvider.notifier)
              .verifyOtp('123456');
        }
      }
    });
    final router = createAppRouter(initialLocation: route);
    authContainer = container;
    appRouter = router;
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
            disableAnimations: true,
          ),
          child: FlowApp(router: appRouter),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Finder input(String key) => find.descendant(
    of: find.byKey(ValueKey(key)),
    matching: find.byType(TextField),
  );

  Finder button(String text) => find.widgetWithText(FilledButton, text);

  Future<void> waitForAuth(WidgetTester tester) async {
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 20));
      if (!authContainer.read(authControllerProvider).busy) return;
    }
    fail('The authentication request did not finish.');
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.pump();
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await waitForAuth(tester);
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
  }

  test(
    'identifier validation accepts email and rejects phone and incomplete input',
    () {
      expect(isEmail('hello@flow.example'), isTrue);
      expect(isEmail('+1 (555) 123-4567'), isFalse);
      for (final value in [
        '',
        'hello',
        'hello@',
        'hello@flow',
        '123',
        'hello1234567',
      ]) {
        expect(isEmail(value), isFalse);
      }
    },
  );

  testWidgets('passwordless accounts only offer code sign-in', (tester) async {
    await open(tester, hasPassword: false);
    await tester.enterText(input('sign-in-identifier'), 'new@flow.example');
    await tap(tester, button('Continue'));
    expect(find.text('Enter your code'), findsOneWidget);
    expect(find.text('Try another way'), findsNothing);
    expect(find.text('Forgot password?'), findsNothing);
    await close(tester);
  });

  testWidgets(
    'password alternative appears only after an existing account requests OTP',
    (tester) async {
      await open(tester);
      expect(find.text('Try another way'), findsNothing);
      expect(find.text('Sign in with password instead'), findsNothing);
      await tester.enterText(input('sign-in-identifier'), 'hello@flow.example');
      await tap(tester, button('Continue'));
      expect(find.text('Try another way'), findsOneWidget);
      expect(find.text('Forgot password?'), findsNothing);
      await tap(tester, find.text('Try another way'));
      expect(find.text('Enter your password'), findsOneWidget);
      expect(find.text('Forgot password?'), findsOneWidget);
      await close(tester);
    },
  );

  testWidgets(
    'returning profile-complete accounts go from OTP through getting ready to home',
    (tester) async {
      await open(tester, profileCompleted: true);
      await tester.enterText(input('sign-in-identifier'), 'hello@flow.example');
      await tap(tester, button('Continue'));
      await tester.enterText(
        find.byKey(const ValueKey('verification-code')),
        '123456',
      );
      await tester.pump();
      await tester.tap(button('Confirm'));
      await waitForAuth(tester);
      for (
        var i = 0;
        i < 20 && find.text('Getting Ready').evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.text('Getting Ready'),
        findsOneWidget,
        reason: appRouter.routeInformationProvider.value.uri.path,
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(appRouter.routeInformationProvider.value.uri.path, '/today');
      expect(find.text('Finish creating your account'), findsNothing);
      await close(tester);
    },
  );

  testWidgets('password reset requires a code and matching strong passwords', (
    tester,
  ) async {
    await open(tester, route: '/auth/reset-password');
    await tester.enterText(input('reset-email'), 'hello@flow.example');
    await tap(tester, button('Send reset code'));
    await tester.enterText(input('reset-code'), '123456');
    await tester.enterText(input('new-password'), 'short');
    await tester.enterText(input('confirm-password'), 'short');
    await tester.pump();
    expect(
      tester.widget<FilledButton>(button('Update password')).onPressed,
      isNull,
    );
    await tester.enterText(input('new-password'), 'a-new-strong-password');
    await tester.enterText(input('confirm-password'), 'a-new-strong-password');
    await tap(tester, button('Update password'));
    expect(find.text('Welcome to Flow'), findsOneWidget);
    await close(tester);
  });

  testWidgets(
    'OTP error, resend, paste, profile and getting ready lead to home',
    (tester) async {
      await open(tester);
      expect(tester.widget<FilledButton>(button('Continue')).onPressed, isNull);
      await tester.enterText(input('sign-in-identifier'), 'hello@flow.example');
      await tap(tester, button('Continue'));
      expect(find.text('Enter your code'), findsOneWidget);
      expect(find.textContaining('hello@flow.example'), findsWidgets);
      expect(find.byType(FlowBottomNavigation), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('verification-code')),
        '256688',
      );
      await tap(tester, button('Confirm'));
      expect(find.text('Invalid code. Please try again.'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(button('Confirm')).onPressed,
        isNotNull,
      );
      final errorCells = tester
          .widgetList<Container>(find.byType(Container))
          .where((widget) {
            final decoration = widget.decoration;
            return decoration is BoxDecoration &&
                decoration.border is Border &&
                (decoration.border! as Border).top.color == authErrorColor;
          });
      expect(errorCells.length, 6);

      await tap(tester, find.text('Resend code'));
      expect(find.text('Invalid code. Please try again.'), findsNothing);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('verification-code')))
            .controller!
            .text,
        '',
      );
      await tester.enterText(
        find.byKey(const ValueKey('verification-code')),
        '123456',
      );
      await tap(tester, button('Confirm'));
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('Finish creating your account'), findsOneWidget);
      expect(tester.widget<FilledButton>(button('Confirm')).onPressed, isNull);

      await tester.enterText(input('profile-first-name'), 'Jawad');
      await tester.enterText(input('profile-last-name'), 'Rahimi');
      await tap(tester, input('profile-birthday'));
      expect(find.byType(CupertinoDatePicker), findsOneWidget);
      final picker = tester.widget<CupertinoDatePicker>(
        find.byType(CupertinoDatePicker),
      );
      expect(picker.maximumDate!.isAfter(DateTime.now()), isFalse);
      await tap(tester, find.text('Done'));
      expect(
        tester.widget<TextField>(input('profile-birthday')).controller!.text,
        isNotEmpty,
      );
      await tester.ensureVisible(button('Confirm'));
      await tester.tap(button('Confirm'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(appRouter.routeInformationProvider.value.uri.path, '/today');
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(appRouter.routeInformationProvider.value.uri.path, '/today');
      expect(find.byType(FlowBottomNavigation), findsOneWidget);
      await close(tester);
    },
  );

  testWidgets('editing an incorrect code clears its error and allows retry', (
    tester,
  ) async {
    await open(tester, route: '/auth/code');
    final code = find.byKey(const ValueKey('verification-code'));
    await tester.enterText(code, '000000');
    await tap(tester, button('Confirm'));
    expect(find.text('Invalid code. Please try again.'), findsOneWidget);
    await tester.enterText(code, '123');
    await tester.pump();
    expect(find.text('Invalid code. Please try again.'), findsNothing);
    expect(tester.widget<FilledButton>(button('Confirm')).onPressed, isNull);
    await tester.enterText(code, '123456');
    await tap(tester, button('Confirm'));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Finish creating your account'), findsOneWidget);
    await close(tester);
  });

  testWidgets(
    'alternate password, visibility, reset email and return navigation work',
    (tester) async {
      await open(tester);
      await tester.enterText(input('sign-in-identifier'), 'hello@flow.example');
      await tap(tester, button('Continue'));
      await tap(tester, find.text('Try another way'));
      expect(find.text('Enter your password'), findsOneWidget);
      expect(tester.widget<FilledButton>(button('Continue')).onPressed, isNull);
      await tester.enterText(input('sign-in-password'), 'correct-password');
      expect(
        tester.widget<TextField>(input('sign-in-password')).obscureText,
        isTrue,
      );
      await tap(tester, find.byTooltip('Show password'));
      expect(
        tester.widget<TextField>(input('sign-in-password')).obscureText,
        isFalse,
      );

      await tap(tester, find.text('Forgot password?'));
      expect(find.text('Reset your password'), findsOneWidget);
      expect(
        tester.widget<TextField>(input('reset-email')).controller!.text,
        'hello@flow.example',
      );
      await tester.enterText(input('reset-email'), 'bad-address');
      await tester.pump();
      expect(
        tester.widget<FilledButton>(button('Send reset code')).onPressed,
        isNull,
      );
      await tester.enterText(input('reset-email'), 'another@flow.example');
      await tap(tester, button('Send reset code'));
      expect(find.text('Enter your reset code'), findsOneWidget);
      expect(find.textContaining('another@flow.example'), findsOneWidget);
      await tap(tester, find.byTooltip('Back'));
      expect(find.text('Reset your password'), findsOneWidget);
      await tap(tester, find.byTooltip('Back'));
      expect(find.text('Enter your password'), findsOneWidget);
      expect(
        tester.widget<TextField>(input('sign-in-password')).controller!.text,
        'correct-password',
      );
      await tap(tester, button('Continue'));
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('Finish creating your account'), findsOneWidget);
      await close(tester);
    },
  );

  testWidgets(
    'birthday cancel, clear names, help and legal links keep profile usable',
    (tester) async {
      await open(tester, route: '/auth/profile');
      await tester.enterText(input('profile-first-name'), 'Amina');
      await tester.enterText(input('profile-last-name'), 'Ahmadi');
      await tap(tester, find.byTooltip('Clear first name'));
      expect(
        tester.widget<TextField>(input('profile-first-name')).controller!.text,
        '',
      );
      await tap(tester, input('profile-birthday'));
      await tap(tester, find.text('Cancel'));
      expect(
        tester.widget<TextField>(input('profile-birthday')).controller!.text,
        '',
      );
      await tester.tapOnText(
        find.textRange.ofSubstring('Why do I need to provide my birthday?'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Why your birthday?'), findsOneWidget);
      await tap(tester, find.text('Got it'));
      await tap(tester, find.text('terms'));
      expect(find.text('Terms of service'), findsOneWidget);
      await tap(tester, find.bySemanticsLabel('Back'));
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('Finish creating your account'), findsOneWidget);
      expect(
        tester.widget<TextField>(input('profile-last-name')).controller!.text,
        'Ahmadi',
      );
      await close(tester);
    },
  );

  testWidgets(
    'all forms fit narrow screens, large text, landscape and keyboard insets',
    (tester) async {
      for (final size in [const Size(320, 700), const Size(568, 320)]) {
        await open(tester, size: size, textScale: 1.8);
        for (final route in [
          '/auth',
          '/auth/code',
          '/auth/password',
          '/auth/reset-password',
          '/auth/profile',
        ]) {
          appRouter.go(route);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: route);
          final action = find.byType(AuthButton).last;
          await tester.ensureVisible(action);
          await tester.pumpAndSettle();
          expect(action.hitTestable(), findsOneWidget, reason: route);
        }
        await tap(tester, input('profile-birthday'));
        expect(tester.takeException(), isNull);
        await tap(tester, find.text('Cancel'));
        appRouter.go('/auth/password');
        await tester.pumpAndSettle();
        tester.view.viewInsets = const FakeViewPadding(bottom: 160);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Forgot password?'));
        expect(find.text('Forgot password?').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        tester.view.resetViewInsets();
        await close(tester);
      }
    },
  );

  testWidgets('settings opens sign in and isolated auth pages support back', (
    tester,
  ) async {
    await open(tester, route: '/settings/accounts');
    await tap(tester, find.text('Sign in or create an account'));
    expect(find.text('Welcome to Flow'), findsOneWidget);
    await tap(tester, find.byTooltip('Back'));
    expect(find.text('Accounts Center'), findsOneWidget);
    appRouter.go('/auth/password');
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Flow'), findsOneWidget);
    await close(tester);
  });

  testWidgets(
    'Roboto is used by the app and auth stays usable in dark appearance',
    (tester) async {
      await open(tester, route: '/auth/profile', dark: true);
      final context = tester.element(find.byType(AuthScaffold));
      expect(Theme.of(context).brightness, Brightness.dark);
      expect(Theme.of(context).textTheme.bodyMedium!.fontFamily, 'Roboto');
      await tap(tester, input('profile-birthday'));
      await tap(tester, find.text('Done'));
      expect(tester.takeException(), isNull);
      await close(tester);
    },
  );
}
