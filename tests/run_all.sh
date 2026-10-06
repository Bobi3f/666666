#!/bin/bash
# Все автотесты FIRST GEAR. Запуск из корня проекта:
#   tests/run_all.sh            — все наборы
#   tests/run_all.sh test_gai   — один набор (имя файла без .gd)
# Godot ищется в $GODOT, потом в PATH (godot). Итог — строка «ИТОГО» у каждого
# набора; код выхода 1, если хоть один набор с ошибками.
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT:-$(command -v godot || echo godot)}"
LOGS="${TEST_LOGS:-/tmp/firstgear-tests}"
mkdir -p "$LOGS"

# Наборы без экрана (headless) и с экраном (сенсорное управление, меню)
HEADLESS="check_scripts test_vehicles test_driving test_life test_mvp test_round3 test_salon test_village test_seasons test_polish test_gai test_tutorial_save test_roads_town test_region test_jobs test_police test_club test_docs test_town_south test_traffic test_school test_path test_jobs_route test_boot test_perf_lod test_walk_in test_chase test_football test_market test_girl test_autoschool test_izh test_turn test_town_east test_smooth test_old_save test_trees_roads test_story test_lang test_donate test_signs test_junkyard test_farm test_business test_kit_saves test_grove test_sounds_world test_people_shop test_soak"
SCREEN="test_touch test_phone test_menu_pad test_options test_view test_layout"

run_one() {
	local t="$1"
	local args="--no-menu"
	local screen=0
	case " $SCREEN " in *" $t "*) screen=1 ;; esac
	case "$t" in
		test_touch) args="--touch" ;;
		test_menu_pad|test_boot|test_donate) args="" ;;
		test_options|test_view|test_layout) args="--touch --no-menu" ;;
	esac
	if [ "$screen" = 1 ]; then
		timeout 600 xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --rendering-driver opengl3 --path . --script "tests/$t.gd" -- $args > "$LOGS/$t.log" 2>&1
	else
		timeout 600 "$GODOT" --headless --path . --script "tests/$t.gd" -- $args > "$LOGS/$t.log" 2>&1
	fi
	local total
	total=$(grep -o 'ИТОГО.*' "$LOGS/$t.log" || echo "ИТОГО: не дошёл до конца (см. $LOGS/$t.log)")
	printf '%-22s %s\n' "$t" "$total"
	grep -E '^\s*FAIL' "$LOGS/$t.log" | sed 's/^/    /'
	case "$total" in *"всё работает"*) return 0 ;; *) return 1 ;; esac
}

# Проект должен быть импортирован (кэш .godot) — иначе классы не найдутся
[ -d .godot ] || timeout 300 "$GODOT" --headless --path . --import > /dev/null 2>&1

fail=0
if [ $# -gt 0 ]; then
	for t in "$@"; do run_one "$t" || fail=1; done
else
	# По одному: часть наборов пишет общее сохранение и мешала бы соседям
	for t in $HEADLESS $SCREEN; do run_one "$t" || fail=1; done
fi
exit $fail
