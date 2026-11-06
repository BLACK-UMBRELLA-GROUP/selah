// LOCK 3: the local Seeker invitation flow. Its owner supplies the destination.
import 'package:flutter/material.dart';

import '../../models/selah_shepherd_invite.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_text.dart';
import '../../widgets/selah_shepherd_invite_views.dart';
import '../../widgets/selah_state_widgets.dart';

enum SelahShepherdInviteStep { welcome, choose, invite, sent }

class SelahShepherdInviteFlow extends StatefulWidget {
  const SelahShepherdInviteFlow({
    super.key,
    required this.controller,
    required this.onContinue,
    this.initialStep = SelahShepherdInviteStep.welcome,
  });
  final SelahShepherdInviteController controller;
  final VoidCallback onContinue;
  final SelahShepherdInviteStep initialStep;

  @override
  State<SelahShepherdInviteFlow> createState() =>
      _SelahShepherdInviteFlowState();
}

class _SelahShepherdInviteFlowState extends State<SelahShepherdInviteFlow> {
  late SelahShepherdInviteStep _step;
  late SelahShepherdInviteSendState _lastSendState;
  late final TextEditingController _name;
  bool _writingName = false;

  SelahShepherdInviteController get _invite => widget.controller;

  SelahShepherdInviteStep _initial() => switch (_invite.sendState) {
    SelahShepherdInviteSendState.sending ||
    SelahShepherdInviteSendState.failed => SelahShepherdInviteStep.invite,
    SelahShepherdInviteSendState.sent => SelahShepherdInviteStep.sent,
    _ => widget.initialStep,
  };

  @override
  void initState() {
    super.initState();
    _step = _initial();
    _lastSendState = _invite.sendState;
    _name = TextEditingController(text: _invite.fullName);
    _invite.addListener(_changed);
  }

  @override
  void didUpdateWidget(covariant SelahShepherdInviteFlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      _invite.addListener(_changed);
      _step = _initial();
      _lastSendState = _invite.sendState;
      _name.text = _invite.fullName;
    }
  }

  void _changed() {
    if (!mounted) return;
    if (!_writingName && _name.text != _invite.fullName) {
      _name.value = TextEditingValue(
        text: _invite.fullName,
        selection: TextSelection.collapsed(offset: _invite.fullName.length),
      );
    }
    final state = _invite.sendState;
    setState(() {
      if (state != _lastSendState) {
        if (state == SelahShepherdInviteSendState.sending ||
            state == SelahShepherdInviteSendState.failed) {
          _step = SelahShepherdInviteStep.invite;
        } else if (state == SelahShepherdInviteSendState.sent) {
          _step = SelahShepherdInviteStep.sent;
        }
      }
      _lastSendState = state;
    });
  }

  @override
  void dispose() {
    _invite.removeListener(_changed);
    _name.dispose();
    super.dispose();
  }

  void _send({bool copied = false}) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_invite.send(copied: copied)) return;
    setState(() => _step = SelahShepherdInviteStep.sent);
    if (copied) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invite link copied.')));
    }
  }

  Widget _welcome() => SelahInviteFillScroll(
    padding: const EdgeInsets.fromLTRB(26, 20, 26, 26),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: SelahWordmark(size: 44),
        ),
        const Spacer(),
        Text('WELCOME', style: SelahText.chapterLabel().copyWith(height: 1)),
        const SizedBox(height: 14),
        Text(
          'No one should walk toward marriage alone.',
          style: SelahText.heading(size: 48).copyWith(height: 1.05),
        ),
        const SizedBox(height: 14),
        Text(
          'Selah means pause. Here you take each step slowly, with a Shepherd you trust beside you.',
          style: SelahText.body(),
        ),
        const Spacer(),
        SelahInviteButton(
          key: const ValueKey('invite_begin'),
          label: 'Begin',
          onPressed: () =>
              setState(() => _step = SelahShepherdInviteStep.choose),
        ),
        const SizedBox(height: 10),
        Text(
          'Asked to be someone’s Shepherd? Open the invite in your message.',
          textAlign: TextAlign.center,
          style: SelahText.subtext().copyWith(height: 1.5),
        ),
      ],
    ),
  );

  Widget _choose() => SelahInviteFillScroll(
    padding: const EdgeInsets.fromLTRB(22, 6, 22, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SelahInviteBackRow(
          onBack: () => setState(() => _step = SelahShepherdInviteStep.welcome),
          stepLabel: 'Step 1 of 2',
        ),
        const SizedBox(height: 12),
        Text('Who will walk with you?', style: SelahText.pageTitle()),
        const SizedBox(height: 14),
        Text(
          'Your Shepherd encourages you, prays for you and sees each request you send or receive. Choose someone who knows you and your faith.',
          style: SelahText.body(color: SelahColors.muted),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < SelahShepherdRelation.values.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          _choice(SelahShepherdRelation.values[i], i),
        ],
        if (_invite.showChoiceError) ...[
          const SizedBox(height: 14),
          Text(
            'Choose who your Shepherd is.',
            key: const ValueKey('invite_choice_error'),
            style: SelahText.subtext(size: 13, color: SelahColors.dawn),
          ),
        ],
        const SizedBox(height: 14),
        const Spacer(),
        SelahInviteButton(
          key: const ValueKey('invite_continue'),
          label: 'Continue',
          onPressed: () {
            if (_invite.continueChoice()) {
              setState(() => _step = SelahShepherdInviteStep.invite);
            }
          },
        ),
      ],
    ),
  );

  Widget _choice(SelahShepherdRelation relation, int index) {
    final selected = _invite.relation == relation;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: SelahColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? SelahColors.lake : SelahColors.line,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('invite_choice_$index'),
          onTap: () => _invite.chooseRelation(relation),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Text(relation.label, style: SelahText.body(size: 14.5)),
          ),
        ),
      ),
    );
  }

  Widget _invitePage() {
    final sending = _invite.sendState == SelahShepherdInviteSendState.sending;
    final failed = _invite.sendState == SelahShepherdInviteSendState.failed;
    return SelahInviteFillScroll(
      padding: const EdgeInsets.fromLTRB(22, 6, 22, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SelahInviteBackRow(
            onBack: () =>
                setState(() => _step = SelahShepherdInviteStep.choose),
            stepLabel: 'Step 2 of 2',
          ),
          const SizedBox(height: 12),
          if (failed) ...[
            SelahErrorBanner(
              key: const ValueKey('invite_failure'),
              message: 'Your invite didn’t send. Try again.',
              retryKey: const ValueKey('invite_retry'),
              onRetry: _send,
            ),
            const SizedBox(height: 14),
          ],
          Text('Invite your Shepherd', style: SelahText.pageTitle()),
          const SizedBox(height: 14),
          Text(
            'THEIR NAME',
            style: SelahText.chapterLabel().copyWith(height: 1),
          ),
          const SizedBox(height: 6),
          TextField(
            key: const ValueKey('invite_name'),
            controller: _name,
            textCapitalization: TextCapitalization.words,
            style: SelahText.body(size: 16).copyWith(height: 1),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: SelahColors.surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 13,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: SelahColors.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: SelahColors.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: SelahColors.lake),
              ),
            ),
            onChanged: (value) {
              _writingName = true;
              try {
                _invite.setName(value);
              } finally {
                _writingName = false;
              }
            },
          ),
          if (_invite.showNameError) ...[
            const SizedBox(height: 6),
            Text(
              'Enter your Shepherd’s name.',
              key: const ValueKey('invite_name_error'),
              style: SelahText.subtext(size: 13, color: SelahColors.dawn),
            ),
          ],
          const SizedBox(height: 14),
          const SelahShepherdPermissionsCard(
            title: 'What your Shepherd will see',
          ),
          const SizedBox(height: 14),
          Text(
            'They get a message with a link. They don’t need to be looking for marriage themselves. You can add another Shepherd later.',
            style: SelahText.subtext().copyWith(height: 1.5),
          ),
          const SizedBox(height: 14),
          const Spacer(),
          Opacity(
            opacity: sending ? .75 : 1,
            child: SelahInviteButton(
              key: const ValueKey('invite_send'),
              label: sending ? 'Sending…' : 'Send invite by message',
              onPressed: sending ? null : _send,
            ),
          ),
          if (sending)
            // The locked sending master retains the 32px private demo row's
            // space and 10px gap; the member surface has no demo action.
            const SizedBox(height: 42)
          else ...[
            const SizedBox(height: 10),
            SelahInviteButton(
              key: const ValueKey('invite_copy'),
              label: 'Copy invite link',
              ghost: true,
              onPressed: () => _send(copied: true),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sent() => SelahInviteFillScroll(
    padding: const EdgeInsets.fromLTRB(26, 20, 26, 26),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SelahInviteBackRow(
          onBack: () => setState(() => _step = SelahShepherdInviteStep.invite),
        ),
        const SizedBox(height: 30),
        Text(
          '’',
          style: SelahText.heading(
            size: 120,
            color: SelahColors.dawn,
          ).copyWith(height: .6),
        ),
        const Spacer(),
        Text(
          'INVITE SENT',
          style: SelahText.chapterLabel().copyWith(height: 1),
        ),
        const SizedBox(height: 14),
        Text(
          '${_invite.firstName} has your invite.',
          style: SelahText.heading(size: 48).copyWith(height: 1.05),
        ),
        const SizedBox(height: 14),
        Text(
          'You can look around Selah now. You can ask or accept once ${_invite.firstName} says yes.',
          style: SelahText.body(),
        ),
        const Spacer(),
        SelahInviteButton(
          key: const ValueKey('invite_sent_continue'),
          label: 'Continue',
          onPressed: () {
            if (_invite.hasInvite) widget.onContinue();
          },
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    key: ValueKey('invite_step_${_step.name}'),
    backgroundColor: _step == SelahShepherdInviteStep.sent
        ? SelahColors.soft
        : SelahColors.mist,
    body: SafeArea(
      bottom: false,
      child: switch (_step) {
        SelahShepherdInviteStep.welcome => _welcome(),
        SelahShepherdInviteStep.choose => _choose(),
        SelahShepherdInviteStep.invite => _invitePage(),
        SelahShepherdInviteStep.sent => _sent(),
      },
    ),
  );
}
