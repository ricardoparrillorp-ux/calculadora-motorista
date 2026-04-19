import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';

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

  void _check401(http.Response r) {
    if (r.statusCode == 401) throw UnauthorizedException();
  }

  Future<Map<String, dynamic>> register(
      String nome, String pin, String question, String answer) async {
    final r = await http.post(Uri.parse('$apiBase/auth/register'),
        headers: _h(),
        body: jsonEncode({
          'nome': nome,
          'pin': pin,
          'security_question': question,
          'security_answer': answer
        }));
    final d = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode != 200) throw ApiException(d['detail'] ?? 'Erro ao cadastrar');
    return d;
  }

  Future<String> getSecurityQuestion(String nome) async {
    final r = await http.get(
        Uri.parse('$apiBase/auth/security-question?nome=${Uri.encodeComponent(nome)}'));
    final d = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode != 200) throw ApiException(d['detail'] ?? 'Usuário não encontrado');
    return d['security_question'] as String;
  }

  Future<Map<String, dynamic>> resetPin(
      String nome, String answer, String newPin) async {
    final r = await http.post(Uri.parse('$apiBase/auth/reset-pin'),
        headers: _h(),
        body: jsonEncode(
            {'nome': nome, 'security_answer': answer, 'new_pin': newPin}));
    final d = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode != 200) throw ApiException(d['detail'] ?? 'Resposta incorreta');
    return d;
  }

  Future<Map<String, dynamic>> login(String nome, String pin) async {
    final r = await http.post(Uri.parse('$apiBase/auth/login'),
        headers: _h(), body: jsonEncode({'nome': nome, 'pin': pin}));
    final d = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode != 200) throw ApiException(d['detail'] ?? 'Nome ou PIN incorreto');
    return d;
  }

  Future<void> salvarJornada(String token, Map<String, dynamic> data) async {
    final r = await http.post(Uri.parse('$apiBase/jornadas'),
        headers: _h(token), body: jsonEncode(data));
    _check401(r);
    if (r.statusCode != 200) {
      final d = jsonDecode(r.body) as Map<String, dynamic>;
      throw ApiException(d['detail'] ?? 'Erro ao salvar');
    }
  }

  Future<List<dynamic>> minhasJornadas(String token) async {
    final r = await http.get(Uri.parse('$apiBase/jornadas/minhas'),
        headers: _h(token));
    _check401(r);
    if (r.statusCode != 200) throw ApiException('Erro ao carregar jornadas');
    return jsonDecode(r.body) as List;
  }

  Future<void> editarJornada(
      String token, String id, Map<String, dynamic> data) async {
    final r = await http.put(Uri.parse('$apiBase/jornadas/$id'),
        headers: _h(token), body: jsonEncode(data));
    _check401(r);
    if (r.statusCode != 200) {
      final d = jsonDecode(r.body) as Map<String, dynamic>;
      throw ApiException(d['detail'] ?? 'Erro ao editar');
    }
  }

  Future<void> deletarJornada(String token, String id) async {
    final r = await http.delete(Uri.parse('$apiBase/jornadas/$id'),
        headers: _h(token));
    _check401(r);
    if (r.statusCode != 200) throw ApiException('Erro ao deletar');
  }

  Future<List<dynamic>> ranking(String token, String periodo) async {
    final r = await http.get(Uri.parse('$apiBase/ranking?periodo=$periodo'),
        headers: _h(token));
    _check401(r);
    if (r.statusCode != 200) throw ApiException('Erro ao carregar ranking');
    return jsonDecode(r.body) as List;
  }

  Future<Map<String, dynamic>> comparar(
      String token, String userA, String userB, String desde, String ate) async {
    final url = Uri.parse('$apiBase/comparar').replace(queryParameters: {
      'usuario_a': userA,
      'usuario_b': userB,
      'desde': desde,
      'ate': ate,
    });
    final r = await http.get(url, headers: _h(token));
    _check401(r);
    if (r.statusCode != 200) throw ApiException('Erro ao carregar comparação');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }
}

final api = ApiService();
