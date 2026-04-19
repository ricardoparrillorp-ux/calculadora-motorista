import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../services/api_service.dart';

class FecharDiaSheet extends StatefulWidget {
  final String token;
  final double total, km, horas, porKm, porHora;
  final String appsJson, kmJson, horasJson;
  final String Function(double) fmtFn;
  final String Function(double) fmtHorasFn;

  const FecharDiaSheet({
    super.key,
    required this.token,
    required this.total,
    required this.km,
    required this.horas,
    required this.porKm,
    required this.porHora,
    required this.appsJson,
    required this.kmJson,
    required this.horasJson,
    required this.fmtFn,
    required this.fmtHorasFn,
  });

  @override
  State<FecharDiaSheet> createState() => _FecharDiaSheetState();
}

class _FecharDiaSheetState extends State<FecharDiaSheet> {
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
          colorScheme: const ColorScheme.dark(
              primary: blue, surface: Color(0xFF1C1C1E)),
        ),
        child: child!,
      ),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _confirmar() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await api.salvarJornada(widget.token, {
        'data': '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
        'km': widget.km,
        'horas': widget.horas,
        'faturamento': widget.total,
        'ganho_por_km': widget.porKm,
        'ganho_por_hora': widget.porHora,
        'apps_json': widget.appsJson,
        'km_json': widget.kmJson,
        'horas_json': widget.horasJson,
      });
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Sem conexão com o servidor';
        _loading = false;
      });
    }
  }

  String _fmtDateDisplay(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF161617),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: border, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          const Text('FECHAR JORNADA',
              style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 3,
                  color: muted,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: const Color(0xFF0F0F10),
                borderRadius: BorderRadius.circular(radiusMd),
                border: Border.all(color: border)),
            child: Row(children: [
              _stat('TOTAL', widget.fmtFn(widget.total), green),
              if (widget.km > 0) ...[
                const SizedBox(width: 20),
                _stat('KM', '${widget.km.toStringAsFixed(0)} km', blue),
              ],
              if (widget.horas > 0) ...[
                const SizedBox(width: 20),
                _stat('HORAS', widget.fmtHorasFn(widget.horas), blue),
              ],
            ]),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(radiusMd),
                  border: Border.all(color: border)),
              child: Row(children: [
                const Icon(Icons.calendar_today_rounded, size: 15, color: dim),
                const SizedBox(width: 10),
                Text(_fmtDateDisplay(_date),
                    style: const TextStyle(
                        fontSize: 14,
                        color: txt,
                        fontWeight: FontWeight.w500)),
                const Spacer(),
                const Text('Alterar',
                    style: TextStyle(fontSize: 12, color: blue)),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: red, fontSize: 12)),
            const SizedBox(height: 8),
          ],
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _loading ? null : _confirmar,
              style: ElevatedButton.styleFrom(
                backgroundColor: green,
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(radiusMd)),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black))
                  : const Text('CONFIRMAR E SALVAR',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1)),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                const Text('Cancelar', style: TextStyle(color: dim, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color cor) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 9, color: muted, letterSpacing: 1.5)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: cor)),
        ],
      );
}
