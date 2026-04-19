import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../services/api_service.dart';
import '../utils/time_formatter.dart';
import '../widgets/fechar_dia_sheet.dart';

class CalculadoraTab extends StatefulWidget {
  final String token;
  final String userName;
  final VoidCallback onLogout;
  final VoidCallback onJornadaSalva;

  const CalculadoraTab({
    super.key,
    required this.token,
    required this.userName,
    required this.onLogout,
    required this.onJornadaSalva,
  });

  @override
  State<CalculadoraTab> createState() => CalculadoraTabState();
}

class CalculadoraTabState extends State<CalculadoraTab> {
  final _ctrlMeta = TextEditingController();

  List<TextEditingController> _nomesCtrl      = [];
  List<TextEditingController> _valoresCtrl    = [];
  List<TextEditingController> _abatimentoCtrl = [];
  List<TextEditingController> _kmCtrl         = [];
  List<TextEditingController> _horasCtrl      = [];

  bool _pronto = false;
  String? _editandoId;
  String  _editandoData = '';

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final p = await SharedPreferences.getInstance();
    final nomes       = p.getStringList('nomes')       ?? ['Uber', '99', 'inDrive'];
    final valores     = p.getStringList('valores')     ?? List.filled(nomes.length, '');
    final abatimentos = p.getStringList('abatimentos') ?? [''];
    final kmList      = p.getStringList('km_list')     ?? [''];
    final horasList   = p.getStringList('horas_list')  ?? [''];
    setState(() {
      _ctrlMeta.text  = p.getString('meta') ?? '';
      _nomesCtrl      = nomes.map(_makeCtrl).toList();
      _valoresCtrl    = valores.map(_makeCtrl).toList();
      _abatimentoCtrl = abatimentos.map(_makeCtrl).toList();
      _kmCtrl         = kmList.map(_makeCtrl).toList();
      _horasCtrl      = horasList.map(_makeCtrl).toList();
      _pronto = true;
    });
    _ctrlMeta.addListener(_onChange);
  }

  TextEditingController _makeCtrl(String text) {
    final c = TextEditingController(text: text);
    c.addListener(_onChange);
    return c;
  }

  void _onChange() {
    if (!_pronto) return;
    setState(() {});
    _salvar();
  }

  Future<void> _salvar() async {
    if (!_pronto) return;
    final p = await SharedPreferences.getInstance();
    p.setString('meta', _ctrlMeta.text);
    p.setStringList('nomes',       _nomesCtrl.map((c) => c.text).toList());
    p.setStringList('valores',     _valoresCtrl.map((c) => c.text).toList());
    p.setStringList('abatimentos', _abatimentoCtrl.map((c) => c.text).toList());
    p.setStringList('km_list',     _kmCtrl.map((c) => c.text).toList());
    p.setStringList('horas_list',  _horasCtrl.map((c) => c.text).toList());
  }

  @override
  void dispose() {
    for (final c in [
      _ctrlMeta, ..._nomesCtrl, ..._valoresCtrl,
      ..._abatimentoCtrl, ..._kmCtrl, ..._horasCtrl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Cálculos ────────────────────────────────────────────────────────────────
  double _p(String s) => double.tryParse(s.replaceAll(',', '.')) ?? 0;
  double get meta       => _p(_ctrlMeta.text);
  double get somaApps   => _valoresCtrl.fold(0.0, (s, c) => s + _p(c.text));
  double get abatimento => _abatimentoCtrl.fold(0.0, (s, c) => s + _p(c.text));
  double get total      => somaApps - abatimento;
  double get falta      => (meta > 0 && total < meta) ? meta - total : 0;
  double get pctMeta    => meta > 0 ? (total / meta) * 100 : 0;
  double get km => _kmCtrl.fold(0.0, (s, c) => s + _p(c.text));
  double get horas => _horasCtrl.fold(0.0, (s, c) {
    final t = c.text.trim();
    if (t.contains(':')) {
      final pts = t.split(':');
      return s + _p(pts[0]) + (pts.length > 1 ? _p(pts[1]) / 60.0 : 0);
    }
    return s + _p(t);
  });
  double get porKm   => km    > 0 ? total / km    : 0;
  double get porHora => horas > 0 ? total / horas : 0;

  // ── Formatação ──────────────────────────────────────────────────────────────
  String fmt(double v) {
    final sign = v < 0 ? '-' : '';
    final s = v.abs().toStringAsFixed(2);
    final pts = s.split('.');
    final buf = StringBuffer();
    for (int i = 0; i < pts[0].length; i++) {
      if (i > 0 && (pts[0].length - i) % 3 == 0) buf.write('.');
      buf.write(pts[0][i]);
    }
    return '${sign}R\$ $buf,${pts[1]}';
  }

  String _pct(double v) =>
      '${v.toStringAsFixed(1).replaceAll('.', ',')}%';

  String fmtHoras(double h) {
    final hI = h.floor();
    final mI = ((h - hI) * 60).round();
    return '$hI:${mI.toString().padLeft(2, '0')}h';
  }

  // ── Add/Remove ──────────────────────────────────────────────────────────────
  void _addApp() => setState(() {
        _nomesCtrl.add(_makeCtrl(''));
        _valoresCtrl.add(_makeCtrl(''));
      });

  void _removeApp(int i) {
    _nomesCtrl[i].dispose();
    _valoresCtrl[i].dispose();
    setState(() {
      _nomesCtrl.removeAt(i);
      _valoresCtrl.removeAt(i);
    });
    _salvar();
  }

  void _addAbatimento() =>
      setState(() => _abatimentoCtrl.add(_makeCtrl('')));

  void _removeAbatimento(int i) {
    if (_abatimentoCtrl.length <= 1) {
      _abatimentoCtrl[0].text = '';
      return;
    }
    _abatimentoCtrl[i].dispose();
    setState(() => _abatimentoCtrl.removeAt(i));
    _salvar();
  }

  void _addKm() => setState(() => _kmCtrl.add(_makeCtrl('')));

  void _removeKm(int i) {
    if (_kmCtrl.length <= 1) {
      _kmCtrl[0].text = '';
      return;
    }
    _kmCtrl[i].dispose();
    setState(() => _kmCtrl.removeAt(i));
    _salvar();
  }

  void _addHora() => setState(() => _horasCtrl.add(_makeCtrl('')));

  void _removeHora(int i) {
    if (_horasCtrl.length <= 1) {
      _horasCtrl[0].text = '';
      return;
    }
    _horasCtrl[i].dispose();
    setState(() => _horasCtrl.removeAt(i));
    _salvar();
  }

  // ── Reset ───────────────────────────────────────────────────────────────────
  Future<void> _confirmarReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Zerar o dia?',
            style: TextStyle(
                color: txt, fontWeight: FontWeight.w600, fontSize: 16)),
        content: const Text(
            'Todos os valores serão zerados.\nOs nomes dos apps são mantidos.',
            style: TextStyle(color: dim, fontSize: 14, height: 1.5)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCELAR',
                  style: TextStyle(color: muted, fontSize: 13))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('ZERAR',
                  style: TextStyle(
                      color: red,
                      fontSize: 13,
                      fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (ok == true) {
      setState(() {
        _ctrlMeta.text = '';
        for (final c in _valoresCtrl) c.text = '';
        for (final c in _abatimentoCtrl) c.text = '';
        for (final c in _kmCtrl) c.text = '';
        for (final c in _horasCtrl) c.text = '';
      });
      _salvar();
    }
  }

  // ── Carregar Jornada para Edição ────────────────────────────────────────────
  void carregarJornada(Map<String, dynamic> j) {
    for (final c in [
      ..._nomesCtrl, ..._valoresCtrl, ..._abatimentoCtrl,
      ..._kmCtrl, ..._horasCtrl
    ]) {
      c.removeListener(_onChange);
      c.dispose();
    }

    final appsRaw = j['apps_json'] as String? ?? '[]';
    List<dynamic> apps = [];
    try {
      apps = jsonDecode(appsRaw) as List;
    } catch (_) {}

    List<TextEditingController> nomes, valores;
    if (apps.isEmpty) {
      final fat = (j['faturamento'] as num?)?.toDouble() ?? 0;
      nomes  = [_makeCtrl('')];
      valores = [
        _makeCtrl(fat > 0 ? fat.toStringAsFixed(2).replaceAll('.', ',') : '')
      ];
    } else {
      nomes = apps
          .map<TextEditingController>(
              (a) => _makeCtrl(a['nome'] as String? ?? ''))
          .toList();
      valores = apps.map<TextEditingController>((a) {
        final v = (a['valor'] as num?)?.toDouble() ?? 0;
        return _makeCtrl(
            v > 0 ? v.toStringAsFixed(2).replaceAll('.', ',') : '');
      }).toList();
    }

    final kmRaw = j['km_json'] as String? ?? '[]';
    List<dynamic> kmList = [];
    try {
      kmList = jsonDecode(kmRaw) as List;
    } catch (_) {}
    List<TextEditingController> kmCtrls;
    if (kmList.isEmpty) {
      final d = (j['km'] as num?)?.toDouble() ?? 0;
      kmCtrls = [
        _makeCtrl(d > 0
            ? (d % 1 == 0 ? d.toInt().toString() : d.toStringAsFixed(1))
            : '')
      ];
    } else {
      kmCtrls = kmList.map<TextEditingController>((v) {
        final d = (v as num?)?.toDouble() ?? 0;
        return _makeCtrl(d > 0
            ? (d % 1 == 0 ? d.toInt().toString() : d.toStringAsFixed(1))
            : '');
      }).toList();
    }

    final horasRaw = j['horas_json'] as String? ?? '[]';
    List<dynamic> horasList = [];
    try {
      horasList = jsonDecode(horasRaw) as List;
    } catch (_) {}
    List<TextEditingController> horasCtrls;
    if (horasList.isEmpty) {
      final hVal = (j['horas'] as num?)?.toDouble() ?? 0;
      String ht = '';
      if (hVal > 0) {
        final hI = hVal.floor();
        final mI = ((hVal - hI) * 60).round();
        ht = '${hI.toString().padLeft(2, "0")}:${mI.toString().padLeft(2, "0")}';
      }
      horasCtrls = [_makeCtrl(ht)];
    } else {
      horasCtrls = horasList.map<TextEditingController>((v) {
        final h = (v as num?)?.toDouble() ?? 0;
        if (h <= 0) return _makeCtrl('');
        final hI = h.floor();
        final mI = ((h - hI) * 60).round();
        return _makeCtrl(
            '${hI.toString().padLeft(2, "0")}:${mI.toString().padLeft(2, "0")}');
      }).toList();
    }

    setState(() {
      _nomesCtrl      = nomes;
      _valoresCtrl    = valores;
      _abatimentoCtrl = () {
        final somaApps = valores.fold(0.0, (s, c) {
          return s + (double.tryParse(c.text.replaceAll(',', '.')) ?? 0);
        });
        final fat = (j['faturamento'] as num?)?.toDouble() ?? 0;
        final desconto = somaApps - fat;
        if (desconto > 0.001) {
          return [
            _makeCtrl(desconto.toStringAsFixed(2).replaceAll('.', ','))
          ];
        }
        return [_makeCtrl('')];
      }();
      _kmCtrl         = kmCtrls;
      _horasCtrl      = horasCtrls;
      _editandoId     = j['id'] as String?;
      _editandoData   = j['data'] as String? ?? '';
    });
  }

  void _cancelarEdicao() {
    setState(() {
      _editandoId   = null;
      _editandoData = '';
      for (final c in [
        ..._valoresCtrl, ..._abatimentoCtrl, ..._kmCtrl, ..._horasCtrl
      ]) c.text = '';
    });
    _salvar();
  }

  Future<void> _fecharDia() async {
    if (total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Adicione um valor de faturamento antes de fechar o dia'),
          backgroundColor: surface,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final appsJson = jsonEncode(List.generate(
      _nomesCtrl.length,
      (i) => {'nome': _nomesCtrl[i].text, 'valor': _p(_valoresCtrl[i].text)},
    ));
    final kmJson =
        jsonEncode(_kmCtrl.map((c) => _p(c.text)).toList());
    final horasJson = jsonEncode(_horasCtrl.map((c) {
      final t = c.text.trim();
      if (t.contains(':')) {
        final pts = t.split(':');
        return _p(pts[0]) + (pts.length > 1 ? _p(pts[1]) / 60.0 : 0);
      }
      return _p(t);
    }).toList());

    if (_editandoId != null) {
      try {
        await api.editarJornada(widget.token, _editandoId!, {
          'km': km,
          'horas': horas,
          'faturamento': total,
          'ganho_por_km': porKm,
          'ganho_por_hora': porHora,
          'apps_json': appsJson,
          'km_json': kmJson,
          'horas_json': horasJson,
        });
        setState(() {
          _editandoId   = null;
          _editandoData = '';
        });
        widget.onJornadaSalva();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Jornada atualizada com sucesso!',
                style: TextStyle(color: green, fontWeight: FontWeight.w600)),
            backgroundColor: surface,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar: $e'),
            backgroundColor: red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final saved = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => FecharDiaSheet(
        token: widget.token,
        total: total,
        km: km,
        horas: horas,
        porKm: porKm,
        porHora: porHora,
        appsJson: appsJson,
        kmJson: kmJson,
        horasJson: horasJson,
        fmtFn: fmt,
        fmtHorasFn: fmtHoras,
      ),
    );

    if (saved == true) {
      widget.onJornadaSalva();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Jornada salva com sucesso!',
              style: TextStyle(color: green, fontWeight: FontWeight.w600)),
          backgroundColor: surface,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _skeletonBox(double height) => Container(
        width: double.infinity,
        height: height,
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(radiusLg),
          border: Border.all(color: border),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (!_pronto) {
      return Scaffold(
        backgroundColor: bg,
        body: Padding(
          padding: const EdgeInsets.fromLTRB(12, 60, 12, 16),
          child: Column(children: [
            _skeletonBox(130),
            _skeletonBox(110),
            _skeletonBox(100),
            _skeletonBox(60),
          ]),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: border),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('MOTORISTA',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.5,
                    color: muted)),
            Text(widget.userName,
                style: const TextStyle(
                    fontSize: 11, color: dim, letterSpacing: 0.2)),
          ],
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh_rounded, color: dim, size: 22),
              tooltip: 'Zerar o dia',
              onPressed: _confirmarReset),
          IconButton(
              icon: const Icon(Icons.logout_rounded, color: dim, size: 22),
              tooltip: 'Sair',
              onPressed: widget.onLogout),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
        child: Column(
          children: [
            _heroTotal(),
            const SizedBox(height: 6),
            _cardFaturamento(),
            const SizedBox(height: 6),
            _cardIndicadores(),
            const SizedBox(height: 6),
            _cardMeta(),
            const SizedBox(height: 6),
            _cardAbatimento(),
            const SizedBox(height: 12),
            _btnFecharDia(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _btnFecharDia() {
    final isEditing = _editandoId != null;
    return Column(
      children: [
        if (isEditing) ...[
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2A3A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: blue.withOpacity(0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.edit_rounded, size: 13, color: blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Editando jornada de ${_editandoData.length == 10 ? "${_editandoData.substring(8, 10)}/${_editandoData.substring(5, 7)}/${_editandoData.substring(0, 4)}" : _editandoData}',
                  style: const TextStyle(fontSize: 11, color: blue),
                ),
              ),
              GestureDetector(
                onTap: _cancelarEdicao,
                child: const Text('Cancelar',
                    style: TextStyle(
                        fontSize: 11,
                        color: red,
                        fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
        ],
        Container(
          width: double.infinity,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: green.withOpacity(0.35),
                blurRadius: 16,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: _fecharDia,
            icon: Icon(
                isEditing ? Icons.check_rounded : Icons.flag_rounded,
                size: 18),
            label: Text(
              isEditing ? 'SALVAR' : 'CONCLUIR DIA',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: green,
              foregroundColor: Colors.black,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _heroTotal() {
    final cor = total < 0
        ? red
        : (meta > 0 && total >= meta) ? green : txt;
    final progress =
        meta > 0 ? (pctMeta / 100).clamp(0.0, 1.0) : 0.0;
    final barColor = pctMeta >= 100
        ? const Color(0xFF10B981)
        : pctMeta >= 90
            ? const Color(0xFF22C55E)
            : pctMeta >= 80
                ? const Color(0xFF4ADE80)
                : pctMeta >= 70
                    ? const Color(0xFF84CC16)
                    : pctMeta >= 60
                        ? const Color(0xFFBEF264)
                        : pctMeta >= 50
                            ? const Color(0xFFEAB308)
                            : pctMeta >= 40
                                ? const Color(0xFFFBBF24)
                                : pctMeta >= 30
                                    ? const Color(0xFFF97316)
                                    : pctMeta >= 20
                                        ? const Color(0xFFEF4444)
                                        : const Color(0xFFDC2626);

    return _box(
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('FATURAMENTO TOTAL',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: dim,
                letterSpacing: 1.5)),
        const SizedBox(height: 6),
        Text(fmt(total),
            style: TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.w700,
                letterSpacing: -2.0,
                color: cor,
                height: 1.0)),
        if (km > 0 || horas > 0) ...[
          const SizedBox(height: 8),
          Row(children: [
            if (km > 0) ...[
              const Icon(Icons.route_rounded, size: 12, color: dim),
              const SizedBox(width: 4),
              Text('${fmt(porKm)}/km',
                  style: const TextStyle(
                      fontSize: 12,
                      color: blue,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 16),
            ],
            if (horas > 0) ...[
              const Icon(Icons.access_time_rounded, size: 12, color: dim),
              const SizedBox(width: 4),
              Text('${fmt(porHora)}/h',
                  style: const TextStyle(
                      fontSize: 12,
                      color: blue,
                      fontWeight: FontWeight.w600)),
            ],
          ]),
        ],
        if (meta > 0) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
                value: progress,
                backgroundColor: border,
                color: barColor,
                minHeight: 4),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                  falta > 0
                      ? 'Falta ${fmt(falta)} para a meta'
                      : 'Meta atingida!',
                  style: TextStyle(
                      fontSize: 12,
                      color: falta > 0 ? dim : green,
                      fontWeight: FontWeight.w500)),
              Text(_pct(pctMeta),
                  style: TextStyle(
                      fontSize: 12,
                      color: barColor,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ],
    ));
  }

  Widget _cardFaturamento() => _box(
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _secHeader('FATURAMENTO', blue),
          const SizedBox(height: 8),
          for (int i = 0; i < _nomesCtrl.length; i++) _appRow(i),
          const SizedBox(height: 4),
          _addBtn('ADICIONAR APP', _addApp, blue),
        ],
      ));

  Widget _cardIndicadores() => _box(
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _secHeader('INDICADORES', green),
          const SizedBox(height: 10),
          Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('KM RODADOS',
                    style: TextStyle(
                        fontSize: 11,
                        color: dim,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0)),
                if (km > 0)
                  Text(
                    '${km % 1 == 0 ? km.toInt() : km.toStringAsFixed(1)} km  •  ${fmt(porKm)}/km',
                    style: const TextStyle(fontSize: 11, color: muted)),
              ]),
          const SizedBox(height: 6),
          for (int i = 0; i < _kmCtrl.length; i++)
            _simpleRow(_kmCtrl[i], '0', () => _removeKm(i)),
          _addBtn('ADICIONAR KM', _addKm, green),
          const SizedBox(height: 12),
          Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('HORAS TRABALHADAS',
                    style: TextStyle(
                        fontSize: 11,
                        color: dim,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0)),
                if (horas > 0)
                  Text(
                    '${fmtHoras(horas)}  •  ${fmt(porHora)}/h',
                    style: const TextStyle(fontSize: 11, color: muted)),
              ]),
          const SizedBox(height: 6),
          for (int i = 0; i < _horasCtrl.length; i++)
            _horaRow(_horasCtrl[i], () => _removeHora(i)),
          _addBtn('ADICIONAR HORA', _addHora, green),
        ],
      ));

  Widget _cardMeta() => _box(
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _secHeader('META', red),
          const SizedBox(height: 8),
          _inputRow('Meta diária (R\$)', _ctrlMeta),
        ],
      ));

  Widget _cardAbatimento() => _box(
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _secHeader('DESCONTOS', orange),
            if (abatimento > 0)
              Text('- ${fmt(abatimento)}',
                  style: const TextStyle(fontSize: 11, color: muted)),
          ]),
          const SizedBox(height: 8),
          for (int i = 0; i < _abatimentoCtrl.length; i++)
            _simpleRow(
                _abatimentoCtrl[i], '0,00', () => _removeAbatimento(i)),
          _addBtn('ADICIONAR DESCONTO', _addAbatimento, orange),
        ],
      ));

  Widget _box({required Widget child}) => Container(
        width: double.infinity,
        decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border)),
        padding: const EdgeInsets.all(12),
        child: child,
      );

  Widget _secHeader(String titulo, Color cor) => Row(children: [
        Container(
            width: 3,
            height: 13,
            decoration: BoxDecoration(
                color: cor, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(titulo,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: dim,
                letterSpacing: 1.2)),
      ]);

  Widget _appRow(int i) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Expanded(
              flex: 4,
              child: _textField(ctrl: _nomesCtrl[i], hint: 'Nome do app')),
          const SizedBox(width: 8),
          Expanded(
              flex: 3,
              child: _numField(ctrl: _valoresCtrl[i], hint: '0,00')),
          const SizedBox(width: 4),
          GestureDetector(
              onTap: () => _removeApp(i),
              child: const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.remove_circle_outline_rounded,
                      color: red, size: 20))),
        ]),
      );

  Widget _simpleRow(TextEditingController ctrl, String hint,
          VoidCallback onRemove) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Expanded(
              child: _numField(
                  ctrl: ctrl, hint: hint, align: TextAlign.left)),
          const SizedBox(width: 4),
          GestureDetector(
              onTap: onRemove,
              child: const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.remove_circle_outline_rounded,
                      color: red, size: 20))),
        ]),
      );

  Widget _horaRow(
          TextEditingController ctrl, VoidCallback onRemove) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Expanded(
              child: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.left,
            inputFormatters: [TimeFormatter()],
            style: const TextStyle(fontSize: 13, color: txt),
            decoration: _dec('0:00'),
            onTap: () => ctrl.selection =
                TextSelection(baseOffset: 0, extentOffset: ctrl.text.length),
          )),
          const SizedBox(width: 4),
          GestureDetector(
              onTap: onRemove,
              child: const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.remove_circle_outline_rounded,
                      color: red, size: 20))),
        ]),
      );

  Widget _addBtn(String label, VoidCallback onTap, Color cor) => Center(
        child: TextButton.icon(
          onPressed: onTap,
          icon: Icon(Icons.add_rounded, size: 15, color: cor),
          label: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: cor,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5)),
          style: TextButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero),
        ),
      );

  Widget _inputRow(String label, TextEditingController ctrl) => Row(children: [
        Expanded(
            flex: 3,
            child: Text(label, style: const TextStyle(fontSize: 13, color: dim))),
        Expanded(
            flex: 2,
            child: _numField(
                ctrl: ctrl, hint: '0,00', align: TextAlign.right)),
      ]);

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(fontSize: 13, color: Color(0xFF3F3F46)),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: blue, width: 1.5)),
        filled: true,
        fillColor: const Color(0xFF111112),
      );

  Widget _numField(
          {required TextEditingController ctrl,
          String hint = '0',
          TextAlign align = TextAlign.right}) =>
      TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: align,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))
        ],
        style: const TextStyle(fontSize: 13, color: txt),
        decoration: _dec(hint),
        onTap: () => ctrl.selection =
            TextSelection(baseOffset: 0, extentOffset: ctrl.text.length),
      );

  Widget _textField(
          {required TextEditingController ctrl, String hint = ''}) =>
      TextField(
          controller: ctrl,
          style: const TextStyle(fontSize: 13, color: txt),
          decoration: _dec(hint));
}
