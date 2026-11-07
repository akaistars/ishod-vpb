import 'dart:io' show Platform, exit;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

const _bg = Color(0xFF08060B);
const _panel = Color(0xFF151019);
const _pink = Color(0xFFFF4FA3);
const _rose = Color(0xFFFFB4D4);
const _text = Color(0xFFF7F1F7);
const _muted = Color(0xFFAA9EAE);

/// Local demo authentication only: credentials are held in memory and lost
/// when the application closes. This is not production authentication.
class DemoAuthGate extends StatefulWidget {
  const DemoAuthGate({super.key, required this.appBuilder});
  final WidgetBuilder appBuilder;

  @override
  State<DemoAuthGate> createState() => _DemoAuthGateState();
}

class _DemoAuthGateState extends State<DemoAuthGate> with TickerProviderStateMixin {
  late final AnimationController _shine;
  late final AnimationController _weave;
  late final AnimationController _entry;
  String? _username;
  String? _password;
  bool _authorized = false;
  bool _entering = false;

  @override
  void initState() {
    super.initState();
    _shine = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _weave = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))
      ..addStatusListener(_onWeaveStatus);
    _entry = AnimationController(vsync: this, duration: const Duration(milliseconds: 850));
  }

  @override
  void dispose() {
    _shine.dispose();
    _weave.dispose();
    _entry.dispose();
    super.dispose();
  }

  void _onWeaveStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted || !_entering) return;
    setState(() {
      _entering = false;
      _authorized = true;
    });
    _entry.forward(from: 0);
  }

  void _message(String value) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  void _register(String username, String password) {
    setState(() {
      _username = username.trim();
      _password = password;
    });
    _message('Аккаунт создан. Теперь войдите.');
  }

  void _login(String username, String password) {
    if (_username == null || username.trim().toLowerCase() != _username!.toLowerCase() || password != _password) {
      _message('Неверный логин или пароль.');
      return;
    }
    setState(() => _entering = true);
    _weave.forward(from: 0);
  }

  Future<void> _recover() async {
    if (_username == null) {
      _message('Сначала создайте демо-аккаунт.');
      return;
    }
    final usernameController = TextEditingController();
    final usernameKey = GlobalKey<FormState>();
    final enteredUsername = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _panel,
        title: const Text('Восстановление пароля', style: TextStyle(color: _text)),
        content: Form(
          key: usernameKey,
          child: TextFormField(
            controller: usernameController,
            style: const TextStyle(color: _text),
            decoration: const InputDecoration(labelText: 'Логин аккаунта'),
            validator: (value) => (value?.trim().isNotEmpty ?? false) ? null : 'Введите логин',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Отмена')),
          FilledButton(
            onPressed: () {
              if (usernameKey.currentState!.validate()) {
                Navigator.pop(dialogContext, usernameController.text.trim());
              }
            },
            child: const Text('Продолжить'),
          ),
        ],
      ),
    );
    usernameController.dispose();
    if (!mounted || enteredUsername == null) return;
    if (enteredUsername.toLowerCase() != _username!.toLowerCase()) {
      _message('Демо-аккаунт с таким логином не найден.');
      return;
    }

    final passwordController = TextEditingController();
    final repeatController = TextEditingController();
    final passwordKey = GlobalKey<FormState>();
    final password = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _panel,
        title: const Text('Новый пароль', style: TextStyle(color: _text)),
        content: Form(
          key: passwordKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Демо-восстановление выполняется локально.', style: TextStyle(color: _muted)),
              TextFormField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Новый пароль'),
                validator: (value) => (value ?? '').length >= 6 ? null : 'Минимум 6 символов',
              ),
              TextFormField(
                controller: repeatController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Повторите пароль'),
                validator: (value) => value == passwordController.text ? null : 'Пароли не совпадают',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Отмена')),
          FilledButton(
            onPressed: () {
              if (passwordKey.currentState!.validate()) {
                Navigator.pop(dialogContext, passwordController.text);
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    passwordController.dispose();
    repeatController.dispose();
    if (password != null && mounted) {
      setState(() => _password = password);
      _message('Пароль изменён. Войдите с новым паролем.');
    }
  }

  void _close() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      exit(0);
    } else {
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_authorized) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: _entry, curve: Curves.easeInOut),
        child: widget.appBuilder(context),
      );
    }

    if (_entering) {
      return Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: AnimatedBuilder(
            animation: Listenable.merge([_shine, _weave]),
            builder: (context, _) => Stack(
              children: [
                Center(
                  child: SizedBox(
                    width: 280,
                    height: 300,
                    child: CustomPaint(painter: _SpiderTreePainter(progress: _weave.value, shimmer: _shine.value)),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 20,
                  child: Center(
                    child: SizedBox(
                      width: 112,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _weave.value,
                          minHeight: 2,
                          backgroundColor: const Color(0xFF28151F),
                          color: _pink,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      body: AnimatedBuilder(
        animation: _shine,
        builder: (context, _) => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1 + 2 * _shine.value, -1),
              end: Alignment(1 - 2 * _shine.value, 1),
              colors: const [Color(0xFF08060B), Color(0xFF1D101A), Color(0xFF100B13), Color(0xFF08060B)],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _AuthTitleBar(onClose: _close),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: _username == null
                            ? _RegistrationForm(shine: _shine, onRegister: _register)
                            : _LoginForm(shine: _shine, onLogin: _login, onForgot: _recover),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthTitleBar extends StatelessWidget {
  const _AuthTitleBar({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 42,
        child: Row(
          children: [
            IconButton(
              tooltip: 'Закрыть приложение',
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded, color: _rose, size: 23),
            ),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanStart: (_) => windowManager.startDragging(),
                child: const SizedBox(
                  height: 42,
                  child: Center(
                    child: Text(
                      'Spider VPN',
                      style: TextStyle(color: _text, fontWeight: FontWeight.w600, letterSpacing: 1.2),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
      );
}

class _RegistrationForm extends StatefulWidget {
  const _RegistrationForm({required this.shine, required this.onRegister});
  final Animation<double> shine;
  final void Function(String, String) onRegister;

  @override
  State<_RegistrationForm> createState() => _RegistrationFormState();
}

class _RegistrationFormState extends State<_RegistrationForm> {
  final _key = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _repeat = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _repeat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
        key: _key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Brand(shine: widget.shine),
            const SizedBox(height: 22),
            const Text(
              'Создать аккаунт',
              textAlign: TextAlign.center,
              style: TextStyle(color: _text, fontSize: 22, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 7),
            const Text('Придумайте логин и пароль', textAlign: TextAlign.center, style: TextStyle(color: _muted)),
            const SizedBox(height: 24),
            TextFormField(
              controller: _username,
              style: const TextStyle(color: _text),
              decoration: const InputDecoration(labelText: 'Логин'),
              validator: (v) => (v?.trim().length ?? 0) >= 3 ? null : 'Минимум 3 символа',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              style: const TextStyle(color: _text),
              decoration: InputDecoration(
                labelText: 'Пароль',
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                ),
              ),
              validator: (v) => (v ?? '').length >= 6 ? null : 'Минимум 6 символов',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _repeat,
              obscureText: _obscure,
              style: const TextStyle(color: _text),
              decoration: const InputDecoration(labelText: 'Повторите пароль'),
              validator: (v) => v == _password.text ? null : 'Пароли не совпадают',
            ),
            const SizedBox(height: 20),
            _GlowButton(
              shine: widget.shine,
              label: 'Зарегистрироваться',
              onPressed: () {
                if (_key.currentState!.validate()) {
                  widget.onRegister(_username.text.trim(), _password.text);
                }
              },
            ),
          ],
        ),
      );
}

class _LoginForm extends StatefulWidget {
  const _LoginForm({required this.shine, required this.onLogin, required this.onForgot});
  final Animation<double> shine;
  final void Function(String, String) onLogin;
  final VoidCallback onForgot;

  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  final _key = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
        key: _key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Brand(shine: widget.shine),
            const SizedBox(height: 22),
            const Text(
              'Вход в аккаунт',
              textAlign: TextAlign.center,
              style: TextStyle(color: _text, fontSize: 22, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _username,
              style: const TextStyle(color: _text),
              decoration: const InputDecoration(labelText: 'Логин'),
              validator: (v) => (v?.trim().isNotEmpty ?? false) ? null : 'Введите логин',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: true,
              style: const TextStyle(color: _text),
              decoration: const InputDecoration(labelText: 'Пароль'),
              validator: (v) => (v?.isNotEmpty ?? false) ? null : 'Введите пароль',
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: widget.onForgot,
                child: const Text('Забыл логин/пароль?', style: TextStyle(color: _muted, fontSize: 12)),
              ),
            ),
            const SizedBox(height: 8),
            _GlowButton(
              shine: widget.shine,
              label: 'Войти',
              onPressed: () {
                if (_key.currentState!.validate()) {
                  widget.onLogin(_username.text.trim(), _password.text);
                }
              },
            ),
          ],
        ),
      );
}

class _Brand extends StatelessWidget {
  const _Brand({required this.shine});
  final Animation<double> shine;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 190, height: 190, child: CustomPaint(painter: _SpiderPainter(shine))),
          const SizedBox(height: 5),
          AnimatedBuilder(
            animation: shine,
            builder: (context, _) => ShaderMask(
              shaderCallback: (bounds) =>
                  LinearGradient(
                    begin: Alignment(-1 + 2 * shine.value, 0),
                    end: Alignment(1 - 2 * shine.value, 0),
                    colors: const [_text, _rose, _text],
                  ).createShader(bounds),
              child: const Text(
                'SPIDER VPN',
                style: TextStyle(color: Colors.white, fontFamily: 'serif', fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 4.5),
              ),
            ),
          ),
        ],
      );
}

class _SpiderPainter extends CustomPainter {
  _SpiderPainter(this.animation) : super(repaint: animation);
  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final scale = size.shortestSide / 300;
    final phase = animation.value;
    final shader = LinearGradient(
      begin: Alignment(-1 + 2 * phase, -1),
      end: Alignment(1 - 2 * phase, 1),
      colors: [
        const Color(0x884A172E),
        Color.lerp(_pink, _rose, (math.sin(phase * math.pi * 2) + 1) / 2)!,
        const Color(0xFFFFE0ED),
        _pink,
      ],
      stops: const [0, .35, .58, 1],
    ).createShader(Offset.zero & size);

    final line = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..shader = shader;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale);

    final legs = <Path>[
      Path()..moveTo(-9, -25)..cubicTo(-42, -53, -54, -83, -60, -111)..cubicTo(-66, -137, -66, -166, -82, -191),
      Path()..moveTo(9, -25)..cubicTo(42, -53, 54, -83, 60, -111)..cubicTo(66, -137, 66, -166, 82, -191),
      Path()..moveTo(-16, -19)..cubicTo(-56, -39, -92, -44, -120, -72)..cubicTo(-137, -89, -143, -108, -159, -124),
      Path()..moveTo(16, -19)..cubicTo(56, -39, 92, -44, 120, -72)..cubicTo(137, -89, 143, -108, 159, -124),
      Path()..moveTo(-17, -2)..cubicTo(-60, -2, -100, 4, -128, 24)..cubicTo(-151, 40, -160, 61, -178, 76),
      Path()..moveTo(17, -2)..cubicTo(60, -2, 100, 4, 128, 24)..cubicTo(151, 40, 160, 61, 178, 76),
      Path()..moveTo(-12, 17)..cubicTo(-48, 39, -78, 58, -83, 95)..cubicTo(-87, 132, -67, 164, -52, 190),
      Path()..moveTo(12, 17)..cubicTo(48, 39, 78, 58, 83, 95)..cubicTo(87, 132, 67, 164, 52, 190),
    ];

    for (final leg in legs) {
      canvas.drawPath(leg, line);
    }

    canvas.drawOval(Rect.fromCenter(center: const Offset(0, 9), width: 61, height: 83), fill);
    canvas.drawOval(Rect.fromCenter(center: const Offset(0, -34), width: 51, height: 48), fill);

    final fangs = Path()
      ..moveTo(-10, -52)..quadraticBezierTo(-31, -76, -17, -91)
      ..moveTo(10, -52)..quadraticBezierTo(31, -76, 17, -91);

    canvas.drawPath(fangs, line);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SpiderPainter oldDelegate) => oldDelegate.animation != animation;
}

class _SpiderTreePainter extends CustomPainter {
  const _SpiderTreePainter({required this.progress, required this.shimmer});
  final double progress;
  final double shimmer;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * .69);
    final scale = size.shortestSide / 300;
    final tint = Color.lerp(_pink, _rose, (math.sin(shimmer * math.pi * 2) + 1) / 2)!;
    final treePaint = Paint()
      ..color = tint.withOpacity(.78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2 * scale
      ..strokeCap = StrokeCap.round;
    final treeGlow = Paint()
      ..color = tint.withOpacity(.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10 * scale
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale);

    final trunk = Path()
      ..moveTo(0, 118)..cubicTo(-8, 75, 9, 45, 0, 5)..cubicTo(-8, -30, -2, -60, 0, -95);

    final branches = <Path>[
      Path()..moveTo(-1, -28)..cubicTo(-28, -48, -42, -70, -54, -96),
      Path()..moveTo(1, -35)..cubicTo(28, -52, 43, -73, 56, -101),
      Path()..moveTo(0, 7)..cubicTo(-25, -2, -44, -18, -67, -39),
      Path()..moveTo(0, -6)..cubicTo(26, -11, 48, -28, 68, -49),
    ];

    canvas.drawPath(trunk, treeGlow);
    canvas.drawPath(trunk, treePaint);

    for (final branch in branches) {
      canvas.drawPath(branch, treeGlow);
      canvas.drawPath(branch, treePaint);
    }

    final p = progress.clamp(0.0, 1.0);
    const rays = 8;
    const rings = 5;
    const webCenter = Offset(0, -33);
    const webRadius = 105.0;

    final webPaint = Paint()
      ..color = tint.withOpacity(.83)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    final webGlow = Paint()
      ..color = tint.withOpacity(.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final rayProgress = (p / .55).clamp(0.0, 1.0);

    for (var i = 0; i < rays; i++) {
      final angle = -math.pi / 2 + i * math.pi * 2 / rays;
      final end = Offset(
        webCenter.dx + math.cos(angle) * webRadius * rayProgress,
        webCenter.dy + math.sin(angle) * webRadius * rayProgress,
      );
      final ray = Path()..moveTo(webCenter.dx, webCenter.dy)..lineTo(end.dx, end.dy);
      canvas.drawPath(ray, webGlow);
      canvas.drawPath(ray, webPaint);
    }

    final ringProgress = ((p - .3) / .7).clamp(0.0, 1.0);

    for (var ring = 1; ring <= rings; ring++) {
      final reveal = (ringProgress * rings - ring + 1).clamp(0.0, 1.0);
      if (reveal <= 0) continue;
      final radius = webRadius * ring / rings;
      final path = Path();

      for (var i = 0; i <= rays; i++) {
        final angle = -math.pi / 2 + i * math.pi * 2 / rays;
        final point = Offset(webCenter.dx + math.cos(angle) * radius, webCenter.dy + math.sin(angle) * radius);

        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          final previousAngle = -math.pi / 2 + (i - 1) * math.pi * 2 / rays;
          final middleAngle = (previousAngle + angle) / 2;
          final control = Offset(
            webCenter.dx + math.cos(middleAngle) * radius * .78,
            webCenter.dy + math.sin(middleAngle) * radius * .78,
          );
          path.quadraticBezierTo(control.dx, control.dy, point.dx, point.dy);
        }
      }

      final metrics = path.computeMetrics().toList();
      if (metrics.isNotEmpty) {
        final partial = metrics.first.extractPath(0, metrics.first.length * reveal);
        canvas.drawPath(partial, webGlow);
        canvas.drawPath(partial, webPaint);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SpiderTreePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.shimmer != shimmer;
}

class _GlowButton extends StatelessWidget {
  const _GlowButton({required this.shine, required this.label, required this.onPressed});
  final Animation<double> shine;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: shine,
        builder: (context, _) => Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment(-1 + 2 * shine.value, 0),
              end: Alignment(1 - 2 * shine.value, 0),
              colors: const [Color(0xFF6D254B), Color(0xFFE95A9D), Color(0xFF6D254B)],
            ),
            boxShadow: [BoxShadow(color: _pink.withOpacity(.2), blurRadius: 18)],
          ),
          child: FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: .5)),
            ),
          ),
        ),
      );
}
