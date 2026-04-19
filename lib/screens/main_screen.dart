import 'package:flutter/material.dart';
import '../core/constants.dart';
import 'calculator_tab.dart';
import 'ranking_tab.dart';

class MainScreen extends StatefulWidget {
  final String token;
  final String userName;
  final VoidCallback onLogout;

  const MainScreen({
    super.key,
    required this.token,
    required this.userName,
    required this.onLogout,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _tab = 0;
  final _rankingKey = GlobalKey<RankingTabState>();
  final _calcKey    = GlobalKey<CalculadoraTabState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
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
          border: Border(top: BorderSide(color: border)),
        ),
        child: BottomNavigationBar(
          currentIndex: _tab,
          onTap: (i) {
            setState(() => _tab = i);
            if (i == 1) _rankingKey.currentState?.refresh();
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: blue,
          unselectedItemColor: muted,
          selectedLabelStyle: const TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5),
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
