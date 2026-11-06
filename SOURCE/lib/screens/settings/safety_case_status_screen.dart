import 'package:flutter/material.dart';
import '../../dev/selah_app_gold_preview.dart';

import '../../services/selah_report_service.dart';
import '../../state/app_state.dart';
import '../../theme/selah_colors.dart';
import '../../theme/selah_text.dart';
import '../../widgets/selah_loading.dart';
import '../../widgets/selah_state_widgets.dart';

class SafetyCaseStatusScreen extends StatefulWidget {
  final Future<List<SelahSafetyCase>?> Function()? loadCases;

  const SafetyCaseStatusScreen({super.key, this.loadCases});

  @override
  State<SafetyCaseStatusScreen> createState() => _SafetyCaseStatusScreenState();
}

class _SafetyCaseStatusScreenState extends State<SafetyCaseStatusScreen> {
  bool _loading = true;
  bool _failed = false;
  List<SelahSafetyCase> _cases = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final result =
        await (widget.loadCases?.call() ?? SelahReportService.safetyCases());
    if (!mounted) return;
    setState(() {
      _loading = false;
      _failed = result == null;
      _cases = result ?? const [];
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('Your safety reports', style: SelahText.heading(size: 17)),
    ),
    body: Container(
      decoration: SelahAppGoldDecoration(
        gradient: SelahColors.genderGradient(AppState.instance.gender),
      ),
      child: SafeArea(
        top: false,
        child: _loading
            ? const SelahLoading(label: 'Checking your reports…')
            : _failed
            ? SelahUnknownErrorState(contentName: 'Reports', onRetry: _load)
            : _cases.isEmpty
            ? const _NoSafetyCases()
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
                children: [
                  const _SafetyReportExplanation(),
                  const SizedBox(height: 18),
                  ...List.generate(
                    _cases.length,
                    (index) => Padding(
                      padding: EdgeInsets.only(
                        bottom: index == _cases.length - 1 ? 0 : 10,
                      ),
                      child: _SafetyCaseCard(value: _cases[index]),
                    ),
                  ),
                ],
              ),
      ),
    ),
  );
}

class _NoSafetyCases extends StatelessWidget {
  const _NoSafetyCases();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
    children: const [
      _SafetyReportExplanation(),
      SizedBox(height: 90),
      SelahEmptyState(
        icon: Icons.verified_user_outlined,
        title: 'No reports submitted',
        message:
            'If you report a member or a Shepherd Circle message, its review status will appear here.',
      ),
    ],
  );
}

class _SafetyReportExplanation extends StatelessWidget {
  const _SafetyReportExplanation();

  @override
  Widget build(BuildContext context) => Text(
    'Track safety reports you have sent to SELAH. You will see when each '
    'report is received, under review or complete.',
    style: SelahText.subtext(size: 12.5, color: SelahColors.ink(0.54)),
  );
}

class _SafetyCaseCard extends StatelessWidget {
  final SelahSafetyCase value;

  const _SafetyCaseCard({required this.value});

  String _date(DateTime value) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${value.day} ${months[value.month - 1]} ${value.year}';
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: SelahColors.surfaceFill,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: SelahColors.surfaceBorder),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.shield_outlined, color: SelahColors.journeyGold, size: 21),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value.typeLabel, style: SelahText.body(size: 14.5)),
              const SizedBox(height: 5),
              Text(
                value.statusLabel,
                style: SelahText.body(
                  size: 12.5,
                  color: SelahColors.journeyGold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Submitted ${_date(value.createdAt)}',
                style: SelahText.subtext(size: 11.5),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
