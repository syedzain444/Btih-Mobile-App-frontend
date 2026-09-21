import 'package:btih_andriod_app/services/auth_session.dart';
import 'package:btih_andriod_app/services/support_service.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/widgets/app_app_bar.dart';
import 'package:btih_andriod_app/widgets/app_bar_icon_badge.dart';
import 'package:btih_andriod_app/widgets/tap_feedback.dart';
import 'package:flutter/material.dart';

class SupportTicketsScreen extends StatefulWidget {
  const SupportTicketsScreen({super.key});

  @override
  State<SupportTicketsScreen> createState() => _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends State<SupportTicketsScreen> {
  final _service = SupportService();
  List<SupportTicket> _tickets = const [];
  bool _loading = true;
  String? _error;

  String get _mrNo => AuthSession.mrNo?.trim() ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_mrNo.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Log in to view your support tickets.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tickets = await _service.getTickets(_mrNo);
      if (!mounted) return;
      setState(() {
        _tickets = tickets;
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

  Future<void> _openCreate() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreateSupportTicketScreen()),
    );
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppAppBar(
        title: Text(
          'My Tickets',
          style: AppTypography.raleway(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.white,
          ),
        ),
        centerTitle: true,
        actions: const [
          AppBarIconBadge(icon: Icons.confirmation_number_outlined),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        backgroundColor: AppColors.primaryRed,
        foregroundColor: AppColors.white,
        icon: const Icon(Icons.add),
        label: Text(
          'New ticket',
          style: AppTypography.raleway(fontWeight: FontWeight.w700),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryRed),
            )
          : RefreshIndicator(
              color: AppColors.primaryRed,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 88),
                children: [
                  if (_error != null)
                    Text(
                      _error!,
                      style: AppTypography.roboto(
                        fontSize: 13,
                        color: AppColors.primaryRed,
                      ),
                    )
                  else if (_tickets.isEmpty)
                    Text(
                      'No support tickets yet.',
                      style: AppTypography.roboto(
                        fontSize: 13,
                        color: AppColors.greyText,
                      ),
                    )
                  else
                    ..._tickets.map(
                      (t) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TapFeedback(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SupportTicketDetailScreen(
                                  ticketId: t.ticketId,
                                  mrNo: _mrNo,
                                ),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
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
                                        t.subject,
                                        style: AppTypography.raleway(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.darkText,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      t.status,
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
                                  t.category,
                                  style: AppTypography.roboto(
                                    fontSize: 12,
                                    color: AppColors.greyText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class CreateSupportTicketScreen extends StatefulWidget {
  const CreateSupportTicketScreen({super.key});

  @override
  State<CreateSupportTicketScreen> createState() =>
      _CreateSupportTicketScreenState();
}

class _CreateSupportTicketScreenState extends State<CreateSupportTicketScreen> {
  final _service = SupportService();
  final _nameCtrl = TextEditingController(
    text: AuthSession.displayName == 'Patient' ? '' : AuthSession.displayName,
  );
  final _subjectCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _category = 'General';
  bool _submitting = false;

  static const _categories = [
    'General',
    'Billing',
    'Appointments',
    'Technical',
    'Medical Records',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _subjectCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty ||
        _subjectCtrl.text.trim().isEmpty ||
        _descCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name, subject, and description are required.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final id = await _service.createTicket(
        mrNo: AuthSession.mrNo,
        contactName: _nameCtrl.text.trim(),
        category: _category,
        subject: _subjectCtrl.text.trim(),
        description: _descCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(id > 0 ? 'Ticket #$id submitted' : 'Ticket submitted'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppAppBar(
        title: Text(
          'New Ticket',
          style: AppTypography.raleway(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.white,
          ),
        ),
        centerTitle: true,
        actions: const [
          AppBarIconBadge(icon: Icons.edit_outlined),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Your name'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _category,
            items: [
              for (final c in _categories)
                DropdownMenuItem(value: c, child: Text(c)),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _category = v);
            },
            decoration: const InputDecoration(labelText: 'Category'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _subjectCtrl,
            decoration: const InputDecoration(labelText: 'Subject'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          const SizedBox(height: 20),
          TapFeedback(
            onTap: _submitting ? null : _submit,
            borderRadius: BorderRadius.circular(22),
            child: Container(
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(22),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : Text(
                      'Submit ticket',
                      style: AppTypography.raleway(
                        fontSize: 15,
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

class SupportTicketDetailScreen extends StatefulWidget {
  final int ticketId;
  final String mrNo;

  const SupportTicketDetailScreen({
    super.key,
    required this.ticketId,
    required this.mrNo,
  });

  @override
  State<SupportTicketDetailScreen> createState() =>
      _SupportTicketDetailScreenState();
}

class _SupportTicketDetailScreenState extends State<SupportTicketDetailScreen> {
  final _service = SupportService();
  SupportTicket? _ticket;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final ticket = await _service.getTicketDetail(
        ticketId: widget.ticketId,
        mrNo: widget.mrNo,
      );
      if (!mounted) return;
      setState(() {
        _ticket = ticket;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _ticket;
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppAppBar(
        title: Text(
          'Ticket #${widget.ticketId}',
          style: AppTypography.raleway(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.white,
          ),
        ),
        centerTitle: true,
        actions: const [
          AppBarIconBadge(icon: Icons.confirmation_number_outlined),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryRed),
            )
          : t == null
              ? const Center(child: Text('Ticket not found'))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  children: [
                    Text(
                      t.subject,
                      style: AppTypography.raleway(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${t.status} · ${t.category}',
                      style: AppTypography.roboto(
                        fontSize: 13,
                        color: AppColors.greyText,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      t.description,
                      style: AppTypography.roboto(
                        fontSize: 14,
                        color: AppColors.darkText,
                        height: 1.45,
                      ),
                    ),
                    if (t.adminNotes != null && t.adminNotes!.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text(
                        'Hospital reply',
                        style: AppTypography.raleway(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.deepRed,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        t.adminNotes!,
                        style: AppTypography.roboto(
                          fontSize: 14,
                          color: AppColors.darkText,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ],
                ),
    );
  }
}
