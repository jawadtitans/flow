import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:passkeys/authenticator.dart';
import 'package:passkeys/types.dart';
import 'settings_repository.dart';

final passkeyServiceProvider = Provider(
  (ref) => PasskeyService(ref.watch(accountSettingsRepositoryProvider)),
);

/// Native plugin uses Credential Manager on Android and AuthenticationServices
/// on iOS. Only the signed public credential response is sent to the server.
class PasskeyService {
  PasskeyService(this.repository);
  final AccountSettingsRepository repository;
  final authenticator = PasskeyAuthenticator();
  Future<void> register() async {
    final options = await repository.registrationOptions();
    final credential = await authenticator.register(
      RegisterRequestType.fromJson(
        Map<String, dynamic>.from(options['publicKey']),
      ),
    );
    await repository.verifyRegistration({
      'challenge_id': options['challenge_id'],
      'credential': credential.toJson(),
    });
  }

  Future<void> authenticate() async {
    final options = await repository.authenticationOptions();
    final response = await authenticator.authenticate(
      AuthenticateRequestType.fromJson(
        Map<String, dynamic>.from(options['publicKey']),
      ),
    );
    await repository.verifyAuthentication({
      'challenge_id': options['challenge_id'],
      'credential': response.toJson(),
    });
  }
}
