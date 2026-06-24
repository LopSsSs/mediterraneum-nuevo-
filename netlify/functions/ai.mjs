// El modelo y los límites se fijan aquí, no los decide el cliente
const MODEL = 'gemini-2.5-flash';
const MAX_TOKENS = 4096;

// Orígenes permitidos. El dominio principal de Netlify, cualquier deploy
// o preview *.netlify.app, y opcionalmente un dominio propio que se puede
// configurar en Netlify → Site settings → Environment variables → SITE_ORIGIN.
function isAllowedOrigin(origin) {
  if (!origin) return false;
  if (process.env.SITE_ORIGIN && origin === process.env.SITE_ORIGIN) return true;
  try {
    const { hostname } = new URL(origin);
    if (hostname === 'mediterraneum.netlify.app') return true;
    if (hostname.endsWith('.netlify.app')) return true;
  } catch {
    /* el origen no es una URL válida */
  }
  return false;
}

// Cabeceras CORS que DEVUELVEN el origen real de la petición. Si se devuelve
// un origen fijo distinto al de la web, el navegador bloquea la respuesta y el
// frontend lo ve como un "error de conexión".
function corsFor(origin) {
  return {
    'Access-Control-Allow-Origin': origin || '*',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    Vary: 'Origin',
  };
}

export async function handler(event) {
  const origin = event.headers.origin || event.headers.Origin || '';
  const cors = corsFor(origin);

  if (event.httpMethod === 'OPTIONS') {
    return { statusCode: 200, headers: cors, body: '' };
  }

  if (event.httpMethod !== 'POST') {
    return { statusCode: 405, headers: cors, body: 'Method Not Allowed' };
  }

  // Rechaza peticiones que no vengan de tu web
  if (!isAllowedOrigin(origin)) {
    return {
      statusCode: 403,
      headers: { ...cors, 'Content-Type': 'application/json' },
      body: JSON.stringify({ type: 'error', error: { message: 'Origen no permitido' } }),
    };
  }

  // Avisa con claridad si falta la clave en el servidor (causa habitual del fallo)
  if (!process.env.GEMINI_API_KEY) {
    return {
      statusCode: 500,
      headers: { ...cors, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        type: 'error',
        error: {
          message:
            'Falta la clave GEMINI_API_KEY en el servidor. Configúrala en Netlify → Site settings → Environment variables.',
        },
      }),
    };
  }

  let body;
  try {
    body = JSON.parse(event.body);
  } catch {
    return {
      statusCode: 400,
      headers: { ...cors, 'Content-Type': 'application/json' },
      body: JSON.stringify({ type: 'error', error: { message: 'JSON inválido' } }),
    };
  }

  // Solo se acepta el array de mensajes y un system opcional del cliente
  if (!Array.isArray(body.messages) || body.messages.length === 0) {
    return {
      statusCode: 400,
      headers: { ...cors, 'Content-Type': 'application/json' },
      body: JSON.stringify({ type: 'error', error: { message: 'Falta el campo messages' } }),
    };
  }

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
  if (typeof body.system === 'string') {
    payload.system_instruction = { parts: [{ text: body.system }] };
  }

  try {
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${process.env.GEMINI_API_KEY}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      }
    );

    const data = await response.json();

    if (data.error) {
      return {
        statusCode: response.status,
        headers: { ...cors, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          type: 'error',
          error: { message: data.error.message || 'Error de Gemini' },
        }),
      };
    }

    // Normaliza la respuesta al formato {content:[{type:'text',text}]} que espera el frontend
    const text = data.candidates?.[0]?.content?.parts?.[0]?.text || '';

    return {
      statusCode: 200,
      headers: { ...cors, 'Content-Type': 'application/json' },
      body: JSON.stringify({ content: [{ type: 'text', text }] }),
    };
  } catch (err) {
    return {
      statusCode: 500,
      headers: { ...cors, 'Content-Type': 'application/json' },
      body: JSON.stringify({ type: 'error', error: { message: err.message } }),
    };
  }
}
