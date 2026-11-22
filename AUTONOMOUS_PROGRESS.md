# Casino Tycoon — прогресс автономной разработки

## Этап 1 — фундамент экономики и состояния участков (ЗАВЕРШЁН)
Сделано:
- Новый серверный ModuleScript ServerScriptService.CasinoTycoonData: профиль v2 (Cash, Plots по PlotId, StreakDays, LastBonusDay, PurchaseIds, Milestones), UpdateAsync, session-lock (TTL 120с), autosave 45с, BindToClose.
- Legacy-миграция CasinoTycoonCash_v1 -> v2 с переносом снимков участка по имени на PlotId.
- Studio-fallback: memory-backend, чтобы сохранять/восстанавливать прогресс до публикации места.
- PlotOwnership переписан: выдача по сохранённому PlotId -> иначе первый свободный; снимок атрибутов до освобождения; сохранение и снятие lock после release; сохранены NameSign, очередь, 4 участка.
- CasinoTycoonPersistence сокращён до daily-бонуса (250 + 100×streak, max 5).
- Economy и HotelTiers пересобирают suite/restaurant/spa при восстановлении; DecorUpgrades строит по DecorTier.
- Милстоуны пишутся в профиль и не выплачиваются повторно при restore (проверено).
- Гейт CashLoaded в Economy, HotelTiers, DecorUpgrades, Slots. Утечка Slots.cooldowns закрыта.

Проверено playtest: модуль компилируется, участок выдаётся, CashLoaded=true, daily +250, save->reload возвращает suite/DecorTier, комнаты пересобираются, повторных выплат нет.
Ограничение: DataStore недоступен на локальном .rbxl, работает memory-fallback.

## Следующие задачи
Актуализировано по аудиту Issue #2 (2026-11-22): см. `AUDIT_ISSUE_2.md`.
2. Игровой луп ставок: базовый автомат уже в `CasinoTycoonSlots` (ставка 50, джекпот 500). Осталось: конфиг столов, BetRequest/BetResult, выбор ставки, лимиты, кулдауны.
3. Монетизация: каркас в `CasinoTycoonMonetization`/`CasinoTycoonVIPs`, все id в `CasinoTycoonShopConfig` равны 0. Блокер: реальные id после публикации. Первый дефект к исправлению — выдача до загрузки профиля и сохранение `PurchaseIds`.
4. Leaderboard: работает на `DataStore` `CasinoTycoonBoard_v1` (не `OrderedDataStore`). Осталось: устойчивость к гонкам и телеметрия.
5. Визуал, NPC, UI/mobile, туториал, удержание, баланс, оптимизация.

## Изменённые объекты
CasinoTycoonData (новый), PlotOwnership, CasinoTycoonPersistence (переписаны), CasinoTycoonEconomy, CasinoTycoonHotelTiers, CasinoTycoonDecorUpgrades, CasinoTycoonSlots, CasinoTycoonMilestones (правки).
Резервная копия исходников: ServerStorage.__Backups_Phase1 (14 скриптов).

## Состояние на момент сохранения
- Place сохранён в `CasinoTycoon_copy_20261118.rbxl` в корне репозитория (локальный файл, не опубликован).
- Playtest остановлен, Studio в Edit.
- Бэкап исходных скриптов: ServerStorage.__Backups_Phase1 (14 скриптов).
- Краткий статус продублирован в ServerStorage.AUTONOMOUS_PROGRESS.
