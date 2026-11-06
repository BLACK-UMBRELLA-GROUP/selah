// Report / block a specific person — 2026-08-01 (Founder request).
//
// Replaces the old "Report a Problem" row, which opened the generic Help
// & Support screen: no subject, no reason, nowhere for a report to go.
//
// Show the subject clearly, separate blocking from reporting, and keep
// moderation warnings out of the reporting flow.
//
// Blocking is enforced in profiles_select's RLS, so it applies everywhere
// at once rather than only on the screen it was triggered from.

import 'package:flutter/material.dart';
import 'selah_loading.dart';
import 'package:flutter/services.dart';
import '../models/seeker_profile.dart';
import '../models/selah_moderation_review.dart';
import '../services/selah_hidden_profile_store.dart';
import '../services/selah_moderation_preview_store.dart';
import '../services/selah_report_service.dart';
import '../state/app_state.dart';
import '../theme/selah_colors.dart';
import '../theme/selah_text.dart';

enum SelahReportTarget { profile, photo }

/// Returns true if the user reported or blocked (so the caller can
/// advance past this profile), false/null if they backed out.
/// CHANGED 2026-08-01 (Founder: "when I click on report user there's one
/// animation and when I click Help and Support it's a different animation.
/// Keep them consistent — both copying the Help and Support style").
///
/// Was showModalBottomSheet: the sheet slid UP from the bottom while Help
/// pushed in from the RIGHT. Both sat behind the same two rows of the same
/// menu, so the menu appeared to lead to two different kinds of place.
///
/// Now a pushed route, matching HelpSupportScreen exactly — same
/// MaterialPageRoute, same transparent AppBar over a gender gradient, same
/// back arrow. The function name is kept so the four call sites do not
/// churn; the return contract is unchanged (true = reported or blocked).
///
/// This also resolves something flagged the same day: the Help/Report menu
/// became a centred glass card, and a centred card opening a bottom sheet
/// was the last inconsistency left in that flow.
Future<bool?> showReportProfileSheet(
  BuildContext context, {
  required String profileId,
  required String firstName,
  SelahReportSource source = SelahReportSource.browse,
  SeekerProfile? profileSnapshot,
  bool simulateOnly = false,
  bool applySimulatedHideLocally = true,
  SelahReportTarget target = SelahReportTarget.profile,
  int photoIndex = 0,
}) async {
  var reportCompleted = false;
  final routeResult = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => _ReportProfileSheet(
        profileId: profileId,
        firstName: firstName,
        source: source,
        profileSnapshot: profileSnapshot,
        simulateOnly: simulateOnly,
        applySimulatedHideLocally: applySimulatedHideLocally,
        target: target,
        photoIndex: photoIndex,
        onReportComplete: () => reportCompleted = true,
      ),
    ),
  );
  return reportCompleted ? true : routeResult;
}

class _ReportProfileSheet extends StatefulWidget {
  final String profileId;
  final String firstName;
  final SelahReportSource source;
  final SeekerProfile? profileSnapshot;
  final bool simulateOnly;
  final bool applySimulatedHideLocally;
  final SelahReportTarget target;
  final int photoIndex;
  final VoidCallback onReportComplete;

  const _ReportProfileSheet({
    required this.profileId,
    required this.firstName,
    required this.source,
    required this.profileSnapshot,
    required this.simulateOnly,
    required this.applySimulatedHideLocally,
    required this.target,
    required this.photoIndex,
    required this.onReportComplete,
  });

  @override
  State<_ReportProfileSheet> createState() => _ReportProfileSheetState();
}

class _ReportProfileSheetState extends State<_ReportProfileSheet> {
  SelahReportReason? _selected;
  final TextEditingController _detailController = TextEditingController();
  bool _submitting = false;
  bool _reportSent = false;
  bool _reportStored = false;
  bool _confirmingHide = false;
  String? _error;

  @override
  void dispose() {
    _detailController.dispose();
    super.dispose();
  }

  Future<void> _rememberHiddenProfile() async {
    final profile = widget.profileSnapshot;
    if (profile != null) await SelahHiddenProfileStore.remember(profile);
    AppState.instance.removeHiddenProfileFromSession(widget.profileId);
  }

  Future<void> _blockOnly() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    final ok = widget.simulateOnly
        ? true
        : await SelahReportService.block(widget.profileId);
    if (!mounted) return;
    if (ok) {
      if (!widget.simulateOnly || widget.applySimulatedHideLocally) {
        await _rememberHiddenProfile();
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _submitting = false;
      _error = "That didn't go through. Please try again.";
    });
  }

  Future<void> _submitReport() async {
    final reason = _selected;
    if (reason == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    if (widget.simulateOnly) {
      final profile = widget.profileSnapshot;
      if (profile != null) {
        final index = profile.photos.isEmpty
            ? 0
            : widget.photoIndex.clamp(0, profile.photos.length - 1).toInt();
        SelahModerationPreviewStore.instance.flag(
          profileId: profile.id,
          firstName: profile.firstName,
          photoUrl: profile.photos.isEmpty ? '' : profile.photos[index],
          contentType: widget.target == SelahReportTarget.photo
              ? SelahReportedContentType.photo
              : SelahReportedContentType.profile,
          reason: reason.label,
        );
      }
      if (widget.source != SelahReportSource.shepherd &&
          widget.applySimulatedHideLocally) {
        await _rememberHiddenProfile();
      }
      if (!mounted) return;
      _markReportSent();
      return;
    }

    // Store the report first, then hide separately. This keeps the two
    // outcomes honest: a report must never be resent just because its
    // accompanying hide failed, and Browse must not remove someone locally
    // while the server can still return them on the next fetch.
    final reported = await SelahReportService.reportAndBlock(
      reportedId: widget.profileId,
      reason: reason,
      detail: _detailController.text,
      source: widget.source,
      alsoBlock: false,
    );
    if (!mounted) return;

    if (!reported) {
      setState(() {
        _submitting = false;
        _error =
            "We couldn't send that report. Please try again — nothing has been sent yet.";
      });
      return;
    }

    // A Shepherd report is evidence only. Removing a Shepherd remains a
    // separate, deliberate action on their detail page.
    if (widget.source == SelahReportSource.shepherd) {
      _markReportSent();
      return;
    }

    final hidden = await SelahReportService.block(widget.profileId);
    if (!mounted) return;
    if (hidden) {
      await _rememberHiddenProfile();
      if (!mounted) return;
      _markReportSent();
      return;
    }

    // The report exists. Do not let another tap create a duplicate report;
    // offer an explicit retry of the failed hide only.
    widget.onReportComplete();
    setState(() {
      _reportSent = true;
      _reportStored = true;
      _submitting = false;
      _error =
          'Your report was sent, but we could not hide this profile yet. '
          'Please retry the hide before leaving this screen.';
    });
  }

  void _markReportSent() {
    widget.onReportComplete();
    setState(() {
      _reportSent = true;
      _reportStored = false;
      _submitting = false;
      _error = null;
    });
  }

  Future<void> _retryHideAfterReport() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    final hidden = await SelahReportService.block(widget.profileId);
    if (!mounted) return;
    if (hidden) {
      await _rememberHiddenProfile();
      if (!mounted) return;
      setState(() {
        _reportStored = false;
        _submitting = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _submitting = false;
      _error =
          'The report is safe, but hiding still did not go through. Check '
          'your connection and try again.';
    });
  }

  @override
  Widget build(BuildContext context) {
    // FIXED 2026-08-01 (Founder: "look at the bottom of the picture,
    // it's still the browse page then it's purple"). SafeArea was
    // WRAPPING the coloured Container, so the sheet's surface stopped
    // above the home-indicator inset and the Browse photo showed through
    // underneath it as a strip. Moving SafeArea INSIDE means the colour
    // runs to the physical bottom edge while the content still clears
    // the home indicator.
    // NOW A FULL SCREEN, 2026-08-01. Structure copied from
    // HelpSupportScreen so the two destinations behind the long-press menu
    // are the same kind of place: transparent AppBar over the ratified
    // gender gradient, body extended behind it, back arrow in the corner.
    //
    // SafeArea's top inset covers the status bar only, not the toolbar, so
    // content extending behind the AppBar needs both — same calculation as
    // HelpSupportScreen, for the same reason.
    final topInset = MediaQuery.of(context).padding.top + kToolbarHeight;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.target == SelahReportTarget.photo
              ? 'Report photo'
              : 'Report profile',
          style: SelahText.heading(size: 17),
        ),
        iconTheme: IconThemeData(color: SelahColors.ink(0.70)),
      ),
      // FIXED 2026-08-03 (Founder: "at the bottom there's a pink line —
      // that shouldn't be there").
      //
      // `SingleChildScrollView` sizes itself to its CONTENT, not to the
      // viewport. So this Container — which has only a decoration and a
      // child — shrank to the content height too, and whatever was left
      // below it showed the Scaffold's own background.
      //
      // That background is Rose Pink for a female Seeker, because
      // main.dart sets scaffoldBackgroundColor to the gender gradient's
      // FIRST stop. Which is a change I made earlier the same day to kill
      // the purple-to-pink launch flash — correct there, and it turned a
      // previously-invisible seam into a bright pink band here.
      //
      // Fixed at the cause: the gradient now fills the viewport whatever
      // the content height. Left as-is, every future screen built on
      // SingleChildScrollView would inherit the same band.
      //
      // Not fixed by changing scaffoldBackgroundColor to the gradient's
      // last stop — that would hide gaps at the bottom while reintroducing
      // a flash at the top on cold start, which is the worse trade.
      body: Container(
        constraints: const BoxConstraints.expand(),
        decoration: BoxDecoration(
          gradient: SelahColors.genderGradient(AppState.instance.gender),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(0, topInset + 4, 0, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_reportSent)
                  _ReportSentConfirmation(
                    hideError: _error,
                    retryingHide: _submitting,
                    canRetryHide: _reportStored,
                    onRetryHide: _retryHideAfterReport,
                  )
                else ...[
                  // The drag handle went with the bottom sheet — a pushed
                  // screen is not draggable, so a handle would be an
                  // affordance that does nothing.

                  // Show who is being reported, especially on Browse where
                  // this sheet is reached by a hidden long-press and the
                  // user may not be sure which card they were on.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Column(
                      children: [
                        Text(
                          widget.target == SelahReportTarget.photo
                              ? 'Report this photo'
                              : 'Report ${widget.firstName}',
                          style: SelahText.heading(size: 17),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 5),
                        Text(
                          "They won't be told, and they won't see you again.",
                          style: SelahText.subtext(size: 12.5),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        for (final reason in SelahReportReason.values)
                          _ReasonTile(
                            reason: reason,
                            selected: _selected == reason,
                            enabled: !_submitting,
                            detailController: _detailController,
                            onTap: () => setState(() {
                              _selected = _selected == reason ? null : reason;
                              _confirmingHide = false;
                            }),
                          ),

                        // Browse keeps Hide Profile as its own navigation
                        // action. Connections keeps it here because this is
                        // the person-level safety surface reached from a card;
                        // it expands into confirmation rather than hiding on
                        // the first tap.
                        if (widget.source != SelahReportSource.shepherd &&
                            widget.source != SelahReportSource.browse) ...[
                          SizedBox(height: 14),
                          Divider(
                            color: SelahColors.foreground.withValues(
                              alpha: 0.10,
                            ),
                            height: 1,
                          ),
                          SizedBox(height: 14),
                          _BlockOnlyRow(
                            firstName: widget.firstName,
                            enabled: !_submitting,
                            expanded: _confirmingHide,
                            onTap: () => setState(() {
                              _selected = null;
                              _confirmingHide = !_confirmingHide;
                            }),
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOutCubic,
                            child: _confirmingHide
                                ? Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: _HideConfirmation(
                                      firstName: widget.firstName,
                                      enabled: !_submitting,
                                      onCancel: () => setState(
                                        () => _confirmingHide = false,
                                      ),
                                      onConfirm: _blockOnly,
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ],
                    ),
                  ),

                  if (_error != null) ...[
                    SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: Text(
                        _error!,
                        style: SelahText.subtext(
                          size: 12.5,
                          color: SelahColors.destructive,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],

                  SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _submitting
                            ? null
                            : _reportStored
                            ? _retryHideAfterReport
                            : _selected == null
                            ? null
                            : _submitReport,
                        child: _submitting
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: SelahLoading(),
                              )
                            : Text(
                                _reportStored ? 'Retry hiding' : 'Send report',
                                style: SelahText.button(size: 14),
                              ),
                      ),
                    ),
                  ),
                  SizedBox(height: 6),
                  TextButton(
                    onPressed: _submitting
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: Text('Cancel', style: SelahText.subtext(size: 13)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportSentConfirmation extends StatelessWidget {
  final String? hideError;
  final bool retryingHide;
  final bool canRetryHide;
  final VoidCallback onRetryHide;

  const _ReportSentConfirmation({
    required this.hideError,
    required this.retryingHide,
    required this.canRetryHide,
    required this.onRetryHide,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        children: [
          const SizedBox(height: 112),
          Icon(
            Icons.check_circle_outline_rounded,
            size: 36,
            color: SelahColors.positiveGreen,
          ),
          const SizedBox(height: 14),
          Text(
            'Report sent',
            key: const ValueKey('report-sent-message'),
            style: SelahText.heading(size: 20),
            textAlign: TextAlign.center,
          ),
          if (hideError != null) ...[
            const SizedBox(height: 16),
            Text(
              hideError!,
              style: SelahText.subtext(
                size: 12.5,
                color: SelahColors.destructive,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (canRetryHide) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: retryingHide ? null : onRetryHide,
                child: retryingHide
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: SelahLoading(),
                      )
                    : Text('Retry hiding', style: SelahText.button(size: 14)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReasonTile extends StatelessWidget {
  final SelahReportReason reason;
  final bool selected;
  final bool enabled;
  final TextEditingController detailController;
  final VoidCallback onTap;

  const _ReasonTile({
    required this.reason,
    required this.selected,
    required this.enabled,
    required this.detailController,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          GestureDetector(
            onTap: enabled ? onTap : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: selected
                    ? SelahColors.surfaceEmphasisFill
                    : SelahColors.surfaceFill,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? SelahColors.surfaceEmphasisBorder
                      : SelahColors.surfaceBorder,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reason.label,
                          style: SelahText.body(
                            size: 14.5,
                            color: Colors.white,
                          ),
                        ),
                        if (reason.isUrgent) ...[
                          SizedBox(height: 2),
                          Text(
                            'Reviewed first',
                            style: SelahText.subtext(size: 11),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 20,
                    // White, not SelahColors.accentBorder — that constant is a
                    // 40%-opacity purple intended as a BORDER against a light
                    // fill. As an icon colour on this dark sheet it reads as
                    // disabled rather than selected.
                    color: selected ? Colors.white : SelahColors.ink(0.30),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: selected
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 6),
                          child: Text(
                            'Add details (optional)',
                            style: SelahText.subtext(
                              size: 10.5,
                              color: SelahColors.ink(0.55),
                            ),
                          ),
                        ),
                        TextField(
                          key: ValueKey<String>('report-detail-${reason.name}'),
                          controller: detailController,
                          enabled: enabled,
                          minLines: 3,
                          maxLines: 5,
                          maxLength: 250,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(250),
                          ],
                          style: SelahText.body(size: 13, color: Colors.white),
                          textAlignVertical: TextAlignVertical.top,
                          decoration: InputDecoration(
                            hintText: 'Tell us anything else that would help.',
                            hintMaxLines: 2,
                            hintStyle: SelahText.subtext(
                              size: 11.5,
                              color: SelahColors.ink(0.38),
                            ),
                            counterStyle: SelahText.subtext(
                              size: 9.5,
                              color: SelahColors.ink(0.34),
                            ),
                            contentPadding: const EdgeInsets.fromLTRB(
                              14,
                              14,
                              14,
                              12,
                            ),
                            filled: true,
                            fillColor: SelahColors.surfaceFill,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: SelahColors.surfaceBorder,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: SelahColors.surfaceBorder,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: SelahColors.surfaceEmphasisBorder,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _BlockOnlyRow extends StatelessWidget {
  final String firstName;
  final bool enabled;
  final bool expanded;
  final VoidCallback onTap;

  const _BlockOnlyRow({
    required this.firstName,
    required this.enabled,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: SelahColors.surfaceFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: SelahColors.surfaceBorder, width: 1),
        ),
        child: Row(
          children: [
            Icon(
              Icons.visibility_off_outlined,
              size: 20,
              color: SelahColors.ink(0.70),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hide $firstName',
                    style: SelahText.body(size: 14.5, color: Colors.white),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Hides you both. Nothing is reported.",
                    style: SelahText.subtext(size: 11.5),
                  ),
                ],
              ),
            ),
            Icon(
              expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 18,
              color: SelahColors.ink(0.30),
            ),
          ],
        ),
      ),
    );
  }
}

class _HideConfirmation extends StatelessWidget {
  final String firstName;
  final bool enabled;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const _HideConfirmation({
    required this.firstName,
    required this.enabled,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('report-hide-confirmation'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SelahColors.surfaceEmphasisFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SelahColors.surfaceEmphasisBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hide $firstName?',
            style: SelahText.body(size: 14.5, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            "You won't see each other. Any live Journey between you will "
            'end. Nothing is reported and they will not be told.',
            style: SelahText.subtext(size: 11.5),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('report-hide-cancel'),
                  onPressed: enabled ? onCancel : null,
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  key: const ValueKey('report-hide-confirm'),
                  onPressed: enabled ? onConfirm : null,
                  child: const Text('Confirm'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
