import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants.dart';
import '../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  final void Function(String token, String nome) onLogin;
  const LoginScreen({super.key, required this.onLogin});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nomeCtrl     = TextEditingController();
  final _perguntaCtrl = TextEditingController();
  final _respostaCtrl = TextEditingController();
  String  _pin        = '';
  bool    _loading    = false;
  String? _error;
  bool    _isCadastro = false;

  bool    _isRecovering    = false;
  int     _recoveryStep    = 1;
  String  _recoveryQuestion = '';
  String  _recoveryPin     = '';
  bool    _recoveryLoading = false;
  String? _recoveryError;

  void _tapNum(String d) {
    if (_isRecovering) {
      if (_recoveryPin.length >= 4) return;
      setState(() {
        _recoveryPin += d;
        _recoveryError = null;
      });
    } else {
      if (_pin.length >= 4) return;
      setState(() {
        _pin += d;
        _error = null;
      });
      if (_pin.length == 4 &&
          _nomeCtrl.text.trim().isNotEmpty &&
          !_isCadastro) _submit();
    }
  }

  void _backspace() {
    if (_isRecovering) {
      if (_recoveryPin.isNotEmpty) {
        setState(() => _recoveryPin =
            _recoveryPin.substring(0, _recoveryPin.length - 1));
      }
    } else {
      if (_pin.isNotEmpty) {
        setState(() => _pin = _pin.substring(0, _pin.length - 1));
      }
    }
  }

  Future<void> _fetchQuestion() async {
    final nome = _nomeCtrl.text.trim();
    if (nome.isEmpty) {
      setState(() => _recoveryError = 'Digite seu nome');
      return;
    }
    setState(() {
      _recoveryLoading = true;
      _recoveryError = null;
    });
    try {
      final q = await api.getSecurityQuestion(nome);
      setState(() {
        _recoveryQuestion = q;
        _recoveryStep = 2;
        _recoveryLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _recoveryError = e.message;
        _recoveryLoading = false;
      });
    } catch (_) {
      setState(() {
        _recoveryError = 'Sem conexão com o servidor';
        _recoveryLoading = false;
      });
    }
  }

  Future<void> _doResetPin() async {
    final nome   = _nomeCtrl.text.trim();
    final answer = _respostaCtrl.text.trim();
    if (answer.isEmpty) {
      setState(() => _recoveryError = 'Digite a resposta');
      return;
    }
    if (_recoveryPin.length < 4) {
      setState(() => _recoveryError = 'Digite o novo PIN');
      return;
    }
    setState(() {
      _recoveryLoading = true;
      _recoveryError = null;
    });
    try {
      final data = await api.resetPin(nome, answer, _recoveryPin);
      widget.onLogin(data['token'] as String, data['nome'] as String);
    } on ApiException catch (e) {
      setState(() {
        _recoveryError = e.message;
        _recoveryPin = '';
        _recoveryLoading = false;
      });
    } catch (_) {
      setState(() {
        _recoveryError = 'Sem conexão com o servidor';
        _recoveryPin = '';
        _recoveryLoading = false;
      });
    }
  }

  void _exitRecovery() => setState(() {
        _isRecovering = false;
        _recoveryStep = 1;
        _recoveryQuestion = '';
        _recoveryPin = '';
        _recoveryError = null;
        _respostaCtrl.clear();
      });

  Future<void> _submit() async {
    final nome = _nomeCtrl.text.trim();
    if (nome.isEmpty) {
      setState(() => _error = 'Digite seu nome');
      return;
    }
    if (_pin.length < 4) {
      setState(() => _error = 'Digite os 4 dígitos do PIN');
      return;
    }
    if (_isCadastro) {
      if (_perguntaCtrl.text.trim().length < 5) {
        setState(() => _error = 'Pergunta de segurança muito curta');
        return;
      }
      if (_respostaCtrl.text.trim().isEmpty) {
        setState(() => _error = 'Digite a resposta de segurança');
        return;
      }
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = _isCadastro
          ? await api.register(nome, _pin, _perguntaCtrl.text.trim(),
              _respostaCtrl.text.trim())
          : await api.login(nome, _pin);
      widget.onLogin(data['token'] as String, data['nome'] as String);
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _pin = '';
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Sem conexão com o servidor';
        _pin = '';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _perguntaCtrl.dispose();
    _respostaCtrl.dispose();
    super.dispose();
  }

  InputDecoration _fieldDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: muted),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusMd),
            borderSide: const BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusMd),
            borderSide: const BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusMd),
            borderSide: const BorderSide(color: blue, width: 1.5)),
        filled: true,
        fillColor: surface,
      );

  Widget _pinDots(String pin) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
            4,
            (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < pin.length ? blue : Colors.transparent,
                    border: Border.all(
                        color: i < pin.length ? blue : border, width: 1.5),
                  ),
                )),
      );

  @override
  Widget build(BuildContext context) {
    if (_isRecovering) return _buildRecovery();
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  const Icon(Icons.directions_car_rounded,
                      size: 36, color: green),
                  const SizedBox(height: 10),
                  const Text('MOTORISTAS',
                      style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 4,
                          color: muted,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  const Text('Calculadora',
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: txt,
                          letterSpacing: -0.5)),
                  const SizedBox(height: 36),
                  TextField(
                    controller: _nomeCtrl,
                    style: const TextStyle(fontSize: 15, color: txt),
                    onChanged: (_) => setState(() => _error = null),
                    textCapitalization: TextCapitalization.words,
                    decoration: _fieldDeco('Seu nome'),
                  ),
                  const SizedBox(height: 28),
                  const Text('PIN',
                      style: TextStyle(
                          fontSize: 10, color: muted, letterSpacing: 2)),
                  const SizedBox(height: 12),
                  _pinDots(_pin),
                  const SizedBox(height: 20),
                  if (_isCadastro) ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('SEGURANÇA',
                          style: TextStyle(
                              fontSize: 10, color: muted, letterSpacing: 2)),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _perguntaCtrl,
                      style: const TextStyle(fontSize: 14, color: txt),
                      onChanged: (_) => setState(() => _error = null),
                      decoration: _fieldDeco(
                          'Pergunta de segurança (ex: nome do seu pet)'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _respostaCtrl,
                      style: const TextStyle(fontSize: 14, color: txt),
                      onChanged: (_) => setState(() => _error = null),
                      decoration: _fieldDeco('Resposta'),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_error != null) ...[
                    Text(_error!,
                        style:
                            const TextStyle(color: red, fontSize: 12)),
                    const SizedBox(height: 12),
                  ],
                  _buildNumpad(),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: blue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(radiusMd)),
                        disabledBackgroundColor: const Color(0xFF1D2D4A),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(
                              _isCadastro ? 'CADASTRAR' : 'ENTRAR',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextButton(
                    onPressed: () => setState(() {
                      _isCadastro = !_isCadastro;
                      _error = null;
                      _pin = '';
                      _perguntaCtrl.clear();
                      _respostaCtrl.clear();
                    }),
                    child: Text(
                      _isCadastro
                          ? 'Já tenho conta · Entrar'
                          : 'Primeiro acesso · Cadastrar',
                      style: const TextStyle(color: dim, fontSize: 12),
                    ),
                  ),
                  if (!_isCadastro)
                    TextButton(
                      onPressed: () => setState(() {
                        _isRecovering = true;
                        _nomeCtrl.clear();
                      }),
                      child: const Text('Esqueci o PIN',
                          style: TextStyle(color: muted, fontSize: 12)),
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
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '⌫'];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.4,
      children: keys.map((k) {
        if (k.isEmpty) return const SizedBox();
        if (k == '⌫') {
          return Material(
            color: surface,
            borderRadius: BorderRadius.circular(radiusSm),
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                _backspace();
              },
              borderRadius: BorderRadius.circular(radiusSm),
              child: Container(
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radiusSm),
                    border: Border.all(color: border)),
                child: const Center(
                    child: Icon(Icons.backspace_outlined, color: dim, size: 18)),
              ),
            ),
          );
        }
        return Material(
          color: surface,
          borderRadius: BorderRadius.circular(radiusSm),
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              _tapNum(k);
            },
            borderRadius: BorderRadius.circular(radiusSm),
            child: Container(
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radiusSm),
                  border: Border.all(color: border)),
              child: Center(
                  child: Text(k,
                      style: const TextStyle(
                          fontSize: 18,
                          color: txt,
                          fontWeight: FontWeight.w500))),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecovery() {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  const Icon(Icons.lock_reset_rounded, size: 36, color: blue),
                  const SizedBox(height: 10),
                  const Text('RECUPERAR',
                      style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 4,
                          color: muted,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  const Text('PIN',
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: txt,
                          letterSpacing: -0.5)),
                  const SizedBox(height: 36),
                  TextField(
                    controller: _nomeCtrl,
                    enabled: _recoveryStep == 1,
                    style: const TextStyle(fontSize: 15, color: txt),
                    textCapitalization: TextCapitalization.words,
                    onChanged: (_) => setState(() => _recoveryError = null),
                    decoration: _fieldDeco('Seu nome'),
                  ),
                  const SizedBox(height: 16),
                  if (_recoveryStep == 2) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(radiusMd),
                        border: Border.all(color: border),
                      ),
                      child: Text(_recoveryQuestion,
                          style: const TextStyle(color: dim, fontSize: 13)),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _respostaCtrl,
                      style: const TextStyle(fontSize: 14, color: txt),
                      onChanged: (_) =>
                          setState(() => _recoveryError = null),
                      decoration: _fieldDeco('Sua resposta'),
                    ),
                    const SizedBox(height: 24),
                    const Text('NOVO PIN',
                        style: TextStyle(
                            fontSize: 10, color: muted, letterSpacing: 2)),
                    const SizedBox(height: 12),
                    _pinDots(_recoveryPin),
                    const SizedBox(height: 20),
                  ],
                  if (_recoveryError != null) ...[
                    Text(_recoveryError!,
                        style: const TextStyle(color: red, fontSize: 12)),
                    const SizedBox(height: 12),
                  ],
                  if (_recoveryStep == 2) _buildNumpad(),
                  if (_recoveryStep == 2) const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _recoveryLoading
                          ? null
                          : (_recoveryStep == 1
                              ? _fetchQuestion
                              : _doResetPin),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: blue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(radiusMd)),
                        disabledBackgroundColor: const Color(0xFF1D2D4A),
                      ),
                      child: _recoveryLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(
                              _recoveryStep == 1
                                  ? 'BUSCAR PERGUNTA'
                                  : 'REDEFINIR PIN',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextButton(
                    onPressed: _exitRecovery,
                    child: const Text('Voltar ao login',
                        style: TextStyle(color: dim, fontSize: 12)),
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
}
