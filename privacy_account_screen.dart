import 'package:flutter/material.dart';
import 'privacy_repository.dart';

const _privacyBg = Color(0xFF08060B);
const _privacyPanel = Color(0xFF151019);
const _privacyText = Color(0xFFF7F1F7);
const _privacyMuted = Color(0xFFAA9EAE);
const _privacyGreen = Color(0xFF39E875);

/// Interactive privacy UI for the Spider VPN DEMO. All accent surfaces and
/// controls use the active app palette passed from ProfileScreen.
class PrivacyAccountScreen extends StatefulWidget {
  const PrivacyAccountScreen({super.key, required this.repository, required this.english, required this.accent});
  final PrivacyRepository repository;
  final bool english;
  final Color accent;

  @override
  State<PrivacyAccountScreen> createState() => _PrivacyAccountScreenState();
}

class _PrivacyAccountScreenState extends State<PrivacyAccountScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _success = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
  bool _busy = false;
  String? _successText;

  String t(String ru, String en) => widget.english ? en : ru;
  Color get _accent => widget.accent;
  Color get _accentSoft => Color.lerp(widget.accent, Colors.white, .18)!;
  @override
  void dispose() { _success.dispose(); super.dispose(); }

  void _toast(String text) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text))); }
  String _error(Object error) {
    final code = error is PrivacyDemoException ? error.code : 'unknown';
    return switch (code) {
      'email_required' => t('Сначала привяжите Gmail.', 'Link a Gmail address first.'),
      'email_already_linked' => t('Gmail уже привязан.', 'A Gmail address is already linked.'),
      'invalid_email' => t('Введите корректный адрес @gmail.com.', 'Enter a valid @gmail.com address.'),
      'invalid_username' => t('Логин: 3–32 латинских символа, цифры, точка, дефис или подчёркивание.', 'Username must be 3–32 letters, digits, dot, dash or underscore.'),
      'weak_password' => t('Пароль: минимум 10 символов, строчные и заглавные буквы и цифра.', 'Use 10+ characters with lowercase, uppercase, and a digit.'),
      'invalid_password' => t('Неверный DEMO-пароль. Для нового демо-аккаунта: DemoPass123!', 'Incorrect DEMO password. New demo accounts use: DemoPass123!'),
      'invalid_or_expired_code' => t('Неверный код, истёк срок или превышено число попыток.', 'Invalid code, expired challenge, or too many attempts.'),
      'verification_required' => t('Сначала подтвердите DEMO-код.', 'Confirm the DEMO code first.'),
      _ => t('Не удалось выполнить действие.', 'The action could not be completed.'),
    };
  }

  Future<void> _act(Future<void> Function() action, StateSetter refresh) async {
    refresh(() => _busy = true);
    try { await action(); }
    catch (error) { _toast(_error(error)); }
    finally { if (mounted) refresh(() => _busy = false); }
  }

  Future<void> _requestCode(String purpose, String target, StateSetter refresh, void Function(String) saveId) async {
    await _act(() async {
      saveId(await widget.repository.sendVerificationCode(purpose: purpose, target: target));
      _toast(t('DEMO: письмо не отправлено. Тестовый код: 123456.', 'DEMO: no email was sent. Test code: 123456.'));
    }, refresh);
  }

  Future<void> _confirmCode(String id, TextEditingController input, StateSetter refresh, void Function() onConfirmed) async {
    await _act(() async {
      await widget.repository.confirmVerificationCode(challengeId: id, code: input.text.trim());
      onConfirmed();
      _toast(t('DEMO-код подтверждён.', 'DEMO code confirmed.'));
    }, refresh);
  }

  Future<void> _showDialog(String title, Widget Function(StateSetter, BuildContext) buildContent) async {
    await showDialog<void>(context: context, builder: (dialog) => StatefulBuilder(
      builder: (dialog, refresh) => Theme(
        data: _privacyTheme(context),
        child: AlertDialog(
          backgroundColor: _privacyPanel,
          title: Text(title, style: const TextStyle(color: _privacyText)),
          content: SingleChildScrollView(child: buildContent(refresh, dialog)),
        ),
      ),
    ));
  }

  ThemeData _privacyTheme(BuildContext context) => Theme.of(context).copyWith(
    colorScheme: Theme.of(context).colorScheme.copyWith(primary: _accent, secondary: _accent),
  );

  Future<void> _usernameDialog() async {
    final username = TextEditingController(text: widget.repository.username), code = TextEditingController();
    String? challenge; bool verified = false;
    await _showDialog(t('Сменить логин', 'Change username'), (refresh, dialog) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('${t('Текущий логин:', 'Current username:')} ${widget.repository.username}', style: const TextStyle(color: _privacyMuted)),
      const SizedBox(height: 10),
      TextField(controller: username, style: const TextStyle(color: _privacyText), decoration: InputDecoration(labelText: t('Новый логин', 'New username'))),
      if (!verified) ...[
        TextField(controller: code, keyboardType: TextInputType.number, style: const TextStyle(color: _privacyText), decoration: InputDecoration(labelText: t('DEMO-код', 'DEMO code'))),
        TextButton(onPressed: _busy ? null : () { if (!RegExp(r'^[A-Za-z0-9._-]{3,32}$').hasMatch(username.text.trim())) { _toast(_error(const PrivacyDemoException('invalid_username'))); return; } _requestCode('change_username', widget.repository.email ?? '', refresh, (id) => challenge = id); }, child: Text(t('Сымитировать отправку кода', 'Simulate sending code'), style: TextStyle(color: _accentSoft))),
        FilledButton(onPressed: _busy || challenge == null ? null : () => _confirmCode(challenge!, code, refresh, () => refresh(() => verified = true)), child: Text(t('Подтвердить DEMO-код', 'Confirm DEMO code'))),
      ],
      if (verified) FilledButton(onPressed: _busy ? null : () => _act(() async { await widget.repository.changeUsername(username: username.text.trim(), challengeId: challenge!); if (dialog.mounted) Navigator.pop(dialog); _showSuccess(t('Ваш логин успешно изменён!', 'Your username was changed!')); }, refresh), child: Text(t('Сохранить', 'Save'))),
      TextButton(onPressed: () => Navigator.pop(dialog), child: Text(t('Отмена', 'Cancel'))),
    ]));
    username.dispose(); code.dispose();
  }

  Future<void> _passwordDialog() async {
    final code = TextEditingController(), password = TextEditingController(), confirm = TextEditingController();
    String? challenge; bool verified = false;
    await _showDialog(t('Сменить пароль', 'Change password'), (refresh, dialog) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('${t('Письмо не отправляется. DEMO-код для', 'No email is sent. DEMO code for')} ${widget.repository.email ?? t('тестового сценария','the demo scenario')}: 123456', style: const TextStyle(color: _privacyMuted)),
      if (!verified) ...[
        TextField(controller: code, keyboardType: TextInputType.number, style: const TextStyle(color: _privacyText), decoration: InputDecoration(labelText: t('Введите DEMO-код', 'Enter DEMO code'))),
        TextButton(onPressed: _busy ? null : () => _requestCode('change_password', widget.repository.email ?? '', refresh, (id) => challenge = id), child: Text(t('Создать DEMO-код', 'Create DEMO code'), style: TextStyle(color: _accentSoft))),
        FilledButton(onPressed: _busy || challenge == null ? null : () => _confirmCode(challenge!, code, refresh, () => refresh(() => verified = true)), child: Text(t('Подтвердить', 'Confirm'))),
      ] else ...[
        TextField(controller: password, obscureText: true, style: const TextStyle(color: _privacyText), decoration: InputDecoration(labelText: t('Новый пароль', 'New password'))),
        TextField(controller: confirm, obscureText: true, style: const TextStyle(color: _privacyText), decoration: InputDecoration(labelText: t('Повторите пароль', 'Repeat password'))),
        FilledButton(onPressed: _busy ? null : () { if (password.text != confirm.text) { _toast(t('Пароли не совпадают.', 'Passwords do not match.')); return; } if (!DemoPrivacyRepository.isStrongPassword(password.text)) { _toast(_error(const PrivacyDemoException('weak_password'))); return; } _act(() async { await widget.repository.changePassword(password: password.text, challengeId: challenge!); if (dialog.mounted) Navigator.pop(dialog); _showSuccess(t('Ваш пароль успешно изменён!', 'Your password was changed!')); }, refresh); }, child: Text(t('Сохранить пароль', 'Save password'))),
      ],
      TextButton(onPressed: () => Navigator.pop(dialog), child: Text(t('Закрыть', 'Close'))),
    ]));
    code.dispose(); password.dispose(); confirm.dispose();
  }

  Future<void> _emailDialog({required bool replacing}) async {
    final email = TextEditingController(text: replacing ? widget.repository.email ?? '' : ''), code = TextEditingController();
    String? challenge; bool verified = false;
    await _showDialog(replacing ? t('Изменить Gmail', 'Change Gmail') : t('Привязать Gmail', 'Link Gmail'), (refresh, dialog) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (replacing) Text('${t('Текущий адрес:', 'Current address:')} ${widget.repository.email ?? '—'}', style: const TextStyle(color: _privacyMuted)),
      TextField(controller: email, keyboardType: TextInputType.emailAddress, style: const TextStyle(color: _privacyText), decoration: InputDecoration(labelText: t('Адрес Gmail', 'Gmail address'))),
      if (!verified) ...[
        TextField(controller: code, keyboardType: TextInputType.number, style: const TextStyle(color: _privacyText), decoration: InputDecoration(labelText: t('DEMO-код', 'DEMO code'))),
        TextButton(onPressed: _busy ? null : () { final value = email.text.trim().toLowerCase(); if (!DemoPrivacyRepository.isValidGmail(value)) { _toast(_error(const PrivacyDemoException('invalid_email'))); return; } _requestCode(replacing ? 'change_email' : 'link_email', value, refresh, (id) => challenge = id); }, child: Text(t('Сымитировать отправку кода', 'Simulate sending code'), style: TextStyle(color: _accentSoft))),
        FilledButton(onPressed: _busy || challenge == null ? null : () => _confirmCode(challenge!, code, refresh, () => refresh(() => verified = true)), child: Text(t('Подтвердить DEMO-код', 'Confirm DEMO code'))),
      ],
      if (verified) FilledButton(onPressed: _busy ? null : () => _act(() async { await widget.repository.changeEmail(email: email.text.trim(), challengeId: challenge!); if (dialog.mounted) Navigator.pop(dialog); _showSuccess(t(replacing ? 'Ваша почта успешно изменена!' : 'Ваша почта успешно привязана!', replacing ? 'Your email was changed!' : 'Your email was linked!')); }, refresh), child: Text(t('Сохранить Gmail', 'Save Gmail'))),
      TextButton(onPressed: () => Navigator.pop(dialog), child: Text(t('Отмена', 'Cancel'))),
    ]));
    email.dispose(); code.dispose();
  }

  Future<void> _unlinkDialog() async {
    final password = TextEditingController(), code = TextEditingController(); String? challenge; bool verified = false;
    await _showDialog(t('Отвязать Gmail', 'Unlink Gmail'), (refresh, dialog) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('${t('Gmail:', 'Gmail:')} ${widget.repository.email ?? '—'}', style: const TextStyle(color: _privacyMuted)),
      TextField(controller: password, obscureText: true, style: const TextStyle(color: _privacyText), decoration: InputDecoration(labelText: t('DEMO-пароль', 'DEMO password'))),
      if (!verified) ...[
        TextField(controller: code, keyboardType: TextInputType.number, style: const TextStyle(color: _privacyText), decoration: InputDecoration(labelText: t('DEMO-код', 'DEMO code'))),
        TextButton(onPressed: _busy ? null : () => _requestCode('unlink_email', widget.repository.email ?? '', refresh, (id) => challenge = id), child: Text(t('Создать DEMO-код', 'Create DEMO code'), style: TextStyle(color: _accentSoft))),
        FilledButton(onPressed: _busy || challenge == null ? null : () => _confirmCode(challenge!, code, refresh, () => refresh(() => verified = true)), child: Text(t('Подтвердить код', 'Confirm code'))),
      ],
      if (verified) FilledButton(onPressed: _busy ? null : () => _act(() async { await widget.repository.unlinkEmail(currentPassword: password.text, challengeId: challenge!); if (dialog.mounted) Navigator.pop(dialog); _showSuccess(t('Gmail отвязан.', 'Gmail was unlinked.')); }, refresh), child: Text(t('Подтвердить отвязку', 'Confirm unlink'))),
      TextButton(onPressed: () => Navigator.pop(dialog), child: Text(t('Отмена', 'Cancel'))),
    ]));
    password.dispose(); code.dispose();
  }

  Future<void> _showSuccess(String text) async {
    if (!mounted) return;
    setState(() => _successText = text);
    _success.forward(from: 0);
    await showDialog<void>(context: context, builder: (dialog) => Theme(data: _privacyTheme(context), child: AlertDialog(backgroundColor: _privacyPanel,
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        ScaleTransition(scale: CurvedAnimation(parent: _success, curve: Curves.elasticOut), child: FadeTransition(opacity: _success, child: const Icon(Icons.check_circle, color: _privacyGreen, size: 60))),
        const SizedBox(height: 14), Text(text, textAlign: TextAlign.center, style: const TextStyle(color: _privacyText, fontSize: 17, fontWeight: FontWeight.w600)),
      ]), actions: [TextButton(onPressed: () => Navigator.pop(dialog), child: Text(t('Готово', 'Done'))])));
    if (mounted) setState(() => _successText = null);
  }

  Future<void> _options() async {
    await showModalBottomSheet<void>(context: context, backgroundColor: _privacyPanel,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Theme(data: _privacyTheme(context), child: SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        _option(context, Icons.person_outline, t('Сменить логин', 'Change username'), _usernameDialog),
        _option(context, Icons.lock_outline, t('Сменить пароль', 'Change password'), _passwordDialog),
        _option(context, Icons.email_outlined, widget.repository.email ?? t('Привязать Gmail', 'Link Gmail'), () => _emailDialog(replacing: widget.repository.email != null)),
        if (widget.repository.email != null) ...[
          _option(context, Icons.edit_outlined, t('Изменить Gmail', 'Change Gmail'), () => _emailDialog(replacing: true)),
          _option(context, Icons.link_off, t('Отвязать Gmail', 'Unlink Gmail'), _unlinkDialog),
        ],
      ]))));
  }

  Widget _option(BuildContext context, IconData icon, String label, Future<void> Function() action) => ListTile(
    leading: Icon(icon, color: _accent), title: Text(label, style: const TextStyle(color: _privacyText)),
    onTap: () { Navigator.pop(context); action(); });

  Widget _tile(IconData icon, String title, String subtitle, VoidCallback onTap) => Card(color: _privacyPanel,
    child: ListTile(leading: Icon(icon, color: _accent), title: Text(title, style: const TextStyle(color: _privacyText)),
      subtitle: subtitle.isEmpty ? null : Text(subtitle, style: const TextStyle(color: _privacyMuted)),
      trailing: Icon(Icons.chevron_right, color: _accent), onTap: onTap));

  @override
  Widget build(BuildContext context) => Theme(
    data: _privacyTheme(context),
    child: Scaffold(
      backgroundColor: _privacyBg,
      appBar: AppBar(backgroundColor: _privacyBg, foregroundColor: _accent, title: Text(t('Конфиденциальность', 'Privacy'))),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _privacyPanel, borderRadius: BorderRadius.circular(12), border: Border.all(color: _accent.withOpacity(.55))),
          child: Text(t('DEMO-режим: данные сохраняются локально. Письма не отправляются. Тестовый код: 123456. Не используйте для реального аккаунта.', 'DEMO mode: data is stored locally. No emails are sent. Test code: 123456. Do not use for a real account.'), style: TextStyle(color: _accentSoft, fontSize: 12))),
        const SizedBox(height: 14),
        _tile(Icons.person_outline, t('Сменить логин', 'Change username'), widget.repository.username, _usernameDialog),
        _tile(Icons.lock_outline, t('Сменить пароль', 'Change password'), t('Подтверждение DEMO-кодом', 'DEMO code verification'), _passwordDialog),
        if (widget.repository.email == null)
          _tile(Icons.email_outlined, t('Привязать Gmail', 'Link Gmail'), t('Не привязан', 'Not linked'), () => _emailDialog(replacing: false))
        else ...[
          _tile(Icons.email_outlined, widget.repository.email!, t('Подтверждён в DEMO', 'Verified in DEMO'), () => _emailDialog(replacing: true)),
          _tile(Icons.edit_outlined, t('Изменить Gmail', 'Change Gmail'), '', () => _emailDialog(replacing: true)),
          _tile(Icons.link_off, t('Отвязать Gmail', 'Unlink Gmail'), '', _unlinkDialog),
        ],
        if (_successText != null) FadeTransition(opacity: _success, child: Text(_successText!, textAlign: TextAlign.center, style: const TextStyle(color: _privacyGreen))),
      ]),
    ),
  );
}
