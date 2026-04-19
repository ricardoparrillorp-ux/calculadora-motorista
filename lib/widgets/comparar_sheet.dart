import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../services/api_service.dart';

class CompararSheet extends StatefulWidget {
  final String token;
  final String myName;
  final String otherName;

  const CompararSheet({
    super.key,
    required this.token,
    required this.myName,
    required this.otherName,
  });

  @override
  State<CompararSheet> createState() => _CompararSheetState();
}

class _CompararSheetState extends State<CompararSheet> {
  String _periodo = 'mes';
  bool _custom = false;
  late DateTime _desde;
  late DateTime _ate;
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _dataA;
  Map<String, dynamic>? _dataB;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _desde = DateTime(now.year, now.month, 1);
    _ate = now;
    _load();
  }

  String _isoDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  (String, String) get _range {
    if (_custom) return (_isoDate(_desde), _isoDate(_ate));
    final today = DateTime.now();
    final todayStr = _isoDate(today);
    switch (_periodo) {
      case 'dia':
        return (todayStr, todayStr);
      case 'semana':
        final start = today.subtract(Duration(days: today.weekday - 1));
        return (_isoDate(start), todayStr);
      case 'mes':
        return (
          '${today.year}-${today.month.toString().padLeft(2, '0')}-01',
          todayStr
        );
      default:
        return ('1970-01-01', todayStr);
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final (desde, ate) = _range;
    try {
      final d = await api.comparar(
          widget.token, widget.myName, widget.otherName, desde, ate);
      if (mounted) {
        setState(() {
          _dataA = d['usuario_a'] as Map<String, dynamic>;
          _dataB = d['usuario_b'] as Map<String, dynamic>;
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() {
        _error = 'Sem conexão com o servidor';
        _loading = false;
      });
    }
  }

  Future<void> _pickDate(bool isDesde) async {
    final initial = isDesde ? _desde : _ate;
    final first = isDesde ? DateTime(2020) : _desde;
    final last = isDesde ? _ate : DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
                primary: blue, surface: Color(0xFF1C1C1E))),
        child: child!,
      ),
    );
    if (d != null) {
      setState(() {
        if (isDesde) {
          _desde = d;
        } else {
          _ate = d;
        }
      });
      _load();
    }
  }

  String _fmt(double v) {
    final s = v.toStringAsFixed(2);
    final pts = s.split('.');
    final buf = StringBuffer();
    for (int i = 0; i < pts[0].length; i++) {
      if (i > 0 && (pts[0].length - i) % 3 == 0) buf.write('.');
      buf.write(pts[0][i]);
    }
    return 'R\$ $buf,${pts[1]}';
  }

  String _fmtH(double h) {
    final hI = h.floor();
    final mI = ((h - hI) * 60).round();
    return '$hI:${mI.toString().padLeft(2, '0')}h';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF161617),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: border,
                        borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            const Text('COMPARAÇÃO',
                style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 3,
                    color: muted,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                    child: Text(widget.myName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: blue))),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('vs',
                      style: TextStyle(
                          fontSize: 11,
                          color: dim,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w600)),
                ),
                Flexible(
                    child: Text(widget.otherName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: txt))),
              ],
            ),
            const SizedBox(height: 20),
            _buildPeriodChips(),
            if (_custom) ...[
              const SizedBox(height: 12),
              _buildDateRange(),
            ],
            const SizedBox(height: 16),
            if (_loading)
              Column(
                children: List.generate(
                  4,
                  (_) => Container(
                    height: 42,
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(radiusMd),
                      border: Border.all(color: border),
                    ),
                  ),
                ),
              )
            else if (_error != null)
              _errBox(_error!)
            else if (_dataA != null && _dataB != null)
              _buildStats(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodChips() {
    final opcoes = [
      ('dia', 'Hoje'),
      ('semana', 'Semana'),
      ('mes', 'Mês'),
      ('geral', 'Geral'),
      ('custom', 'Período'),
    ];
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(radiusMd),
        border: Border.all(color: border),
      ),
      child: Row(
        children: opcoes.map((o) {
          final selected =
              o.$1 == 'custom' ? _custom : (!_custom && _periodo == o.$1);
          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (o.$1 == 'custom') {
                  setState(() => _custom = true);
                } else {
                  setState(() {
                    _custom = false;
                    _periodo = o.$1;
                  });
                  _load();
                }
              },
              child: Container(
                margin: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF1A2F4A)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(radiusSm - 1),
                ),
                child: Center(
                  child: Text(o.$2,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: selected ? blue : dim)),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDateRange() {
    return Row(children: [
      Expanded(child: _dateTile('De', _desde, () => _pickDate(true))),
      const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.arrow_forward_rounded, size: 16, color: muted)),
      Expanded(child: _dateTile('Até', _ate, () => _pickDate(false))),
    ]);
  }

  Widget _dateTile(String label, DateTime d, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(radiusMd),
              border: Border.all(color: border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 9, color: muted, letterSpacing: 1.5)),
            const SizedBox(height: 3),
            Text(
              '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}',
              style: const TextStyle(
                  fontSize: 13, color: txt, fontWeight: FontWeight.w600),
            ),
          ]),
        ),
      );

  Widget _buildStats() {
    double dbl(Map<String, dynamic> m, String k) =>
        (m[k] as num?)?.toDouble() ?? 0;

    final fatA = dbl(_dataA!, 'total_faturamento');
    final fatB = dbl(_dataB!, 'total_faturamento');
    final kmA = dbl(_dataA!, 'total_km');
    final kmB = dbl(_dataB!, 'total_km');
    final hA = dbl(_dataA!, 'total_horas');
    final hB = dbl(_dataB!, 'total_horas');
    final gkmA = dbl(_dataA!, 'ganho_km');
    final gkmB = dbl(_dataB!, 'ganho_km');
    final ghA = dbl(_dataA!, 'ganho_hora');
    final ghB = dbl(_dataB!, 'ganho_hora');
    final jA = (_dataA!['total_jornadas'] as num?)?.toInt() ?? 0;
    final jB = (_dataB!['total_jornadas'] as num?)?.toInt() ?? 0;

    int aWins = 0, bWins = 0;
    void tally(double a, double b) {
      if (a > b) {
        aWins++;
      } else if (b > a) {
        bWins++;
      }
    }

    tally(fatA, fatB);
    tally(kmA, kmB);
    tally(hA, hB);
    tally(gkmA, gkmB);
    tally(ghA, ghB);
    tally(jA.toDouble(), jB.toDouble());

    return Column(
      children: [
        if (aWins != bWins)
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: aWins > bWins
                  ? const Color(0xFF0D1829)
                  : const Color(0xFF0F1F12),
              borderRadius: BorderRadius.circular(radiusMd),
              border: Border.all(
                  color: aWins > bWins
                      ? const Color(0xFF1A3050)
                      : const Color(0xFF1A3A2A)),
            ),
            child: Text(
              aWins > bWins
                  ? 'Você está à frente em $aWins de ${aWins + bWins} métricas'
                  : '${widget.otherName} está à frente em $bWins de ${aWins + bWins} métricas',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: aWins > bWins ? blue : green),
            ),
          ),
        _statRow('FATURAMENTO', _fmt(fatA), _fmt(fatB), fatA.compareTo(fatB)),
        _statRow('R\$/KM', gkmA > 0 ? _fmt(gkmA) : '—',
            gkmB > 0 ? _fmt(gkmB) : '—', gkmA.compareTo(gkmB)),
        _statRow('R\$/HORA', ghA > 0 ? _fmt(ghA) : '—',
            ghB > 0 ? _fmt(ghB) : '—', ghA.compareTo(ghB)),
        _statRow(
            'KM RODADOS',
            kmA > 0 ? '${kmA.toStringAsFixed(0)} km' : '—',
            kmB > 0 ? '${kmB.toStringAsFixed(0)} km' : '—',
            kmA.compareTo(kmB)),
        _statRow('HORAS', hA > 0 ? _fmtH(hA) : '—',
            hB > 0 ? _fmtH(hB) : '—', hA.compareTo(hB)),
        _statRow('JORNADAS', '$jA', '$jB', jA.compareTo(jB)),
      ],
    );
  }

  Widget _statRow(String label, String valA, String valB, int cmp) {
    final aColor = cmp > 0 ? green : (cmp < 0 ? muted : dim);
    final bColor = cmp < 0 ? green : (cmp > 0 ? muted : dim);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(radiusMd),
          border: Border.all(color: border)),
      child: Row(children: [
        Expanded(
            child: Text(valA,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: aColor))),
        Text(label,
            style: const TextStyle(
                fontSize: 9,
                color: muted,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w500)),
        Expanded(
            child: Text(valB,
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: bColor))),
      ]),
    );
  }

  Widget _errBox(String msg) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: const Color(0xFF1A0F0F),
            borderRadius: BorderRadius.circular(radiusMd),
            border: Border.all(color: const Color(0xFF3A1A1A))),
        child: Row(children: [
          const Icon(Icons.error_outline_rounded, color: red, size: 16),
          const SizedBox(width: 8),
          Expanded(
              child: Text(msg,
                  style: const TextStyle(fontSize: 12, color: red))),
        ]),
      );
}
