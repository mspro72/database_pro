-- Тест расчета Метео приближенный на типовых данных из ТЗ
-- Запускать после 20261108_01_migration.sql и 20261108_02_calc_functions.sql
-- Ожидаемые значения прочитаны по таблицам из ТЗ (Таблица 2, Таблица 3, примеры расчета)
do $do$
declare
	var_case record;
	var_ground public.meteo_ground_type;
	var_equipment_id integer;
	var_tt text;
	var_hh text;
	var_cc text;
	var_actual text;
	var_status text;
	var_failed integer := 0;
begin

	-- 1. БББТТ на уровне метеопоста
	for var_case in
		select *
		from (values
			('Пример 2 из ТЗ: давление 765, температура 25', 25::numeric, 765, '01511'::text),
			('Пример 1 из ТЗ: температура 23, ТТ = 09', 23, 750, '00009'),
			('Отрицательные отклонения: давление 743 (507), температура 10 (55)', 10, 743, '50755')
		) as t(case_name, temperature, pressure, expected)
	loop
		var_ground := public.fn_calc_meteo_ground(row(100, var_case.temperature, var_case.pressure, 15, 6, null)::public.meteo_input_params_type);
		var_actual := var_ground.bbbtt;

		if var_actual = var_case.expected then var_status := 'TRUE'; else var_status := 'FALSE'; var_failed := var_failed + 1; end if;
		raise notice '% | БББТТ ожидалось % получено % | %', var_case.case_name, var_case.expected, var_actual, var_status;
	end loop;

	-- 2. Таблица 2: пример из ТЗ, отклонение -13 на высоте 200 м: -10 и -3 = -9 + (-3) = -12, записывается как 62
	var_actual := public.fn_get_temperature_deviation(200, -13)::text || ' / ' || public.fn_encode_deviation(public.fn_get_temperature_deviation(200, -13), 50, 2);
	if var_actual = '-12 / 62' then var_status := 'TRUE'; else var_status := 'FALSE'; var_failed := var_failed + 1; end if;
	raise notice 'Таблица 2, 200 м, отклонение -13 | ожидалось -12 / 62 получено % | %', var_actual, var_status;

	var_actual := public.fn_get_temperature_deviation(800, 22)::text;
	if var_actual = '22' then var_status := 'TRUE'; else var_status := 'FALSE'; var_failed := var_failed + 1; end if;
	raise notice 'Таблица 2, 800 м, отклонение +22 | ожидалось 22 получено % | %', var_actual, var_status;

	-- 3. Расчет по всем стандартным высотам (высоты: 200, 400, 800, 1200, 1600, 2000, 2400, 3000, 4000)
	for var_case in
		select *
		from (values
			('Пример 2 из ТЗ, ДМК: V0 = 6, направление 15',
			 'ДМК', 25::numeric, 765, 15, 6, null::integer,
			 '11 11 11 11 11 11 11 11 11'::text, '16 17 18 18 19 19 19 20 20'::text, '09 11 11 12 13 13 14 14 14'::text),
			('ВР: Дг = 100, направление 58 (переход через 60)',
			 'ВР', 25, 765, 58, null, 100,
			 '11 11 11 11 11 11 11 11 11', '58 59 00 00 01 01 01 02 02', '08 10 10 11 11 11 12 12 12'),
			('ВР: Дг = 45, интерполяция между колонками 40 и 50',
			 'ВР', 25, 765, 10, null, 45,
			 '11 11 11 11 11 11 11 11 11', '10 11 12 12 13 13 13 14 14', '04 05 05 05 05 05 05 06 06'),
			('ДМК: V0 = 2, меньше 3, ветер нулевой',
			 'ДМК', 25, 765, 15, 2, null,
			 '11 11 11 11 11 11 11 11 11', '00 00 00 00 00 00 00 00 00', '00 00 00 00 00 00 00 00 00'),
			('ВР: Дг = 30, меньше 40, ветер нулевой',
			 'ВР', 25, 765, 15, null, 30,
			 '11 11 11 11 11 11 11 11 11', '00 00 00 00 00 00 00 00 00', '00 00 00 00 00 00 00 00 00'),
			('ДМК: температура 10 (отклонение -5), V0 = 3',
			 'ДМК', 10, 750, 0, 3, null,
			 '55 55 55 54 54 54 54 54 54', '01 02 03 03 04 04 04 05 05', '04 05 05 05 06 06 06 06 06')
		) as t(case_name, equipment, temperature, pressure, direction, wind_speed, bullet_drift, expected_tt, expected_hh, expected_cc)
	loop
		select t1.id into var_equipment_id from public.measurement_equipment t1 where t1.short_name = var_case.equipment;

		select string_agg(t1.tt, ' ' order by t1.height_y),
		       string_agg(t1.hh, ' ' order by t1.height_y),
		       string_agg(t1.cc, ' ' order by t1.height_y)
		into var_tt, var_hh, var_cc
		from public.fn_calc_meteo_bulletin(
			row(100, var_case.temperature, var_case.pressure, var_case.direction, var_case.wind_speed, var_case.bullet_drift)::public.meteo_input_params_type,
			var_equipment_id) as t1;

		if var_tt = var_case.expected_tt and var_hh = var_case.expected_hh and var_cc = var_case.expected_cc then
			var_status := 'TRUE';
		else
			var_status := 'FALSE';
			var_failed := var_failed + 1;
		end if;

		raise notice '%', var_case.case_name;
		raise notice '   TT: ожидалось % получено %', var_case.expected_tt, var_tt;
		raise notice '   HH: ожидалось % получено %', var_case.expected_hh, var_hh;
		raise notice '   CC: ожидалось % получено % | %', var_case.expected_cc, var_cc, var_status;
	end loop;

	-- 4. Некорректные данные должны давать ошибку
	begin
		perform * from public.fn_calc_meteo_bulletin(row(100, 70, 750, 15, 6, null)::public.meteo_input_params_type, 1);
		var_status := 'FALSE';
		var_failed := var_failed + 1;
	exception when others then
		var_status := 'TRUE';
	end;
	raise notice 'Температура 70 вне диапазона, ожидалась ошибка | %', var_status;

	if var_failed > 0 then
		raise exception 'Проверок не пройдено: %', var_failed;
	end if;

	raise notice 'Все проверки пройдены';
end
$do$;
