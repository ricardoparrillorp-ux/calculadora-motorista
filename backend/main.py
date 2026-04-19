import os
import uuid
import time
import bcrypt
import jwt
from collections import defaultdict
from datetime import datetime, timedelta, date, timezone
from fastapi import FastAPI, HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional
from dotenv import load_dotenv

load_dotenv()

SECRET_KEY        = os.getenv('SECRET_KEY', 'dev-secret-change-in-production')
TOKEN_EXPIRE_DAYS = int(os.getenv('TOKEN_EXPIRE_DAYS', '30'))
DATABASE_URL      = os.getenv('DATABASE_URL', '')
DB_PATH           = os.getenv('DB_PATH', 'motoristas.db')
CORS_ORIGINS      = os.getenv('CORS_ORIGINS', 'https://calculadora-motorista.onrender.com').split(',')

# ── Modo banco (SQLite local / PostgreSQL produção) ───────────────────────────

USE_PG = bool(DATABASE_URL)

if USE_PG:
    import psycopg2
    import psycopg2.errors
    PH = '%s'
    _IntegrityError = psycopg2.IntegrityError
    _DuplicateColumn = psycopg2.errors.DuplicateColumn
else:
    import sqlite3
    PH = '?'
    _IntegrityError = sqlite3.IntegrityError
    _DuplicateColumn = None  # SQLite raises OperationalError with message

def db():
    if USE_PG:
        return psycopg2.connect(DATABASE_URL)
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

def _one(cur):
    r = cur.fetchone()
    if r is None:
        return None
    if USE_PG:
        cols = [d[0] for d in cur.description]
        return dict(zip(cols, r))
    return dict(r)

def _all(cur):
    rows = cur.fetchall()
    if USE_PG:
        cols = [d[0] for d in cur.description]
        return [dict(zip(cols, r)) for r in rows]
    return [dict(r) for r in rows]

def _exec(conn, sql, params=()):
    if USE_PG:
        cur = conn.cursor()
        cur.execute(sql, params)
        return cur
    return conn.execute(sql, params)

# ── App ────────────────────────────────────────────────────────────────────────

app = FastAPI(title='Calculadora Motorista API', docs_url=None, redoc_url=None)

app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ORIGINS,
    allow_credentials=False,
    allow_methods=['*'],
    allow_headers=['*'],
)

from fastapi import Request

@app.middleware('http')
async def log_requests(request: Request, call_next):
    start = time.time()
    response = await call_next(request)
    dur = round((time.time() - start) * 1000)
    print(f'[{request.method}] {request.url.path} | status={response.status_code} | {dur}ms', flush=True)
    return response

# ── Rate limiting (in-memory, per nome) ───────────────────────────────────────

_auth_attempts: dict[str, list[float]] = defaultdict(list)
_WINDOW_SECS = 300   # 5 minutos
_MAX_ATTEMPTS = 5

def _check_rate_limit(nome: str):
    now = time.time()
    attempts = _auth_attempts[nome]
    # limpar tentativas fora da janela
    _auth_attempts[nome] = [t for t in attempts if now - t < _WINDOW_SECS]
    if len(_auth_attempts[nome]) >= _MAX_ATTEMPTS:
        raise HTTPException(429, 'Muitas tentativas. Tente novamente em 5 minutos.')

def _record_attempt(nome: str):
    _auth_attempts[nome].append(time.time())

def _clear_attempts(nome: str):
    _auth_attempts.pop(nome, None)

# ── Banco de dados ─────────────────────────────────────────────────────────────

def _migration_add_column(conn, table: str, col: str, definition: str):
    try:
        _exec(conn, f'ALTER TABLE {table} ADD COLUMN {col} {definition}')
        conn.commit()
    except Exception as e:
        if USE_PG:
            conn.rollback()
            if not isinstance(e, _DuplicateColumn):
                raise
        else:
            if 'duplicate column' not in str(e).lower():
                raise

def init_db():
    conn = db()
    nocase = '' if USE_PG else ' COLLATE NOCASE'
    _exec(conn, f"""
        CREATE TABLE IF NOT EXISTS usuarios (
            id        TEXT PRIMARY KEY,
            nome      TEXT UNIQUE NOT NULL{nocase},
            pin_hash  TEXT NOT NULL,
            criado_em TEXT NOT NULL
        )
    """)
    _exec(conn, """
        CREATE TABLE IF NOT EXISTS jornadas (
            id             TEXT PRIMARY KEY,
            usuario_id     TEXT NOT NULL,
            usuario_nome   TEXT NOT NULL,
            data           TEXT NOT NULL,
            km             REAL DEFAULT 0,
            horas          REAL DEFAULT 0,
            faturamento    REAL NOT NULL,
            ganho_por_km   REAL DEFAULT 0,
            ganho_por_hora REAL DEFAULT 0,
            apps_json      TEXT DEFAULT '[]',
            km_json        TEXT DEFAULT '[]',
            horas_json     TEXT DEFAULT '[]',
            criado_em      TEXT NOT NULL,
            FOREIGN KEY (usuario_id) REFERENCES usuarios(id)
        )
    """)
    conn.commit()
    _migration_add_column(conn, 'jornadas', 'km_json', "TEXT DEFAULT '[]'")
    _migration_add_column(conn, 'jornadas', 'horas_json', "TEXT DEFAULT '[]'")
    _migration_add_column(conn, 'usuarios', 'security_question', "TEXT DEFAULT ''")
    _migration_add_column(conn, 'usuarios', 'security_answer_hash', "TEXT DEFAULT ''")
    conn.close()

init_db()

# ── Auth ───────────────────────────────────────────────────────────────────────

security = HTTPBearer()

def make_token(uid: str, nome: str) -> str:
    payload = {
        'sub': uid,
        'nome': nome,
        'exp': datetime.now(timezone.utc) + timedelta(days=TOKEN_EXPIRE_DAYS)
    }
    return jwt.encode(payload, SECRET_KEY, algorithm='HS256')

def current_user(creds: HTTPAuthorizationCredentials = Depends(security)):
    try:
        p = jwt.decode(creds.credentials, SECRET_KEY, algorithms=['HS256'])
        return {'id': p['sub'], 'nome': p['nome']}
    except jwt.ExpiredSignatureError:
        raise HTTPException(401, 'Token expirado')
    except jwt.InvalidTokenError:
        raise HTTPException(401, 'Token inválido')

# ── Models ─────────────────────────────────────────────────────────────────────

class AuthReq(BaseModel):
    nome: str
    pin: str

class RegisterReq(BaseModel):
    nome: str
    pin: str
    security_question: str
    security_answer: str

class ResetPinReq(BaseModel):
    nome: str
    security_answer: str
    new_pin: str

class JornadaReq(BaseModel):
    data: str
    km: float = 0
    horas: float = 0
    faturamento: float
    ganho_por_km: float = 0
    ganho_por_hora: float = 0
    apps_json: str = '[]'
    km_json: str = '[]'
    horas_json: str = '[]'

class JornadaUpdate(BaseModel):
    data: Optional[str] = None
    km: Optional[float] = None
    horas: Optional[float] = None
    faturamento: Optional[float] = None
    ganho_por_km: Optional[float] = None
    ganho_por_hora: Optional[float] = None
    apps_json: Optional[str] = None
    km_json: Optional[str] = None
    horas_json: Optional[str] = None

_JORNADA_ALLOWED_COLS = frozenset({
    'data', 'km', 'horas', 'faturamento',
    'ganho_por_km', 'ganho_por_hora',
    'apps_json', 'km_json', 'horas_json',
})

# ── Endpoints ──────────────────────────────────────────────────────────────────

@app.get('/health')
def health():
    conn = db()
    try:
        _exec(conn, 'SELECT 1')
        conn.close()
        return {'status': 'ok'}
    except Exception:
        conn.close()
        raise HTTPException(503, 'Database unavailable')


@app.post('/auth/register')
def register(req: RegisterReq):
    nome = req.nome.strip()
    if len(nome) < 2:
        raise HTTPException(400, 'Nome muito curto')
    if len(req.pin) != 4 or not req.pin.isdigit():
        raise HTTPException(400, 'PIN deve ter exatamente 4 dígitos numéricos')
    if len(req.security_question.strip()) < 5:
        raise HTTPException(400, 'Pergunta de segurança muito curta')
    if not req.security_answer.strip():
        raise HTTPException(400, 'Resposta não pode ser vazia')

    pin_hash    = bcrypt.hashpw(req.pin.encode(), bcrypt.gensalt()).decode()
    answer_hash = bcrypt.hashpw(req.security_answer.strip().lower().encode(), bcrypt.gensalt()).decode()
    uid = str(uuid.uuid4())
    conn = db()
    try:
        _exec(conn,
            f'INSERT INTO usuarios (id, nome, pin_hash, security_question, security_answer_hash, criado_em) VALUES ({PH},{PH},{PH},{PH},{PH},{PH})',
            (uid, nome, pin_hash, req.security_question.strip(), answer_hash, datetime.now(timezone.utc).isoformat())
        )
        conn.commit()
    except _IntegrityError:
        raise HTTPException(409, 'Nome já cadastrado')
    finally:
        conn.close()
    return {'token': make_token(uid, nome), 'nome': nome, 'id': uid}

@app.get('/auth/security-question')
def get_security_question(nome: str):
    conn = db()
    cur = _exec(conn, f'SELECT security_question FROM usuarios WHERE LOWER(nome) = LOWER({PH})', (nome.strip(),))
    row = _one(cur)
    conn.close()
    if not row:
        raise HTTPException(404, 'Usuário não encontrado')
    q = row.get('security_question') or ''
    if not q:
        raise HTTPException(404, 'Este usuário não tem pergunta de segurança cadastrada')
    return {'security_question': q}

@app.post('/auth/reset-pin')
def reset_pin(req: ResetPinReq):
    if len(req.new_pin) != 4 or not req.new_pin.isdigit():
        raise HTTPException(400, 'PIN deve ter exatamente 4 dígitos')
    nome = req.nome.strip()
    _check_rate_limit(nome)
    conn = db()
    cur = _exec(conn, f'SELECT * FROM usuarios WHERE LOWER(nome) = LOWER({PH})', (nome,))
    row = _one(cur)
    answer_hash = row.get('security_answer_hash', '') if row else ''
    if not row or not answer_hash or not bcrypt.checkpw(req.security_answer.strip().lower().encode(), answer_hash.encode()):
        conn.close()
        _record_attempt(nome)
        raise HTTPException(401, 'Nome ou resposta incorretos')
    new_pin_hash = bcrypt.hashpw(req.new_pin.encode(), bcrypt.gensalt()).decode()
    _exec(conn, f'UPDATE usuarios SET pin_hash = {PH} WHERE id = {PH}', (new_pin_hash, row['id']))
    conn.commit()
    conn.close()
    _clear_attempts(nome)
    return {'token': make_token(row['id'], row['nome']), 'nome': row['nome'], 'id': row['id']}

@app.post('/auth/login')
def login(req: AuthReq):
    nome = req.nome.strip()
    _check_rate_limit(nome)
    conn = db()
    cur = _exec(conn,
        f'SELECT * FROM usuarios WHERE LOWER(nome) = LOWER({PH})',
        (nome,)
    )
    row = _one(cur)
    conn.close()
    if not row or not bcrypt.checkpw(req.pin.encode(), row['pin_hash'].encode()):
        _record_attempt(nome)
        raise HTTPException(401, 'Nome ou PIN incorreto')
    _clear_attempts(nome)
    return {'token': make_token(row['id'], row['nome']), 'nome': row['nome'], 'id': row['id']}

@app.post('/jornadas')
def criar_jornada(req: JornadaReq, u=Depends(current_user)):
    jid = str(uuid.uuid4())
    conn = db()
    _exec(conn, f"""
        INSERT INTO jornadas
            (id, usuario_id, usuario_nome, data, km, horas, faturamento,
             ganho_por_km, ganho_por_hora, apps_json, km_json, horas_json, criado_em)
        VALUES ({PH},{PH},{PH},{PH},{PH},{PH},{PH},{PH},{PH},{PH},{PH},{PH},{PH})
    """, (
        jid, u['id'], u['nome'], req.data,
        req.km, req.horas, req.faturamento,
        req.ganho_por_km, req.ganho_por_hora,
        req.apps_json, req.km_json, req.horas_json,
        datetime.now(timezone.utc).isoformat()
    ))
    conn.commit()
    conn.close()
    return {'id': jid, 'message': 'Jornada salva'}

@app.get('/jornadas/minhas')
def minhas_jornadas(offset: int = 0, limit: int = 50, u=Depends(current_user)):
    if limit > 200:
        limit = 200
    conn = db()
    cur = _exec(conn,
        f'SELECT * FROM jornadas WHERE usuario_id = {PH} ORDER BY data DESC LIMIT {PH} OFFSET {PH}',
        (u['id'], limit, offset)
    )
    result = _all(cur)
    conn.close()
    return result

@app.put('/jornadas/{jid}')
def editar_jornada(jid: str, req: JornadaUpdate, u=Depends(current_user)):
    conn = db()
    cur = _exec(conn, f'SELECT * FROM jornadas WHERE id = {PH}', (jid,))
    row = _one(cur)
    if not row:
        conn.close()
        raise HTTPException(404, 'Jornada não encontrada')
    if row['usuario_id'] != u['id']:
        conn.close()
        raise HTTPException(403, 'Sem permissão')
    ups = {
        k: v for k, v in req.model_dump().items()
        if v is not None and k in _JORNADA_ALLOWED_COLS
    }
    if ups:
        sql = 'UPDATE jornadas SET ' + ', '.join(f'{k}={PH}' for k in ups) + f' WHERE id={PH}'
        _exec(conn, sql, list(ups.values()) + [jid])
        conn.commit()
    conn.close()
    return {'message': 'Atualizado'}

@app.delete('/jornadas/{jid}')
def deletar_jornada(jid: str, u=Depends(current_user)):
    conn = db()
    cur = _exec(conn, f'SELECT * FROM jornadas WHERE id = {PH}', (jid,))
    row = _one(cur)
    if not row:
        conn.close()
        raise HTTPException(404, 'Não encontrada')
    if row['usuario_id'] != u['id']:
        conn.close()
        raise HTTPException(403, 'Sem permissão')
    _exec(conn, f'DELETE FROM jornadas WHERE id = {PH}', (jid,))
    conn.commit()
    conn.close()
    return {'message': 'Deletado'}

@app.get('/comparar')
def comparar(
    usuario_a: str,
    usuario_b: str,
    desde: str,
    ate: str,
    u=Depends(current_user)
):
    try:
        date.fromisoformat(desde)
        date.fromisoformat(ate)
    except ValueError:
        raise HTTPException(400, 'Formato de data inválido. Use YYYY-MM-DD.')

    def stats(nome: str, conn):
        cur = _exec(conn, f"""
            SELECT
                COALESCE(SUM(faturamento), 0)  AS total_faturamento,
                COALESCE(SUM(km), 0)           AS total_km,
                COALESCE(SUM(horas), 0)        AS total_horas,
                CASE WHEN SUM(km)    > 0 THEN SUM(faturamento) / SUM(km)    ELSE 0 END AS ganho_km,
                CASE WHEN SUM(horas) > 0 THEN SUM(faturamento) / SUM(horas) ELSE 0 END AS ganho_hora,
                COUNT(*)                       AS total_jornadas
            FROM jornadas
            WHERE LOWER(usuario_nome) = LOWER({PH})
              AND data >= {PH} AND data <= {PH}
        """, (nome, desde, ate))
        row = _one(cur)
        return {k: (v if v is not None else 0) for k, v in row.items()}

    conn = db()
    a = stats(usuario_a, conn)
    b = stats(usuario_b, conn)
    conn.close()
    return {
        'usuario_a': {'nome': usuario_a, **a},
        'usuario_b': {'nome': usuario_b, **b},
    }

@app.get('/ranking')
def ranking(periodo: str = 'mes', u=Depends(current_user)):
    today = date.today()
    if periodo == 'dia':
        desde = today.isoformat()
    elif periodo == 'semana':
        desde = (today - timedelta(days=today.weekday())).isoformat()
    elif periodo == 'mes':
        desde = today.replace(day=1).isoformat()
    else:
        desde = '1970-01-01'

    conn = db()
    cur = _exec(conn, f"""
        SELECT
            usuario_nome,
            SUM(faturamento)  AS total_faturamento,
            SUM(km)           AS total_km,
            SUM(horas)        AS total_horas,
            CASE WHEN SUM(km)    > 0 THEN SUM(faturamento) / SUM(km)    ELSE 0 END AS ganho_km,
            CASE WHEN SUM(horas) > 0 THEN SUM(faturamento) / SUM(horas) ELSE 0 END AS ganho_hora,
            COUNT(*)          AS total_jornadas
        FROM jornadas
        WHERE data >= {PH}
        GROUP BY usuario_id, usuario_nome
        ORDER BY total_faturamento DESC
        LIMIT 100
    """, (desde,))
    result = _all(cur)
    conn.close()
    return result
