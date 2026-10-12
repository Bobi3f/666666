// FIRST GEAR — оплата GEARCOIN через Pi Network (только в Pi Browser).
//
// Игра (Godot) зовёт window.FirstGearPi через JavaScriptBridge:
//   status() — готово ли, кто вошёл, ошибка (JSON-строка);
//   buy(pack) — купить пакет №pack (0–5), цена — в PI_PACKS ниже;
//   take()    — забрать готовые результаты (JSON-массив) и очистить очередь.
// Каждый платёж подтверждает наш сервер (Cloudflare Pages Functions,
// server/cloudflare/functions/api/pi): секретный ключ Pi хранится только там.
// Монеты игра начисляет, лишь когда сервер ответил, что платёж завершён.
(function () {
  // Пакеты: [цена в Pi, монет]. Те же цифры — в gear_shop.gd (PI_PRICES)
  // и на сервере ([[route]].js) — тест сверяет, что везде одинаково.
  var PI_PACKS = [[0.5, 100], [2, 500], [4, 1200], [10, 3000], [20, 7500], [35, 15000]];
  var cfg = window.FIRSTGEAR_PI || {};
  var api = cfg.api || "api/pi";
  var state = { ready: false, user: "", error: "", busy: false, results: [] };

  function post(path, body) {
    return fetch(api + "/" + path, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body)
    }).then(function (r) {
      if (!r.ok) throw new Error("сервер ответил " + r.status);
      return r.json();
    });
  }

  function done(paymentId, txid) {
    return post("complete", { paymentId: paymentId, txid: txid }).then(function (p) {
      state.results.push({ id: paymentId, pack: p.pack, coins: p.coins, ok: true });
    });
  }

  window.FirstGearPi = {
    packs: PI_PACKS,
    status: function () {
      return JSON.stringify({ ready: state.ready, user: state.user, error: state.error, busy: state.busy });
    },
    take: function () {
      var r = state.results;
      state.results = [];
      return JSON.stringify(r);
    },
    buy: function (pack) {
      if (!state.ready || state.busy || !PI_PACKS[pack]) return false;
      state.busy = true;
      state.error = "";
      window.Pi.createPayment({
        amount: PI_PACKS[pack][0],
        memo: "FIRST GEAR: " + PI_PACKS[pack][1] + " GEARCOIN",
        metadata: { pack: pack }
      }, {
        onReadyForServerApproval: function (paymentId) {
          post("approve", { paymentId: paymentId }).catch(function (e) {
            state.error = "Сервер не подтвердил оплату: " + e.message;
            state.busy = false;
          });
        },
        onReadyForServerCompletion: function (paymentId, txid) {
          done(paymentId, txid).catch(function (e) {
            state.error = "Оплата прошла, но сервер её не засчитал: " + e.message + ". Откройте игру снова — засчитается";
          }).then(function () { state.busy = false; });
        },
        onCancel: function () {
          state.results.push({ cancel: true });
          state.busy = false;
        },
        onError: function (e) {
          state.error = String((e && e.message) || e);
          state.busy = false;
        }
      });
      return true;
    }
  };

  // Только в Pi Browser (или ?pi=1 — проверить страницу в обычном браузере)
  if (!/PiBrowser/i.test(navigator.userAgent) && !/[?&]pi=1/.test(location.search)) return;
  var s = document.createElement("script");
  s.src = "https://sdk.minepi.com/pi-sdk.js";
  s.onload = function () {
    try {
      window.Pi.init({ version: "2.0", sandbox: !!cfg.sandbox });
      // Незавершённый платёж с прошлого раза (закрыли игру посреди оплаты)
      var incomplete = function (payment) {
        if (payment && payment.transaction && payment.transaction.txid) {
          done(payment.identifier, payment.transaction.txid).catch(function () {});
        }
      };
      window.Pi.authenticate(["username", "payments"], incomplete).then(function (auth) {
        state.user = (auth && auth.user && auth.user.username) || "";
        // Сервер на месте? Без него платёж не завершить — тогда кнопок Pi нет
        return fetch(api + "/ping").then(function (r) { state.ready = r.ok; if (!r.ok) state.error = "нет сервера оплаты"; });
      }).catch(function (e) {
        state.error = String((e && e.message) || e);
      });
    } catch (e) {
      state.error = String(e);
    }
  };
  s.onerror = function () { state.error = "не загрузился Pi SDK"; };
  document.head.appendChild(s);
})();
