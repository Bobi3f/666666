# Оплата GEARCOIN через Pi Network

Игра продаёт пакеты GEARCOIN за Pi (π). Платить можно только в **Pi Browser**.
Каждый платёж проверяет и подтверждает сервер игры секретным ключом приложения
Pi — поэтому игре нужен свой маленький сервер. Он бесплатный: **Cloudflare Pages**
отдаёт игру и подтверждает платежи на одном адресе (например,
`https://firstgear.pages.dev`).

Что где лежит:

| Файл | Что делает |
|---|---|
| `docs/pi.js` | Подключает Pi SDK в Pi Browser, открывает оплату, передаёт результат игре |
| `scripts/ui/gear_shop.gd` | Окно GEARCOIN: в Pi Browser цены в π, монеты — после подтверждения |
| `server/cloudflare/functions/api/pi/[[route]].js` | Сервер: проверяет пакет и сумму, одобряет и завершает платёж |
| `tools/build_pi_site.sh` | Собирает сайт для Cloudflare (игра + сервер) |

Цены пакетов в Pi записаны в трёх местах — `docs/pi.js`, сервер и
`gear_shop.gd` (`PI_PRICES`). Меняешь цену — меняй везде, тест `test_pi`
проверит, что совпадает.

## Шаг 1. Приложение в Pi Developer Portal

1. Установи **Pi Browser** и войди в свой аккаунт Pi.
2. В Pi Browser открой `develop.pi` → **New App**.
3. Название — FIRST GEAR. Сеть — сначала **Testnet** (тестовые π, для проверки).
4. Хостинг — свой (не Pi-хостинг). Адрес приложения (App URL) впишешь после
   шага 2 — например `https://firstgear.pages.dev`.
5. В разделе **API Key** создай ключ (Server API Key) — он секретный, никому не
   показывай и не клади в репозиторий.
6. В разделе проверки домена портал покажет **validation key** — текст. Сохрани
   его в файл `server/cloudflare/validation-key.txt` (он не попадёт в git).

## Шаг 2. Сайт на Cloudflare Pages

Нужен бесплатный аккаунт Cloudflare и Node.js на компьютере.

```bash
bash tools/build_pi_site.sh
cd server/cloudflare
npx wrangler login
npx wrangler pages deploy public --project-name firstgear
npx wrangler pages secret put PI_API_KEY --project-name firstgear   # вставь Server API Key
npx wrangler pages deploy public --project-name firstgear           # ещё раз, чтобы ключ подхватился
```

Проверка: `https://firstgear.pages.dev/api/pi/ping` должен ответить `{"ok":true}`.

## Шаг 3. Домен и проверка в Pi Browser

1. В Developer Portal впиши App URL `https://firstgear.pages.dev` и нажми проверку
   домена (validation key уже лежит в корне сайта).
2. Открой приложение в Pi Browser → меню → **GEARCOIN** → вкладка «Купить монеты».
   Должна быть надпись «Оплата Pi Network — вход: @твоё_имя» и цены в π.
3. Купи пакет тестовыми π — монеты придут, игра сохранится.

## Шаг 4. Настоящие π (Mainnet)

Когда всё работает на Testnet — в портале переключи приложение на **Mainnet**
и пройди проверку Pi Core Team (их чек-лист в портале). Код менять не нужно.

## Важно

- На GitHub Pages (`bobi3f.github.io/666666`) сервера нет — там оплата Pi не
  показывается, игра работает как раньше.
- Монеты хранятся в сохранении на устройстве игрока, как и всё остальное.
- Если оплата прошла, а связь оборвалась, — при следующем входе в Pi Browser
  незавершённый платёж засчитается сам.
