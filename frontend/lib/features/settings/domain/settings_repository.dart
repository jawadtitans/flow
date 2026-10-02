import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../auth/auth_controller.dart';

enum SubscriptionTier { free, pro, max }

enum BillingPeriod { monthly, yearly }

class PlanFeature {
  const PlanFeature(this.title, this.tiers);
  final String title;
  final Set<SubscriptionTier> tiers;
  bool included(SubscriptionTier tier) => tiers.contains(tier);
  factory PlanFeature.fromJson(Map<String, dynamic> json) => PlanFeature(
    json['title'] as String,
    (json['tiers'] as List)
        .map((v) => SubscriptionTier.values.byName(v as String))
        .toSet(),
  );
}

class PlanPrice {
  const PlanPrice(this.tier, this.period, this.label, this.productId);
  final SubscriptionTier tier;
  final BillingPeriod period;
  final String label;
  final String productId;
  factory PlanPrice.fromJson(Map<String, dynamic> j) => PlanPrice(
    SubscriptionTier.values.byName(j['tier']),
    BillingPeriod.values.byName(j['period']),
    j['formatted_price'],
    j['product_id'],
  );
}

class SubscriptionState {
  const SubscriptionState({
    this.tier = SubscriptionTier.free,
    this.features = const [],
    this.prices = const [],
  });
  final SubscriptionTier tier;
  final List<PlanFeature> features;
  final List<PlanPrice> prices;
  factory SubscriptionState.fromJson(Map<String, dynamic> j) =>
      SubscriptionState(
        tier: SubscriptionTier.values.byName(j['tier']),
        features: (j['features'] as List)
            .map((v) => PlanFeature.fromJson(Map<String, dynamic>.from(v)))
            .toList(),
        prices: (j['prices'] as List)
            .map((v) => PlanPrice.fromJson(Map<String, dynamic>.from(v)))
            .toList(),
      );
}

class MfaState {
  const MfaState(this.enabled, this.recoveryAvailable);
  final bool enabled;
  final bool recoveryAvailable;
  factory MfaState.fromJson(Map<String, dynamic> j) =>
      MfaState(j['enabled'] == true, j['recovery_available'] == true);
}

class MfaSetup {
  const MfaSetup(this.id, this.uri, this.key);
  final String id, uri, key;
  factory MfaSetup.fromJson(Map<String, dynamic> j) =>
      MfaSetup(j['setup_id'], j['otpauth_uri'], j['manual_key']);
}

class PasskeyCredential {
  const PasskeyCredential(this.id, this.name, this.createdAt, this.lastUsedAt);
  final String id, name;
  final DateTime createdAt;
  final DateTime? lastUsedAt;
  factory PasskeyCredential.fromJson(Map<String, dynamic> j) =>
      PasskeyCredential(
        j['id'],
        j['display_name'] ?? j['provider'] ?? 'Passkey',
        DateTime.parse(j['created_at']),
        j['last_used_at'] == null ? null : DateTime.parse(j['last_used_at']),
      );
}

final accountSettingsRepositoryProvider = Provider(
  (ref) => AccountSettingsRepository(ref.watch(apiClientProvider)),
);
final subscriptionProvider = FutureProvider(retry: (count, error) => null, (
  ref,
) {
  final email = ref.watch(authControllerProvider.select((a) => a.user?.email));
  if (email == null) return Future.value(const SubscriptionState());
  return ref.watch(accountSettingsRepositoryProvider).subscription();
});
final mfaProvider = FutureProvider.autoDispose(retry: (count, error) => null, (
  ref,
) {
  ref.watch(authControllerProvider.select((a) => a.user?.email));
  return ref.watch(accountSettingsRepositoryProvider).mfa();
});
final passkeysProvider = FutureProvider.autoDispose(
  retry: (count, error) => null,
  (ref) {
    ref.watch(authControllerProvider.select((a) => a.user?.email));
    return ref.watch(accountSettingsRepositoryProvider).passkeys();
  },
);

/// All account security state is returned by the authenticated server.
class AccountSettingsRepository {
  AccountSettingsRepository(this.client);
  final ApiClient client;
  Future<Map<String, dynamic>> get(String path) async =>
      (await client.dio.get<Map<String, dynamic>>(
        path,
        options: ApiClient.authenticated,
      )).data!;
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> data,
  ) async => (await client.dio.post<Map<String, dynamic>>(
    path,
    data: data,
    options: ApiClient.authenticated,
  )).data!;
  Future<SubscriptionState> subscription() async =>
      SubscriptionState.fromJson(await get('me/subscription'));
  Future<MfaState> mfa() async =>
      MfaState.fromJson(await get('me/security/mfa'));
  Future<MfaSetup> setupMfa(String password) async => MfaSetup.fromJson(
    await post('me/security/mfa/setup', {'password': password}),
  );
  Future<List<String>> verifyMfa(String id, String code) async =>
      ((await post('me/security/mfa/verify', {
                    'setup_id': id,
                    'code': code,
                  }))['recovery_codes']
                  as List? ??
              [])
          .cast<String>();
  Future<void> disableMfa(String code) async {
    await post('me/security/mfa/disable', {'code': code});
  }

  Future<List<String>> regenerateRecovery(String code) async =>
      ((await post('me/security/mfa/recovery', {
                'code': code,
              }))['recovery_codes']
              as List)
          .cast<String>();
  Future<List<PasskeyCredential>> passkeys() async =>
      ((await get('me/passkeys'))['credentials'] as List)
          .map((j) => PasskeyCredential.fromJson(Map<String, dynamic>.from(j)))
          .toList();
  Future<Map<String, dynamic>> registrationOptions() =>
      post('auth/passkeys/register/options', {});
  Future<void> verifyRegistration(Map<String, dynamic> credential) async {
    await post('auth/passkeys/register/verify', credential);
  }

  Future<Map<String, dynamic>> authenticationOptions() async =>
      (await client.dio.post<Map<String, dynamic>>(
        'auth/passkeys/authenticate/options',
        data: {},
      )).data!;
  Future<void> verifyAuthentication(Map<String, dynamic> credential) async {
    final tokens = (await client.dio.post<Map<String, dynamic>>(
      'auth/passkeys/authenticate/verify',
      data: credential,
    )).data!;
    await client.establish(tokens);
  }

  Future<void> renamePasskey(String id, String name) async {
    await client.dio.patch(
      'me/passkeys/${Uri.encodeComponent(id)}',
      data: {'display_name': name},
      options: ApiClient.authenticated,
    );
  }

  Future<void> removePasskey(String id) async {
    await client.dio.delete(
      'me/passkeys/${Uri.encodeComponent(id)}',
      options: ApiClient.authenticated,
    );
  }

  Future<String> requestPhone(String phone) async =>
      (await post('me/phone/request', {'phone': phone}))['verification_id'];
  Future<void> verifyPhone(String id, String code) async {
    await post('me/phone/verify', {'verification_id': id, 'code': code});
  }

  Future<void> changePassword(String current, String password) async {
    await post('me/security/password', {
      'current_password': current,
      'new_password': password,
    });
  }
}

enum BillingOutcome { success, pending, cancelled, restoreRequired }

abstract interface class SubscriptionBilling {
  Future<BillingOutcome> purchase(PlanPrice price);
  Future<BillingOutcome> restore();
  Future<BillingOutcome> manage();
  bool get available;
}

class UnconfiguredBilling implements SubscriptionBilling {
  @override
  bool get available => false;
  @override
  Future<BillingOutcome> purchase(PlanPrice price) async =>
      throw const AuthFailure('Purchases are not available yet.');
  @override
  Future<BillingOutcome> restore() async =>
      throw const AuthFailure('Store billing is not configured yet.');
  @override
  Future<BillingOutcome> manage() async =>
      throw const AuthFailure('Subscription management is not configured yet.');
}

final subscriptionBillingProvider = Provider<SubscriptionBilling>(
  (ref) => UnconfiguredBilling(),
);
