import 'package:flow_app/features/settings/domain/app_lock.dart';
import 'package:flow_app/features/settings/domain/settings_repository.dart';
import 'package:flow_app/features/settings/presentation/account_settings_pages.dart';
import 'package:flow_app/features/settings/presentation/device_settings_pages.dart';
import 'package:flow_app/features/settings/presentation/flow_pro_page.dart';
import 'package:flow_app/features/settings/settings_controller.dart';
import 'package:flow_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'language persists and unfinished languages cannot be selected',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [settingsStorageProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);
      await container
          .read(settingsControllerProvider.notifier)
          .setLanguage('en');
      expect(storage.getString('settings.language'), 'en');
      expect(
        () => container
            .read(settingsControllerProvider.notifier)
            .setLanguage('fa'),
        throwsArgumentError,
      );
      final restored = ProviderContainer(
        overrides: [settingsStorageProvider.overrideWithValue(storage)],
      );
      addTearDown(restored.dispose);
      expect(restored.read(settingsControllerProvider).language, 'en');
    },
  );
  test(
    'permission mapping distinguishes full, limited, and restricted access',
    () {
      expect(permissionStatusKey(PermissionStatus.granted), 'granted');
      expect(permissionStatusKey(PermissionStatus.limited), 'limited');
      expect(permissionStatusKey(PermissionStatus.denied), 'denied');
      expect(
        permissionStatusKey(PermissionStatus.permanentlyDenied),
        'settings',
      );
      expect(permissionStatusKey(PermissionStatus.restricted), 'settings');
    },
  );
  test(
    'phone normalization supports international numbers and rejects malformed input',
    () {
      expect(normalizePhone('070 123 4567', 'AF'), '+93701234567');
      expect(normalizePhone('(202) 555-0123', 'US'), '+12025550123');
      expect(normalizePhone('+44 7911 123456', 'GB'), '+447911123456');
      for (final input in ['++93701234567', '+93+701234567', '123', 'abcdef']) {
        expect(() => normalizePhone(input, 'AF'), throwsFormatException);
      }
    },
  );
  test('password confirmation validates without inventing a server policy', () {
    expect(passwordsMatch('', ''), false);
    expect(passwordsMatch('server-policy-password', 'different'), false);
    expect(passwordsMatch('some password', 'some password'), true);
  });
  test(
    'app lock timeout includes its boundary and cold immediate behavior',
    () {
      const off = AppLockConfiguration();
      const immediate = AppLockConfiguration(enabled: true);
      const delayed = AppLockConfiguration(enabled: true, minutes: 5);
      expect(off.shouldLock(const Duration(days: 1)), false);
      expect(immediate.shouldLock(Duration.zero), true);
      expect(
        delayed.shouldLock(const Duration(minutes: 4, seconds: 59)),
        false,
      );
      expect(delayed.shouldLock(const Duration(minutes: 5)), true);
    },
  );
  test(
    'PIN is salted, derived, persisted securely and attempts are throttled',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(appLockProvider.future);
      final controller = container.read(appLockProvider.notifier);
      await controller.enable('629471', false);
      final raw = await controller.storage.read(key: AppLockController.key);
      expect(raw, isNot(contains('629471')));
      expect(raw, contains('digest'));
      for (var i = 0; i < 5; i++) {
        expect(await controller.verify('000000'), false);
      }
      expect(await controller.verify('629471'), false);
      controller.record!['retry_after'] = 0;
      expect(await controller.verify('629471'), true);
      await controller.timeout(15);
      final restored = ProviderContainer();
      addTearDown(restored.dispose);
      final config = await restored.read(appLockProvider.future);
      expect(config.enabled, true);
      expect(config.minutes, 15);
      await restored.read(appLockProvider.notifier).disable('629471');
      expect(await controller.storage.read(key: AppLockController.key), null);
    },
  );
  test(
    'subscription entitlements are parsed centrally and unconfigured billing fails',
    () async {
      final state = SubscriptionState.fromJson({
        'tier': 'pro',
        'features': [
          {
            'title': 'Assistant',
            'tiers': ['free', 'pro', 'max'],
          },
          {
            'title': 'Advanced reasoning',
            'tiers': ['pro', 'max'],
          },
        ],
        'prices': [
          {
            'tier': 'pro',
            'period': 'yearly',
            'formatted_price': 'Server price',
            'product_id': 'server-product',
          },
        ],
      });
      expect(state.features[0].included(SubscriptionTier.free), true);
      expect(state.features[1].included(SubscriptionTier.free), false);
      expect(state.features[1].included(SubscriptionTier.max), true);
      expect(state.prices.single.period, BillingPeriod.yearly);
      final billing = UnconfiguredBilling();
      expect(billing.available, false);
      await expectLater(
        billing.purchase(state.prices.single),
        throwsA(isA<Exception>()),
      );
      await expectLater(billing.restore(), throwsA(isA<Exception>()));
    },
  );
  for (final scale in [1.0, 1.8]) {
    testWidgets(
      'Pro tier and billing selections fit narrow screens at scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final router = GoRouter(
          initialLocation: '/pro',
          routes: [
            GoRoute(
              path: '/pro',
              builder: (context, state) => const FlowProPage(),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              subscriptionProvider.overrideWith(
                (ref) async => const SubscriptionState(
                  features: [
                    PlanFeature('Assistant', {
                      SubscriptionTier.free,
                      SubscriptionTier.pro,
                      SubscriptionTier.max,
                    }),
                  ],
                ),
              ),
            ],
            child: MaterialApp.router(
              routerConfig: router,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  disableAnimations: true,
                  textScaler: TextScaler.linear(scale),
                ),
                child: child!,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('Max').first, 120);
        await Scrollable.ensureVisible(
          tester.element(find.text('Max').first),
          alignment: .5,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Max').first);
        await tester.pumpAndSettle();
        expect(find.text('Get Flow Max'), findsOneWidget);
        await tester.scrollUntilVisible(find.text('Monthly'), 120);
        await Scrollable.ensureVisible(
          tester.element(find.text('Monthly')),
          alignment: .3,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Monthly'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<Semantics>(find.byKey(const ValueKey('billing-monthly')))
              .properties
              .selected,
          true,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), null);
        expect(
          tester
              .widget<FilledButton>(find.byType(FilledButton).first)
              .onPressed,
          null,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
