// App-stopping error states shared by routing, startup and presentation.
//
// These are deliberately separate from inline field errors, banners and
// honest empty states. A full-screen error is reserved for a route or app
// surface that cannot be opened at all.

import 'dart:async';

import 'package:flutter/foundation.dart';

enum SelahErrorKind {
  page,
  offline,
  serviceUnavailable,
  sessionExpired,
  previewAccess,
}

/// A protected preview must never fall through to ordinary member data when
/// fresh authorization is unavailable. This error offers an explicit recovery.
class SelahPreviewAuthorizationException implements Exception {
  const SelahPreviewAuthorizationException();

  @override
  String toString() => 'Local preview authorization could not be verified.';
}

@immutable
class SelahErrorContent {
  final String title;
  final String message;
  final String primaryLabel;
  final String secondaryLabel;

  const SelahErrorContent({
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.secondaryLabel,
  });
}

extension SelahErrorKindContent on SelahErrorKind {
  SelahErrorContent get content => switch (this) {
    SelahErrorKind.page => const SelahErrorContent(
      title: 'We couldn’t open this page.',
      message: 'Something didn’t load correctly. Please try again.',
      primaryLabel: 'Try again',
      secondaryLabel: 'Return home',
    ),
    SelahErrorKind.offline => const SelahErrorContent(
      title: 'We couldn’t connect to Selah.',
      message: 'Check your connection, or try again shortly.',
      primaryLabel: 'Try again',
      secondaryLabel: 'Return to welcome',
    ),
    SelahErrorKind.serviceUnavailable => const SelahErrorContent(
      title: 'Selah is taking a moment.',
      message: 'We’re temporarily unavailable. Please try again shortly.',
      primaryLabel: 'Try again',
      secondaryLabel: 'Return home',
    ),
    SelahErrorKind.sessionExpired => const SelahErrorContent(
      title: 'Your session has ended.',
      message: 'For your security, please sign in again.',
      primaryLabel: 'Sign in again',
      secondaryLabel: 'Return to welcome',
    ),
    SelahErrorKind.previewAccess => const SelahErrorContent(
      title: 'Preview access needs checking.',
      message: 'Check access again, or sign out. Live data stays blocked.',
      primaryLabel: 'Check access again',
      secondaryLabel: 'Sign out',
    ),
  };
}

/// Maps an internal failure to one of the four user-facing states without
/// ever putting the raw exception on screen.
SelahErrorKind selahErrorKindFor(Object error) {
  if (error is SelahPreviewAuthorizationException) {
    return SelahErrorKind.previewAccess;
  }
  // A timed-out operation can be local storage or a slow service. It is not
  // evidence that the member's device is offline.
  if (error is TimeoutException) return SelahErrorKind.serviceUnavailable;

  final text = '${error.runtimeType}: $error'.toLowerCase();
  if (_containsAny(text, const [
    'invalid refresh token',
    'refresh token is invalid',
    'refresh token has expired',
    'refresh token is expired',
    'refresh token expired',
    'refresh token not found',
    'refresh token was not found',
    'refresh token already used',
    'refresh token has already been used',
    'refresh token has been reused',
    'refresh_token_not_found',
    'refresh_token_already_used',
    'refresh_token_invalid',
    'invalid jwt',
    'jwt expired',
    'token has expired',
    'session expired',
    'statuscode: 401',
    'status: 401',
  ])) {
    return SelahErrorKind.sessionExpired;
  }
  if (_containsAny(text, const [
    'service unavailable',
    'bad gateway',
    'gateway timeout',
    'internal server error',
    'statuscode: 500',
    'statuscode: 502',
    'statuscode: 503',
    'statuscode: 504',
    'status: 500',
    'status: 502',
    'status: 503',
    'status: 504',
  ])) {
    return SelahErrorKind.serviceUnavailable;
  }
  if (_containsAny(text, const [
    'socketexception',
    'failed host lookup',
    'network is unreachable',
    'network request failed',
    'connection refused',
    'connection reset',
    'connection closed',
    'no address associated',
  ])) {
    return SelahErrorKind.offline;
  }
  return SelahErrorKind.page;
}

bool _containsAny(String text, List<String> needles) =>
    needles.any(text.contains);

/// An opaque, non-sensitive code the member can quote to support. The same
/// error object produces the same code while its screen remains mounted.
String selahErrorReference(Object error) {
  final value = Object.hash(error.runtimeType, error.hashCode) & 0xFFFFF;
  return 'ZY-${value.toRadixString(36).toUpperCase().padLeft(4, '0')}';
}
