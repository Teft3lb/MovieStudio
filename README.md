# MovieStudio

**Рабочее название:** MovieStudio  
**Жанр:** 3D-симулятор киностудии с глубокой экономической, социальной и творческой симуляцией.  
**Статус:** активная разработка базовых игровых систем.

Мы создаём самостоятельного духовного наследника The Movies: игрок начинает с небольшой киностудии в вымышленном мире, развивает её на протяжении меняющихся эпох кинематографа, управляет персоналом и экономикой, а главное — самостоятельно создаёт и снимает фильмы.

## Ключевые особенности

- Живая 3D-территория киностудии и свободное строительство.
- Персонажи с профессиями, навыками, потребностями, отношениями и карьерой.
- Автоматический сценарный отдел и ручное создание сценариев.
- Полноценный редактор фильмов: сцены, действия, реплики, камеры и монтаж.
- Экономика студии, конкуренты, кинорынок и изменяющиеся вкусы аудитории.
- Кампания и отдельный режим песочницы.
- Стилизованный реализм с визуальной идентичностью оригинальной The Movies.

## Текущий статус

В репозитории находится запускаемый 3D-проект Godot 4.7.2. Работают территория студии, строительство, игровое время, свободная камера, управление персоналом и симуляция потребностей сотрудников. Фильм проходит путь от сценарного отдела через съёмочный павильон и монтаж до пункта релиза. Реклама влияет на сборы, которые поступают в бюджет в течение семи игровых дней.

## Документация

- [GDD v0.3](docs/GDD/GDD_v0.3.md)
- [Обзор технической архитектуры](docs/architecture/overview.md)
- [Character System v1](docs/architecture/character_system.md)
- [Character System v2](docs/architecture/character_system_v2.md)
- [Employee Management v1](docs/architecture/employee_management_v1.md)
- [Profession Catalogue](docs/architecture/profession_catalog.md)
- [Film Production v1](docs/architecture/film_production_v1.md)
- [Film Set Dressing v1](docs/architecture/film_set_dressing_v1.md)
- [Экономика реквизита, реклама и прокат](docs/architecture/studio_business_system_v1.md)
- [Visual Overhaul v1 и конвейер Blender → Godot](docs/architecture/visual_overhaul_v1.md)
- [Visual Overhaul v2, рабочие места и замеры](docs/architecture/visual_overhaul_v2.md)
- [Visual Overhaul v3, интерьеры, сотрудники и карта ресурсов](docs/architecture/visual_overhaul_v3.md)
- [Архитектурные решения](docs/decisions/0001-project-foundation.md)

## Технологии

- Целевой движок: Godot 4.7.2.
- Основная целевая платформа: PC; конкретные минимальные системные требования будут определены после прототипирования.
- 3D-контент: Blender и glTF-пайплайн.
- Версионирование: Git.

## Разработка

- Единственный рабочий проект — `D:/Develop/MovieStudio`. В Godot Project Manager открывайте именно `D:/Develop/MovieStudio/project.godot`.
- Единственная рабочая ветка — `main`. Вложенные копии проекта и новые рабочие ветки запрещены.
- Перед каждой задачей проверяйте `git rev-parse --show-toplevel`, `git branch --show-current` и `git status --short --branch`.
- После завершённого и протестированного этапа создайте коммит, выполните `git fetch origin`, интегрируйте удалённые изменения при их наличии и опубликуйте результат обычным `git push origin main`.
- Сверьте `git rev-parse HEAD` и `git ls-remote origin refs/heads/main`. Этап завершён после публикации всех необходимых изменений и совпадения SHA.
- Сохраняйте пользовательские наработки. `git reset --hard`, `git clean -fd` и force push запрещены.

Подробные правила собраны в [AGENTS.md](AGENTS.md) и [Git workflow](docs/architecture/git_workflow.md).

Visual Overhaul v3 обновляет сценарный и монтажный отделы, столовую, жильё и клуб, отдел продвижения и три типоразмера съёмочных павильонов. Сотрудники получили шесть причёсок, вариации лица и одежды поверх общего рига. Команды для скриншотов, пересборки моделей и замеров собраны в [документации v3](docs/architecture/visual_overhaul_v3.md).

Для локальной проверки в PowerShell укажите путь к консольному исполняемому файлу Godot 4.7.2 и выполните команды из корня проекта.

```powershell
$godotExe = 'C:\path\to\Godot_v4.7.2-stable_win64_console.exe'
& $godotExe --version
& $godotExe --headless --path . --editor --import --quit
& $godotExe --headless --path . --quit-after 5
& $godotExe --headless --path . --script res://tests/character_action_wheel_smoke_test.gd
& $godotExe --headless --path . --script res://tests/film_distribution_smoke_test.gd
```

## Лицензия

Лицензия проекта пока не выбрана. До её утверждения не следует считать код или контент свободными для повторного использования.

Все игровые названия, персонажи, модели, тексты и другие материалы будут создаваться как самостоятельная интеллектуальная собственность. Проект вдохновлён жанром и игровыми принципами The Movies, но не использует её защищённые ресурсы.
