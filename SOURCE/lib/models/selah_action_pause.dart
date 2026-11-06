/// LOCK 7/13 wording for the existing local Journey actions.
enum SelahActionPauseKind { ask, accept, end, replace }

class SelahActionPause {
  const SelahActionPause({
    required this.kind,
    required this.name,
    this.shepherdName,
    this.endingName,
    this.otherGender,
  }) : assert(kind != SelahActionPauseKind.replace || endingName != null),
       assert(
         kind != SelahActionPauseKind.accept ||
             otherGender == 'male' ||
             otherGender == 'female',
       );

  final SelahActionPauseKind kind;
  final String name;
  final String? shepherdName;
  final String? endingName;
  final String? otherGender;

  bool get hasShepherd => shepherdName?.trim().isNotEmpty == true;
  bool get canOpen => kind == SelahActionPauseKind.end || hasShepherd;
  bool get destructive =>
      kind == SelahActionPauseKind.end || kind == SelahActionPauseKind.replace;

  static const noShepherdMessage =
      'Add a Shepherd to request or accept a Journey.';

  String get heading => switch (kind) {
    SelahActionPauseKind.ask => 'Pause before you ask.',
    SelahActionPauseKind.accept => 'Pause before you accept.',
    SelahActionPauseKind.end => 'Pause before you end.',
    SelahActionPauseKind.replace => 'Pause before you choose.',
  };

  String get body => switch (kind) {
    SelahActionPauseKind.ask =>
      'Asking $name to begin a Journey is a serious step toward marriage. '
          '$shepherdName will see this request, and so will $name’s Shepherd.',
    SelahActionPauseKind.accept =>
      'Accepting $name starts a Journey. Your Shepherd and '
          '${otherGender == 'female' ? 'hers' : 'his'} will both walk with you.',
    SelahActionPauseKind.end =>
      'Ending your Journey with $name closes it for both of you.'
          '${hasShepherd ? ' $shepherdName will be told and can support you.' : ''}',
    SelahActionPauseKind.replace =>
      'Your Journeys are full. Accepting $name means ending your '
          'Journey with $endingName. Your history stays. $shepherdName will be '
          'told, and so will $endingName’s and $name’s Shepherds.',
  };

  String get primaryLabel => switch (kind) {
    SelahActionPauseKind.ask => 'Send request',
    SelahActionPauseKind.accept => 'Accept and begin',
    SelahActionPauseKind.end => 'End Journey',
    SelahActionPauseKind.replace => 'End and accept',
  };

  String get workingLabel => destructive ? 'Ending…' : 'Sending…';

  String get failureMessage => switch (kind) {
    SelahActionPauseKind.ask => 'Your request didn’t send. Try again.',
    SelahActionPauseKind.accept => 'Your answer didn’t send. Try again.',
    SelahActionPauseKind.end => 'Ending didn’t go through. Try again.',
    SelahActionPauseKind.replace =>
      'That didn’t go through. Nothing has changed. Try again.',
  };
}
