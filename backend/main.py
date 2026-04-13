import os
import uuid
import bcrypt
import jwt
import psycopg2
import psycopg2.extras
from datetime import datetime, timedelta, date
from fastapi import FastAPI, HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional
from dotenv import load_dotenv

load_dotenv()

SECRET_KEY = os.getenv('SECRET_KEY', 'dev-secret-troque-em-producao-2024!')
TOKEN_EXPIRE_DAYS = int(os.getenv('TOKEN_EXPIRE_DAYS', '30'))
DATABASE_URL = os.getenv('DATABASE_URL', '')
CORS_ORIGINS = os.getenv('CORS_ORIGINS', '*').split(',')

app = FastAPI(title='Calculadora Motorista API', docs_url=None, redoc_url=None)

app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ORIGINS,
    allow_credentials=False,
    allow_methods=['*'],
    allow_headers=['*'],
)

from fastapi import Request
import time

@app.middleware('http')
async def log_requests(request: Request, call_next):
    start = time.time()
    response = await call_next(request)
    dur = round((time.time() - start) * 1000)
    print(f'[{request.method}] {request.url.path} | status={response.status_code} | {dur}ms', flush=True)
    return response

# ── Banco de dados ─────────────────────────────────────────────────────────────

def db():
    conn = psycopg2.connect(DATABASE_URL)
    return conn

def row_to_dict(cursor, row):
    if row is None:
        return None
    cols = [d[0] for d in cursor.description]
    return dict(zip(cols, row))

def rows_to_list(cursor, rows):
    cols = [d[0] for d in cursor.description]
    return [dict(zip(cols, row)) for row in rows]

def init_db():
    conn = db()
    cur = conn.cursor()
    cur.execute("""
        CREATE TABLE IF NOT EXISTS usuarios (
            id        TEXT PRIMARY KEY,
            nome      TEXT UNIQUE NOT NULL,
            pin_hash  TEXT NOT NULL,
            criado_em TEXT NOT NULL
        )
    """)
    cur.execute("""
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
            criado_em      TEXT NOT NULL,
            FOREIGN KEY (usuario_id) REFERENCES usuarios(id)
        )
    """)
    conn.commit()
    cur.close()
    conn.close()

init_db()

# ── Auth ───────────────────────────────────────────────────────────────────────

security = HTTPBearer()

def make_token(uid: str, nome: str) -> str:
    payload = {
        'sub': uid,
        'nome': nome,
        'exp': datetime.utcnow() + timedelta(days=TOKEN_EXPIRE_DAYS)
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

class JornadaReq(BaseModel):
    data: str
    km: float = 0
    horas: float = 0
    faturamento: float
    ganho_por_km: float = 0
    ganho_por_hora: float = 0
    apps_json: str = '[]'

class JornadaUpdate(BaseModel):
    data: Optional[str] = None
    km: Optional[float] = None
    horas: Optional[float] = None
    faturamento: Optional[float] = None
    ganho_por_km: Optional[float] = None
    ganho_por_hora: Optional[float] = None
    apps_json: Optional[str] = None

# ── Endpoints ──────────────────────────────────────────────────────────────────

@app.post('/auth/register')
def register(req: AuthReq):
    nome = req.nome.strip()
    if len(nome) < 2:
        raise HTTPException(400, 'Nome muito curto')
    if len(req.pin) != 4 or not req.pin.isdigit():
        raise HTTPException(400, 'PIN deve ter exatamente 4 dígitos numéricos')

    pin_hash = bcrypt.hashpw(req.pin.encode(), bcrypt.gensalt()).decode()
    uid = str(uuid.uuid4())
    conn = db()
    cur = conn.cursor()
    try:
        cur.execute(
            'INSERT INTO usuarios (id, nome, pin_hash, criado_em) VALUES (%s, %s, %s, %s)',
            (uid, nome, pin_hash, datetime.utcnow().isoformat())
        )
        conn.commit()
    except psycopg2.IntegrityError:
        conn.rollback()
        raise HTTPException(409, 'Nome já cadastrado')
    finally:
        cur.close()
        conn.close()
    return {'token': make_token(uid, nome), 'nome': nome, 'id': uid}

@app.post('/auth/login')
def login(req: AuthReq):
    conn = db()
    cur = conn.cursor()
    cur.execute(
        'SELECT * FROM usuarios WHERE LOWER(nome) = LOWER(%s)',
        (req.nome.strip(),)
    )
    row = row_to_dict(cur, cur.fetchone())
    cur.close()
    conn.close()
    if not row or not bcrypt.checkpw(req.pin.encode(), row['pin_hash'].encode()):
        raise HTTPException(401, 'Nome ou PIN incorreto')
    return {'token': make_token(row['id'], row['nome']), 'nome': row['nome'], 'id': row['id']}

@app.post('/jornadas')
def criar_jornada(req: JornadaReq, u=Depends(current_user)):
    jid = str(uuid.uuid4())
    conn = db()
    cur = conn.cursor()
    cur.execute("""
        INSERT INTO jornadas
            (id, usuario_id, usuario_nome, data, km, horas, faturamento,
             ganho_por_km, ganho_por_hora, apps_json, criado_em)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
    """, (
        jid, u['id'], u['nome'], req.data,
        req.km, req.horas, req.faturamento,
        req.ganho_por_km, req.ganho_por_hora,
        req.apps_json, datetime.utcnow().isoformat()
    ))
    conn.commit()
    cur.close()
    conn.close()
    return {'id': jid, 'message': 'Jornada salva'}

@app.get('/jornadas/minhas')
def minhas_jornadas(u=Depends(current_user)):
    conn = db()
    cur = conn.cursor()
    cur.execute(
        'SELECT * FROM jornadas WHERE usuario_id = %s ORDER BY data DESC',
        (u['id'],)
    )
    result = rows_to_list(cur, cur.fetchall())
    cur.close()
    conn.close()
    return result

@app.put('/jornadas/{jid}')
def editar_jornada(jid: str, req: JornadaUpdate, u=Depends(current_user)):
    conn = db()
    cur = conn.cursor()
    cur.execute('SELECT * FROM jornadas WHERE id = %s', (jid,))
    row = row_to_dict(cur, cur.fetchone())
    if not row:
        cur.close()
        conn.close()
        raise HTTPException(404, 'Jornada não encontrada')
    if row['usuario_id'] != u['id']:
        cur.close()
        conn.close()
        raise HTTPException(403, 'Sem permissão')
    ups = {k: v for k, v in req.model_dump().items() if v is not None}
    if ups:
        sql = 'UPDATE jornadas SET ' + ', '.join(f'{k}=%s' for k in ups) + ' WHERE id=%s'
        cur.execute(sql, list(ups.values()) + [jid])
        conn.commit()
    cur.close()
    conn.close()
    return {'message': 'Atualizado'}

@app.delete('/jornadas/{jid}')
def deletar_jornada(jid: str, u=Depends(current_user)):
    conn = db()
    cur = conn.cursor()
    cur.execute('SELECT * FROM jornadas WHERE id = %s', (jid,))
    row = row_to_dict(cur, cur.fetchone())
    if not row:
        cur.close()
        conn.close()
        raise HTTPException(404, 'Não encontrada')
    if row['usuario_id'] != u['id']:
        cur.close()
        conn.close()
        raise HTTPException(403, 'Sem permissão')
    cur.execute('DELETE FROM jornadas WHERE id = %s', (jid,))
    conn.commit()
    cur.close()
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
    def stats(nome: str, conn):
        cur = conn.cursor()
        cur.execute("""
            SELECT
                COALESCE(SUM(faturamento), 0)  AS total_faturamento,
                COALESCE(SUM(km), 0)           AS total_km,
                COALESCE(SUM(horas), 0)        AS total_horas,
                CASE WHEN SUM(km)    > 0 THEN SUM(faturamento) / SUM(km)    ELSE 0 END AS ganho_km,
                CASE WHEN SUM(horas) > 0 THEN SUM(faturamento) / SUM(horas) ELSE 0 END AS ganho_hora,
                COUNT(*)                       AS total_jornadas
            FROM jornadas
            WHERE LOWER(usuario_nome) = LOWER(%s)
              AND data >= %s AND data <= %s
        """, (nome, desde, ate))
        row = row_to_dict(cur, cur.fetchone())
        cur.close()
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
    cur = conn.cursor()
    cur.execute("""
        SELECT
            usuario_nome,
            SUM(faturamento)  AS total_faturamento,
            SUM(km)           AS total_km,
            SUM(horas)        AS total_horas,
            CASE WHEN SUM(km)    > 0 THEN SUM(faturamento) / SUM(km)    ELSE 0 END AS ganho_km,
            CASE WHEN SUM(horas) > 0 THEN SUM(faturamento) / SUM(horas) ELSE 0 END AS ganho_hora,
            COUNT(*)          AS total_jornadas
        FROM jornadas
        WHERE data >= %s
        GROUP BY usuario_id, usuario_nome
        ORDER BY total_faturamento DESC
    """, (desde,))
    result = rows_to_list(cur, cur.fetchall())
    cur.close()
    conn.close()
    return result
