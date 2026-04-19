import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// ── Config ────────────────────────────────────────────────────────────────────
// Troque pela URL do seu servidor em produção
const _apiBase = 'https://ricardoparrillo-calculadora-motorista-api.hf.space';

// ── Palette ───────────────────────────────────────────────────────────────────
const _bg      = Color(0xFF0D0D0E);
const _surface = Color(0xFF161617);
const _border  = Color(0xFF242425);
const _dim     = Color(0xFF71717A);
const _muted   = Color(0xFF52525B);
const _txt     = Color(0xFFF4F4F5);
const _blue    = Color(0xFF3B82F6);
const _green   = Color(0xFF22C55E);
const _red     = Color(0xFFEF4444);
const _orange  = Color(0xFFF97316);
const _gold    = Color(0xFFFFAE00);
const _silver  = Color(0xFF94A3B8);
const _bronze  = Color(0xFFCD7F32);

// ── API Service ───────────────────────────────────────────────────────────────

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
}

class UnauthorizedException implements Exception {}

class ApiService {
  Map<String, String> _h([String? token]) => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  Future<Map<String, dynamic>> register(String nome, String pin) async {
    final r = await http.post(Uri.parse('$_apiBase/auth/register'),
        headers: _h(), body: jsonEncode({'nome': nome, 'pin': pin}));
    final d = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode != 200) throw ApiException(d['detail'] ?? 'Erro ao cadastrar');
    return d;
  }

  Future<Map<String, dynamic>> login(String nome, String pin) async {
    final r = await http.post(Uri.parse('$_apiBase/auth/login'),
        headers: _h(), body: jsonEncode({'nome': nome, 'pin': pin}));
    final d = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode != 200) throw ApiException(d['detail'] ?? 'Nome ou PIN incorreto');
    return d;
  }

  void _check401(http.Response r) {
    if (r.statusCode == 401) throw UnauthorizedException();
  }

  Future<void> salvarJornada(String token, Map<String, dynamic> data) async {
    final r = await http.post(Uri.parse('$_apiBase/jornadas'),
        headers: _h(token), body: jsonEncode(data));
    _check401(r);
    if (r.statusCode != 200) {
      final d = jsonDecode(r.body) as Map<String, dynamic>;
      throw ApiException(d['detail'] ?? 'Erro ao salvar');
    }
  }

  Future<List<dynamic>> minhasJornadas(String token) async {
    final r = await http.get(Uri.parse('$_apiBase/jornadas/minhas'), headers: _h(token));
    _check401(r);
    if (r.statusCode != 200) throw ApiException('Erro ao carregar jornadas');
    return jsonDecode(r.body) as List;
  }

  Future<void> editarJornada(String token, String id, Map<String, dynamic> data) async {
    final r = await http.put(Uri.parse('$_apiBase/jornadas/$id'),
        headers: _h(token), body: jsonEncode(data));
    _check401(r);
    if (r.statusCode != 200) {
      final d = jsonDecode(r.body) as Map<String, dynamic>;
      throw ApiException(d['detail'] ?? 'Erro ao editar');
    }
  }

  Future<void> deletarJornada(String token, String id) async {
    final r = await http.delete(Uri.parse('$_apiBase/jornadas/$id'), headers: _h(token));
    _check401(r);
    if (r.statusCode != 200) throw ApiException('Erro ao deletar');
  }

  Future<List<dynamic>> ranking(String token, String periodo) async {
    final r = await http.get(Uri.parse('$_apiBase/ranking?periodo=$periodo'), headers: _h(token));
    _check401(r);
    if (r.statusCode != 200) throw ApiException('Erro ao carregar ranking');
    return jsonDecode(r.body) as List;
  }

  Future<Map<String, dynamic>> comparar(
      String token, String userA, String userB, String desde, String ate) async {
    final url = Uri.parse('$_apiBase/comparar').replace(queryParameters: {
      'usuario_a': userA, 'usuario_b': userB, 'desde': desde, 'ate': ate,
    });
    final r = await http.get(url, headers: _h(token));
    _check401(r);
    if (r.statusCode != 200) throw ApiException('Erro ao carregar comparação');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }
}

final _api = ApiService();

// ── App Root ──────────────────────────────────────────────────────────────────

void main() => runApp(const CalculadoraApp());

class CalculadoraApp extends StatefulWidget {
  const CalculadoraApp({super.key});
  @override
  State<CalculadoraApp> createState() => _CalculadoraAppState();
}

class _CalculadoraAppState extends State<CalculadoraApp> {
  String? _token;
  String? _userName;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _token     = p.getString('auth_token');
      _userName  = p.getString('auth_nome');
      _checking  = false;
    });
  }

  void _onLogin(String token, String nome) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('auth_token', token);
    await p.setString('auth_nome', nome);
    setState(() { _token = token; _userName = nome; });
  }

  void _onLogout() async {
    final p = await SharedPreferences.getInstance();
    await p.remove('auth_token');
    await p.remove('auth_nome');
    setState(() { _token = null; _userName = null; });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calculadora Motorista',
      debugShowCheckedModeBanner: false,
      locale: const Locale('pt', 'BR'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('pt', 'BR')],
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: _bg,
        colorScheme: const ColorScheme.dark(primary: _blue, surface: _surface, onSurface: _txt),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: _blue,
          selectionColor: Color(0x443B82F6),
          selectionHandleColor: _blue,
        ),
        dialogTheme: const DialogTheme(
          backgroundColor: Color(0xFF1C1C1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
        ),
      ),
      home: _checking
          ? const Scaffold(backgroundColor: _bg)
          : (_token == null
              ? LoginScreen(onLogin: _onLogin)
              : MainScreen(token: _token!, userName: _userName!, onLogout: _onLogout)),
    );
  }
}

// ── Login Screen ──────────────────────────────────────────────────────────────

class LoginScreen extends StatefulWidget {
  final void Function(String token, String nome) onLogin;
  const LoginScreen({super.key, required this.onLogin});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nomeCtrl = TextEditingController();
  String _pin       = '';
  bool   _loading   = false;
  String? _error;
  bool   _isCadastro = false;

  void _tapNum(String d) {
    if (_pin.length >= 4) return;
    setState(() { _pin += d; _error = null; });
    if (_pin.length == 4 && _nomeCtrl.text.trim().isNotEmpty) _submit();
  }

  void _backspace() {
    if (_pin.isNotEmpty) setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    final nome = _nomeCtrl.text.trim();
    if (nome.isEmpty)       { setState(() => _error = 'Digite seu nome'); return; }
    if (_pin.length < 4)    { setState(() => _error = 'Digite os 4 dígitos do PIN'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      final data = _isCadastro
          ? await _api.register(nome, _pin)
          : await _api.login(nome, _pin);
      widget.onLogin(data['token'] as String, data['nome'] as String);
    } on ApiException catch (e) {
      setState(() { _error = e.message; _pin = ''; _loading = false; });
    } catch (_) {
      setState(() { _error = 'Sem conexão com o servidor'; _pin = ''; _loading = false; });
    }
  }

  @override
  void dispose() { _nomeCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  const Icon(Icons.directions_car_rounded, size: 36, color: _green),
                  const SizedBox(height: 10),
                  const Text('MOTORISTAS',
                      style: TextStyle(fontSize: 11, letterSpacing: 4, color: _muted, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  const Text('Calculadora',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: _txt, letterSpacing: -0.5)),
                  const SizedBox(height: 36),

                  // Campo nome
                  TextField(
                    controller: _nomeCtrl,
                    style: const TextStyle(fontSize: 15, color: _txt),
                    onChanged: (_) => setState(() => _error = null),
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      hintText: 'Seu nome',
                      hintStyle: const TextStyle(color: _muted),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _border)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _border)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _blue, width: 1.5)),
                      filled: true,
                      fillColor: _surface,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Dots do PIN
                  const Text('PIN', style: TextStyle(fontSize: 10, color: _muted, letterSpacing: 2)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (i) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: 14, height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < _pin.length ? _blue : Colors.transparent,
                        border: Border.all(
                            color: i < _pin.length ? _blue : _border, width: 1.5),
                      ),
                    )),
                  ),
                  const SizedBox(height: 20),

                  if (_error != null) ...[
                    Text(_error!, style: const TextStyle(color: _red, fontSize: 12)),
                    const SizedBox(height: 12),
                  ],

                  // Numpad
                  _buildNumpad(),
                  const SizedBox(height: 20),

                  // Botão entrar
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _blue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        disabledBackgroundColor: const Color(0xFF1D2D4A),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(_isCadastro ? 'CADASTRAR' : 'ENTRAR',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextButton(
                    onPressed: () => setState(() { _isCadastro = !_isCadastro; _error = null; _pin = ''; }),
                    child: Text(
                      _isCadastro ? 'Já tenho conta · Entrar' : 'Primeiro acesso · Cadastrar',
                      style: const TextStyle(color: _dim, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumpad() {
    const keys = ['1','2','3','4','5','6','7','8','9','','0','⌫'];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.4,
      children: keys.map((k) {
        if (k.isEmpty) return const SizedBox();
        if (k == '⌫') return GestureDetector(
          onTap: _backspace,
          child: Container(
            decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _border)),
            child: const Center(
                child: Icon(Icons.backspace_outlined, color: _dim, size: 18)),
          ),
        );
        return GestureDetector(
          onTap: () => _tapNum(k),
          child: Container(
            decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _border)),
            child: Center(
                child: Text(k,
                    style: const TextStyle(fontSize: 18, color: _txt, fontWeight: FontWeight.w500))),
          ),
        );
      }).toList(),
    );
  }
}

// ── Main Screen ───────────────────────────────────────────────────────────────

class MainScreen extends StatefulWidget {
  final String token;
  final String userName;
  final VoidCallback onLogout;
  const MainScreen({super.key, required this.token, required this.userName, required this.onLogout});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _tab = 0;
  final _rankingKey = GlobalKey<_RankingTabState>();
  final _calcKey    = GlobalKey<_CalculadoraTabState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: IndexedStack(
        index: _tab,
        children: [
          CalculadoraTab(
            key: _calcKey,
            token: widget.token,
            userName: widget.userName,
            onLogout: widget.onLogout,
            onJornadaSalva: () {
              _rankingKey.currentState?.refresh();
              setState(() => _tab = 1);
            },
          ),
          RankingTab(
            key: _rankingKey,
            token: widget.token,
            userName: widget.userName,
            onLogout: widget.onLogout,
            onEditarJornada: (jornada) {
              _calcKey.currentState?.carregarJornada(jornada);
              setState(() => _tab = 0);
            },
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF111112),
          border: Border(top: BorderSide(color: _border)),
        ),
        child: BottomNavigationBar(
          currentIndex: _tab,
          onTap: (i) {
            setState(() => _tab = i);
            if (i == 1) _rankingKey.currentState?.refresh();
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: _blue,
          unselectedItemColor: _muted,
          selectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5),
          unselectedLabelStyle: const TextStyle(fontSize: 10),
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.calculate_outlined),
                activeIcon: Icon(Icons.calculate_rounded),
                label: 'Calculadora'),
            BottomNavigationBarItem(
                icon: Icon(Icons.leaderboard_outlined),
                activeIcon: Icon(Icons.leaderboard_rounded),
                label: 'Ranking'),
          ],
        ),
      ),
    );
  }
}

// ── Calculadora Tab ───────────────────────────────────────────────────────────

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
  State<CalculadoraTab> createState() => _CalculadoraTabState();
}

class _CalculadoraTabState extends State<CalculadoraTab> {
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
  void initState() { super.initState(); _carregar(); }

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

  void _onChange() { if (!_pronto) return; setState(() {}); _salvar(); }

  Future<void> _salvar() async {
    if (!_pronto) return;
    final p = await SharedPreferences.getInstance();
    p.setString('meta',            _ctrlMeta.text);
    p.setStringList('nomes',       _nomesCtrl.map((c) => c.text).toList());
    p.setStringList('valores',     _valoresCtrl.map((c) => c.text).toList());
    p.setStringList('abatimentos', _abatimentoCtrl.map((c) => c.text).toList());
    p.setStringList('km_list',     _kmCtrl.map((c) => c.text).toList());
    p.setStringList('horas_list',  _horasCtrl.map((c) => c.text).toList());
  }

  @override
  void dispose() {
    for (final c in [_ctrlMeta, ..._nomesCtrl, ..._valoresCtrl,
                     ..._abatimentoCtrl, ..._kmCtrl, ..._horasCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Cálculos ──────────────────────────────────────────────────────────────
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

  // ── Formatação ────────────────────────────────────────────────────────────
  String _fmt(double v) {
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
  String _pct(double v) => '${v.toStringAsFixed(1).replaceAll('.', ',')}%';
  String _fmtHoras(double h) {
    final hI = h.floor();
    final mI = ((h - hI) * 60).round();
    return '$hI:${mI.toString().padLeft(2, '0')}h';
  }

  // ── Add/Remove ────────────────────────────────────────────────────────────
  void _addApp()         => setState(() { _nomesCtrl.add(_makeCtrl('')); _valoresCtrl.add(_makeCtrl('')); });
  void _removeApp(int i) {
    _nomesCtrl[i].dispose(); _valoresCtrl[i].dispose();
    setState(() { _nomesCtrl.removeAt(i); _valoresCtrl.removeAt(i); }); _salvar();
  }
  void _addAbatimento()         => setState(() => _abatimentoCtrl.add(_makeCtrl('')));
  void _removeAbatimento(int i) {
    if (_abatimentoCtrl.length <= 1) { _abatimentoCtrl[0].text = ''; return; }
    _abatimentoCtrl[i].dispose();
    setState(() => _abatimentoCtrl.removeAt(i)); _salvar();
  }
  void _addKm()        => setState(() => _kmCtrl.add(_makeCtrl('')));
  void _removeKm(int i) {
    if (_kmCtrl.length <= 1) { _kmCtrl[0].text = ''; return; }
    _kmCtrl[i].dispose(); setState(() => _kmCtrl.removeAt(i)); _salvar();
  }
  void _addHora()        => setState(() => _horasCtrl.add(_makeCtrl('')));
  void _removeHora(int i) {
    if (_horasCtrl.length <= 1) { _horasCtrl[0].text = ''; return; }
    _horasCtrl[i].dispose(); setState(() => _horasCtrl.removeAt(i)); _salvar();
  }

  // ── Reset ─────────────────────────────────────────────────────────────────
  Future<void> _confirmarReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Zerar o dia?',
            style: TextStyle(color: _txt, fontWeight: FontWeight.w600, fontSize: 16)),
        content: const Text('Todos os valores serão zerados.\nOs nomes dos apps são mantidos.',
            style: TextStyle(color: _dim, fontSize: 14, height: 1.5)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCELAR', style: TextStyle(color: _muted, fontSize: 13))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('ZERAR',
                  style: TextStyle(color: _red, fontSize: 13, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (ok == true) {
      setState(() {
        _ctrlMeta.text = '';
        for (final c in _valoresCtrl)    c.text = '';
        for (final c in _abatimentoCtrl) c.text = '';
        for (final c in _kmCtrl)         c.text = '';
        for (final c in _horasCtrl)      c.text = '';
      });
      _salvar();
    }
  }

  // ── Fechar Dia ────────────────────────────────────────────────────────────
  // ── Carregar Jornada para Edição ─────────────────────────────────────────
  void carregarJornada(Map<String, dynamic> j) {
    for (final c in [..._nomesCtrl, ..._valoresCtrl, ..._abatimentoCtrl, ..._kmCtrl, ..._horasCtrl]) {
      c.removeListener(_onChange);
      c.dispose();
    }
    final appsRaw = j['apps_json'] as String? ?? '[]';
    List<dynamic> apps = [];
    try { apps = jsonDecode(appsRaw) as List; } catch (_) {}
    List<TextEditingController> nomes, valores;
    if (apps.isEmpty) {
      final fat = (j['faturamento'] as num?)?.toDouble() ?? 0;
      nomes  = [_makeCtrl('')];
      valores = [_makeCtrl(fat > 0 ? fat.toStringAsFixed(2).replaceAll('.', ',') : '')];
    } else {
      nomes  = apps.map<TextEditingController>((a) => _makeCtrl(a['nome'] as String? ?? '')).toList();
      valores = apps.map<TextEditingController>((a) {
        final v = (a['valor'] as num?)?.toDouble() ?? 0;
        return _makeCtrl(v > 0 ? v.toStringAsFixed(2).replaceAll('.', ',') : '');
      }).toList();
    }
    final kmRaw = j['km_json'] as String? ?? '[]';
    List<dynamic> kmList = [];
    try { kmList = jsonDecode(kmRaw) as List; } catch (_) {}
    List<TextEditingController> kmCtrls;
    if (kmList.isEmpty) {
      final d = (j['km'] as num?)?.toDouble() ?? 0;
      kmCtrls = [_makeCtrl(d > 0 ? (d % 1 == 0 ? d.toInt().toString() : d.toStringAsFixed(1)) : '')];
    } else {
      kmCtrls = kmList.map<TextEditingController>((v) {
        final d = (v as num?)?.toDouble() ?? 0;
        return _makeCtrl(d > 0 ? (d % 1 == 0 ? d.toInt().toString() : d.toStringAsFixed(1)) : '');
      }).toList();
    }
    final horasRaw = j['horas_json'] as String? ?? '[]';
    List<dynamic> horasList = [];
    try { horasList = jsonDecode(horasRaw) as List; } catch (_) {}
    List<TextEditingController> horasCtrls;
    if (horasList.isEmpty) {
      final hVal = (j['horas'] as num?)?.toDouble() ?? 0;
      String ht = '';
      if (hVal > 0) {
        final hI = hVal.floor(); final mI = ((hVal - hI) * 60).round();
        ht = '${hI.toString().padLeft(2,"0")}:${mI.toString().padLeft(2,"0")}';
      }
      horasCtrls = [_makeCtrl(ht)];
    } else {
      horasCtrls = horasList.map<TextEditingController>((v) {
        final h = (v as num?)?.toDouble() ?? 0;
        if (h <= 0) return _makeCtrl('');
        final hI = h.floor(); final mI = ((h - hI) * 60).round();
        return _makeCtrl('${hI.toString().padLeft(2,"0")}:${mI.toString().padLeft(2,"0")}');
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
          return [_makeCtrl(desconto.toStringAsFixed(2).replaceAll('.', ','))];
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
      for (final c in [..._valoresCtrl, ..._abatimentoCtrl, ..._kmCtrl, ..._horasCtrl]) c.text = '';
    });
    _salvar();
  }

  Future<void> _fecharDia() async {
    if (total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Adicione um valor de faturamento antes de fechar o dia'),
          backgroundColor: _surface,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final appsJson = jsonEncode(List.generate(
      _nomesCtrl.length,
      (i) => {'nome': _nomesCtrl[i].text, 'valor': _p(_valoresCtrl[i].text)},
    ));
    final kmJson = jsonEncode(_kmCtrl.map((c) => _p(c.text)).toList());
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
        await _api.editarJornada(widget.token, _editandoId!, {
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
                style: TextStyle(color: _green, fontWeight: FontWeight.w600)),
            backgroundColor: _surface,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar: $e'),
            backgroundColor: _red,
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
      builder: (_) => _FecharDiaSheet(
        token: widget.token,
        total: total, km: km, horas: horas,
        porKm: porKm, porHora: porHora,
        appsJson: appsJson,
        kmJson: kmJson,
        horasJson: horasJson,
        fmtFn: _fmt,
        fmtHorasFn: _fmtHoras,
      ),
    );

    if (saved == true) {
      widget.onJornadaSalva();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Jornada salva com sucesso!',
              style: TextStyle(color: _green, fontWeight: FontWeight.w600)),
          backgroundColor: _surface,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (!_pronto) return const Scaffold(backgroundColor: _bg);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _border),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('MOTORISTA',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 2.5, color: _muted)),
            Text(widget.userName,
                style: const TextStyle(fontSize: 11, color: _dim, letterSpacing: 0.2)),
          ],
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh_rounded, color: _muted, size: 20),
              tooltip: 'Zerar o dia',
              onPressed: _confirmarReset),
          IconButton(
              icon: const Icon(Icons.logout_rounded, color: _muted, size: 20),
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2A3A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _blue.withOpacity(0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.edit_rounded, size: 13, color: _blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Editando jornada de ${_editandoData.length == 10 ? "${_editandoData.substring(8,10)}/${_editandoData.substring(5,7)}/${_editandoData.substring(0,4)}" : _editandoData}',
                  style: const TextStyle(fontSize: 11, color: _blue),
                ),
              ),
              GestureDetector(
                onTap: _cancelarEdicao,
                child: const Text('Cancelar', style: TextStyle(fontSize: 11, color: _red, fontWeight: FontWeight.w600)),
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
                color: _green.withOpacity(0.35),
                blurRadius: 16,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: _fecharDia,
            icon: Icon(isEditing ? Icons.check_rounded : Icons.flag_rounded, size: 18),
            label: Text(
              isEditing ? 'SALVAR' : 'CONCLUIR DIA',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.5),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.black,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }


  // ── Hero ──────────────────────────────────────────────────────────────────
  Widget _heroTotal() {
    final cor = total < 0 ? _red : (meta > 0 && total >= meta) ? _green : _txt;
    final progress = meta > 0 ? (pctMeta / 100).clamp(0.0, 1.0) : 0.0;
    final barColor = pctMeta >= 100 ? const Color(0xFF10B981)
        : pctMeta >= 90 ? const Color(0xFF22C55E)
        : pctMeta >= 80 ? const Color(0xFF4ADE80)
        : pctMeta >= 70 ? const Color(0xFF84CC16)
        : pctMeta >= 60 ? const Color(0xFFBEF264)
        : pctMeta >= 50 ? const Color(0xFFEAB308)
        : pctMeta >= 40 ? const Color(0xFFFBBF24)
        : pctMeta >= 30 ? const Color(0xFFF97316)
        : pctMeta >= 20 ? const Color(0xFFEF4444)
        : const Color(0xFFDC2626);

    return _box(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('FATURAMENTO TOTAL',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _dim, letterSpacing: 1.5)),
        const SizedBox(height: 6),
        Text(_fmt(total),
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -1.5, color: cor, height: 1.0)),
        if (km > 0 || horas > 0) ...[
          const SizedBox(height: 8),
          Row(children: [
            if (km > 0) ...[
              const Icon(Icons.route_rounded, size: 12, color: _dim),
              const SizedBox(width: 4),
              Text('${_fmt(porKm)}/km',
                  style: const TextStyle(fontSize: 12, color: _blue, fontWeight: FontWeight.w600)),
              const SizedBox(width: 16),
            ],
            if (horas > 0) ...[
              const Icon(Icons.access_time_rounded, size: 12, color: _dim),
              const SizedBox(width: 4),
              Text('${_fmt(porHora)}/h',
                  style: const TextStyle(fontSize: 12, color: _blue, fontWeight: FontWeight.w600)),
            ],
          ]),
        ],
        if (meta > 0) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
                value: progress, backgroundColor: _border, color: barColor, minHeight: 9),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(falta > 0 ? 'Falta ${_fmt(falta)} para a meta' : 'Meta atingida!',
                  style: TextStyle(fontSize: 12, color: falta > 0 ? _dim : _green, fontWeight: FontWeight.w500)),
              Text(_pct(pctMeta),
                  style: TextStyle(fontSize: 12, color: barColor, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ],
    ));
  }

  // ── Cards ─────────────────────────────────────────────────────────────────
  Widget _cardFaturamento() => _box(child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _secHeader('FATURAMENTO', _blue),
      const SizedBox(height: 8),
      for (int i = 0; i < _nomesCtrl.length; i++) _appRow(i),
      const SizedBox(height: 4),
      _addBtn('ADICIONAR APP', _addApp, _blue),
    ],
  ));

  Widget _cardIndicadores() => _box(child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _secHeader('INDICADORES', _green),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('KM RODADOS',
            style: TextStyle(fontSize: 11, color: _dim, fontWeight: FontWeight.w600, letterSpacing: 1.0)),
        if (km > 0) Text(
          '${km % 1 == 0 ? km.toInt() : km.toStringAsFixed(1)} km  •  ${_fmt(porKm)}/km',
          style: const TextStyle(fontSize: 11, color: _muted)),
      ]),
      const SizedBox(height: 6),
      for (int i = 0; i < _kmCtrl.length; i++) _simpleRow(_kmCtrl[i], '0', () => _removeKm(i)),
      _addBtn('ADICIONAR KM', _addKm, _green),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('HORAS TRABALHADAS',
            style: TextStyle(fontSize: 11, color: _dim, fontWeight: FontWeight.w600, letterSpacing: 1.0)),
        if (horas > 0) Text(
          '${_fmtHoras(horas)}  •  ${_fmt(porHora)}/h',
          style: const TextStyle(fontSize: 11, color: _muted)),
      ]),
      const SizedBox(height: 6),
      for (int i = 0; i < _horasCtrl.length; i++) _horaRow(_horasCtrl[i], () => _removeHora(i)),
      _addBtn('ADICIONAR HORA', _addHora, _green),
    ],
  ));

  Widget _cardMeta() => _box(child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _secHeader('META', _red),
      const SizedBox(height: 8),
      _inputRow('Meta diária (R\$)', _ctrlMeta),
    ],
  ));

  Widget _cardAbatimento() => _box(child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _secHeader('DESCONTOS', _orange),
        if (abatimento > 0)
          Text('- ${_fmt(abatimento)}', style: const TextStyle(fontSize: 11, color: _muted)),
      ]),
      const SizedBox(height: 8),
      for (int i = 0; i < _abatimentoCtrl.length; i++)
        _simpleRow(_abatimentoCtrl[i], '0,00', () => _removeAbatimento(i)),
      _addBtn('ADICIONAR DESCONTO', _addAbatimento, _orange),
    ],
  ));

  // ── Layout helpers ────────────────────────────────────────────────────────
  Widget _box({required Widget child}) => Container(
    width: double.infinity,
    decoration: BoxDecoration(
        color: _surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)),
    padding: const EdgeInsets.all(12),
    child: child,
  );

  Widget _secHeader(String titulo, Color cor) => Row(children: [
    Container(
        width: 3, height: 13,
        decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 8),
    Text(titulo, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _dim, letterSpacing: 1.2)),
  ]);

  Widget _appRow(int i) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      Expanded(flex: 4, child: _textField(ctrl: _nomesCtrl[i], hint: 'Nome do app')),
      const SizedBox(width: 8),
      Expanded(flex: 3, child: _numField(ctrl: _valoresCtrl[i], hint: '0,00')),
      const SizedBox(width: 4),
      GestureDetector(
          onTap: () => _removeApp(i),
          child: const Padding(padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.remove_circle_outline_rounded, color: _red, size: 20))),
    ]),
  );

  Widget _simpleRow(TextEditingController ctrl, String hint, VoidCallback onRemove) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      Expanded(child: _numField(ctrl: ctrl, hint: hint, align: TextAlign.left)),
      const SizedBox(width: 4),
      GestureDetector(
          onTap: onRemove,
          child: const Padding(padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.remove_circle_outline_rounded, color: _red, size: 20))),
    ]),
  );

  Widget _horaRow(TextEditingController ctrl, VoidCallback onRemove) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      Expanded(child: TextField(
        controller: ctrl, keyboardType: TextInputType.number,
        textAlign: TextAlign.left, inputFormatters: [_TimeFormatter()],
        style: const TextStyle(fontSize: 13, color: _txt), decoration: _dec('0:00'),
        onTap: () => ctrl.selection = TextSelection(baseOffset: 0, extentOffset: ctrl.text.length),
      )),
      const SizedBox(width: 4),
      GestureDetector(
          onTap: onRemove,
          child: const Padding(padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.remove_circle_outline_rounded, color: _red, size: 20))),
    ]),
  );

  Widget _addBtn(String label, VoidCallback onTap, Color cor) => Center(
    child: TextButton.icon(
      onPressed: onTap,
      icon: Icon(Icons.add_rounded, size: 15, color: cor),
      label: Text(label, style: TextStyle(fontSize: 12, color: cor, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), minimumSize: Size.zero),
    ),
  );

  Widget _inputRow(String label, TextEditingController ctrl) => Row(children: [
    Expanded(flex: 3, child: Text(label, style: const TextStyle(fontSize: 13, color: _dim))),
    Expanded(flex: 2, child: _numField(ctrl: ctrl, hint: '0,00', align: TextAlign.right)),
  ]);

  InputDecoration _dec(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF3F3F46)),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _blue, width: 1.5)),
    filled: true, fillColor: const Color(0xFF111112),
  );

  Widget _numField({required TextEditingController ctrl, String hint = '0', TextAlign align = TextAlign.right}) =>
      TextField(
        controller: ctrl, keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: align, inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
        style: const TextStyle(fontSize: 13, color: _txt), decoration: _dec(hint),
        onTap: () => ctrl.selection = TextSelection(baseOffset: 0, extentOffset: ctrl.text.length),
      );

  Widget _textField({required TextEditingController ctrl, String hint = ''}) =>
      TextField(controller: ctrl, style: const TextStyle(fontSize: 13, color: _txt), decoration: _dec(hint));
}

// ── Fechar Dia Sheet ──────────────────────────────────────────────────────────

class _FecharDiaSheet extends StatefulWidget {
  final String token;
  final double total, km, horas, porKm, porHora;
  final String appsJson, kmJson, horasJson;
  final String Function(double) fmtFn;
  final String Function(double) fmtHorasFn;
  const _FecharDiaSheet({
    required this.token, required this.total, required this.km,
    required this.horas, required this.porKm, required this.porHora,
    required this.appsJson, required this.kmJson, required this.horasJson,
    required this.fmtFn, required this.fmtHorasFn,
  });
  @override
  State<_FecharDiaSheet> createState() => _FecharDiaSheetState();
}

class _FecharDiaSheetState extends State<_FecharDiaSheet> {
  DateTime _date = DateTime.now();
  bool _loading = false;
  String? _error;

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: _blue, surface: Color(0xFF1C1C1E)),
        ),
        child: child!,
      ),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _confirmar() async {
    setState(() { _loading = true; _error = null; });
    try {
      await _api.salvarJornada(widget.token, {
        'data':           '${_date.year}-${_date.month.toString().padLeft(2,'0')}-${_date.day.toString().padLeft(2,'0')}',
        'km':             widget.km,
        'horas':          widget.horas,
        'faturamento':    widget.total,
        'ganho_por_km':   widget.porKm,
        'ganho_por_hora': widget.porHora,
        'apps_json':      widget.appsJson,
        'km_json':        widget.kmJson,
        'horas_json':     widget.horasJson,
      });
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      setState(() { _error = 'Sem conexão com o servidor'; _loading = false; });
    }
  }

  String _fmtDateDisplay(DateTime d) =>
      '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF161617),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(
              color: _border, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          const Text('FECHAR JORNADA',
              style: TextStyle(fontSize: 11, letterSpacing: 3, color: _muted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),

          // Resumo
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: const Color(0xFF0F0F10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border)),
            child: Row(children: [
              _stat('TOTAL', widget.fmtFn(widget.total), _green),
              if (widget.km > 0) ...[
                const SizedBox(width: 20),
                _stat('KM', '${widget.km.toStringAsFixed(0)} km', _blue),
              ],
              if (widget.horas > 0) ...[
                const SizedBox(width: 20),
                _stat('HORAS', widget.fmtHorasFn(widget.horas), _blue),
              ],
            ]),
          ),
          const SizedBox(height: 16),

          // Seletor de data
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                  color: _surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
              child: Row(children: [
                const Icon(Icons.calendar_today_rounded, size: 15, color: _dim),
                const SizedBox(width: 10),
                Text(_fmtDateDisplay(_date),
                    style: const TextStyle(fontSize: 14, color: _txt, fontWeight: FontWeight.w500)),
                const Spacer(),
                const Text('Alterar', style: TextStyle(fontSize: 12, color: _blue)),
              ]),
            ),
          ),
          const SizedBox(height: 12),

          if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: _red, fontSize: 12)),
            const SizedBox(height: 8),
          ],

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _loading ? null : _confirmar,
              style: ElevatedButton.styleFrom(
                backgroundColor: _green, foregroundColor: Colors.black, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _loading
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Text('CONFIRMAR E SALVAR',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1)),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: _dim, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color cor) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 9, color: _muted, letterSpacing: 1.5)),
      const SizedBox(height: 2),
      Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cor)),
    ],
  );
}

// ── Ranking Tab ───────────────────────────────────────────────────────────────

class RankingTab extends StatefulWidget {
  final String token;
  final String userName;
  final VoidCallback onLogout;
  final Function(Map<String, dynamic>) onEditarJornada;
  const RankingTab({super.key, required this.token, required this.userName, required this.onLogout, required this.onEditarJornada});
  @override
  State<RankingTab> createState() => _RankingTabState();
}

class _RankingTabState extends State<RankingTab> {
  String _periodo = 'mes';
  List<dynamic> _ranking   = [];
  List<dynamic> _jornadas  = [];
  bool _loadingRanking  = false;
  bool _loadingJornadas = false;
  String? _errorRanking;
  String? _errorJornadas;

  @override
  void initState() { super.initState(); refresh(); }

  Future<void> refresh() async {
    await Future.wait([_loadRanking(), _loadJornadas()]);
  }

  Future<void> _loadRanking() async {
    if (!mounted) return;
    setState(() { _loadingRanking = true; _errorRanking = null; });
    try {
      final data = await _api.ranking(widget.token, _periodo);
      if (mounted) setState(() { _ranking = data; _loadingRanking = false; });
    } on UnauthorizedException {
      widget.onLogout();
    } on ApiException catch (e) {
      if (mounted) setState(() { _errorRanking = e.message; _loadingRanking = false; });
    } catch (_) {
      if (mounted) setState(() { _errorRanking = 'Sem conexão com o servidor'; _loadingRanking = false; });
    }
  }

  Future<void> _loadJornadas() async {
    if (!mounted) return;
    setState(() { _loadingJornadas = true; _errorJornadas = null; });
    try {
      final data = await _api.minhasJornadas(widget.token);
      if (mounted) setState(() { _jornadas = data; _loadingJornadas = false; });
    } on UnauthorizedException {
      widget.onLogout();
    } on ApiException catch (e) {
      if (mounted) setState(() { _errorJornadas = e.message; _loadingJornadas = false; });
    } catch (_) {
      if (mounted) setState(() { _errorJornadas = 'Sem conexão com o servidor'; _loadingJornadas = false; });
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
      return '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
    } catch (_) { return iso; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg, elevation: 0,
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: _border)),
        title: const Text('RANKING',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 2.5, color: _muted)),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        color: _blue, backgroundColor: _surface,
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
        color: _surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: opcoes.map((o) {
          final selected = _periodo == o.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () { setState(() { _periodo = o.$1; _ranking = []; }); _loadRanking(); },
              child: Container(
                margin: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFF1A2F4A) : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Center(
                  child: Text(o.$2,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                          color: selected ? _blue : _dim)),
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
          Container(width: 3, height: 13,
              decoration: BoxDecoration(color: _gold, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          const Text('RANKING',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _dim, letterSpacing: 1.2)),
        ]),
        const SizedBox(height: 10),
        if (_loadingRanking)
          const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: _blue, strokeWidth: 2)))
        else if (_errorRanking != null)
          _errBox(_errorRanking!)
        else if (_ranking.isEmpty)
          _emptyBox('Nenhum dado para o período selecionado')
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

    final medalColor = idx == 0 ? _gold : idx == 1 ? _silver : idx == 2 ? _bronze : _muted;
    final medalIcon  = idx == 0 ? Icons.emoji_events_rounded
        : idx == 1 ? Icons.military_tech_rounded
        : idx == 2 ? Icons.military_tech_rounded
        : null;

    final card = IntrinsicHeight(
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF0D1829) : _surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isMe ? const Color(0xFF1A3050) : _border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isMe)
              Container(
                width: 3,
                decoration: const BoxDecoration(
                    color: _blue,
                    borderRadius: BorderRadius.horizontal(left: Radius.circular(10)))),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  SizedBox(
                    width: 28,
                    child: medalIcon != null
                        ? Icon(medalIcon, color: medalColor, size: 20)
                        : Text('${idx + 1}',
                            style: TextStyle(fontSize: 12, color: medalColor, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(nome,
                          style: const TextStyle(fontSize: 13, color: _txt, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(
                        '${jorn} jornada${jorn != 1 ? 's' : ''}'
                        '${km > 0 ? '  ·  ${km.toStringAsFixed(0)} km' : ''}'
                        '${h > 0 ? '  ·  ${h.toStringAsFixed(1)}h' : ''}',
                        style: const TextStyle(fontSize: 10, color: _muted)),
                      if (gKm > 0 || gH > 0) ...[
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (gKm > 0) '${_fmt(gKm)}/km',
                            if (gH > 0) '${_fmt(gH)}/h',
                          ].join('  ·  '),
                          style: const TextStyle(fontSize: 10, color: _blue)),
                      ],
                    ]),
                  ),
                  Text(_fmt(fat),
                      style: const TextStyle(fontSize: 14, color: _green, fontWeight: FontWeight.w700)),
                  if (!isMe) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.compare_arrows_rounded, size: 14, color: _muted),
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
      builder: (_) => _CompararSheet(
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
          Container(width: 3, height: 13,
              decoration: BoxDecoration(color: _blue, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          const Text('MINHAS JORNADAS',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _dim, letterSpacing: 1.2)),
        ]),
        const SizedBox(height: 10),
        if (_loadingJornadas)
          const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: _blue, strokeWidth: 2)))
        else if (_errorJornadas != null)
          _errBox(_errorJornadas!)
        else if (_jornadas.isEmpty)
          _emptyBox('Nenhuma jornada registrada ainda.\nFeche o seu primeiro dia na calculadora.')
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
            color: _red.withOpacity(0.85), borderRadius: BorderRadius.circular(10)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
          SizedBox(height: 3),
          Text('EXCLUIR', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1)),
        ]),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
            color: _surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _editarJornada(j),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_fmtDate(data),
                    style: const TextStyle(fontSize: 13, color: _txt, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(
                  [
                    if (km > 0) '${km.toStringAsFixed(0)} km',
                    if (h > 0) '${h.toStringAsFixed(1)}h',
                  ].join('  ·  '),
                  style: const TextStyle(fontSize: 11, color: _muted),
                ),
              ])),
              Text(_fmt(fat),
                  style: const TextStyle(fontSize: 14, color: _green, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              const Icon(Icons.edit_outlined, size: 15, color: _muted),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _editarJornada(Map<String, dynamic> jornada) async {
    widget.onEditarJornada(jornada);
  }

  Future<bool?> _confirmarDelete() => showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: _surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text('Excluir jornada?',
          style: TextStyle(color: _txt, fontWeight: FontWeight.w600, fontSize: 16)),
      content: const Text('Esta ação não pode ser desfeita.',
          style: TextStyle(color: _dim, fontSize: 14)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR', style: TextStyle(color: _muted))),
        TextButton(onPressed: () => Navigator.pop(context, true),
            child: const Text('EXCLUIR', style: TextStyle(color: _red, fontWeight: FontWeight.w700))),
      ],
    ),
  );

  Future<void> _deletarJornada(String id) async {
    try {
      await _api.deletarJornada(widget.token, id);
      if (mounted) setState(() => _jornadas.removeWhere((j) => j['id'] == id));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: _surface));
      refresh();
    }
  }

  Widget _errBox(String msg) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
        color: const Color(0xFF1A0F0F), borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF3A1A1A))),
    child: Row(children: [
      const Icon(Icons.error_outline_rounded, color: _red, size: 16),
      const SizedBox(width: 8),
      Expanded(child: Text(msg, style: const TextStyle(fontSize: 12, color: _red))),
    ]),
  );

  Widget _emptyBox(String msg) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
        color: _surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
    child: Center(child: Text(msg,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, color: _muted, height: 1.6))),
  );
}

// ── Editar Jornada Sheet ──────────────────────────────────────────────────────

class _EditarJornadaSheet extends StatefulWidget {
  final String token;
  final Map<String, dynamic> jornada;
  final String Function(double) fmtFn;
  const _EditarJornadaSheet({required this.token, required this.jornada, required this.fmtFn});
  @override
  State<_EditarJornadaSheet> createState() => _EditarJornadaSheetState();
}

class _EditarJornadaSheetState extends State<_EditarJornadaSheet> {
  List<TextEditingController> _nomesCtrl   = [];
  List<TextEditingController> _valoresCtrl = [];
  List<TextEditingController> _kmCtrl      = [];
  List<TextEditingController> _horasCtrl   = [];
  late DateTime _date;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final appsRaw = widget.jornada['apps_json'] as String? ?? '[]';
    List<dynamic> apps = [];
    try { apps = jsonDecode(appsRaw) as List; } catch (_) {}

    if (apps.isEmpty) {
      final fat = (widget.jornada['faturamento'] as num?)?.toDouble() ?? 0;
      _nomesCtrl   = [TextEditingController(text: '')];
      _valoresCtrl = [TextEditingController(
          text: fat > 0 ? fat.toStringAsFixed(2).replaceAll('.', ',') : '')];
    } else {
      _nomesCtrl   = apps.map<TextEditingController>(
          (a) => TextEditingController(text: a['nome'] as String? ?? '')).toList();
      _valoresCtrl = apps.map<TextEditingController>((a) {
        final v = (a['valor'] as num?)?.toDouble() ?? 0;
        return TextEditingController(
            text: v > 0 ? v.toStringAsFixed(2).replaceAll('.', ',') : '');
      }).toList();
    }

    // KM — parse km_json, fallback para valor total
    final kmRaw = widget.jornada['km_json'] as String? ?? '[]';
    List<dynamic> kmList = [];
    try { kmList = jsonDecode(kmRaw) as List; } catch (_) {}
    if (kmList.isEmpty) {
      final kmVal = (widget.jornada['km'] as num?)?.toDouble() ?? 0;
      _kmCtrl = [TextEditingController(
          text: kmVal > 0 ? (kmVal % 1 == 0 ? kmVal.toInt().toString() : kmVal.toStringAsFixed(1)) : '')];
    } else {
      _kmCtrl = kmList.map<TextEditingController>((v) {
        final d = (v as num?)?.toDouble() ?? 0;
        return TextEditingController(
            text: d > 0 ? (d % 1 == 0 ? d.toInt().toString() : d.toStringAsFixed(1)) : '');
      }).toList();
    }

    // Horas — parse horas_json, fallback para valor total
    final horasRaw = widget.jornada['horas_json'] as String? ?? '[]';
    List<dynamic> horasList = [];
    try { horasList = jsonDecode(horasRaw) as List; } catch (_) {}
    if (horasList.isEmpty) {
      final hVal = (widget.jornada['horas'] as num?)?.toDouble() ?? 0;
      String horasText = '';
      if (hVal > 0) {
        final hInt = hVal.floor();
        final mInt = ((hVal - hInt) * 60).round();
        horasText = '${hInt.toString().padLeft(2, '0')}:${mInt.toString().padLeft(2, '0')}';
      }
      _horasCtrl = [TextEditingController(text: horasText)];
    } else {
      _horasCtrl = horasList.map<TextEditingController>((v) {
        final h = (v as num?)?.toDouble() ?? 0;
        if (h <= 0) return TextEditingController(text: '');
        final hInt = h.floor();
        final mInt = ((h - hInt) * 60).round();
        return TextEditingController(
            text: '${hInt.toString().padLeft(2, '0')}:${mInt.toString().padLeft(2, '0')}');
      }).toList();
    }

    try { _date = DateTime.parse(widget.jornada['data'] as String? ?? ''); }
    catch (_) { _date = DateTime.now(); }
  }

  @override
  void dispose() {
    for (final c in [..._nomesCtrl, ..._valoresCtrl, ..._kmCtrl, ..._horasCtrl]) c.dispose();
    super.dispose();
  }

  double _p(String s) => double.tryParse(s.replaceAll(',', '.')) ?? 0;
  double _parseHoras(String t) {
    if (t.contains(':')) {
      final pts = t.split(':');
      return _p(pts[0]) + (pts.length > 1 ? _p(pts[1]) / 60.0 : 0);
    }
    return _p(t);
  }
  String _fmtHoras(double h) {
    final hI = h.floor(); final mI = ((h - hI) * 60).round();
    return '$hI:${mI.toString().padLeft(2, '0')}h';
  }

  double get _total    => _valoresCtrl.fold(0.0, (s, c) => s + _p(c.text));
  double get _totalKm  => _kmCtrl.fold(0.0, (s, c) => s + _p(c.text));
  double get _totalH   => _horasCtrl.fold(0.0, (s, c) => s + _parseHoras(c.text));

  void _addApp() => setState(() {
    _nomesCtrl.add(TextEditingController());
    _valoresCtrl.add(TextEditingController());
  });
  void _removeApp(int i) {
    _nomesCtrl[i].dispose(); _valoresCtrl[i].dispose();
    setState(() { _nomesCtrl.removeAt(i); _valoresCtrl.removeAt(i); });
  }
  void _addKm() => setState(() => _kmCtrl.add(TextEditingController()));
  void _removeKm(int i) {
    if (_kmCtrl.length <= 1) { _kmCtrl[0].text = ''; return; }
    _kmCtrl[i].dispose();
    setState(() => _kmCtrl.removeAt(i));
  }
  void _addHora() => setState(() => _horasCtrl.add(TextEditingController()));
  void _removeHora(int i) {
    if (_horasCtrl.length <= 1) { _horasCtrl[0].text = ''; return; }
    _horasCtrl[i].dispose();
    setState(() => _horasCtrl.removeAt(i));
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(primary: _blue, surface: Color(0xFF1C1C1E))),
        child: child!,
      ),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _salvar() async {
    final fat = _total;
    if (fat <= 0) { setState(() => _error = 'Informe pelo menos um valor'); return; }
    setState(() { _loading = true; _error = null; });
    final km    = _totalKm;
    final horas = _totalH;
    final apps  = List.generate(_nomesCtrl.length,
        (i) => {'nome': _nomesCtrl[i].text, 'valor': _p(_valoresCtrl[i].text)});
    final kmVals    = _kmCtrl.map((c) => _p(c.text)).toList();
    final horasVals = _horasCtrl.map((c) => _parseHoras(c.text)).toList();
    try {
      await _api.editarJornada(widget.token, widget.jornada['id'] as String, {
        'data':           '${_date.year}-${_date.month.toString().padLeft(2,'0')}-${_date.day.toString().padLeft(2,'0')}',
        'km':             km,
        'horas':          horas,
        'faturamento':    fat,
        'ganho_por_km':   km > 0 ? fat / km : 0,
        'ganho_por_hora': horas > 0 ? fat / horas : 0,
        'apps_json':      jsonEncode(apps),
        'km_json':        jsonEncode(kmVals),
        'horas_json':     jsonEncode(horasVals),
      });
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      setState(() { _error = 'Sem conexão com o servidor'; _loading = false; });
    }
  }

  Future<void> _excluir() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir jornada?',
            style: TextStyle(color: _txt, fontWeight: FontWeight.w600, fontSize: 16)),
        content: const Text('Esta ação não pode ser desfeita.',
            style: TextStyle(color: _dim, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCELAR', style: TextStyle(color: _muted))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('EXCLUIR', style: TextStyle(color: _red, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (ok != true) return;
    setState(() { _loading = true; _error = null; });
    try {
      await _api.deletarJornada(widget.token, widget.jornada['id'] as String);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';

  InputDecoration _dec(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF3F3F46)),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _blue, width: 1.5)),
    filled: true, fillColor: const Color(0xFF111112),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF161617),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Row(children: [
              const Expanded(child: Text('EDITAR JORNADA',
                  style: TextStyle(fontSize: 11, letterSpacing: 3, color: _muted, fontWeight: FontWeight.w600))),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: _red, size: 20),
                onPressed: _loading ? null : _excluir,
                padding: EdgeInsets.zero, constraints: const BoxConstraints(),
              ),
            ]),
            const SizedBox(height: 16),

            // Data
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                    color: _surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
                child: Row(children: [
                  const Icon(Icons.calendar_today_rounded, size: 15, color: _dim),
                  const SizedBox(width: 10),
                  Text(_fmtDate(_date),
                      style: const TextStyle(fontSize: 14, color: _txt, fontWeight: FontWeight.w500)),
                  const Spacer(),
                  const Text('Alterar', style: TextStyle(fontSize: 12, color: _blue)),
                ]),
              ),
            ),
            const SizedBox(height: 12),

            // Apps
            const Text('FATURAMENTO POR APP',
                style: TextStyle(fontSize: 10, letterSpacing: 1.5, color: _muted, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),

            ...List.generate(_nomesCtrl.length, (i) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _nomesCtrl[i],
                    style: const TextStyle(fontSize: 13, color: _txt),
                    decoration: _dec('App (ex: Uber)'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _valoresCtrl[i],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
                    style: const TextStyle(fontSize: 13, color: _txt),
                    decoration: _dec('Valor (R\$)'),
                    onTap: () => _valoresCtrl[i].selection = TextSelection(
                        baseOffset: 0, extentOffset: _valoresCtrl[i].text.length),
                  ),
                ),
                if (_nomesCtrl.length > 1) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => _removeApp(i),
                    child: const Icon(Icons.close_rounded, size: 16, color: _muted),
                  ),
                ],
              ]),
            )),

            GestureDetector(
              onTap: _addApp,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Icon(Icons.add_rounded, size: 14, color: _blue),
                  SizedBox(width: 4),
                  Text('Adicionar app',
                      style: TextStyle(fontSize: 12, color: _blue, fontWeight: FontWeight.w500)),
                ]),
              ),
            ),
            const SizedBox(height: 12),

            // KM e Horas
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('KM RODADOS',
                      style: TextStyle(fontSize: 10, color: _muted, letterSpacing: 1.2, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _kmCtrl[0],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
                    style: const TextStyle(fontSize: 14, color: _txt),
                    decoration: _dec('0'),
                    onTap: () => _kmCtrl[0].selection = TextSelection(baseOffset: 0, extentOffset: _kmCtrl[0].text.length),
                  ),
                ]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('HORAS DE TRABALHO',
                      style: TextStyle(fontSize: 10, color: _muted, letterSpacing: 1.2, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _horasCtrl[0],
                    keyboardType: TextInputType.number,
                    inputFormatters: [_TimeFormatter()],
                    style: const TextStyle(fontSize: 14, color: _txt),
                    decoration: _dec('0:00'),
                    onTap: () => _horasCtrl[0].selection = TextSelection(baseOffset: 0, extentOffset: _horasCtrl[0].text.length),
                  ),
                ]),
              ),
            ]),
            const SizedBox(height: 12),

            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: _red, fontSize: 12)),
              const SizedBox(height: 8),
            ],

            SizedBox(
              width: double.infinity, height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _salvar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blue, foregroundColor: Colors.white, elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _loading
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('SALVAR',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Comparar Sheet ────────────────────────────────────────────────────────────

class _CompararSheet extends StatefulWidget {
  final String token;
  final String myName;
  final String otherName;
  const _CompararSheet({required this.token, required this.myName, required this.otherName});
  @override
  State<_CompararSheet> createState() => _CompararSheetState();
}

class _CompararSheetState extends State<_CompararSheet> {
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
      case 'dia': return (todayStr, todayStr);
      case 'semana':
        final start = today.subtract(Duration(days: today.weekday - 1));
        return (_isoDate(start), todayStr);
      case 'mes':
        return ('${today.year}-${today.month.toString().padLeft(2, '0')}-01', todayStr);
      default:
        return ('1970-01-01', todayStr);
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    final (desde, ate) = _range;
    try {
      final d = await _api.comparar(widget.token, widget.myName, widget.otherName, desde, ate);
      if (mounted) setState(() {
        _dataA = d['usuario_a'] as Map<String, dynamic>;
        _dataB = d['usuario_b'] as Map<String, dynamic>;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Sem conexão com o servidor'; _loading = false; });
    }
  }

  Future<void> _pickDate(bool isDesde) async {
    final initial = isDesde ? _desde : _ate;
    final first   = isDesde ? DateTime(2020) : _desde;
    final last    = isDesde ? _ate : DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(primary: _blue, surface: Color(0xFF1C1C1E))),
        child: child!,
      ),
    );
    if (d != null) {
      setState(() { if (isDesde) _desde = d; else _ate = d; });
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
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            const Text('COMPARAÇÃO',
                style: TextStyle(fontSize: 10, letterSpacing: 3, color: _muted, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(child: Text(widget.myName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _blue))),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('vs', style: TextStyle(fontSize: 12, color: _muted, fontWeight: FontWeight.w500)),
                ),
                Flexible(child: Text(widget.otherName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _txt))),
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
              const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator(color: _blue, strokeWidth: 2)))
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
      ('dia',    'Hoje'),
      ('semana', 'Semana'),
      ('mes',    'Mês'),
      ('geral',  'Geral'),
      ('custom', 'Período'),
    ];
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: opcoes.map((o) {
          final selected = o.$1 == 'custom' ? _custom : (!_custom && _periodo == o.$1);
          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (o.$1 == 'custom') {
                  setState(() => _custom = true);
                } else {
                  setState(() { _custom = false; _periodo = o.$1; });
                  _load();
                }
              },
              child: Container(
                margin: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFF1A2F4A) : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Center(
                  child: Text(o.$2,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                          color: selected ? _blue : _dim)),
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
          child: Icon(Icons.arrow_forward_rounded, size: 16, color: _muted)),
      Expanded(child: _dateTile('Até', _ate, () => _pickDate(false))),
    ]);
  }

  Widget _dateTile(String label, DateTime d, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
          color: _surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 9, color: _muted, letterSpacing: 1.5)),
        const SizedBox(height: 3),
        Text(
          '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}',
          style: const TextStyle(fontSize: 13, color: _txt, fontWeight: FontWeight.w600),
        ),
      ]),
    ),
  );

  Widget _buildStats() {
    double dbl(Map<String, dynamic> m, String k) => (m[k] as num?)?.toDouble() ?? 0;

    final fatA = dbl(_dataA!, 'total_faturamento');
    final fatB = dbl(_dataB!, 'total_faturamento');
    final kmA  = dbl(_dataA!, 'total_km');
    final kmB  = dbl(_dataB!, 'total_km');
    final hA   = dbl(_dataA!, 'total_horas');
    final hB   = dbl(_dataB!, 'total_horas');
    final gkmA = dbl(_dataA!, 'ganho_km');
    final gkmB = dbl(_dataB!, 'ganho_km');
    final ghA  = dbl(_dataA!, 'ganho_hora');
    final ghB  = dbl(_dataB!, 'ganho_hora');
    final jA   = (_dataA!['total_jornadas'] as num?)?.toInt() ?? 0;
    final jB   = (_dataB!['total_jornadas'] as num?)?.toInt() ?? 0;

    int aWins = 0, bWins = 0;
    void tally(double a, double b) { if (a > b) aWins++; else if (b > a) bWins++; }
    tally(fatA, fatB); tally(kmA, kmB); tally(hA, hB);
    tally(gkmA, gkmB); tally(ghA, ghB); tally(jA.toDouble(), jB.toDouble());

    return Column(
      children: [
        if (aWins != bWins) Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: aWins > bWins ? const Color(0xFF0D1829) : const Color(0xFF0F1F12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: aWins > bWins ? const Color(0xFF1A3050) : const Color(0xFF1A3A2A)),
          ),
          child: Text(
            aWins > bWins
                ? 'Você está à frente em $aWins de ${aWins + bWins} métricas'
                : '${widget.otherName} está à frente em $bWins de ${aWins + bWins} métricas',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: aWins > bWins ? _blue : _green),
          ),
        ),
        _statRow('FATURAMENTO',
            _fmt(fatA), _fmt(fatB), fatA.compareTo(fatB)),
        _statRow('R\$/KM',
            gkmA > 0 ? _fmt(gkmA) : '—', gkmB > 0 ? _fmt(gkmB) : '—', gkmA.compareTo(gkmB)),
        _statRow('R\$/HORA',
            ghA > 0 ? _fmt(ghA) : '—', ghB > 0 ? _fmt(ghB) : '—', ghA.compareTo(ghB)),
        _statRow('KM RODADOS',
            kmA > 0 ? '${kmA.toStringAsFixed(0)} km' : '—',
            kmB > 0 ? '${kmB.toStringAsFixed(0)} km' : '—', kmA.compareTo(kmB)),
        _statRow('HORAS',
            hA > 0 ? _fmtH(hA) : '—', hB > 0 ? _fmtH(hB) : '—', hA.compareTo(hB)),
        _statRow('JORNADAS', '$jA', '$jB', jA.compareTo(jB)),
      ],
    );
  }

  Widget _statRow(String label, String valA, String valB, int cmp) {
    final aColor = cmp > 0 ? _green : (cmp < 0 ? _muted : _dim);
    final bColor = cmp < 0 ? _green : (cmp > 0 ? _muted : _dim);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
          color: _surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
      child: Row(children: [
        Expanded(child: Text(valA,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: aColor))),
        Text(label,
            style: const TextStyle(fontSize: 9, color: _muted, letterSpacing: 1.2, fontWeight: FontWeight.w500)),
        Expanded(child: Text(valB,
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: bColor))),
      ]),
    );
  }

  Widget _errBox(String msg) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
        color: const Color(0xFF1A0F0F), borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF3A1A1A))),
    child: Row(children: [
      const Icon(Icons.error_outline_rounded, color: _red, size: 16),
      const SizedBox(width: 8),
      Expanded(child: Text(msg, style: const TextStyle(fontSize: 12, color: _red))),
    ]),
  );
}

// ── Time Formatter ────────────────────────────────────────────────────────────

class _TimeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return newValue.copyWith(text: '', selection: const TextSelection.collapsed(offset: 0));
    final d = digits.length > 4 ? digits.substring(0, 4) : digits;
    final formatted = d.length <= 2 ? d : '${d.substring(0, 2)}:${d.substring(2)}';
    return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
  }
}
