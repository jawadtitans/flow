import 'package:flow_app/features/settings/domain/app_lock.dart';
import 'package:flow_app/features/settings/presentation/app_lock_pages.dart';
import 'package:flow_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class LifecycleLockFixture extends AppLockController {
  @override
  Future<AppLockConfiguration> build() async =>
      const AppLockConfiguration(enabled: true);
  @override
  Future<bool> verify(String pin) async => pin == '123456';
}

void main() {
  testWidgets(
    'cold start and background lock hide content; system dialogs preserve unlock',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appLockProvider.overrideWith(LifecycleLockFixture.new)],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const AppLockGate(
              child: Scaffold(body: Text('Private account content')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Private account content'), findsNothing);
      await tester.enterText(find.byType(TextField), '000000');
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();
      expect(find.text('Private account content'), findsNothing);
      await tester.enterText(find.byType(TextField), '123456');
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();
      expect(find.text('Private account content'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.text('Private account content'), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Private account content'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.text('Private account content'), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(find.text('Private account content'), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Private account content'), findsNothing);
      expect(find.text('Unlock Flow'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
