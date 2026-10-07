# winws2 — папка для zapret2

Здесь собрано всё, что специфично для движка **zapret2 / winws2.exe / Lua**.

## Файлы

- `modules\winws2.ps1` — модуль winws2:
  - `Find-Winws2LuaScripts`        — автопоиск `zapret-lib.lua` / `zapret-antidpi.lua`
  - `Test-Winws2Ready`             — проверка: exe, dll, lua
  - `Get-Winws2LuaInit`            — сборка `--lua-init=@...`
  - `Get-Winws2BlobDefs`           — сборка `--blob=имя=@{путь}` из `LuaBlobFile_*`
  - `New-Winws2StrategyCandidates` — генератор Lua-стратегий

- `ZapretManager2.ps1` — точка входа (magenta-меню)
- `config\settings.yml` — конфиг winws2 (отдельный от `us\winws`)

## Особенности синтаксиса zapret2

Порядок аргументов в стратегии:
--wf-* → --lua-init → --blob → --filter-* → --payload → --lua-desync


- `--payload=tls_client_hello` — обязателен для fake-функций TLS
- `--payload=quic_initial` — для QUIC/UDP
- `--payload=stun` — для STUN/UDP
- `repeats=N` — параметр функции `fake`, пишется через двоеточие
- `tls_mod=rnd,rndsni` — модификация фейкового TLS-пакета

## Запуск

`start2.bat` → `ZapretManager2.ps1` → magenta-меню
