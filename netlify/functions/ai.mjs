// El modelo y los límites se fijan aquí, no los decide el cliente
const MODEL = 'gemini-2.5-flash';
const MAX_TOKENS = 4096;
const MAX_BODY = 1_000_000; // 1 MB: de sobra para el snapshot del asistente
// Proyecto Supabase contra el que se valida la sesión del usuario
const SUPABASE_URL = process.env.SUPABASE_URL || 'https://cenjzfuywziffieawosj.supabase.co';

// Solo la web oficial (y sus deploy previews de Netlify) pueden llamar a la IA.
// Un dominio propio se puede añadir en Netlify → Environment variables → SITE_ORIGIN.
function isAllowedOrigin(origin) {
  if (!origin) return false;
  if (process.env.SITE_ORIGIN && origin === process.env.SITE_ORIGIN) return true;
  try {
    const { hostname } = new URL(origin);
    return hostname === 'mediterraneum.netlify.app' || hostname.endsWith('--mediterraneum.netlify.app');
  } catch {
    return false; // el origen no es una URL válida
  }
}

// Cabeceras CORS que devuelven el origen real de la petición (si se devuelve un
// origen fijo distinto, el navegador bloquea la respuesta como "error de conexión")
function corsFor(origin) {
  return {
    'Access-Control-Allow-Origin': origin || '*',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization, apikey',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    Vary: 'Origin',
  };
}

const errorRes = (statusCode, cors, message) => ({
  statusCode,
  headers: { ...cors, 'Content-Type': 'application/json' },
  body: JSON.stringify({ type: 'error', error: { message } }),
});

// Comprueba contra Supabase que la petición viene de un usuario con sesión válida.
// Sin esto, cualquiera podría gastar la cuota de Gemini llamando a /api/ai.
async function sesionValida(headers) {
  const token = (headers.authorization || headers.Authorization || '').replace(/^Bearer\s+/i, '');
  const apikey = headers.apikey || '';
  if (!token || !apikey) return false;
  try {
    const r = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
      headers: { apikey, Authorization: `Bearer ${token}` },
    });
    return r.ok;
  } catch {
    return false;
  }
}

export async function handler(event) {
  const origin = event.headers.origin || event.headers.Origin || '';
  const cors = corsFor(origin);

  if (event.httpMethod === 'OPTIONS') return { statusCode: 200, headers: cors, body: '' };
  if (event.httpMethod !== 'POST') return errorRes(405, cors, 'Method Not Allowed');
  if (!isAllowedOrigin(origin)) return errorRes(403, cors, 'Origen no permitido');
  if ((event.body || '').length > MAX_BODY) return errorRes(413, cors, 'Petición demasiado grande');
  if (!process.env.GEMINI_API_KEY)
    return errorRes(500, cors, 'Falta la clave GEMINI_API_KEY en el servidor. Configúrala en Netlify → Site settings → Environment variables.');
  if (!(await sesionValida(event.headers)))
    return errorRes(401, cors, 'Sesión no válida. Inicia sesión de nuevo (o pulsa "Actualizar" si la app te lo ofrece).');

  let body;
  try {
    body = JSON.parse(event.body);
  } catch {
    return errorRes(400, cors, 'JSON inválido');
  }

  // Solo se acepta el array de mensajes y un system opcional del cliente
  if (!Array.isArray(body.messages) || body.messages.length === 0)
    return errorRes(400, cors, 'Falta el campo messages');

  // Traduce los mensajes {role: user|assistant, content} al formato de Gemini
  const contents = body.messages.map((m) => ({
    role: m.role === 'assistant' ? 'model' : 'user',
    parts: [{ text: String(m.content) }],
  }));

  const payload = {
    contents,
    // thinkingBudget 0: en gemini-2.5-flash el "razonamiento interno" consume
    // tokens del límite de salida; lo desactivamos para respuestas completas
    generationConfig: {
      maxOutputTokens: MAX_TOKENS,
      temperature: 0.7,
      thinkingConfig: { thinkingBudget: 0 },
    },
  };
  if (typeof body.system === 'string') payload.system_instruction = { parts: [{ text: body.system }] };

  try {
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${process.env.GEMINI_API_KEY}`,
      { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) }
    );
    const data = await response.json();
    if (data.error) return errorRes(response.status, cors, data.error.message || 'Error de Gemini');

    // Normaliza la respuesta al formato {content:[{type:'text',text}]} que espera el frontend
    const text = data.candidates?.[0]?.content?.parts?.[0]?.text || '';
    return {
      statusCode: 200,
      headers: { ...cors, 'Content-Type': 'application/json' },
      body: JSON.stringify({ content: [{ type: 'text', text }] }),
    };
  } catch (err) {
    return errorRes(500, cors, err.message);
  }
}
