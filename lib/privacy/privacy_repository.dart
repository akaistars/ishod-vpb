import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stable boundary between privacy UI and account storage/verification.
/// Replace [DemoPrivacyRepository] with a server-backed implementation later.
abstract interface class PrivacyRepository {
  String get username;
  String? get email;

  Future<String> sendVerificationCode({required String purpose, required String target});
  Future<void> confirmVerificationCode({required String challengeId, required String code});
  Future<void> changeUsername({required String username, required String challengeId});
  Future<void> changePassword({required String password, required String challengeId});
  Future<void> changeEmail({required String email, required String challengeId});
  Future<void> unlinkEmail({required String currentPassword, required String challengeId});
}

/// In-memory DEMO repository for isolated tests. App code should use the
/// secure-storage subclass. Challenges remain ephemeral and expire after 10m.
class DemoPrivacyRepository implements PrivacyRepository {
  DemoPrivacyRepository({String username = 'spider_user', String? email, String demoPassword = 'DemoPass123!'})
      : _username = username,
        _email = email,
        _demoPassword = demoPassword;

  static const demoCode = '123456';
  static const _purposes = {'link_email', 'change_email', 'change_username', 'change_password', 'unlink_email'};
  static const _emailPurposes = {'link_email', 'change_email'};
  static const _requiresLinkedEmail = {'change_username', 'change_password', 'unlink_email'};
  String _username;
  String? _email;
  String _demoPassword;
  final Map<String, _Challenge> _challenges = {};

  @override
  String get username => _username;
  @override
  String? get email => _email;

  @override
  Future<String> sendVerificationCode({required String purpose, required String target}) async {
    if (!_purposes.contains(purpose)) throw const PrivacyDemoException('unsupported_action');
    if (_requiresLinkedEmail.contains(purpose) && (_email == null || _email!.isEmpty)) {
      throw const PrivacyDemoException('email_required');
    }
    if (purpose == 'link_email' && _email != null) throw const PrivacyDemoException('email_already_linked');
    final normalizedTarget = target.trim().toLowerCase();
    if (_emailPurposes.contains(purpose) && !isValidGmail(normalizedTarget)) {
      throw const PrivacyDemoException('invalid_email');
    }
    final id = '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${Random.secure().nextInt(1 << 32).toRadixString(36)}';
    _challenges[id] = _Challenge(purpose, normalizedTarget, DateTime.now().add(const Duration(minutes: 10)));
    return id;
  }

  @override
  Future<void> confirmVerificationCode({required String challengeId, required String code}) async {
    final challenge = _challenges[challengeId];
    if (challenge == null || challenge.consumed || challenge.verified || !DateTime.now().isBefore(challenge.expiresAt) || challenge.attempts >= 5) {
      throw const PrivacyDemoException('invalid_or_expired_code');
    }
    if (code != demoCode) {
      challenge.attempts++;
      throw const PrivacyDemoException('invalid_or_expired_code');
    }
    challenge.verified = true;
  }

  _Challenge verifiedChallenge(String id, String purpose) {
    final challenge = _challenges[id];
    if (challenge == null || !challenge.verified || challenge.consumed || challenge.purpose != purpose || !DateTime.now().isBefore(challenge.expiresAt)) {
      throw const PrivacyDemoException('verification_required');
    }
    challenge.consumed = true;
    return challenge;
  }

  @override
  Future<void> changeUsername({required String username, required String challengeId}) async {
    final value = username.trim();
    if (!RegExp(r'^[A-Za-z0-9._-]{3,32}$').hasMatch(value)) throw const PrivacyDemoException('invalid_username');
    verifiedChallenge(challengeId, 'change_username');
    _username = value;
  }

  @override
  Future<void> changePassword({required String password, required String challengeId}) async {
    if (!isStrongPassword(password)) throw const PrivacyDemoException('weak_password');
    verifiedChallenge(challengeId, 'change_password');
    _demoPassword = password;
  }

  @override
  Future<void> changeEmail({required String email, required String challengeId}) async {
    final challenge = _challenges[challengeId];
    if (challenge == null || !challenge.verified || challenge.consumed || !DateTime.now().isBefore(challenge.expiresAt)) {
      throw const PrivacyDemoException('verification_required');
    }
    if (!_emailPurposes.contains(challenge.purpose)) throw const PrivacyDemoException('verification_required');
    final value = email.trim().toLowerCase();
    if (value != challenge.target || !isValidGmail(value)) throw const PrivacyDemoException('verification_required');
    if (challenge.purpose == 'link_email' && _email != null) throw const PrivacyDemoException('email_already_linked');
    challenge.consumed = true;
    _email = value;
  }

  @override
  Future<void> unlinkEmail({required String currentPassword, required String challengeId}) async {
    if (currentPassword != _demoPassword) throw const PrivacyDemoException('invalid_password');
    verifiedChallenge(challengeId, 'unlink_email');
    _email = null;
  }

  static bool isValidGmail(String value) => RegExp(r'^[A-Z0-9._%+-]+@gmail\.com$', caseSensitive: false).hasMatch(value);
  static bool isStrongPassword(String value) => value.length >= 10 && value.length <= 128 && RegExp(r'[a-z]').hasMatch(value) && RegExp(r'[A-Z]').hasMatch(value) && RegExp(r'\d').hasMatch(value);
}

/// Persistent local DEMO account. User profile and a salted PBKDF2 password
/// verifier are stored using OS-backed secure storage; raw passwords and OTPs
/// are never persisted. OTP challenges intentionally expire on app restart.
class SecureDemoPrivacyRepository extends DemoPrivacyRepository {
  SecureDemoPrivacyRepository._(this._storage, {required super.username, super.email, required super.demoPassword});

  static const _storageKey = 'spider_vpn_privacy_demo_v1';
  final FlutterSecureStorage _storage;
  late String _passwordSalt;
  late String _passwordVerifier;
  bool _ready = false;

  static Future<SecureDemoPrivacyRepository> open({FlutterSecureStorage? storage}) async {
    const secure = FlutterSecureStorage();
    final secureStorage = storage ?? secure;
    const defaultPassword = 'DemoPass123!';
    Map<String, dynamic>? state;
    final serialized = await secureStorage.read(key: _storageKey);
    if (serialized != null) {
      try { state = jsonDecode(serialized) as Map<String, dynamic>; } catch (_) { state = null; }
    }
    final salt = state?['passwordSalt'] as String? ?? _randomSalt();
    final repository = SecureDemoPrivacyRepository._(
      secureStorage,
      username: state?['username'] as String? ?? 'spider_user',
      email: state?['email'] as String?,
      demoPassword: defaultPassword,
    ).._passwordSalt = salt;
    repository._passwordVerifier = state?['passwordVerifier'] as String? ?? _derive(defaultPassword, salt);
    repository._ready = true;
    if (state == null) await repository._persist();
    return repository;
  }

  static String _randomSalt() {
    final random = Random.secure();
    return base64UrlEncode(List<int>.generate(16, (_) => random.nextInt(256)));
  }

  static String _derive(String password, String salt) {
    // PBKDF2-HMAC-SHA256 with 120,000 iterations and a 256-bit result.
    const iterations = 120000;
    final hmac = Hmac(sha256, utf8.encode(password));
    final saltBytes = base64Url.decode(base64Url.normalize(salt));
    var u = hmac.convert([...saltBytes, 0, 0, 0, 1]).bytes;
    final result = List<int>.from(u);
    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < result.length; j++) {
        result[j] ^= u[j];
      }
    }
    return base64UrlEncode(result);
  }

  @override
  Future<void> changeUsername({required String username, required String challengeId}) async {
    await super.changeUsername(username: username, challengeId: challengeId);
    await _persist();
  }

  @override
  Future<void> changePassword({required String password, required String challengeId}) async {
    if (!isStrongPassword(password)) throw const PrivacyDemoException('weak_password');
    verifiedChallenge(challengeId, 'change_password');
    _passwordSalt = _randomSalt();
    _passwordVerifier = _derive(password, _passwordSalt);
    await _persist();
  }

  @override
  Future<void> unlinkEmail({required String currentPassword, required String challengeId}) async {
    if (_derive(currentPassword, _passwordSalt) != _passwordVerifier) throw const PrivacyDemoException('invalid_password');
    verifiedChallenge(challengeId, 'unlink_email');
    _email = null;
    await _persist();
  }

  @override
  Future<void> changeEmail({required String email, required String challengeId}) async {
    await super.changeEmail(email: email, challengeId: challengeId);
    await _persist();
  }

  Future<void> _persist() async {
    if (!_ready) return;
    await _storage.write(key: _storageKey, value: jsonEncode({
      'username': username,
      'email': email,
      'passwordSalt': _passwordSalt,
      'passwordVerifier': _passwordVerifier,
    }));
  }
}

class _Challenge {
  _Challenge(this.purpose, this.target, this.expiresAt);
  final String purpose;
  final String target;
  final DateTime expiresAt;
  int attempts = 0;
  bool verified = false;
  bool consumed = false;
}

class PrivacyDemoException implements Exception {
  const PrivacyDemoException(this.code);
  final String code;
  @override
  String toString() => code;
}
