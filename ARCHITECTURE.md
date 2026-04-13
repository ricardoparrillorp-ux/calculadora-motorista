# Calculadora do Motorista — Decisões de Arquitetura

## Stack

| Ferramenta | Por quê |
|---|---|
| **Flutter** | Gera APK Android nativo sem servidor. Single-screen widget, compilação AOT = performance nativa, leve. |
| **shared_preferences** | Persistência local simples (key-value). Dados salvos automaticamente a cada digitação, sem banco, sem servidor. Offline-first by design. |

## Arquitetura

- **Tela única** (`CalculadoraPage`) — tudo em um `StatefulWidget` com `SingleChildScrollView`
- **Source of truth**: `TextEditingController` de cada campo. Cálculos são `getters` computados direto no build.
- **Persistência**: cada mudança nos controllers dispara `_salvar()` via listener. Ao abrir o app, `_carregar()` restaura o estado.
- **Reset do dia**: botão no AppBar limpa os valores numéricos, mantém os nomes dos apps.

## Cálculos

```
somaApps   = Σ valores digitados em cada app
total      = somaApps - abatimento
falta      = max(0, meta - total)
pctMeta    = (total / meta) × 100
porKm      = total / km_rodados
porHora    = total / horas_trabalhadas   (suporta formato HH:MM)
```

## Como rodar / gerar APK

**Pré-requisito:** [Flutter SDK](https://flutter.dev/docs/get-started/install/windows) instalado.

```bash
# Na pasta do projeto:
flutter create . --project-name calculadora_motorista
flutter pub get
flutter build apk --release
```

O APK estará em: `build/app/outputs/flutter-apk/app-release.apk`

## Estrutura de pastas

```
calculadora_motorista/
├── lib/
│   └── main.dart        ← app inteiro (single-screen)
├── pubspec.yaml
└── ARCHITECTURE.md
```

## Portas e serviços

Nenhum. 100% offline, sem dependências externas.

## Segurança

- Nenhum dado enviado para servidores
- Nenhuma permissão de rede solicitada no AndroidManifest
- Dados ficam no armazenamento privado do app (SharedPreferences)
