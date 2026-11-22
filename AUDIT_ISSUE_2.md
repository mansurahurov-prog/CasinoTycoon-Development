# Аудит репозитория Casino Tycoon — Issue #2

**Дата:** 2026-11-22  
**Ветка:** `agent/issue-2-audit` от `main` @ `a43141c`  
**Режим:** только чтение. Roblox Studio MCP: Edit DataModel, сессия `CasinoTycoon_before_Rojo_Sync.rbxl`.
Sync, Play Mode, `save_place` и публикация не запускались; игровые скрипты не изменялись.

## Итог

Код в репозитории и дерево Studio согласованы: 16 объектов, классы совпадают с Rojo-разметкой,
`Plot_1`–`Plot_4` на месте. Главная проблема — документация: `CASINO_TYCOON_STATE.md` и
`AUTONOMOUS_PROGRESS.md` описывают разные срезы проекта, часть утверждений уже неверна.
Дополнительно чтением кода найдены два дефекта сохранения денег и чеков (P0/P1), которых нет в заметках.
Рекомендуемая первая задача — `CasinoTycoonMonetization`: потеря купленных чипов при выдаче до загрузки профиля
и идемпотентность чеков только в памяти сервера.

## 1. Зафиксированный baseline

| Область | Объекты | Классы |
| --- | --- | --- |
| `ServerScriptService` | `PlotOwnership`, `CasinoTycoonEconomy`, `HotelTiers`, `Guests`, `Persistence`, `Milestones`, `FountainTip`, `LuckyHour`, `DecorUpgrades`, `Monetization`, `Leaderboard`, `Slots`, `VIPs` | 13 × `Script` |
| `ServerScriptService` | `CasinoTycoonData` | `ModuleScript` |
| `ReplicatedStorage` | `CasinoTycoonShopConfig` | `ModuleScript` |
| `StarterPlayer.StarterPlayerScripts` | `CasinoTycoonHUD` | `LocalScript` |

- В Studio нет лишних детей в этих контейнерах; `rojo sourcemap` даёт те же 16 объектов (13/2/1).
- `Workspace.CasinoTycoon.Plots.Plot_1`…`Plot_4` существуют: `PlotId` = 1…4, `OwnerUserId` = 0, по 16 прямых детей.
- `ServerStorage.__Backups_Phase1` — 14 детей (13 `Script` + 1 `LocalScript`); не изменялся и не читался.

## 2. Расхождения документации с фактическим состоянием

| Где | Утверждение | Факт | Доказательство |
| --- | --- | --- | --- |
| `CASINO_TYCOON_STATE.md:3` | Studio = `Place1`, файл `CasinoTycoon_Backup.rbxl` | Открыт `CasinoTycoon_before_Rojo_Sync.rbxl`; файла `CasinoTycoon_Backup.rbxl` в репозитории нет | `list_roblox_studios`; в корне 5 других `.rbxl` |
| `CASINO_TYCOON_STATE.md:7` | `MainVolume` непрозрачный, `CanCollide=true`, блокирует интерьер | `Transparency=1`, `CanCollide=false`, `CanQuery=false`, `CanTouch=false`; размер 108×25×76 и центр (0,16,0) совпадают | `inspect_instance` |
| `CASINO_TYCOON_STATE.md:23` | «Других игровых систем… не найдено; `ReplicatedStorage` пуст» | В `ReplicatedStorage` есть `CasinoTycoonShopConfig`; в `ServerScriptService` 14 серверных скриптов (13 `Script` + 1 `ModuleScript`) | дерево Studio; `src/**` |
| `CASINO_TYCOON_STATE.md:25` | Папки `GrandLobby` пустые | Заполнены: `MainVolumeFloor_2026_11_18`, `MainVolumeWalls_2026_11_18`, `GrandLobbyReceptionDesk_2026_11_18`, `GrandLobbyDecor_2026_11_18`, плюс `LuxuryPass_2026_11_19` | `search_game_tree` |
| `CASINO_TYCOON_STATE.md:39` | `PlotOwnership` «не менялся» | `PlotOwnership.server.luau:2` требует `CasinoTycoonData`; `:173` сбрасывает декор; `:211` снимает снимок участка | исходник |
| `CASINO_TYCOON_STATE.md:44` | Сессионная экономика, «нет DataStore/RemoteEvents» | `CasinoTycoonData:4,6,210,322` использует `DataStoreService`/`UpdateAsync`; `CasinoTycoonLeaderboard:107` — DataStore; `CasinoTycoonEconomy:199-210` создаёт `RemoteEvent` | исходники |
| `CASINO_TYCOON_STATE.md:50` | Очередь: «решить вопрос о сохранении данных» | Профиль v2 с session-lock, autosave 45 с и `BindToClose` уже реализован | `CasinoTycoonData:9-10,522-549` |
| `CASINO_TYCOON_STATE.md` (весь файл) | Не описаны объекты 2026-11-19 | У каждого участка есть `PlotLuxuryTrim_2026_11_19`, `PlotEntry_2026_11_19`, `SignLuxury_2026_11_19`, `PlotBalustrade_2026_11_19`, `PlotAmenities_2026_11_19`; у `Plot_1/2` — `PlotBorder_Back_B`, у `Plot_3/4` — `PlotBorder_Front_B` (симметрично по ряду); в `CentralDistrict` — `ArrivalLuxury_2026_11_19`; в `ServerStorage` — `CasinoTycoon_Backup_2026_11_19` | дерево Studio |
| `AUTONOMOUS_PROGRESS.md:18` | Следующая задача №2 — игровой луп ставок | Базовый автомат уже реализован | `CasinoTycoonSlots.server.luau:6-8,57-109` (ставка 50, джекпот 500) |
| `AUTONOMOUS_PROGRESS.md:19` | Следующая задача №3 — монетизация | Каркас есть, но отключён: все `id = 0`, `vip = 0` | `CasinoTycoonShopConfig.luau:7-9,14`; HUD показывает `NOT IN STORE` (`:651-656`) |
| `AUTONOMOUS_PROGRESS.md:20` | Следующая задача №4 — Leaderboard на OrderedDataStore | Реализован на обычном DataStore, не на `OrderedDataStore` | `CasinoTycoonLeaderboard.server.luau:107,122,150` |

SHA-256 локальных place-файлов совпадают с заявленными в `CASINO_TYCOON_STATE.md` для `preMainVolume`,
`preHotelTiers` и `preGuestPolish`. Для `CasinoTycoon_copy_20261118.rbxl` хеш в заметках не указан.

## 3. Что нельзя подтвердить из репозитория

- Результаты прошлых Playtest (покупки, выплаты, маршруты NPC): логов и тестов в репозитории нет.
- Поведение `DataStore` в опубликованном месте и лимиты запросов: локальный Edit этого не показывает.
- Точные зазоры и проходимость геометрии: проверены только наличие объектов, классы и несколько ключевых свойств.
- Визуальное качество UI и декора: скриншоты и Play Mode в этом аудите не использовались.
- `Output` Studio: `get_console_output` завершился таймаутом 300 с, результат не получен.

## 4. Риски в коде (найдены чтением, не исправлялись)

**P0 — потеря купленных чипов.** `CasinoTycoonMonetization.server.luau:27-52` начисляет `cash.Value` сразу по чеку,
не дожидаясь профиля. `CasinoTycoonData.server.luau` при загрузке перезаписывает `IntValue` значением из профиля
(`:288`, `publishCash`). Покупка, пришедшая до `CashLoaded`, теряется безвозвратно: чек уже помечен выданным (`:49`).

**P1 — идемпотентность чеков только в памяти.** `processed` (`:16`) живёт до рестарта сервера; `Data.AddReceipt` и
`Data.GetReceipts` (`CasinoTycoonData.server.luau:482-513`) нигде не вызываются. После рестарта повторный чек может
начислить чипы второй раз, хотя документация обещает «идемпотентные receipt через PurchaseIds».

**P1 — `BindToClose` не сохраняет состояние участка.** `CasinoTycoonData.server.luau:534-549` пишет профиль, но не
делает `SnapshotPlot`/`SetPlotSnapshot`. Снимок участка снимается только в `PlotOwnership:206-225` при `PlayerRemoving`.
Если при остановке сервера `PlayerRemoving` не отработает, последние покупки и `DecorTier` могут не сохраниться.

**P2 — гонки Leaderboard.** Каждый сервер делает `SetAsync("Top", merged)` (`CasinoTycoonLeaderboard:150`) без блокировки;
параллельные записи теряют результаты. Ключ таблицы — `DisplayName` (`:84,:131`), возможны совпадения имён.

**P2 — утечка `claiming`.** `PlotOwnership:119-147` заполняет `claiming[player]`, но `PlayerRemoving` (`:206-225`) не удаляет ключ.

**P3 — `Slots` использует `math.random`** (`CasinoTycoonSlots:26`) без собственного `Random`-объекта: результат нельзя
воспроизвести или проверить по seed.

## 5. Рекомендуемая первая задача

### `CasinoTycoonMonetization`: дождаться профиля и хранить чеки в профиле

**Почему она первая.** Это единственный найденный путь, где покупка игрока может быть потеряна полностью,
а исправление локально: один серверный скрипт, без геометрии, без `PlotOwnership` и без миграций.

**Область изменений**
- `src/ServerScriptService/CasinoTycoonMonetization.server.luau` — единственный файл.
- Использовать существующие `CasinoTycoonData.WaitReady` и `CasinoTycoonData.AddReceipt/GetReceipts`.
- Не менять `CasinoTycoonData`, `PlotOwnership`, `CasinoTycoonShopConfig` и UI.

**Критерии готовности**
1. `ProcessReceipt` не начисляет чипы, пока профиль не готов, и возвращает `NotProcessedYet` без пометки чека.
2. Обработанный `PurchaseId` сохраняется в профиле и переживает рестарт сервера.
3. Повторный вызов с тем же `PurchaseId` возвращает `PurchaseGranted` и не начисляет чипы второй раз.
4. Неизвестный `ProductId` по-прежнему возвращает `NotProcessedYet`.
5. При `id = 0` в конфиге поведение не меняется: покупка недоступна.
6. Начисление не выходит за `MAX_CASH` (`CasinoTycoonData:14`).

**Риски**
- Новая зависимость от `CasinoTycoonData`: ошибка `require` заблокирует выдачу товаров. Нужен безопасный fallback на `NotProcessedYet`.
- `ProcessReceipt` обязан всегда возвращать решение; нельзя оставлять ветку без `return`.
- Запись чека должна идти после успешного начисления, иначе возможна потеря покупки.
- Проверить в Studio нельзя: все продукты имеют `id = 0`. Нужны реальные id после публикации.

**Проверки**
- Статические: `rojo sourcemap`, поиск вызовов `AddReceipt`/`GetReceipts`, проверка единственного `ProcessReceipt` в проекте.
- Ручные (после публикации): покупка пака, рестарт сервера, повторная доставка чека, сверка баланса и `PurchaseIds`.

**Откат:** вернуть один файл из резервной копии; данные игроков не затрагиваются.

## 6. Что фактически проверено

- `git status`, `git log`, `git ls-tree origin/main` — дерево чистое, `main` = `a43141c`.
- Чтение всех 16 `.luau` (полный Source); классы сверены с деревом Studio и `rojo sourcemap` (13/2/1).
- `list_roblox_studios`, `get_studio_state`, `search_game_tree`, `inspect_instance` — только чтение.
- SHA-256 пяти локальных `.rbxl`; три хеша совпали с документацией.

Не проверено: Playtest, DataStore в опубликованном месте, коллизии «на ощупь», визуальный вид, `Output` Studio.

## 7. Ручные шаги владельца

1. Решить, нужен ли отдельный PR на исправление `CasinoTycoonMonetization` по плану выше.
2. После публикации заполнить `id` продуктов и `vip` в `CasinoTycoonShopConfig` (не в рамках аудита).
3. Подтвердить, какой `.rbxl` считать целевым перед первой синхронизацией Rojo.
