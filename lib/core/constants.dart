import 'package:flutter/material.dart';

// Build: flutter build apk --dart-define=API_BASE_URL=https://seu-servidor.com
const apiBase = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://calculadora-motorista-api.onrender.com',
);

const bg      = Color(0xFF0D0D0E);
const surface = Color(0xFF161617);
const border  = Color(0xFF242425);
const dim     = Color(0xFF71717A);
const muted   = Color(0xFF52525B);
const txt     = Color(0xFFF4F4F5);
const blue    = Color(0xFF3B82F6);
const green   = Color(0xFF22C55E);
const red     = Color(0xFFEF4444);
const orange  = Color(0xFFF97316);
const gold    = Color(0xFFFFAE00);
const silver  = Color(0xFF94A3B8);
const bronze  = Color(0xFFCD7F32);

// Border radius tokens — use consistently across all widgets
const radiusSm = 8.0;   // inputs dentro de cards
const radiusMd = 10.0;  // botões, chips, items de lista
const radiusLg = 12.0;  // cards
const radiusXl = 16.0;  // bottom sheets, dialogs
