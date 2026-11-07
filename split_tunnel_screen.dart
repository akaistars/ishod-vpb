import 'package:flutter/material.dart';

// Match the app's dark background and surface palette.
const _splitBg = Color(0xFF05050A);
const _splitCard = Color(0xFF100D18);

/// Demo split-tunneling settings UI. Changes are local to this screen and do
/// not configure a real VPN tunnel or installed applications.
class SplitTunnelScreen extends StatefulWidget {
  const SplitTunnelScreen({super.key, required this.accent});

  final Color accent;

  @override
  State<SplitTunnelScreen> createState() => _SplitTunnelScreenState();
}

class _SplitTunnelScreenState extends State<SplitTunnelScreen> {
  bool _enabled = true;
  bool _domainsTab = true;
  String _routingMode = 'В обход туннеля';
  final List<String> _domains = ['Российские сайты'];
  final List<String> _apps = [];

  String? _countryFlagFor(String entry) {
    final value = entry.toLowerCase();
    if (value.contains('росси') || value.contains('russia')) return '🇷🇺';
    if (value.contains('сша') || value.contains('америк') || value.contains('united states')) return '🇺🇸';
    if (value.contains('герман') || value.contains('german')) return '🇩🇪';
    if (value.contains('нидерланд') || value.contains('netherland')) return '🇳🇱';
    if (value.contains('швед') || value.contains('swed')) return '🇸🇪';
    if (value.contains('япон') || value.contains('japan')) return '🇯🇵';
    if (value.contains('франц') || value.contains('france')) return '🇫🇷';
    if (value.contains('британ') || value.contains('united kingdom') || value.contains('uk')) return '🇬🇧';
    if (value.contains('турц') || value.contains('turkey')) return '🇹🇷';
    if (value.contains('казах') || value.contains('kazakh')) return '🇰🇿';
    return null;
  }

  Future<void> _chooseRoutingMode() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _splitCard,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final mode in ['В обход туннеля', 'В туннель'])
              ListTile(
                title: Text(mode, style: const TextStyle(color: Colors.white)),
                trailing: mode == _routingMode
                    ? Icon(Icons.check, color: widget.accent)
                    : null,
                onTap: () => Navigator.pop(context, mode),
              ),
          ],
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() => _routingMode = selected);
    }
  }

  Future<void> _addEntry() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _splitCard,
        title: Text(
          _domainsTab ? 'Добавить домен' : 'Добавить приложение',
          style: const TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: _domainsTab ? 'Например, example.com' : 'Название приложения',
            hintStyle: const TextStyle(color: Colors.white54),
          ),
          onSubmitted: (text) => Navigator.pop(context, text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: widget.accent,
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (value == null || value.isEmpty || !mounted) return;
    setState(() => (_domainsTab ? _domains : _apps).add(value));
  }

  @override
  Widget build(BuildContext context) {
    final listItems = _domainsTab ? _domains : _apps;

    return Scaffold(
      backgroundColor: _splitBg,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 56,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                  ),
                  const Expanded(
                    child: Text(
                      'Сплит-туннель',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Switch(
                      value: _enabled,
                      activeTrackColor: widget.accent,
                      activeThumbColor: Colors.white,
                      inactiveThumbColor: Colors.white70,
                      inactiveTrackColor: Colors.white24,
                      onChanged: (value) => setState(() => _enabled = value),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Material(
                color: _splitCard,
                borderRadius: BorderRadius.circular(9),
                child: InkWell(
                  onTap: _chooseRoutingMode,
                  borderRadius: BorderRadius.circular(9),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Выбранное в списке',
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _routingMode,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.white70, size: 25),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                _tabButton('Домены', true),
                _tabButton('Приложения', false),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final entry in listItems)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: _splitCard,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: SizedBox(
                        height: 51,
                        child: Row(
                          children: [
                            const SizedBox(width: 12),
                            if (_domainsTab && _countryFlagFor(entry) != null) ...[
                              Text(_countryFlagFor(entry)!, style: const TextStyle(fontSize: 18)),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Text(
                                entry,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Удалить',
                              onPressed: () => setState(() => listItems.remove(entry)),
                              icon: const Icon(Icons.delete, color: Colors.white, size: 21),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
              child: SizedBox(
                width: double.infinity,
                height: 40,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: widget.accent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _addEntry,
                  child: const Text(
                    'Добавить',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabButton(String title, bool domainsTab) {
    final selected = _domainsTab == domainsTab;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _domainsTab = domainsTab),
        child: Column(
          children: [
            SizedBox(
              height: 47,
              child: Center(
                child: Text(
                  title,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white60,
                    fontSize: 16,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
            Container(
              height: 3,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: selected ? widget.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
