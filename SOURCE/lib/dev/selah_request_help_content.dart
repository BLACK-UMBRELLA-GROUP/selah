import '../data/help_content.dart';

/// Reuse current, unchanged account/profile answers. Legacy matching, saved,
/// paused/restart and old filter instructions must not leak into request flow.
/// This is presentation guidance, not a receipt or live-provider claim.
final List<SelahHelpCategory> selahRequestHelpCategories = List.unmodifiable([
  const SelahHelpCategory('Browsing and Journey invitations', [
    SelahHelpEntry(
      'How do I invite someone to a Journey?',
      'In Browse, choose Request a Journey. The button changes to Journey '
          'invitation sent. Press it again to cancel the invitation.\n\n'
          'An invitation does not open a conversation or reveal private '
          'answers. You both choose whether to begin a Journey.',
    ),
    SelahHelpEntry(
      'How do I move to another profile?',
      'Use the right arrow to move to another profile. Moving on does not '
          'send an invitation. The left arrow returns through up to ten '
          'previously viewed profiles.',
    ),
    SelahHelpEntry(
      'Where can I find my invitations?',
      'Open My Selah, then Journey requests. Received and Sent keep the '
          'two directions separate; Introductions has its own tab.',
    ),
    SelahHelpEntry(
      'How do I find someone by Selah Code?',
      'Open the three dots in Browse, then Scan. Scan their code or enter '
          'it and choose Check code. Confirm the person, then choose View '
          'profile. Finding a profile does not send an invitation.',
    ),
    SelahHelpEntry(
      'What happens when a Journey ends?',
      'Ended Journeys live in My Selah as history, not as invitations to '
          'restart. They do not reserve an active Journey place. A blocked '
          'person appears as User not found instead of revealing their '
          'profile or conversation.',
    ),
  ]),
  for (final category in selahHelpCategories)
    if (category.entries.any(
      (entry) => _retainedQuestions.contains(entry.question),
    ))
      SelahHelpCategory(
        category.title,
        List.unmodifiable(
          category.entries.where(
            (entry) => _retainedQuestions.contains(entry.question),
          ),
        ),
      ),
]);

const _retainedQuestions = {
  'How do I sign in?',
  'Who needs a Shepherd?',
  'When does my profile go live?',
  'Can I change my date of birth?',
  'Who can see my photos?',
  'What is Compatibility Unlock?',
  'Can someone find out I blocked them?',
};
