import 'package:flutter/foundation.dart';

/// Exceptions from auth/HTTP/storage may contain member data or tokens.
/// Release diagnostics use the closed reliability taxonomy instead of raw
/// console messages. Debug/profile tooling remains available for local work.
void installSelahReleaseDiagnostics({bool release = kReleaseMode}) {
  if (release) debugPrint = (String? message, {int? wrapWidth}) {};
}
