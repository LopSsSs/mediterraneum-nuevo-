const ALLOWED_ORIGIN = 'https://mediterraneum.netlify.app';

// El modelo y los límites se fijan aquí, no los decide el cliente
const MODEL = 'gemini-2.5-flash';
const MAX_TOKENS = 4096;

const corsHeaders = {
  'Access-Control-Allow-Origin': ALLOWED_ORIGIN,
  'Access-Control-Allow-Headers': 'Content-Type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

export async function handler(event) {
  if (event.httpMethod === 'OPTIONS') {
    return { statusCode: 200, headers: corsHeaders, body: '' };
  }

  if (event.httpMethod !== 'POST') {
    return { statusCode: 405, headers: corsHeaders, body: 'Method Not Allowed' };
  }

  // Rechaza peticiones que no vengan de tu web
  const origin = event.headers.origin || event.headers.Origin || '';
  if (origin !== ALLOWED_ORIGIN) {
    return {
      statusCode: 403,
      headers: corsHeaders,
      body: JSON.stringify({ error: 'Origen no permitido' }),
    };
  }

  let body;
  try {
    body = JSON.parse(event.body);
  } catch {
    return {
      statusCode: 400,
      headers: corsHeaders,
      body: JSON.stringify({ error: 'JSON inválido' }),
    };
  }

  // Solo se acepta el array de mensajes y un system opcional del cliente
  if (!Array.isArray(body.messages) || body.messages.length === 0) {
    return {
      statusCode: 400,
      headers: corsHeaders,
      body: JSON.stringify({ error: 'Falta el campo messages' }),
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
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
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
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      body: JSON.stringify({ content: [{ type: 'text', text }] }),
    };
  } catch (err) {
    return {
      statusCode: 500,
      headers: corsHeaders,
      body: JSON.stringify({ type: 'error', error: { message: err.message } }),
    };
  }
}
