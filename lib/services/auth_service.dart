import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/protocol_id.dart';

class AppUser {
  final String googleUserId;
  final String? displayName;
  final String email;
  final String? photoUrl;
  final String initials;

  const AppUser({
    required this.googleUserId,
    required this.displayName,
    required this.email,
    required this.photoUrl,
    required this.initials,
  });

  factory AppUser.fromGoogleAccount(GoogleSignInAccount account) {
    return AppUser(
      googleUserId: account.id,
      displayName: account.displayName,
      email: account.email,
      photoUrl: account.photoUrl,
      initials: initialsFromDisplayName(account.displayName),
    );
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      googleUserId: json['googleUserId'] ?? '',
      displayName: json['displayName'],
      email: json['email'] ?? '',
      photoUrl: json['photoUrl'],
      initials:
          json['initials'] ?? initialsFromDisplayName(json['displayName']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'googleUserId': googleUserId,
      'displayName': displayName,
      'email': email,
      'photoUrl': photoUrl,
      'initials': initials,
    };
  }
}

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();
  static const String driveAppDataScope =
      'https://www.googleapis.com/auth/drive.appdata';
  static const String _userKey = 'signed_in_google_user_json';
  static const String _serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );
  static const String _webClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final StreamController<AppUser?> _userController =
      StreamController<AppUser?>.broadcast();

  AppUser? _currentUser;
  GoogleSignInAccount? _currentAccount;
  bool _initialized = false;
  Future<void>? _initializationFuture;
  Object? _initializationError;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _authSubscription;

  AppUser? get currentUser => _currentUser;
  Stream<AppUser?> get userChanges => _userController.stream;
  bool get supportsDirectAuthenticate => _googleSignIn.supportsAuthenticate();
  bool get hasAuthenticatedAccount => _currentAccount != null;
  Object? get initializationError => _initializationError;

  Future<void> initialize() async {
    if (_initialized) return;
    final currentInitialization = _initializationFuture;
    if (currentInitialization != null) return currentInitialization;

    _initializationFuture = _initialize();
    return _initializationFuture;
  }

  Future<void> _initialize() async {
    try {
      await _loadCachedUser();
      await _googleSignIn.initialize(
        clientId: _googleClientId,
        serverClientId: kIsWeb ? null : _nullableEnv(_serverClientId),
      );
      _authSubscription = _googleSignIn.authenticationEvents.listen(
        _handleAuthenticationEvent,
        onError: (_) => _setCurrentUser(null, persist: true),
      );

      final lightweightAuth = _googleSignIn.attemptLightweightAuthentication();
      if (lightweightAuth != null) {
        final account = await lightweightAuth;
        if (account != null) {
          _currentAccount = account;
          await _setCurrentUser(
            AppUser.fromGoogleAccount(account),
            persist: true,
          );
        }
      }

      _initialized = true;
      _initializationError = null;
    } catch (e) {
      _initializationFuture = null;
      _initializationError = e;
      rethrow;
    }
  }

  String? get _googleClientId {
    if (kIsWeb) {
      return _nullableEnv(_webClientId) ?? _nullableEnv(_serverClientId);
    }
    return null;
  }

  String? _nullableEnv(String value) {
    return value.isEmpty ? null : value;
  }

  Future<AppUser?> signIn() async {
    await initialize();
    if (!_googleSignIn.supportsAuthenticate()) {
      throw UnsupportedError(
        'Google Sign-In interactive authentication is not supported on this platform.',
      );
    }

    final account = await _googleSignIn.authenticate(
      scopeHint: const [driveAppDataScope],
    );
    _currentAccount = account;
    final user = AppUser.fromGoogleAccount(account);
    await _setCurrentUser(user, persist: true);
    return user;
  }

  Future<Map<String, String>?> authorizationHeadersForDrive({
    bool promptIfNecessary = false,
  }) async {
    await initialize();
    final account = _currentAccount;
    final authorizationClient =
        account?.authorizationClient ?? _googleSignIn.authorizationClient;
    return authorizationClient.authorizationHeaders(const [
      driveAppDataScope,
    ], promptIfNecessary: promptIfNecessary);
  }

  Future<void> signOut() async {
    await initialize();
    await _googleSignIn.signOut();
    _currentAccount = null;
    await _setCurrentUser(null, persist: true);
  }

  Future<void> _loadCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_userKey);
    if (cached == null || cached.isEmpty) return;

    final decoded = jsonDecode(cached);
    if (decoded is Map<String, dynamic>) {
      _currentUser = AppUser.fromJson(decoded);
      _userController.add(_currentUser);
    }
  }

  Future<void> _handleAuthenticationEvent(
    GoogleSignInAuthenticationEvent event,
  ) async {
    switch (event) {
      case GoogleSignInAuthenticationEventSignIn():
        _currentAccount = event.user;
        await _setCurrentUser(
          AppUser.fromGoogleAccount(event.user),
          persist: true,
        );
      case GoogleSignInAuthenticationEventSignOut():
        _currentAccount = null;
        await _setCurrentUser(null, persist: true);
    }
  }

  Future<void> _setCurrentUser(AppUser? user, {required bool persist}) async {
    _currentUser = user;
    _userController.add(user);
    if (!persist) return;

    final prefs = await SharedPreferences.getInstance();
    if (user == null) {
      await prefs.remove(_userKey);
    } else {
      await prefs.setString(_userKey, jsonEncode(user.toJson()));
    }
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    await _userController.close();
  }
}
