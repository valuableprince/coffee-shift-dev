# AUDIO-01 — музыкальные файлы и происхождение (черновик)
Дата проверки: 2026-11-06. Статус: **предрелизный набор; дополнительная правовая/слуховая проверка обязательна**.

Публичная сборка содержит **13 реальных музыкальных OGG**. Радиотреки №01, №09 и №10 заменены в P0 06.11.2026: их авторские исходные страницы и условия CC0 подтверждены; SHA-256 опубликованных файлов закреплены в этом реестре и автоматически проверяются в CI. Старые файлы исключены из Git-дерева ветки P0. Остальные записи сохраняют свою отдельную цепочку прав; см. замечания ниже.

## Радио — источники
| Файл | Исходник | Информация о лицензии |
| --- | --- | --- |
| radio_01_jazz_improv.ogg | **Jazz Improvisation (Looped)**, Alex McCulloch (Pro Sensory), [авторская страница OGA](https://opengameart.org/content/jazz-improvisation-looped), **CC0 1.0**. [Подтверждённая обработанная 44.1 кГц stereo OGG](https://github.com/MaplebirchLeaf/Deadwood-Reblooms/blob/29a343a208f5df6f504167fcf32d9ef13835457f/audio-pack/audio/CREDITS.md) и [реестр оригинала/обработки](https://github.com/MaplebirchLeaf/Deadwood-Reblooms/blob/29a343a208f5df6f504167fcf32d9ef13835457f/audio-pack/audio/assets.json) | SHA-256 `e0125d6efee5cec8c5c10745ed884530e42c33bde36922ea880df3c1d22220dd`; Git blob `8cc89731013e6d09b4ce6c5d9df4fb893ff83d37`. Импровизация написана автором, без использования чужой мелодии. |
| radio_02_vibraphone.ogg | [beach_mus.ogg](https://github.com/Lelio88/dewdrop/blob/main/assets/audio/beach_mus.ogg) | Freesound #238908, vibraphone, CC0 по CREDITS.md |
| radio_03_acoustic.ogg | [forest_mus.ogg](https://github.com/Lelio88/dewdrop/blob/main/assets/audio/forest_mus.ogg) | Freesound #261608, acoustic, CC0 по CREDITS.md |
| radio_04_harp.ogg | [mountain_mus.ogg](https://github.com/Lelio88/dewdrop/blob/main/assets/audio/mountain_mus.ogg) | Freesound #503244, harp, CC0 по CREDITS.md |
| radio_05_duduk.ogg | [desert_mus.ogg](https://github.com/Lelio88/dewdrop/blob/main/assets/audio/desert_mus.ogg) | Freesound #352572, duduk, CC0 по CREDITS.md |
| radio_06_ambient_a.ogg | [aurora_mus_a.ogg](https://github.com/Lelio88/dewdrop/blob/main/assets/audio/aurora_mus_a.ogg) | Freesound #695587, ambient, CC0 по CREDITS.md |
| radio_07_ambient_b.ogg | [aurora_mus_b.ogg](https://github.com/Lelio88/dewdrop/blob/main/assets/audio/aurora_mus_b.ogg) | Freesound #360352, ambient, CC0 по CREDITS.md |
| radio_08_bossa.ogg | [Cleyton Kauffman — Buy Something! (Shop Theme)](https://opengameart.org/content/shop-theme); [published re-encode and source SHA](https://github.com/xenitV1/mola/blob/main/assets/vendor/Shop-Theme-SOURCE.md) | **CC0 1.0**, primary author submission verified 2026-11-06; re-encoded copy SHA-256 `67a97ef88addadbb12fd534d449b3e4606181b6378ca4191d6fb8ba65e9ddb6c` |
| radio_09_sunset_walk.ogg | **Sunset Walk / Ambient / Quiet / Sweet / Loop**, KiluaBoy, [первичная страница OGA CC0 1.0](https://opengameart.org/content/sunset-walk-ambient-quiet-sweet-loop). Оригинал `SunsetWalk.ogg` [из опубликованного зеркала с SHA](https://github.com/aaquino49/Zombie-Siege/blob/f73aa122fdeb745acd8b4258b6b9221fe1846909/asset_library/audio/t029/README.md) | SHA-256 `1d230721e6200276065b913e44943d0e0503af88fc2dd793be1249738e06d98c`; Git blob `6ac2b1b13794220dc65f73564ea45d5a172e2337`; без изменений. |
| radio_10_etirwer.ogg | **Etirwer (Looped)**, Kistol, [первичная страница OGA CC0 1.0](https://opengameart.org/content/etirwer). Оригинал `[Etirwer (Looped).ogg]` из [проверенного каталога с первичным HTML-доказательством](https://github.com/norinori1/audio-selector/blob/fc0d98e70c11d1f7afeba45e1a76def912e5176f/benchmark/manifest.json) | SHA-256 `382c02bfb3d9abe1c9f432606dd95f27bcef28ac22097ccdcef12a8c608b421b`; Git blob `9d695ff3f849420d7e77e3217a9b64809de2ae8e`; без изменений. |

Для radio_02–07 подтверждение вторичного источника: [Lelio88/dewdrop CREDITS.md](https://github.com/Lelio88/dewdrop/blob/main/CREDITS.md). Музыкальные петли в нём указаны как обработанные исходники с Freesound, а не обязательно исходные записи.

## Темы меню / гаража / итогов
| Файл | Произведение и автор | Лицензия и первичный источник |
| --- | --- | --- |
| menu.ogg | **Feel Good Island Loop**, исходная композиция Brandon Morris, луп-версия AntumDeluge | [OpenGameArt, CC0/OGA-BY для опубликованной обработки](https://opengameart.org/content/feel-good-island-loop); требует фиксации точной редакции применяемых условий |
| garage.ogg | **Cheesy Loop 1**, Tozan | [CC0, OpenGameArt](https://opengameart.org/content/cheesy-loop-1) |
| day_end.ogg | **Short Plingy Loop**, Fupi | [CC0, OpenGameArt](https://opengameart.org/content/short-plingy-loop) |

Промежуточный исходник и маркировка автора: [Iakirmon/platformer-2d assets/music/CREDITS.txt](https://github.com/Iakirmon/platformer-2d/blob/main/assets/music/CREDITS.txt).

## Перед коммерческим выпуском
- Открыть **первичные** страницы лицензии каждого из 13 треков и сохранить URL, дату, точную редакцию лицензии и доказательства авторства.
- **P0 выполнен для известных проблемных записей:** старые radio_01_jazz.ogg (Freesound #770969, описан как `Blue in Green`), radio_09_ambient_space.ogg и radio_10_dreamy.ogg не включать в сборку. Их авторские CC0-замены подтверждены и закреплены SHA-256 в CI.
- Прослушать все записи; оценить попадание в Soft Jazz / Bossa Nova / Acoustic / Lo-fi и отсутствие сезонного или навязчивого звучания.
- Проверить параметры кодирования 44.1 kHz/stereo, true peak, LUFS, бесшовность циклов и целевой объём MUSIC-25; эти файлы пока перенесены **без транскодирования**.
- Сохранить атрибуцию авторов и исходные лицензии в составе коммерческой сборки; даже для CC0 источник желательно указывать.


## Оригинальные короткие музыкальные сигналы
- assets/audio/music/opening_sting.wav — новая инструментальная последовательность 7.5 секунды, без сторонних семплов.
- assets/audio/music/achievement_sting.wav — новая инструментальная последовательность 3.3 секунды, без сторонних семплов.
- Исходный алгоритм: tools/audio01_stings.py. Файлы воспроизводятся этим скриптом побайтово.
- Обе мелодии сгенерированы для Coffee Shift, внешних записей и чьих-либо лицензируемых сэмплов нет.

## Дополнительные прямые источники (6 ноября 2026)
- [OpenGameArt: Shop Theme, CleytonKauffman](https://opengameart.org/content/shop-theme) — CC0, Bossa Nova; **включён как radio_08_bossa.ogg** с зафиксированным происхождением и SHA-256. Слуховая оценка остаётся открытой.
- [OpenGameArt: Bossa Nova, Joth](https://opengameart.org/content/bossa-nova) — CC0. **Не включён в текущий набор**.

## P0: устранение риска лицензирования — 06.11.2026

- Удалены три прежних файла: `radio_01_jazz.ogg`, `radio_09_ambient_space.ogg`, `radio_10_dreamy.ogg`. Копии у прежнего источника сохранены, в публичный комплект они не входят.
- Причина №01: Freesound #770969 прямо называет мелодию **Blue in Green**. Снятие авторских прав на запись (CC0) не означает наличия прав на исходную музыкальную композицию; использование прекращено без дальнейшей правовой дискуссии.
- Причина №09/10: DewDrop `CREDITS.md` не приводит первичный ID этих двух исходников. Утверждение «CC0» вторичного проекта без первичной идентификации было недостаточным для коммерческого выпуска.
- Новые OGG скачаны без перезаписи/синтеза, прошли независимое сравнение SHA-256 и Git blob SHA. №09 и №10 точно соответствуют файлам на зафиксированных авторских CC0-зеркалах. №01 — описанная авторской страницей CC0 импровизация, затем документированная фиксированная обработка другим проектом; SHA-256 этого производного OGG сохранён.
- Одноразовый импорт: GitHub Actions в ветке `fix/audio01-p0-license-clearance`, источник и зеркала закреплены конкретными Git commit SHA, в конце временный workflow удалён. Проверка SHA-256 остаётся в `tools/ci/check_audio_assets.py`.
- **Это не заключение о безусловной чистоте всего музыкального каталога.** Freesound #238908, #261608, #503244, #352572, #695587 и #360352 в исходном каталоге документированы вторично; оригинальные страницы, собственно творческий вклад и права производных обработок требуют отдельной окончательной ревизии перед продажей.
- Также остаются MUSIC-25 аудиомастеринг, прослушивание, Windows QA и комплект финальных титров. P0 для трёх определённых аудиорисков устранён; коммерческий релиз пока не одобрен.
