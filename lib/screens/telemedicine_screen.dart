import 'package:btih_andriod_app/services/auth_session.dart';
import 'package:btih_andriod_app/services/telemedicine_service.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/widgets/app_app_bar.dart';
import 'package:btih_andriod_app/widgets/app_bar_icon_badge.dart';
import 'package:btih_andriod_app/widgets/tap_feedback.dart';
import 'package:flutter/material.dart';

class TelemedicineScreen extends StatefulWidget {
  final String patientMrNo;

  const TelemedicineScreen({super.key, required this.patientMrNo});

  @override
  State<TelemedicineScreen> createState() => _TelemedicineScreenState();
}

class _TelemedicineScreenState extends State<TelemedicineScreen> {
  final _service = TelemedicineService();
  final _doctorNameCtrl = TextEditingController();

  List<TelemedSession> _sessions = const [];
  bool _loading = true;
  bool _scheduling = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _doctorNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sessions = await _service.getSessions(widget.patientMrNo);
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _schedule() async {
    final name = _doctorNameCtrl.text.trim();
    setState(() => _scheduling = true);
    try {
      final session = await _service.createSession(
        mrNo: widget.patientMrNo,
        doctorName: name.isEmpty ? null : name,
        scheduledAt: DateTime.now().add(const Duration(minutes: 15)),
      );
      if (!mounted) return;
      _doctorNameCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Session #${session.sessionId} scheduled'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _scheduling = false);
    }
  }

  Future<void> _join(TelemedSession session) async {
    try {
      if (session.status.toUpperCase() == 'SCHEDULED') {
        await _service.updateStatus(
          sessionId: session.sessionId,
          mrNo: widget.patientMrNo,
          status: 'ACTIVE',
        );
      }
      final detail = await _service.getSession(
        sessionId: session.sessionId,
        mrNo: widget.patientMrNo,
      );
      final url = detail?.joinUrl ?? session.joinUrl;
      final opened = await _service.openJoinUrl(url);
      if (!mounted) return;
      if (!opened) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              url == null || url.isEmpty
                  ? 'Join link is not available yet.'
                  : 'Could not open join link.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _complete(TelemedSession session) async {
    try {
      await _service.updateStatus(
        sessionId: session.sessionId,
        mrNo: widget.patientMrNo,
        status: 'COMPLETED',
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppAppBar(
        title: Text(
          'Telemedicine',
          style: AppTypography.raleway(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.white,
          ),
        ),
        centerTitle: true,
        actions: const [
          AppBarIconBadge(icon: Icons.videocam_outlined),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryRed),
            )
          : RefreshIndicator(
              color: AppColors.primaryRed,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                children: [
                  _buildScheduleCard(),
                  const SizedBox(height: 20),
                  Text(
                    'Your sessions',
                    style: AppTypography.raleway(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkText,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_error != null)
                    Text(
                      _error!,
                      style: AppTypography.roboto(
                        fontSize: 13,
                        color: AppColors.primaryRed,
                      ),
                    )
                  else if (_sessions.isEmpty)
                    Text(
                      'No telemedicine sessions yet.',
                      style: AppTypography.roboto(
                        fontSize: 13,
                        color: AppColors.greyText,
                      ),
                    )
                  else
                    ..._sessions.map(
                      (s) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _SessionTile(
                          session: s,
                          onJoin: () => _join(s),
                          onComplete: () => _complete(s),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildScheduleCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.blush,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.softRed),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Schedule a video visit',
            style: AppTypography.raleway(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.deepRed,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'MR No: ${widget.patientMrNo}',
            style: AppTypography.roboto(
              fontSize: 12,
              color: AppColors.greyText,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _doctorNameCtrl,
            decoration: InputDecoration(
              labelText: 'Doctor name (optional)',
              filled: true,
              fillColor: AppColors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.fieldBorder),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TapFeedback(
            onTap: _scheduling ? null : _schedule,
            borderRadius: BorderRadius.circular(22),
            child: Container(
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(22),
              ),
              child: _scheduling
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : Text(
                      'Schedule session',
                      style: AppTypography.raleway(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final TelemedSession session;
  final VoidCallback onJoin;
  final VoidCallback onComplete;

  const _SessionTile({
    required this.session,
    required this.onJoin,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  session.doctorName?.isNotEmpty == true
                      ? session.doctorName!
                      : 'Video consult #${session.sessionId}',
                  style: AppTypography.raleway(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkText,
                  ),
                ),
              ),
              Text(
                session.status,
                style: AppTypography.roboto(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            session.scheduledAt != null
                ? 'Scheduled: ${session.scheduledAt}'
                : 'Room: ${session.roomId}',
            style: AppTypography.roboto(
              fontSize: 12,
              color: AppColors.greyText,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (session.canJoin)
                TapFeedback(
                  onTap: onJoin,
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryRed,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      'Join',
                      style: AppTypography.raleway(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ),
              if (session.canJoin) const SizedBox(width: 8),
              if (session.status.toUpperCase() == 'ACTIVE')
                TextButton(
                  onPressed: onComplete,
                  child: Text(
                    'Mark completed',
                    style: AppTypography.raleway(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.deepRed,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Convenience opener used from dashboard when MR is available.
Future<void> openTelemedicineScreen(BuildContext context) async {
  final mrNo = AuthSession.mrNo?.trim() ?? '';
  if (mrNo.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please log in to use telemedicine.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => TelemedicineScreen(patientMrNo: mrNo),
    ),
  );
}
