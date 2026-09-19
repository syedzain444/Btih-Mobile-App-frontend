import 'dart:convert';

import 'package:btih_andriod_app/models/patient_model.dart';
import 'package:btih_andriod_app/services/app_lock_service.dart';
import 'package:btih_andriod_app/services/auth_exceptions.dart';
import 'package:btih_andriod_app/services/auth_service.dart';
import 'package:btih_andriod_app/services/auth_session.dart';
import 'package:btih_andriod_app/services/security_cache_service.dart';
import 'package:btih_andriod_app/services/security_devices_service.dart';
import 'package:btih_andriod_app/services/security_preferences_service.dart';
import 'package:btih_andriod_app/services/trusted_device_service.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/utils/ip_file.dart';
import 'package:btih_andriod_app/widgets/app_app_bar.dart';
import 'package:btih_andriod_app/widgets/app_bar_icon_badge.dart';
import 'package:btih_andriod_app/widgets/custom_message_dialog.dart';
import 'package:btih_andriod_app/widgets/tap_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  bool _loading = true;
  bool _busy = false;
  bool _showChangePassword = false;
  bool _changingPassword = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();

  String? _registeredMobile;
  String _deviceLabel = 'This device';
  String? _deviceInstallId;
  List<TrustedLoginDevice> _trustedDevices = [];

  bool _maskSensitive = false;
  bool _hideNotificationPreview = false;
  bool _pinLock = false;
  bool _lockOnBackground = false;

  String get _mrNo => AuthSession.mrNo?.trim() ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    try {
      await AppLockService.instance.init();
    } catch (_) {}

    if (_mrNo.isNotEmpty) {
      final results = await Future.wait([
        SecurityPreferencesService.getMaskSensitiveFields(_mrNo),
        SecurityPreferencesService.getHideNotificationPreview(_mrNo),
        SecurityPreferencesService.getPinLockEnabled(_mrNo),
        SecurityPreferencesService.getLockOnBackground(_mrNo),
        SecurityDevicesService.currentDeviceLabel(),
        TrustedDeviceService.getDeviceInstallId(),
        _fetchRegisteredMobile(),
        _fetchTrustedDevices(),
      ]);

      if (!mounted) return;
      setState(() {
        _maskSensitive = results[0] as bool;
        _hideNotificationPreview = results[1] as bool;
        _pinLock = results[2] as bool;
        _lockOnBackground = results[3] as bool;
        _deviceLabel = results[4] as String;
        _deviceInstallId = results[5] as String;
        _registeredMobile = results[6] as String?;
        _trustedDevices = results[7] as List<TrustedLoginDevice>;
        _loading = false;
      });
    } else {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String?> _fetchRegisteredMobile() async {
    try {
      final response = await ApiConfig.client.get(
        Uri.parse('${ApiConfig.baseUrl}/api/Patient?MR_NO=$_mrNo'),
        headers: {'accept': '*/*'},
      );
      if (response.statusCode != 200) return null;
      final parsed =
          PatientApiResponse.fromDynamic(json.decode(response.body));
      final profile = parsed.profile;
      if (profile != null && profile.contactNo.trim().isNotEmpty) {
        return profile.contactNo.trim();
      }
      if (parsed.visitHistory.isNotEmpty) {
        return parsed.visitHistory.first.contactNo.trim();
      }
    } catch (_) {}
    return null;
  }

  Future<List<TrustedLoginDevice>> _fetchTrustedDevices() async {
    try {
      final devices = await TrustedDeviceService.fetchTrustedDevices(_mrNo);
      return _dedupeTrustedDevices(devices);
    } catch (_) {
      return [];
    }
  }

  /// One row per device install id (keep newest).
  List<TrustedLoginDevice> _dedupeTrustedDevices(
    List<TrustedLoginDevice> devices,
  ) {
    final byInstallId = <String, TrustedLoginDevice>{};
    for (final device in devices) {
      final key = device.deviceInstallId.trim().isNotEmpty
          ? device.deviceInstallId.trim().toLowerCase()
          : 'id:${device.trustedDeviceId}';
      final existing = byInstallId[key];
      if (existing == null) {
        byInstallId[key] = device;
        continue;
      }
      final existingStamp = existing.lastLoginAt ?? existing.trustedAt;
      final nextStamp = device.lastLoginAt ?? device.trustedAt;
      if (existingStamp == null ||
          (nextStamp != null && nextStamp.isAfter(existingStamp))) {
        byInstallId[key] = device;
      }
    }
    return byInstallId.values.toList();
  }

  TrustedLoginDevice? get _currentTrustedDevice {
    final installId = _deviceInstallId?.trim();
    if (installId == null || installId.isEmpty) return null;
    for (final device in _trustedDevices) {
      if (device.deviceInstallId.trim() == installId) return device;
    }
    return null;
  }

  List<TrustedLoginDevice> get _otherTrustedDevices {
    final current = _currentTrustedDevice;
    if (current == null) return _trustedDevices;
    return _trustedDevices
        .where(
          (device) =>
              device.deviceInstallId.trim() !=
              current.deviceInstallId.trim(),
        )
        .toList();
  }

  Future<void> _revokeTrustedDevice(TrustedLoginDevice device) async {
    setState(() => _busy = true);
    final ok = await TrustedDeviceService.revokeTrustedDevice(
      mrNo: _mrNo,
      trustedDeviceId: device.trustedDeviceId,
      deviceInstallId: device.deviceInstallId,
    );
    _trustedDevices = await _fetchTrustedDevices();
    if (!mounted) return;
    setState(() => _busy = false);
    _showMessage(
      ok ? 'Trusted device removed' : 'Could not remove trusted device',
    );
  }

  Future<void> _revokeAllTrustedDevices() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Remove all trusted devices',
          style: AppTypography.raleway(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.deepRed,
          ),
        ),
        content: Text(
          'You will need to verify with OTP the next time you sign in on any device.',
          style: AppTypography.roboto(
            fontSize: 14,
            color: AppColors.greyText,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: AppTypography.roboto(color: AppColors.greyText),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Remove all',
              style: AppTypography.roboto(
                color: AppColors.primaryRed,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final ok = await TrustedDeviceService.revokeAllTrustedDevices(_mrNo);
    _trustedDevices = await _fetchTrustedDevices();
    if (!mounted) return;
    setState(() => _busy = false);
    _showMessage(
      ok ? 'All trusted devices removed' : 'Could not remove trusted devices',
    );
  }

  String _formatShortDate(DateTime? date) {
    if (date == null) return '--';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final local = date.toLocal();
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }

  String _formatSessionExpiry() {
    final expires = AuthSession.expiresAt?.toLocal();
    if (expires == null) return 'Active session';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${expires.day} ${months[expires.month - 1]} ${expires.year}, '
        '${expires.hour.toString().padLeft(2, '0')}:'
        '${expires.minute.toString().padLeft(2, '0')}';
  }

  void _toggleChangePassword() {
    setState(() {
      _showChangePassword = !_showChangePassword;
      if (!_showChangePassword) {
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      }
    });
  }

  Future<void> _submitChangePassword() async {
    final current = _currentPasswordController.text;
    final next = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;
    final contact = (_registeredMobile ?? '').trim();

    if (contact.isEmpty) {
      _showMessage('Registered mobile number is required to change password');
      return;
    }
    if (current.isEmpty || next.isEmpty || confirm.isEmpty) {
      _showMessage('Please fill in all password fields');
      return;
    }
    if (next.length < 6) {
      _showMessage('New password must be at least 6 characters');
      return;
    }
    if (next != confirm) {
      _showMessage('New password and confirm password do not match');
      return;
    }
    if (current == next) {
      _showMessage('New password must be different from current password');
      return;
    }

    setState(() => _changingPassword = true);
    try {
      await _authService.changePassword(
        mrno: _mrNo,
        contactNo: contact,
        currentPassword: current,
        newPassword: next,
      );
      if (!mounted) return;
      setState(() {
        _changingPassword = false;
        _showChangePassword = false;
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      });
      CustomMessageDialog.showSuccess(
        context,
        'Password changed successfully',
      );
    } on AuthApiException catch (e) {
      if (!mounted) return;
      setState(() => _changingPassword = false);
      CustomMessageDialog.showError(
        context,
        e.type == AuthErrorType.unauthorized
            ? 'Current password is incorrect'
            : e.message,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _changingPassword = false);
      CustomMessageDialog.showError(
        context,
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> _confirmLogoutEverywhere() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Log out everywhere',
          style: AppTypography.raleway(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.deepRed,
          ),
        ),
        content: Text(
          'This removes push alerts from all registered devices and '
          'logs you out on this phone. Other phones stay signed in until '
          'their session expires.',
          style: AppTypography.roboto(
            fontSize: 14,
            color: AppColors.greyText,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: AppTypography.roboto(color: AppColors.greyText),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Continue',
              style: AppTypography.roboto(
                color: AppColors.primaryRed,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    await SecurityDevicesService.unregisterAllDevices(_mrNo);
    if (!mounted) return;
    setState(() => _busy = false);
    await AuthSession.logOut();
  }

  Future<void> _setPin() async {
    if (_mrNo.isEmpty) {
      _showMessage('Please sign in again to set a PIN');
      return;
    }

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => const _SetPinDialog(),
    );
    if (result == null || !mounted) return;

    try {
      await AppLockService.instance.setPin(_mrNo, result);
      if (!mounted) return;
      setState(() => _pinLock = true);
      _showMessage('PIN saved');
    } catch (e) {
      if (!mounted) return;
      _showMessage(
        e.toString().contains('digit')
            ? 'PIN must be exactly ${AppLockService.pinLength} digits'
            : 'Could not save PIN. Please try again.',
      );
    }
  }

  Future<void> _clearPin() async {
    try {
      await AppLockService.instance.clearPin(_mrNo);
      if (!mounted) return;
      setState(() {
        _pinLock = false;
        if (!_pinLock) _lockOnBackground = false;
      });
      await SecurityPreferencesService.setLockOnBackground(_mrNo, false);
    } catch (_) {
      if (!mounted) return;
      _showMessage('Could not clear PIN. Please try again.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: AppTypography.roboto(fontSize: 14, color: AppColors.white),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _clearCache() async {
    setState(() => _busy = true);
    final count = await SecurityCacheService.clearDownloadedReportsAndCache();
    if (!mounted) return;
    setState(() => _busy = false);
    _showMessage(
      count > 0
          ? 'Cleared $count cached file${count == 1 ? '' : 's'}'
          : 'No cached files to clear',
    );
  }

  InputDecoration _passwordDecoration({
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: AppTypography.roboto(
        fontSize: 13,
        color: AppColors.greyText,
      ),
      filled: true,
      fillColor: AppColors.fieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.fieldBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.fieldBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.4),
      ),
      suffixIcon: IconButton(
        onPressed: onToggle,
        icon: Icon(
          obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          color: AppColors.greyText,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildChangePasswordPanel() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: !_showChangePassword
            ? const SizedBox.shrink()
            : Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                decoration: BoxDecoration(
                  color: AppColors.blush.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.primaryRed.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Update your password',
                      style: AppTypography.raleway(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.deepRed,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _currentPasswordController,
                      obscureText: _obscureCurrent,
                      style: AppTypography.roboto(
                        fontSize: 14,
                        color: AppColors.darkText,
                      ),
                      decoration: _passwordDecoration(
                        label: 'Current password',
                        obscure: _obscureCurrent,
                        onToggle: () => setState(
                          () => _obscureCurrent = !_obscureCurrent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _newPasswordController,
                      obscureText: _obscureNew,
                      style: AppTypography.roboto(
                        fontSize: 14,
                        color: AppColors.darkText,
                      ),
                      decoration: _passwordDecoration(
                        label: 'New password',
                        obscure: _obscureNew,
                        onToggle: () =>
                            setState(() => _obscureNew = !_obscureNew),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirm,
                      style: AppTypography.roboto(
                        fontSize: 14,
                        color: AppColors.darkText,
                      ),
                      decoration: _passwordDecoration(
                        label: 'Confirm new password',
                        obscure: _obscureConfirm,
                        onToggle: () => setState(
                          () => _obscureConfirm = !_obscureConfirm,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _changingPassword
                                ? null
                                : _toggleChangePassword,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.deepRed,
                              side: const BorderSide(
                                color: AppColors.fieldBorder,
                              ),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: AppTypography.raleway(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.deepRed,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _changingPassword
                                ? null
                                : _submitChangePassword,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.deepRed,
                              foregroundColor: AppColors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _changingPassword
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.white,
                                    ),
                                  )
                                : Text(
                                    'Save',
                                    style: AppTypography.raleway(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppAppBar(
        centerTitle: true,
        title: Text(
          'Security Settings',
          style: AppTypography.raleway(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.white,
          ),
        ),
        actions: const [
          AppBarIconBadge(icon: Icons.shield_outlined),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryRed),
            )
          : Stack(
              children: [
                ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                  children: [
                    const _SectionHeader(title: 'Account'),
                    _ActionTile(
                      icon: Icons.lock_outline_rounded,
                      title: 'Change password',
                      subtitle: _showChangePassword
                          ? 'Enter current and new password below'
                          : null,
                      onTap: _toggleChangePassword,
                    ),
                    _buildChangePasswordPanel(),
                    _InfoTile(
                      icon: Icons.phone_android_rounded,
                      title: 'Registered mobile',
                      value: _registeredMobile == null
                          ? 'Not available'
                          : _maskSensitive
                              ? SecurityPreferencesService.maskPhone(
                                  _registeredMobile!,
                                )
                              : _registeredMobile!,
                    ),
                    const SizedBox(height: 18),
                    const _SectionHeader(title: 'Trusted devices'),
                    if (_trustedDevices.isEmpty)
                      const _InfoTile(
                        icon: Icons.devices_other_outlined,
                        title: 'No trusted devices',
                      )
                    else ...[
                      _InfoTile(
                        icon: Icons.verified_user_outlined,
                        title: _deviceLabel,
                        value: _currentTrustedDevice == null
                            ? null
                            : 'Trusted until ${_formatShortDate(_currentTrustedDevice!.expiresAt)}',
                        trailing: _currentTrustedDevice == null
                            ? null
                            : TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => _revokeTrustedDevice(
                                          _currentTrustedDevice!,
                                        ),
                                child: Text(
                                  'Remove',
                                  style: AppTypography.roboto(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryRed,
                                  ),
                                ),
                              ),
                      ),
                      if (_otherTrustedDevices.isNotEmpty)
                        ..._otherTrustedDevices.map(
                          (device) => _InfoTile(
                            icon: Icons.devices_other_outlined,
                            title: device.displayName,
                            value: device.expiresAt == null
                                ? 'Trusted device'
                                : 'Expires ${_formatShortDate(device.expiresAt)}',
                            trailing: TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _revokeTrustedDevice(device),
                              child: Text(
                                'Remove',
                                style: AppTypography.roboto(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryRed,
                                ),
                              ),
                            ),
                          ),
                        ),
                      _ActionTile(
                        icon: Icons.no_accounts_outlined,
                        title: 'Remove all trusted devices',
                        subtitle:
                            'Require OTP verification on every device next sign-in',
                        onTap: _revokeAllTrustedDevices,
                      ),
                    ],
                    const SizedBox(height: 18),
                    const _SectionHeader(title: 'Session'),
                    _ActionTile(
                      icon: Icons.logout_rounded,
                      title: 'Log out everywhere',
                      subtitle:
                          'Remove push access on all devices and sign out here',
                      onTap: _confirmLogoutEverywhere,
                    ),
                    _InfoTile(
                      icon: Icons.schedule_rounded,
                      title: 'Session expires at',
                      value: _formatSessionExpiry(),
                    ),
                    const SizedBox(height: 18),
                    const _SectionHeader(title: 'App lock'),
                    _SwitchTile(
                      title: 'Unlock with biometric',
                      subtitle:
                          'Fingerprint / face unlock — coming in a future update',
                      value: false,
                      onChanged: (_) {
                        _showMessage(
                          'Biometric unlock will be available in a future update.',
                        );
                      },
                    ),
                    _SwitchTile(
                      title: 'PIN lock',
                      subtitle: _pinLock
                          ? '${AppLockService.pinLength}-digit PIN is enabled'
                          : 'Require a ${AppLockService.pinLength}-digit PIN to unlock the app',
                      value: _pinLock,
                      onChanged: (value) async {
                        if (value) {
                          await _setPin();
                          final enabled = await SecurityPreferencesService
                              .getPinLockEnabled(_mrNo);
                          if (mounted) setState(() => _pinLock = enabled);
                        } else {
                          await _clearPin();
                        }
                      },
                    ),
                    if (_pinLock)
                      _ActionTile(
                        icon: Icons.pin_rounded,
                        title: 'Change PIN',
                        onTap: _setPin,
                      ),
                    _SwitchTile(
                      title: 'Lock when app is in background',
                      subtitle: 'Require unlock when returning to the app',
                      value: _lockOnBackground,
                      onChanged: _pinLock
                          ? (value) async {
                              await SecurityPreferencesService
                                  .setLockOnBackground(_mrNo, value);
                              setState(() => _lockOnBackground = value);
                            }
                          : null,
                    ),
                    const SizedBox(height: 18),
                    const _SectionHeader(title: 'Privacy on this device'),
                    _SwitchTile(
                      title: 'Mask CNIC & contact on profile',
                      subtitle: 'Hide sensitive fields until you edit them',
                      value: _maskSensitive,
                      onChanged: (value) async {
                        await SecurityPreferencesService
                            .setMaskSensitiveFields(_mrNo, value);
                        setState(() => _maskSensitive = value);
                      },
                    ),
                    _SwitchTile(
                      title: 'Hide notification content on lock screen',
                      subtitle: 'Show generic alerts only on the lock screen',
                      value: _hideNotificationPreview,
                      onChanged: (value) async {
                        await SecurityPreferencesService
                            .setHideNotificationPreview(_mrNo, value);
                        setState(() => _hideNotificationPreview = value);
                      },
                    ),
                    _ActionTile(
                      icon: Icons.cleaning_services_outlined,
                      title: 'Clear downloaded reports & cache',
                      onTap: _clearCache,
                    ),
                  ],
                ),
                if (_busy || _changingPassword)
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(
                      minHeight: 2,
                      color: AppColors.primaryRed,
                    ),
                  ),
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.raleway(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.deepRed,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 36,
            height: 3,
            decoration: BoxDecoration(
              color: AppColors.primaryRed,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.deepRed;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TapFeedback(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.fieldBorder),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.raleway(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: accent,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: AppTypography.roboto(
                          fontSize: 12,
                          color: AppColors.greyText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.greyText.withValues(alpha: 0.9),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    this.value,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.fieldBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: AppColors.primaryRed),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.raleway(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.deepRed,
                    ),
                  ),
                  if (value != null && value!.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      value!,
                      style: AppTypography.roboto(
                        fontSize: 12,
                        color: AppColors.greyText,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.fieldBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.raleway(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.deepRed,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.roboto(
                      fontSize: 12,
                      color: AppColors.greyText,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeTrackColor: AppColors.deepRed.withValues(alpha: 0.4),
              activeThumbColor: AppColors.deepRed,
            ),
          ],
        ),
      ),
    );
  }
}

class _SetPinDialog extends StatefulWidget {
  const _SetPinDialog();

  @override
  State<_SetPinDialog> createState() => _SetPinDialogState();
}

class _SetPinDialogState extends State<_SetPinDialog> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _error;

  static const _len = AppLockService.pinLength;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _save() {
    final pin = _pinController.text.trim();
    final confirm = _confirmController.text.trim();
    if (pin.length != _len || !RegExp('^\\d{$_len}\$').hasMatch(pin)) {
      setState(() => _error = 'PIN must be exactly $_len digits');
      return;
    }
    if (pin != confirm) {
      setState(() => _error = 'PIN entries do not match');
      return;
    }
    Navigator.pop(context, pin);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Set $_len-digit PIN',
        style: AppTypography.raleway(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.deepRed,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Choose a $_len-digit PIN. The lock screen will ask for the same length.',
            style: AppTypography.roboto(
              fontSize: 13,
              color: AppColors.greyText,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: _len,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(_len),
            ],
            style: AppTypography.roboto(
              fontSize: 14,
              color: AppColors.darkText,
            ),
            decoration: InputDecoration(
              labelText: 'New PIN ($_len digits)',
              labelStyle: AppTypography.roboto(
                fontSize: 13,
                color: AppColors.greyText,
              ),
              counterText: '',
            ),
          ),
          TextField(
            controller: _confirmController,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: _len,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(_len),
            ],
            style: AppTypography.roboto(
              fontSize: 14,
              color: AppColors.darkText,
            ),
            decoration: InputDecoration(
              labelText: 'Confirm PIN',
              labelStyle: AppTypography.roboto(
                fontSize: 13,
                color: AppColors.greyText,
              ),
              counterText: '',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: AppTypography.roboto(
                fontSize: 13,
                color: AppColors.primaryRed,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: AppTypography.roboto(color: AppColors.greyText),
          ),
        ),
        TextButton(
          onPressed: _save,
          child: Text(
            'Save',
            style: AppTypography.roboto(
              color: AppColors.deepRed,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
