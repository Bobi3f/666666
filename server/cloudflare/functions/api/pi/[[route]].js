// FIRST GEAR — сервер оплаты Pi Network (Cloudflare Pages Functions).
//
// Адреса (их зовёт docs/pi.js из Pi Browser):
//   GET  /api/pi/ping      — сервер на месте;
//   POST /api/pi/approve   {paymentId}        — проверить и одобрить платёж;
//   POST /api/pi/complete  {paymentId, txid}  — завершить, ответ {pack, coins}.
// Секретный ключ приложения Pi — переменная окружения PI_API_KEY (в
// настройках Cloudflare Pages → Settings → Environment variables, как Secret).
// В игру и в репозиторий ключ не попадает.

// Пакеты: [цена в Pi, монет] — те же, что в docs/pi.js и gear_shop.gd.
const PI_PACKS = [[0.5, 100], [2, 500], [4, 1200], [10, 3000], [20, 7500], [35, 15000]];
const PI_API = "https://api.minepi.com/v2";

function json(data, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: { "Content-Type": "application/json" } });
}

async function pi(env, method, path, body) {
  const r = await fetch(PI_API + path, {
    method,
    headers: { "Authorization": "Key " + env.PI_API_KEY, "Content-Type": "application/json" },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await r.text();
  let data = null;
  try { data = JSON.parse(text); } catch (e) { data = { raw: text }; }
  return { ok: r.ok, status: r.status, data };
}

// Платёж наш и сумма верная: пакет из списка, цена совпадает, не отменён.
function checkPayment(p) {
  const pack = p && p.metadata ? Number(p.metadata.pack) : -1;
  const def = PI_PACKS[pack];
  if (!def) return { error: "неизвестный пакет" };
  if (Math.abs(Number(p.amount) - def[0]) > 1e-7) return { error: "сумма не совпадает с ценой пакета" };
  if (p.status && (p.status.cancelled || p.status.user_cancelled)) return { error: "платёж отменён" };
  return { pack, coins: def[1] };
}

export async function onRequest(context) {
  const { request, env, params } = context;
  const route = (params.route || []).join("/");
  if (!env.PI_API_KEY) return json({ error: "на сервере не задан PI_API_KEY" }, 500);
  if (route === "ping") return json({ ok: true });
  if (request.method !== "POST") return json({ error: "нужен POST" }, 405);
  let body;
  try { body = await request.json(); } catch (e) { return json({ error: "плохой запрос" }, 400); }
  const id = String(body.paymentId || "");
  if (!/^[A-Za-z0-9_-]{6,128}$/.test(id)) return json({ error: "нет paymentId" }, 400);

  const got = await pi(env, "GET", "/payments/" + id);
  if (!got.ok) return json({ error: "платёж не найден", pi: got.data }, 404);
  const check = checkPayment(got.data);
  if (check.error) return json({ error: check.error }, 400);

  if (route === "approve") {
    const r = await pi(env, "POST", "/payments/" + id + "/approve");
    return r.ok ? json({ ok: true }) : json({ error: "Pi не одобрил", pi: r.data }, 502);
  }
  if (route === "complete") {
    const txid = String(body.txid || "");
    if (!/^[A-Za-z0-9]{10,128}$/.test(txid)) return json({ error: "нет txid" }, 400);
    // Уже завершён раньше (повторный запрос после обрыва связи) — просто ответить
    const already = got.data.status && got.data.status.developer_completed;
    if (!already) {
      const r = await pi(env, "POST", "/payments/" + id + "/complete", { txid });
      if (!r.ok) return json({ error: "Pi не завершил", pi: r.data }, 502);
    }
    return json({ ok: true, pack: check.pack, coins: check.coins });
  }
  return json({ error: "нет такого адреса" }, 404);
}
