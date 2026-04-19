import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../services/api_service.dart';
import '../widgets/comparar_sheet.dart';

class RankingTab extends StatefulWidget {
  final String token;
  final String userName;
  final VoidCallback onLogout;
  final Function(Map<String, dynamic>) onEditarJornada;

  const RankingTab({
    super.key,
    required this.token,
    required this.userName,
    required this.onLogout,
    required this.onEditarJornada,
  });

  @override
  State<RankingTab> createState() => RankingTabState();
}

class RankingTabState extends State<RankingTab> {
  String _periodo = 'mes';
  List<dynamic> _ranking   = [];
  List<dynamic> _jornadas  = [];
  bool _loadingRanking  = false;
  bool _loadingJornadas = false;
  String? _errorRanking;
  String? _errorJornadas;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    await Future.wait([_loadRanking(), _loadJornadas()]);
  }

  Future<void> _loadRanking() async {
    if (!mounted) return;
    setState(() {
      _loadingRanking = true;
      _errorRanking = null;
    });
    try {
      final data = await api.ranking(widget.token, _periodo);
      if (mounted) setState(() {
        _ranking = data;
        _loadingRanking = false;
      });
    } on UnauthorizedException {
      widget.onLogout();
    } on ApiException catch (e) {
      if (mounted) setState(() {
        _errorRanking = e.message;
        _loadingRanking = false;
      });
    } catch (_) {
      if (mounted) setState(() {
        _errorRanking = 'Sem conexão com o servidor';
        _loadingRanking = false;
      });
    }
  }

  Future<void> _loadJornadas() async {
    if (!mounted) return;
    setState(() {
      _loadingJornadas = true;
      _errorJornadas = null;
    });
    try {
      final data = await api.minhasJornadas(widget.token);
      if (mounted) setState(() {
        _jornadas = data;
        _loadingJornadas = false;
      });
    } on UnauthorizedException {
      widget.onLogout();
    } on ApiException catch (e) {
      if (mounted) setState(() {
        _errorJornadas = e.message;
        _loadingJornadas = false;
      });
    } catch (_) {
      if (mounted) setState(() {
        _errorJornadas = 'Sem conexão com o servidor';
        _loadingJornadas = false;
      });
    }
  }

  String _fmt(double v) {
    final s = v.abs().toStringAsFixed(2);
    final pts = s.split('.');
    final buf = StringBuffer();
    for (int i = 0; i < pts[0].length; i++) {
      if (i > 0 && (pts[0].length - i) % 3 == 0) buf.write('.');
      buf.write(pts[0][i]);
    }
    return 'R\$ $buf,${pts[1]}';
  }

  String _fmtDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: border)),
        title: const Text('RANKING',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.5,
                color: muted)),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        color: blue,
        backgroundColor: surface,
        onRefresh: refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _filtros(),
              const SizedBox(height: 14),
              _rankingSection(),
              const SizedBox(height: 20),
              _jornadasSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filtros() {
    final opcoes = [
      ('dia', 'Hoje'),
      ('semana', 'Semana'),
      ('mes', 'Mês'),
      ('geral', 'Geral'),
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
          final selected = _periodo == o.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _periodo = o.$1;
                  _ranking = [];
                });
                _loadRanking();
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

  Widget _rankingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
              width: 3,
              height: 13,
              decoration: BoxDecoration(
                  color: gold, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          const Text('RANKING',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: dim,
                  letterSpacing: 1.2)),
        ]),
        const SizedBox(height: 10),
        if (_loadingRanking)
          _skeletonList(3)
        else if (_errorRanking != null)
          _errBox(_errorRanking!)
        else if (_ranking.isEmpty)
          _emptyBox(
            icon: Icons.leaderboard_rounded,
            title: 'Nenhum dado no período',
            subtitle: 'Ainda não há corridas registradas\npara o filtro selecionado.',
          )
        else
          for (int i = 0; i < _ranking.length; i++) _rankRow(i, _ranking[i]),
      ],
    );
  }

  Widget _rankRow(int idx, Map<String, dynamic> r) {
    final nome = r['usuario_nome'] as String? ?? '';
    final fat  = (r['total_faturamento'] as num?)?.toDouble() ?? 0;
    final km   = (r['total_km'] as num?)?.toDouble() ?? 0;
    final h    = (r['total_horas'] as num?)?.toDouble() ?? 0;
    final gKm  = (r['ganho_km'] as num?)?.toDouble() ?? 0;
    final gH   = (r['ganho_hora'] as num?)?.toDouble() ?? 0;
    final jorn = (r['total_jornadas'] as num?)?.toInt() ?? 0;
    final isMe = nome.toLowerCase() == widget.userName.toLowerCase();

    final medalColor = idx == 0 ? gold : idx == 1 ? silver : idx == 2 ? bronze : muted;
    final medalIcon = idx == 0
        ? Icons.emoji_events_rounded
        : idx <= 2
            ? Icons.military_tech_rounded
            : null;

    final card = IntrinsicHeight(
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF0D1829) : surface,
          borderRadius: BorderRadius.circular(radiusMd),
          border: Border.all(
              color: isMe ? const Color(0xFF1A3050) : border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isMe)
              Container(
                  width: 3,
                  decoration: const BoxDecoration(
                      color: blue,
                      borderRadius: BorderRadius.horizontal(
                          left: Radius.circular(10)))),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  SizedBox(
                    width: 28,
                    child: medalIcon != null
                        ? Icon(medalIcon, color: medalColor, size: 20)
                        : Text('${idx + 1}',
                            style: TextStyle(
                                fontSize: 12,
                                color: medalColor,
                                fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(nome,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: txt,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(
                            '$jorn jornada${jorn != 1 ? 's' : ''}'
                            '${km > 0 ? '  ·  ${km.toStringAsFixed(0)} km' : ''}'
                            '${h > 0 ? '  ·  ${h.toStringAsFixed(1)}h' : ''}',
                            style: const TextStyle(
                                fontSize: 10, color: muted)),
                          if (gKm > 0 || gH > 0) ...[
                            const SizedBox(height: 2),
                            Text(
                              [
                                if (gKm > 0) '${_fmt(gKm)}/km',
                                if (gH > 0) '${_fmt(gH)}/h',
                              ].join('  ·  '),
                              style: const TextStyle(
                                  fontSize: 10, color: blue)),
                          ],
                        ]),
                  ),
                  Text(_fmt(fat),
                      style: const TextStyle(
                          fontSize: 14,
                          color: green,
                          fontWeight: FontWeight.w700)),
                  if (!isMe) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.compare_arrows_rounded,
                        size: 14, color: muted),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );

    if (isMe) return card;
    return GestureDetector(onTap: () => _comparar(nome), child: card);
  }

  Future<void> _comparar(String otherName) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => CompararSheet(
        token: widget.token,
        myName: widget.userName,
        otherName: otherName,
      ),
    );
  }

  Widget _jornadasSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
              width: 3,
              height: 13,
              decoration: BoxDecoration(
                  color: blue, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          const Text('MINHAS JORNADAS',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: dim,
                  letterSpacing: 1.2)),
        ]),
        const SizedBox(height: 10),
        if (_loadingJornadas)
          _skeletonList(3)
        else if (_errorJornadas != null)
          _errBox(_errorJornadas!)
        else if (_jornadas.isEmpty)
          _emptyBox(
            icon: Icons.calendar_today_rounded,
            title: 'Nenhuma jornada ainda',
            subtitle: 'Feche o seu primeiro dia\nna aba Calculadora.',
          )
        else
          for (final j in _jornadas) _jornadaRow(j),
      ],
    );
  }

  Widget _jornadaRow(Map<String, dynamic> j) {
    final id   = j['id'] as String? ?? '';
    final data = j['data'] as String? ?? '';
    final fat  = (j['faturamento'] as num?)?.toDouble() ?? 0;
    final km   = (j['km'] as num?)?.toDouble() ?? 0;
    final h    = (j['horas'] as num?)?.toDouble() ?? 0;

    return Dismissible(
      key: ValueKey(id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmarDelete(),
      onDismissed: (_) => _deletarJornada(id),
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
            color: red.withOpacity(0.85),
            borderRadius: BorderRadius.circular(radiusMd)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
          SizedBox(height: 3),
          Text('EXCLUIR',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1)),
        ]),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(radiusMd),
            border: Border.all(color: border)),
        child: InkWell(
          borderRadius: BorderRadius.circular(radiusMd),
          onTap: () => widget.onEditarJornada(j),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(_fmtDate(data),
                        style: const TextStyle(
                            fontSize: 13,
                            color: txt,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (km > 0) '${km.toStringAsFixed(0)} km',
                        if (h > 0) '${h.toStringAsFixed(1)}h',
                      ].join('  ·  '),
                      style: const TextStyle(fontSize: 11, color: muted),
                    ),
                  ])),
              Text(_fmt(fat),
                  style: const TextStyle(
                      fontSize: 14,
                      color: green,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              const Icon(Icons.edit_outlined, size: 15, color: muted),
            ]),
          ),
        ),
      ),
    );
  }

  Future<bool?> _confirmarDelete() => showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusLg)),
          title: const Text('Excluir jornada?',
              style: TextStyle(
                  color: txt,
                  fontWeight: FontWeight.w600,
                  fontSize: 16)),
          content: const Text('Esta ação não pode ser desfeita.',
              style: TextStyle(color: dim, fontSize: 14)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child:
                    const Text('CANCELAR', style: TextStyle(color: muted))),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('EXCLUIR',
                    style: TextStyle(
                        color: red, fontWeight: FontWeight.w700))),
          ],
        ),
      );

  Future<void> _deletarJornada(String id) async {
    try {
      await api.deletarJornada(widget.token, id);
      if (mounted) {
        setState(() => _jornadas.removeWhere((j) => j['id'] == id));
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: surface));
      refresh();
    }
  }

  Widget _skeletonList(int count) => Column(
        children: List.generate(
          count,
          (_) => Container(
            height: 64,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(radiusMd),
              border: Border.all(color: border),
            ),
          ),
        ),
      );

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

  Widget _emptyBox({
    required IconData icon,
    required String title,
    String? subtitle,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
        decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(radiusMd),
            border: Border.all(color: border)),
        child: Column(children: [
          Icon(icon, size: 30, color: muted),
          const SizedBox(height: 10),
          Text(title,
              style: const TextStyle(
                  fontSize: 13,
                  color: dim,
                  fontWeight: FontWeight.w600)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 11, color: muted, height: 1.5)),
          ],
        ]),
      );
}
