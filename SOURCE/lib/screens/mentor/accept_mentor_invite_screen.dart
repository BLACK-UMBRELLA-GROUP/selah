// Shared invite-code entry screen — reachable from LinkMentorScreen on
// both sides (a Seeker linking a Mentor, or a Mentor linking a Seeker).
// Previews who sent the code before committing (via preview_mentor_
// invite), then commits via accept_mentor_invite. Same screen serves
// both directions since the underlying mechanism is symmetric — see
// SelahMentorLinkService's doc comment.

import 'package:flutter/material.dart';
import '../../dev/selah_app_gold_preview.dart';
import '../../data/selah_reference_data.dart';
import '../../services/selah_mentor_link_service.dart';
import '../../services/selah_promotion_engine.dart';
import '../../state/app_state.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_text.dart';
import '../../widgets/selah_state_widgets.dart';
import '../../widgets/selah_shepherd_capacity_notice.dart';
import '../../widgets/selah_glass_dialog.dart';

class AcceptMentorInviteScreen extends StatefulWidget {
  final String? initialCode;

  const AcceptMentorInviteScreen({super.key, this.initialCode});

  @override
  State<AcceptMentorInviteScreen> createState() => _AcceptMentorInviteScreenState();
}

class _AcceptMentorInviteScreenState extends State<AcceptMentorInviteScreen> {
  late final TextEditingController _controller;
  bool _checking = false;
  bool _accepting = false;
  bool _declining = false;
  String? _error;
  Map<String, String>? _preview;

  /// The stored CODE, never the label. Null until the preview resolves.
  ///
  /// ADDED 2026-08-06. The relationship question is NOT new — Shepherd
  /// onboarding has always asked it. What was missing is a write: the answer
  /// lived in AppState and was never persisted, so `mentor_links.relationship`
  /// stayed null for every real user while the dev fixtures made the Shepherd
  /// tab look correct. This screen is where the answer finally reaches the
  /// database, because this is the moment the link exists to hang it on.
  String? _relationshipCode;
  bool _changingRelationship = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialCode);
  }

  /// Only a Shepherd states a relationship, and only about the Seeker they
  /// are being linked to. When the inviter is a Shepherd the accepter is the
  /// Seeker, who has nothing to say about themselves.
  bool get _needsRelationship => _preview?['inviterRole'] == 'seeker';

  bool get _canAccept => !_needsRelationship || _relationshipCode != null;

  Future<void> _checkCode() async {
    final code = _controller.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _checking = true;
      _error = null;
      _preview = null;
    });
    final preview = await SelahMentorLinkService.previewInvite(code);
    if (!mounted) return;
    setState(() {
      _checking = false;
      if (preview == null) {
        _error = "That code wasn't found. Check it and try again.";
      } else if (preview['status'] == 'expired') {
        _error = 'This code has expired — ask them to generate a new one.';
      } else if (preview['status'] != 'pending') {
        _error = 'That code has already been used.';
      } else {
        _preview = preview;
        // Pre-fill from the answer already given at Shepherd onboarding.
        // AppState holds a LABEL; the database takes a code, so it is
        // converted here. An unrecognised label yields null rather than
        // being stored raw — the picker then simply opens unselected.
        _relationshipCode = selahRelationshipCode(
          AppState.instance.mentorRelationship,
        );
        _changingRelationship = _relationshipCode == null;
      }
    });
  }

  Future<void> _accept() async {
    setState(() {
      _accepting = true;
      _error = null;
    });
    final error = await SelahMentorLinkService.acceptInvite(
      _controller.text.trim(),
      relationship: _needsRelationship ? _relationshipCode : null,
      currentSeekerPlan: _needsRelationship ? null : AppState.instance.plan,
    );
    if (!mounted) return;
    setState(() => _accepting = false);
    if (error != null) {
      setState(() => _error = error);
      showSelahShepherdCapacityNotice(context, error);
      return;
    }
    if (_needsRelationship) {
      // The signed-in member is the Shepherd accepting their first/new
      // Seeker link. Mark eligibility after the server write, never inside
      // the acceptance decision itself.
      await SelahPromotionEngine.instance.markNotificationValueMoment(
        role: SelahPromotionRole.shepherd,
        trigger: SelahPromotionTrigger.firstSeekerLink,
      );
      await SelahPromotionEngine.instance.markUpgradeValueMoment(
        role: SelahPromotionRole.shepherd,
        product: SelahPromotionProduct.shepherdPlus,
        placement: SelahPromotionPlacement.home,
        feature: SelahPromotionFeature.shepherdNetwork,
        trigger: SelahPromotionTrigger.firstSeekerLink,
      );
      if (!mounted) return;
    }
    Navigator.of(context).pop(true);
  }

  Future<void> _decline() async {
    final inviter = _preview?['inviterFirstName'] ?? 'them';
    final confirmed = await showSelahGlassChoice(
      context: context,
      icon: Icons.person_remove_outlined,
      title: 'Decline invitation?',
      body:
          '$inviter will be told that you declined. You can still link later '
          'with a new invitation.',
      primaryLabel: 'Decline',
      secondaryLabel: 'Keep it',
      destructivePrimary: true,
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _declining = true;
      _error = null;
    });
    final error = await SelahMentorLinkService.declineInvite(_controller.text);
    if (!mounted) return;
    setState(() => _declining = false);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Invitation declined.')));
    Navigator.of(context).pop(false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // FIXED 2026-08-01 (Founder: "there should be no purple at top, it
      // should blend the pink/purple colour... that should be across all
      // things"). Same fix notifications_screen.dart got on 2026-07-27:
      // without this the transparent AppBar shows the Scaffold's own flat
      // background through, cutting the gender gradient off with a hard
      // purple strip. Body content compensates with SafeArea, which still
      // clears the status bar.
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Enter Invite Code', style: SelahText.heading(size: 17)),
        iconTheme: IconThemeData(color: SelahColors.ink(0.70)),
      ),
      body: Container(
        // FILLS ITS BOX — 2026-08-13 (inherited decision 165). Scaffold lays its
        // body out with LOOSE constraints and the child below is a
        // SingleChildScrollView, so without this the gradient Container
        // shrank to its content height and left a band of bare Scaffold
        // beneath short content.
        //
        // This is verbatim the bug fixed in report_profile_sheet.dart on
        // 2026-08-03, whose own note warned "every future screen built on
        // SingleChildScrollView would inherit the same band". This screen
        // became scrollable on 2026-08-06 — three days later — and did
        // not get the constraint.
        constraints: const BoxConstraints.expand(),
        // 2026-07-25: gender-matched gradient (inherited decision 094). This screen
        // is only ever reached by an already-signed-in account (Seeker
        // or Shepherd) linking the other party, so gender is always known
        // here — see SelahColors.genderGradient() doc comment.
        decoration: SelahAppGoldDecoration(
          gradient: SelahColors.genderGradient(AppState.instance.gender),
        ),
        child: SafeArea(
          // Scrollable since 2026-08-06: the relationship picker adds up to
          // seven tiles, which overflows a fixed Column on a small handset
          // once the keyboard is up.
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 24),
                Text(
                  "Enter the code they shared with you.",
                  style: SelahText.subtext(),
                ),
                SizedBox(height: 20),
                TextField(
                  controller: _controller,
                  textCapitalization: TextCapitalization.characters,
                  style: SelahText.heading(size: 20).copyWith(letterSpacing: 4),
                  decoration: InputDecoration(
                    hintText: 'ABCD1234',
                    hintStyle: SelahText.subtext(size: 20),
                    filled: true,
                    fillColor: SelahColors.iconButtonBg,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (_) => setState(() {
                    _preview = null;
                    _error = null;
                    _relationshipCode = null;
                    _changingRelationship = false;
                  }),
                ),
                SizedBox(height: 16),
                if (_preview != null)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: SelahColors.iconButtonBg,
                      border: Border.all(
                        color: SelahColors.iconButtonBorder,
                        width: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_preview!['inviterFirstName']} has invited you to link as their '
                      '${_preview!['inviterRole'] == 'seeker' ? 'Mentor' : 'Seeker'}.',
                      style: SelahText.body(size: 13, color: Colors.white),
                    ),
                  ),
                if (_preview != null && _needsRelationship) ...[
                  SizedBox(height: 22),
                  Text(
                    'How are you related to ${_preview!['inviterFirstName']}?',
                    style: SelahText.body(size: 15, color: Colors.white),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'This is shown to Seekers who unlock their profile, so they '
                    'know who they may be speaking with.',
                    style: SelahText.subtext(size: 12.5),
                  ),
                  SizedBox(height: 14),
                  // Confirm-or-change, not a seventh question. The answer is
                  // already known from onboarding, so the common path is one
                  // tap on Confirm Link. Expanding the full list is the
                  // exception — which is what "confirm or change" means, and
                  // it keeps a code-entry screen from becoming a form.
                  if (!_changingRelationship && _relationshipCode != null)
                    _RelationshipConfirmRow(
                      label: selahRelationshipLabel(_relationshipCode) ?? '',
                      onChange: () =>
                          setState(() => _changingRelationship = true),
                    )
                  else
                    ...selahShepherdRelationships.map(
                      (r) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _RelationshipOption(
                          label: r.name,
                          selected: _relationshipCode == r.code,
                          onTap: () => setState(() {
                            _relationshipCode = r.code;
                            _changingRelationship = false;
                          }),
                        ),
                      ),
                    ),
                ],
                if (_error != null) ...[
                  SizedBox(height: 12),
                  SelahErrorBanner(
                    message: _error!,
                    onDismiss: () => setState(() => _error = null),
                  ),
                ],
                SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _canAccept
                          ? SelahColors.accentBg
                          : SelahColors.iconButtonBg,
                      border: Border.all(
                        color: _canAccept
                            ? SelahColors.accentBorder
                            : SelahColors.iconButtonBorder,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(50),
                        onTap: _checking || _accepting || _declining
                            ? null
                            : (_preview == null
                                  ? _checkCode
                                  : (_canAccept ? _accept : null)),
                        child: Center(
                          child: Text(
                            _checking
                                ? 'Checking…'
                                : _accepting
                                ? 'Linking…'
                                : (_preview == null
                                      ? 'Check Code'
                                      : 'Confirm Link'),
                            style: SelahText.button(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_preview != null) ...[
                  SizedBox(height: 10),
                  Center(
                    child: TextButton(
                      onPressed: _checking || _accepting || _declining
                          ? null
                          : _decline,
                      child: Text(
                        _declining ? 'Declining…' : 'Decline invitation',
                        style: SelahText.body(
                          size: 13.5,
                          color: SelahColors.foreground.withValues(alpha: 0.65),
                        ),
                      ),
                    ),
                  ),
                ],
                SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The pre-filled answer, with one tap to change it.
class _RelationshipConfirmRow extends StatelessWidget {
  final String label;
  final VoidCallback onChange;
  const _RelationshipConfirmRow({required this.label, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: SelahColors.accentBg,
          border: Border.all(color: SelahColors.accentBorder, width: 1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onChange,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  Expanded(child: Text(label, style: SelahText.option())),
                  Text('Change', style: SelahText.subtext(size: 13)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Visually identical to the option tile in `mentor_onboarding_flow.dart`.
/// Duplicated rather than shared because that one is library-private and
/// Shepherd onboarding is explicitly out of scope for this change (Founder,
/// 2026-08-06). Worth promoting to a shared widget when onboarding is next
/// opened for its own reasons — noted, not done here.
class _RelationshipOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _RelationshipOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? SelahColors.accentBg : SelahColors.iconButtonBg,
          border: Border.all(
            color: selected
                ? SelahColors.accentBorder
                : SelahColors.iconButtonBorder,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Center(child: Text(label, style: SelahText.option())),
          ),
        ),
      ),
    );
  }
}
