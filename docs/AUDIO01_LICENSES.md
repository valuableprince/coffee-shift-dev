# AUDIO-01 — музыкальные файлы и происхождение (черновик)
Дата проверки: 2026-11-06. Статус: **предрелизный набор; дополнительная правовая/слуховая проверка обязательна**.

Публикация содержит **13 реальных OGG**: 12 OGG перенесены без изменений из указанных публичных GitHub-репозиториев (Git blob SHA сохранены), а radio_08_bossa.ogg взят из публичного проекта xenitV1/mola, где документированы оригинальное издание CC0, конверсия и SHA-256. Все файлы являются реальными записями, а не синтетическими заменителями.

## Радио — источники
| Файл | Исходник | Информация о лицензии |
| --- | --- | --- |
| radio_01_jazz.ogg | [library_mus.ogg](https://github.com/Lelio88/dewdrop/blob/main/assets/audio/library_mus.ogg) | Freesound #770969, jazz piano, CC0 по CREDITS.md; дополнительно сверить оригинальность музыкальной гармонии/названия, чтобы не включить чужую композицию |
| radio_02_vibraphone.ogg | [beach_mus.ogg](https://github.com/Lelio88/dewdrop/blob/main/assets/audio/beach_mus.ogg) | Freesound #238908, vibraphone, CC0 по CREDITS.md |
| radio_03_acoustic.ogg | [forest_mus.ogg](https://github.com/Lelio88/dewdrop/blob/main/assets/audio/forest_mus.ogg) | Freesound #261608, acoustic, CC0 по CREDITS.md |
| radio_04_harp.ogg | [mountain_mus.ogg](https://github.com/Lelio88/dewdrop/blob/main/assets/audio/mountain_mus.ogg) | Freesound #503244, harp, CC0 по CREDITS.md |
| radio_05_duduk.ogg | [desert_mus.ogg](https://github.com/Lelio88/dewdrop/blob/main/assets/audio/desert_mus.ogg) | Freesound #352572, duduk, CC0 по CREDITS.md |
| radio_06_ambient_a.ogg | [aurora_mus_a.ogg](https://github.com/Lelio88/dewdrop/blob/main/assets/audio/aurora_mus_a.ogg) | Freesound #695587, ambient, CC0 по CREDITS.md |
| radio_07_ambient_b.ogg | [aurora_mus_b.ogg](https://github.com/Lelio88/dewdrop/blob/main/assets/audio/aurora_mus_b.ogg) | Freesound #360352, ambient, CC0 по CREDITS.md |
| radio_08_bossa.ogg | [Cleyton Kauffman — Buy Something! (Shop Theme)](https://opengameart.org/content/shop-theme); [published re-encode and source SHA](https://github.com/xenitV1/mola/blob/main/assets/vendor/Shop-Theme-SOURCE.md) | **CC0 1.0**, primary author submission verified 2026-11-06; re-encoded copy SHA-256 `67a97ef88addadbb12fd534d449b3e4606181b6378ca4191d6fb8ba65e9ddb6c` |
| radio_09_ambient_space.ogg | [space_mus.ogg](https://github.com/Lelio88/dewdrop/blob/main/assets/audio/space_mus.ogg) | CC0 заявлен проектом, **первичный URL не указан — блокер релиза** |
| radio_10_dreamy.ogg | [underwater_mus.ogg](https://github.com/Lelio88/dewdrop/blob/main/assets/audio/underwater_mus.ogg) | CC0 заявлен проектом, **первичный URL не указан — блокер релиза** |

Для radio_01–07, radio_09–10 подтверждение вторичного источника: [Lelio88/dewdrop CREDITS.md](https://github.com/Lelio88/dewdrop/blob/main/CREDITS.md). Музыкальные петли в нём указаны как обработанные исходники с Freesound, а не обязательно исходные записи.

## Темы меню / гаража / итогов
| Файл | Произведение и автор | Лицензия и первичный источник |
| --- | --- | --- |
| menu.ogg | **Feel Good Island Loop**, исходная композиция Brandon Morris, луп-версия AntumDeluge | [OpenGameArt, CC0/OGA-BY для опубликованной обработки](https://opengameart.org/content/feel-good-island-loop); требует фиксации точной редакции применяемых условий |
| garage.ogg | **Cheesy Loop 1**, Tozan | [CC0, OpenGameArt](https://opengameart.org/content/cheesy-loop-1) |
| day_end.ogg | **Short Plingy Loop**, Fupi | [CC0, OpenGameArt](https://opengameart.org/content/short-plingy-loop) |

Промежуточный исходник и маркировка автора: [Iakirmon/platformer-2d assets/music/CREDITS.txt](https://github.com/Iakirmon/platformer-2d/blob/main/assets/music/CREDITS.txt).

## Перед коммерческим выпуском
- Открыть **первичные** страницы лицензии каждого из 13 треков и сохранить URL, дату, точную редакцию лицензии и доказательства авторства.
- Заменить две радио-композиции с неполной прослеживаемостью, если нельзя документально установить первоисточник.
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

## Public branch status — 2026-11-06

- radio_08_fields.ogg not published in coffee-shift-dev; replaced with author-licensed CC0 **Shop Theme / Buy Something!** (Bossa Nova).
- radio_09_ambient_space.ogg and radio_10_dreamy.ogg still have only secondary CC0 declarations; primary license evidence must be obtained or files replaced prior to commercial release.
- CC0 source for Bossa: https://opengameart.org/content/shop-theme ; re-encode provenance: https://github.com/xenitV1/mola/blob/main/assets/vendor/Shop-Theme-SOURCE.md .
