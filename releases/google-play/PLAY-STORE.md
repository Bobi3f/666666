# FIRST GEAR — что заполнить в Google Play Console

Аккаунт: https://play.google.com/console → регистрация **личного** аккаунта
разработчика ($25 один раз, проверка паспорта). Дальше — **Create app**.

## 1. Создание приложения

| Поле | Что вписать |
|---|---|
| App name | `FIRST GEAR: Життя в селі` |
| Default language | Ukrainian – uk-UA |
| App or game | Game |
| Free or paid | Free |

## 2. Store listing (основной — украинский; добавить переводы ru-RU и en-US)

**App name** (до 30 символов)
- uk: `FIRST GEAR: Життя в селі`
- ru: `FIRST GEAR: Жизнь в селе`
- en: `FIRST GEAR: Village Life`

**Short description** (до 80 символов)
- uk: `Життя в селі: робота, машини, свій дім, базар з торгом і чотири пори року`
- ru: `Жизнь в селе: работа, машины, свой дом, базар с торгом и четыре времени года`
- en: `Village life sim: jobs, cars, your own house, a bazaar and four seasons`

**Full description** — тексты из `releases/itch/ITCH-PAGE.md` (украинский, русский,
английский блоки) — подходят как есть.

**Графика**
- App icon 512×512: `releases/google-play/icon-512.png`
- Feature graphic 1024×500: `releases/google-play/feature-1024x500.png`
- Phone screenshots (2–8 шт.): `releases/google-play/screenshots/` — для
  украинской страницы первыми поставить `7-bazaar-uk.png` и `8-menu-uk.png`.

**Категория:** Game → Simulation. **Теги:** Simulation, Driving, Open world, Life sim.

**Contact details:** свой email (обязательно). Website можно
`https://bobi3f.github.io/666666/`.

## 3. App content (раздел «Policy»)

| Пункт | Ответ |
|---|---|
| Privacy policy | `https://bobi3f.github.io/666666/privacy.html` |
| App access | All functionality is available without special access |
| Ads | **No** (рекламы в игре нет; если добавим AdMob — поменять на Yes) |
| Content rating (IARC) | Category: Game. Насилие — нет (погоня милиции, без оружия). Страх — нет. Сексуальное — нет. Грубая речь — нет. Упоминания алкоголя — **да** (пиво, шампанское в разговорах). Азартные игры на виртуальные деньги — **да** (лотерея на ярмарке и спор с Колькой за игровые гривны). Реальные деньги — нет. Общение между игроками — нет. Обмен данными о местоположении — нет. |
| Target audience | 13+ (не «для детей») |
| News app | No |
| Data safety | Data collection: **No**, data sharing: **No** (игра ничего не отправляет — см. политику) |
| Government app / Financial features / Health | No |

## 4. Тестирование — обязательно для нового личного аккаунта

Google не пустит игру в общий доступ, пока **12 тестеров** не пробудут в
закрытом тесте **14 дней подряд**.
1. Testing → Closed testing → Create track, загрузить сборку (AAB).
2. Testers → список email (12+ человек с Android: друзья, родные).
3. Разослать им ссылку на тест — каждый должен нажать «Стать тестировщиком»
   и установить игру.
4. Через 14 дней — Production → Apply for production access.

## 5. Сборка AAB

Google Play принимает только AAB, и с 31 августа 2026 новые игры должны
быть собраны под Android 16 (API 36). В моей среде нужный для этого адрес
`dl.google.com` закрыт — открой его в настройках сети среды (Allowed domains)
и скажи мне: соберу `FirstGear.aab` сам.
