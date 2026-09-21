import 'package:btih_andriod_app/screens/forgot_password_screen.dart';
import 'package:btih_andriod_app/services/app_lock_service.dart';
import 'package:btih_andriod_app/services/auth_session.dart';
import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/widgets/app_primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppLockOverlay extends StatefulWidget {
  const AppLockOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<AppLockOverlay> createState() => _AppLockOverlayState();
}

class _AppLockOverlayState extends State<AppLockOverlay>
    with WidgetsBindingObserver {
  final _pinController = TextEditingController();
  final _pinFocus = FocusNode();
  String _pin = '';
  String? _error;
  bool _showForgotPassword = false;
  bool _verifying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppLockService.instance.addListener(_onLockChanged);
    _pinController.addListener(_onPinTextChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AppLockService.instance.removeListener(_onLockChanged);
    _pinController.removeListener(_onPinTextChanged);
    _pinController.dispose();
    _pinFocus.dispose();
    super.dispose();
  }

  void _onLockChanged() {
    if (!mounted) return;
    if (!AppLockService.instance.isLocked) {
      _resetPinEntry();
      setState(() => _showForgotPassword = false);
    } else {
      setState(() {});
      _focusPinField();
    }
  }

  void _onPinTextChanged() {
    if (_verifying) return;

    final raw = _pinController.text;
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    final maxLen = AppLockService.pinLength;
    final clipped = digits.length > maxLen ? digits.substring(0, maxLen) : digits;

    if (raw != clipped) {
      _pinController.value = TextEditingValue(
        text: clipped,
        selection: TextSelection.collapsed(offset: clipped.length),
      );
      return;
    }

    if (_pin == clipped) return;

    setState(() {
      _pin = clipped;
      if (clipped.isNotEmpty) _error = null;
    });

    if (clipped.length == maxLen) {
      _unlockWithPin();
    }
  }

  void _resetPinEntry({bool keepError = false}) {
    _pinController.clear();
    _pin = '';
    if (!keepError) _error = null;
  }

  void _focusPinField() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !AppLockService.instance.isLocked || _showForgotPassword) {
        return;
      }
      if (!_pinFocus.hasFocus) {
        _pinFocus.requestFocus();
      }
      SystemChannels.textInput.invokeMethod('TextInput.show');
    });
  }

  void _showToast(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: AppTypography.roboto(fontSize: 14, color: AppColors.white),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.deepRed,
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final mrNo = AuthSession.mrNo ?? '';
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.resumed) {
      AppLockService.instance.shouldLockOnResume(mrNo).then((should) {
        if (should) AppLockService.instance.lock();
      });
    }
  }

  Future<void> _unlockWithPin() async {
    if (_verifying) return;

    final mrNo = AuthSession.mrNo ?? '';
    final expected = AppLockService.pinLength;
    final attempt = _pin;

    if (attempt.length != expected) {
      setState(() => _error = 'Enter your $expected-digit PIN');
      _focusPinField();
      return;
    }

    setState(() {
      _verifying = true;
      _error = null;
    });

    final ok = await AppLockService.instance.verifyPin(mrNo, attempt);
    if (!mounted) return;

    if (ok) {
      _resetPinEntry();
      setState(() => _verifying = false);
      AppLockService.instance.unlock();
      return;
    }

    // Wrong PIN — clear and let the user try again immediately.
    _pinController.removeListener(_onPinTextChanged);
    _pinController.clear();
    _pinController.addListener(_onPinTextChanged);

    setState(() {
      _verifying = false;
      _pin = '';
      _error = 'Incorrect PIN. Try again.';
    });
    _focusPinField();
  }

  Future<void> _openForgotPassword() async {
    setState(() => _showForgotPassword = true);
  }

  Future<void> _onForgotPasswordCompleted() async {
    final mrNo = AuthSession.mrNo?.trim() ?? '';
    if (mrNo.isNotEmpty) {
      try {
        await AppLockService.instance.clearPin(mrNo);
      } catch (_) {}
    }
    if (!mounted) return;
    _resetPinEntry();
    setState(() => _showForgotPassword = false);
    AppLockService.instance.unlock();
    _showToast(
      'Password updated. App lock PIN was cleared — set a new PIN in Security Settings if needed.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final locked = AppLockService.instance.isLocked;
    final pinLen = AppLockService.pinLength;
    return Stack(
      children: [
        widget.child,
        if (locked)
          Positioned.fill(
            child: Material(
              color: AppColors.white,
              child: _showForgotPassword
                  ? ForgotPasswordScreen(
                      initialPhone: null,
                      onCompleted: _onForgotPasswordCompleted,
                      onCancelled: () {
                        if (mounted) {
                          setState(() => _showForgotPassword = false);
                          _focusPinField();
                        }
                      },
                    )
                  : SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: const BoxDecoration(
                                color: AppColors.softRed,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.lock_outline_rounded,
                                color: AppColors.primaryRed,
                                size: 32,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'App Locked',
                              style: AppTypography.raleway(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: AppColors.deepRed,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Enter your $pinLen-digit PIN to continue.',
                              textAlign: TextAlign.center,
                              style: AppTypography.roboto(
                                fontSize: 14,
                                color: AppColors.greyText,
                              ),
                            ),
                            const SizedBox(height: 28),
                            GestureDetector(
                              onTap: _focusPinField,
                              behavior: HitTestBehavior.opaque,
                              child: SizedBox(
                                height: 56,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Off-screen style field — no visible underline/line.
                                    Opacity(
                                      opacity: 0,
                                      child: TextField(
                                        controller: _pinController,
                                        focusNode: _pinFocus,
                                        keyboardType: TextInputType.number,
                                        maxLength: pinLen,
                                        autofocus: true,
                                        enabled: !_verifying,
                                        enableSuggestions: false,
                                        autocorrect: false,
                                        obscureText: true,
                                        style: const TextStyle(
                                          color: Colors.transparent,
                                          fontSize: 16,
                                        ),
                                        cursorColor: Colors.transparent,
                                        showCursor: false,
                                        smartDashesType:
                                            SmartDashesType.disabled,
                                        smartQuotesType:
                                            SmartQuotesType.disabled,
                                        decoration: const InputDecoration(
                                          isCollapsed: true,
                                          border: InputBorder.none,
                                          enabledBorder: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                          disabledBorder: InputBorder.none,
                                          errorBorder: InputBorder.none,
                                          focusedErrorBorder: InputBorder.none,
                                          contentPadding: EdgeInsets.zero,
                                          counterText: '',
                                        ),
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                          LengthLimitingTextInputFormatter(
                                            pinLen,
                                          ),
                                        ],
                                        onSubmitted: (_) => _unlockWithPin(),
                                      ),
                                    ),
                                    IgnorePointer(
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children:
                                            List.generate(pinLen, (index) {
                                          final filled = index < _pin.length;
                                          return Container(
                                            width: 48,
                                            height: 52,
                                            margin: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                            ),
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: AppColors.white,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: filled
                                                    ? AppColors.deepRed
                                                    : AppColors.fieldBorder,
                                                width: filled ? 1.5 : 1,
                                              ),
                                            ),
                                            child: filled
                                                ? Container(
                                                    width: 10,
                                                    height: 10,
                                                    decoration:
                                                        const BoxDecoration(
                                                      color: AppColors.deepRed,
                                                      shape: BoxShape.circle,
                                                    ),
                                                  )
                                                : null,
                                          );
                                        }),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 10),
                              Text(
                                _error!,
                                style: AppTypography.roboto(
                                  fontSize: 13,
                                  color: AppColors.primaryRed,
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            AppPrimaryButton(
                              label: _verifying ? 'Checking…' : 'Unlock',
                              onPressed: _verifying ? null : _unlockWithPin,
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed:
                                  _verifying ? null : _openForgotPassword,
                              child: Text(
                                'Forgot PIN?',
                                style: AppTypography.roboto(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryRed,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _verifying
                                  ? null
                                  : () => _showToast(
                                        'Biometric unlock will be available in a future update.',
                                      ),
                              icon: const Icon(
                                Icons.fingerprint_rounded,
                                color: AppColors.deepRed,
                              ),
                              label: Text(
                                'Use biometric',
                                style: AppTypography.roboto(
                                  fontSize: 14,
                                  color: AppColors.deepRed,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
      ],
    );
  }
}
