import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/selah_app_variant.dart';
import '../config/selah_external_tester_policy.dart';
import '../config/selah_internal_founder_policy.dart';

/// Accidental-write isolation for the main app's local Founder previews.
/// Server authentication/RLS remain the security boundary for real members.
/// This client never creates authority or turns a failed request into success.
class SelahInternalPreviewClient extends http.BaseClient {
  SelahInternalPreviewClient(this._inner, {bool Function()? previewActive})
    : _previewActive = previewActive ?? (() => isActive);

  final http.Client _inner;
  final bool Function() _previewActive;
  static final ValueNotifier<bool> _active = ValueNotifier(false);
  static int _requestGeneration = 0;
  static int _previewSession = 0;
  static bool _accountBound = false;
  static String? _accountOwner;
  static ValueListenable<bool> get changes => _active;
  static bool get isActive => _active.value;
  static int get previewSession => _previewSession;

  /// Invalidate responses already in flight before an account boundary.
  /// This cannot undo a server operation; it prevents stale client hydration.
  static void invalidateAccountRequests() => _requestGeneration++;

  /// Deny-only binding: old mounted screens cannot dispatch data with the
  /// previous token while sign-out or an account replacement is in progress.
  /// This never authenticates a request or bypasses server policies.
  static void bindAccount(String? owner) {
    _accountBound = true;
    _accountOwner = owner;
    invalidateAccountRequests();
  }

  static http.Client? create() =>
      (SelahInternalFounderPolicy.enabled || SelahExternalTesterPolicy.enabled) &&
          SelahAppVariantPolicy.current == SelahAppVariant.production
      ? SelahInternalPreviewClient(http.Client())
      : null;

  /// Latched by a freshly authorised Founder, before any preview route opens.
  /// Revocation does NOT release the latch. A completed sign-out does.
  static void beginPreview() {
    if (!_active.value) {
      _previewSession += 1;
      invalidateAccountRequests();
    }
    _active.value = true;
  }

  static void finishSignOut() {
    if (_active.value) invalidateAccountRequests();
    _active.value = false;
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final generation = _requestGeneration;
    final uri = request.url;
    // Never transmit the configured client's credentials to another host.
    final endpoint = Uri.parse(SelahInternalFounderPolicy.approvedSupabaseUrl);
    if (uri.scheme != endpoint.scheme ||
        uri.host != endpoint.host ||
        uri.port != endpoint.port ||
        uri.userInfo.isNotEmpty) {
      return _blocked(request);
    }

    // A token payload is NOT verified here. It is inspected only to DENY
    // requests from the pinned Founder even before/after a preview latch.
    // Forwarded personal requests still need genuine server authentication.
    String? subject;
    final bearer = request.headers['authorization'] ?? '';
    try {
      if (bearer.startsWith('Bearer ')) {
        final parts = bearer.substring(7).split('.');
        if (parts.length == 3) {
          final payload = jsonDecode(
            utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
          );
          if (payload is Map && payload['sub'] is String) {
            subject = payload['sub'] as String;
          }
        }
      }
    } catch (_) {
      // Unknown identity is never permission for a preview data operation.
    }
    final protected =
        _previewActive() ||
        subject == SelahInternalFounderPolicy.approvedFounderUserId;

    if (uri.path.startsWith('/auth/v1/')) {
      // Keep native Google/Apple login, session refresh and logout working.
      // Do not permit preview screens to link providers, edit/delete an Auth
      // identity or request recovery messages with the Founder's session.
      if (protected &&
          !((request.method == 'POST' &&
                  (uri.path == '/auth/v1/token' ||
                      uri.path == '/auth/v1/logout')) ||
              (request.method == 'GET' && uri.path == '/auth/v1/user'))) {
        return _blocked(request);
      }
      return _inner.send(request);
    }

    // Includes reads: preview widgets must not mix real rows with fixtures.
    // A queued Founder request stays denied after a personal sign-in; a
    // personal token also stays denied while a preview session is latched.
    if (protected || subject == null || subject.isEmpty) {
      return _blocked(request);
    }
    if (_accountBound && subject != _accountOwner) {
      return _blocked(request, accountChanged: true, requestSent: false);
    }
    final response = await _inner.send(request);
    if (generation != _requestGeneration || _previewActive()) {
      await response.stream.listen((_) {}).cancel();
      return _blocked(request, accountChanged: true);
    }
    return http.StreamedResponse(
      _guardResponseBody(response.stream, request, generation),
      response.statusCode,
      contentLength: response.contentLength,
      request: response.request ?? request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  Stream<List<int>> _guardResponseBody(
    Stream<List<int>> body,
    http.BaseRequest request,
    int generation,
  ) async* {
    void checkOwner() {
      if (generation != _requestGeneration || _previewActive()) {
        throw http.ClientException(
          'Account changed. The previous account response was discarded.',
          request.url,
        );
      }
    }

    await for (final chunk in body) {
      checkOwner();
      yield chunk;
    }
    checkOwner();
  }

  http.StreamedResponse _blocked(
    http.BaseRequest request, {
    bool accountChanged = false,
    bool requestSent = true,
  }) => http.StreamedResponse(
    Stream.value(
      utf8.encode(
        jsonEncode({
          'code': accountChanged
              ? 'SELAH_ACCOUNT_CHANGED'
              : 'SELAH_LOCAL_PREVIEW',
          'message': accountChanged
              ? (requestSent
                    ? 'Account changed. The previous account response was discarded.'
                    : 'Account changed. No backend request was sent.')
              : 'Local preview only. No backend request was sent.',
        }),
      ),
    ),
    403,
    // PostgREST reads the originating method even when handling an error.
    // Omitting this changed a deliberate denial into a null-check crash.
    request: request,
    headers: {'content-type': 'application/json'},
  );

  @override
  void close() => _inner.close();
}
