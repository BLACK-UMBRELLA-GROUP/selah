/// Signup intent only. None of these values proves payment, identity or access.
enum SelahSignupRole { seeker, shepherd }

enum SelahSignupMembershipKind { basic, one, family }

class SelahSignupMembershipChoice {
  final SelahSignupMembershipKind kind;
  final int seekers;
  final int shepherds;

  const SelahSignupMembershipChoice({
    required this.kind,
    this.seekers = 0,
    this.shepherds = 0,
  });

  bool isValidFor(SelahSignupRole role) {
    if (kind != SelahSignupMembershipKind.family) {
      return seekers == 0 && shepherds == 0;
    }
    if (seekers < 0 || seekers > 10 || shepherds < 0 || shepherds > 10) {
      return false;
    }
    return role == SelahSignupRole.seeker ? seekers > 0 : shepherds > 0;
  }

  Map<String, Object> toJson() => {
    'kind': kind.name,
    'seekers': seekers,
    'shepherds': shepherds,
  };

  static SelahSignupMembershipChoice fromJson(
    Object? value, {
    required SelahSignupRole role,
  }) {
    if (value is! Map<String, dynamic> ||
        value.length != 3 ||
        !SelahSignupMembershipKind.values.any(
          (kind) => kind.name == value['kind'],
        ) ||
        value['seekers'] is! int ||
        value['shepherds'] is! int) {
      throw const FormatException('Invalid membership choice.');
    }
    final choice = SelahSignupMembershipChoice(
      kind: SelahSignupMembershipKind.values.byName(value['kind']),
      seekers: value['seekers'],
      shepherds: value['shepherds'],
    );
    if (!choice.isValidFor(role)) {
      throw const FormatException('Invalid membership choice.');
    }
    return choice;
  }
}

/// Retained separately from the erased identity form. This is not entitlement.
class SelahSignupMembershipIntent {
  final SelahSignupRole role;
  final SelahSignupMembershipChoice choice;

  const SelahSignupMembershipIntent({required this.role, required this.choice});

  bool get isValid => choice.isValidFor(role);

  Map<String, Object> toJson() => {
    'version': 1,
    'role': role.name,
    'choice': choice.toJson(),
  };

  static SelahSignupMembershipIntent fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value.length != 3 ||
        value['version'] != 1 ||
        !SelahSignupRole.values.any((role) => role.name == value['role'])) {
      throw const FormatException('Invalid membership intent.');
    }
    final role = SelahSignupRole.values.byName(value['role']);
    return SelahSignupMembershipIntent(
      role: role,
      choice: SelahSignupMembershipChoice.fromJson(value['choice'], role: role),
    );
  }
}
