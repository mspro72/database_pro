-- Расчет Метео приближенный: типы и функции
-- Запускать после 20261108_01_migration.sql
-- Основная функция: fn_calc_meteo_bulletin(входящие параметры, код оборудования) - по строке на каждую стандартную высоту.
-- Процедурой в PostgreSQL нельзя вернуть таблицу, поэтому расчет оформлен функцией.
do $do$
begin
	drop function if exists public.fn_calc_meteo_bulletin(public.meteo_input_params_type, integer);
	drop function if exists public.fn_calc_meteo_ground(public.meteo_input_params_type);
	drop function if exists public.fn_get_wind_angle_increment(integer, integer);
	drop function if exists public.fn_get_wind_speed(integer, integer, integer);
	drop function if exists public.fn_get_temperature_deviation(integer, integer);
	drop function if exists public.fn_encode_deviation(integer, integer, integer);
	drop type if exists public.meteo_ground_type;
	drop type if exists public.meteo_input_params_type;

	-- Входящие параметры
	create type public.meteo_input_params_type as
	(
		meteopost_height integer,   -- высота метеопоста, м
		temperature numeric(8,1),   -- температура, градусы Цельсия
		pressure integer,           -- давление, мм рт. ст.
		wind_direction integer,     -- направление ветра, большие деления угломера
		wind_speed integer,         -- скорость ветра V0, м/с (для ДМК)
		bullet_drift integer        -- дальность сноса пуль Дг, м (для ВР)
	);

	-- Результат расчета на уровне метеопоста
	create type public.meteo_ground_type as
	(
		delta_pressure integer,           -- отклонение давления от 750, мм рт. ст.
		virtual_temperature numeric(8,2), -- приземная виртуальная температура
		delta_temperature integer,        -- отклонение виртуальной температуры от 15.9
		bbbtt text                        -- БББТТ
	);

	-- Запись отклонения для бюллетеня: отрицательное записывается как модуль + смещение (500 для давления, 50 для температуры)
	create function public.fn_encode_deviation(par_value integer, par_offset integer, par_length integer)
	returns text
	language plpgsql
	immutable
	as $body$
	begin
		if abs(par_value) >= par_offset then
			raise exception 'Отклонение % не помещается в формат бюллетеня (должно быть меньше %)', par_value, par_offset;
		end if;

		return lpad((case when par_value < 0 then abs(par_value) + par_offset else par_value end)::text, par_length, '0');
	end;
	$body$;

	-- Таблица 2: среднее отклонение температуры на высоте по отклонению приземной температуры
	create function public.fn_get_temperature_deviation(par_height integer, par_delta_tau integer)
	returns integer
	language plpgsql
	stable
	as $body$
	declare
		-- Коды типов Таблицы 2 в calc_correction_types
		var_type_positive constant integer := 8;
		var_type_negative constant integer := 9;
		var_columns integer[];
		var_found integer;
		var_result integer;
	begin
		if par_delta_tau = 0 then
			return 0;
		end if;

		-- Отклонение раскладывается на десятки и единицы: -13 это колонки 10 и 3
		var_columns := array_remove(array[abs(par_delta_tau) / 10 * 10, abs(par_delta_tau) % 10], 0);

		select count(t2.row_values[array_position(t4.header_values, t5.col)]),
		       sum(t2.row_values[array_position(t4.header_values, t5.col)])
		into var_found, var_result
		from public.calc_correction_heights t1
		inner join public.calc_correction t2 on t2.height_id = t1.id
		inner join public.calc_correction_types t3 on t3.id = t2.type_id
		inner join public.calc_correction_headers t4 on t4.id = t3.header_id
		cross join unnest(var_columns) as t5(col)
		where t1.height = par_height
		  and t2.type_id = case when par_delta_tau < 0 then var_type_negative else var_type_positive end;

		if var_found <> cardinality(var_columns) then
			raise exception 'В Таблице 2 нет значения для высоты % и отклонения %', par_height, par_delta_tau;
		end if;

		return var_result;
	end;
	$body$;

	-- Таблица 3: скорость среднего ветра по высоте и входному значению (V0 для ДМК, Дг для ВР).
	-- Если значения нет в заголовке, берется линейная интерполяция между соседними колонками
	create function public.fn_get_wind_speed(par_height integer, par_equipment_id integer, par_input integer)
	returns integer
	language plpgsql
	stable
	as $body$
	declare
		-- Код группы "Таблица 3, скорость среднего ветра" в calc_correction_types
		var_group_speed constant integer := 2;
		var_interpolation intepolation_type;
	begin
		with
		wind_row as
		(
			select t4.header_values, t2.row_values
			from public.calc_correction_heights t1
			inner join public.calc_correction t2 on t2.height_id = t1.id
			inner join public.calc_correction_types t3 on t3.id = t2.type_id
			inner join public.calc_correction_headers t4 on t4.id = t3.header_id
			where t1.height = par_height
			  and t3.parent_id = var_group_speed
			  and t3.measurement_equipment_id = par_equipment_id
		),
		points as
		(
			select t2.header_value as x, t1.row_values[t2.pos] as y
			from wind_row t1
			cross join unnest(t1.header_values) with ordinality as t2(header_value, pos)
		)
		select t1.x, t1.y, t2.x, t2.y
		into var_interpolation.x0, var_interpolation.y0, var_interpolation.x1, var_interpolation.y1
		from
		(
			select x, y from points where x <= par_input order by x desc limit 1
		) as t1
		cross join
		(
			select x, y from points where x >= par_input order by x limit 1
		) as t2;

		if not found then
			raise exception 'В Таблице 3 нет значения для высоты %, оборудования % и входного значения %', par_height, par_equipment_id, par_input;
		end if;

		-- Скорость округляется до 1 м/с
		return round(fn_calc_interpolation(par_input, var_interpolation))::integer;
	end;
	$body$;

	-- Таблица 3: приращение дирекционного угла ветра по высоте
	create function public.fn_get_wind_angle_increment(par_height integer, par_equipment_id integer)
	returns integer
	language plpgsql
	stable
	as $body$
	declare
		-- Код группы "Таблица 3, направление среднего ветра" в calc_correction_types
		var_group_angle constant integer := 3;
		var_result integer;
	begin
		select t2.row_values[1]
		into var_result
		from public.calc_correction_heights t1
		inner join public.calc_correction t2 on t2.height_id = t1.id
		inner join public.calc_correction_types t3 on t3.id = t2.type_id
		where t1.height = par_height
		  and t3.parent_id = var_group_angle
		  and t3.measurement_equipment_id = par_equipment_id;

		if var_result is null then
			raise exception 'В Таблице 3 нет приращения угла для высоты % и оборудования %', par_height, par_equipment_id;
		end if;

		return var_result;
	end;
	$body$;

	-- Расчет на уровне метеопоста: отклонение давления, виртуальная температура и БББТТ
	create function public.fn_calc_meteo_ground(par_params public.meteo_input_params_type)
	returns public.meteo_ground_type
	language plpgsql
	stable
	as $body$
	declare
		var_normal_pressure constant numeric := 750;
		var_normal_temperature constant numeric := 15.9;
		var_min_temperature numeric;
		var_max_temperature numeric;
		var_correction numeric;
		var_result public.meteo_ground_type;
	begin
		if par_params.temperature is null or par_params.temperature < -58 or par_params.temperature > 58 then
			raise exception 'Температура должна быть от -58 до 58, передано %', par_params.temperature;
		end if;

		if par_params.pressure is null or par_params.pressure < 500 or par_params.pressure > 900 then
			raise exception 'Давление должно быть от 500 до 900, передано %', par_params.pressure;
		end if;

		-- Виртуальная поправка по Таблице 1. За пределами таблицы берется поправка крайней колонки
		select min(t1.temperature), max(t1.temperature)
		into var_min_temperature, var_max_temperature
		from public.calc_correction_temperature t1;

		var_correction := public.fn_calc_temperature_interpolation(
			least(greatest(par_params.temperature, var_min_temperature), var_max_temperature));

		var_result.virtual_temperature := par_params.temperature + var_correction;
		var_result.delta_temperature := round(var_result.virtual_temperature - var_normal_temperature);
		var_result.delta_pressure := par_params.pressure - var_normal_pressure;

		var_result.bbbtt := public.fn_encode_deviation(var_result.delta_pressure, 500, 3)
		                 || public.fn_encode_deviation(var_result.delta_temperature, 50, 2);

		return var_result;
	end;
	$body$;

	-- Основной расчет: строка на каждую стандартную высоту
	create function public.fn_calc_meteo_bulletin(par_params public.meteo_input_params_type, par_equipment_id integer)
	returns table
	(
		height_y integer,
		height_code text,
		temperature_deviation integer,
		tt text,
		wind_direction integer,
		hh text,
		wind_speed integer,
		cc text
	)
	language plpgsql
	stable
	as $body$
	declare
		-- Код группы "Таблица 3, скорость среднего ветра" в calc_correction_types
		var_group_speed constant integer := 2;
		var_equipment text;
		var_ground public.meteo_ground_type;
		var_input integer;
		var_min_input integer;
	begin
		select t1.short_name
		into var_equipment
		from public.measurement_equipment t1
		where t1.id = par_equipment_id;

		-- Входное значение таблицы скорости ветра зависит от оборудования
		if var_equipment = 'ДМК' then
			if par_params.wind_speed is null or par_params.wind_speed < 0 or par_params.wind_speed > 15 then
				raise exception 'Скорость ветра должна быть от 0 до 15, передано %', par_params.wind_speed;
			end if;
			var_input := par_params.wind_speed;
		elsif var_equipment = 'ВР' then
			if par_params.bullet_drift is null or par_params.bullet_drift < 0 or par_params.bullet_drift > 150 then
				raise exception 'Дальность сноса пуль должна быть от 0 до 150, передано %', par_params.bullet_drift;
			end if;
			var_input := par_params.bullet_drift;
		else
			raise exception 'Неизвестный тип оборудования %', par_equipment_id;
		end if;

		if par_params.wind_direction is null or par_params.wind_direction < 0 or par_params.wind_direction > 59 then
			raise exception 'Направление ветра должно быть от 0 до 59, передано %', par_params.wind_direction;
		end if;

		var_ground := public.fn_calc_meteo_ground(par_params);

		-- Первая колонка таблицы скорости ветра (3 для ДМК, 40 для ВР): при меньшем значении ветер считается нулевым
		select t2.header_values[1]
		into var_min_input
		from public.calc_correction_types t1
		inner join public.calc_correction_headers t2 on t2.id = t1.header_id
		where t1.parent_id = var_group_speed
		  and t1.measurement_equipment_id = par_equipment_id;

		return query
		select t2.height,
		       lpad((t2.height / 100)::text, 2, '0'),
		       t2.deviation,
		       public.fn_encode_deviation(t2.deviation, 50, 2),
		       t2.direction,
		       lpad(t2.direction::text, 2, '0'),
		       t2.speed,
		       lpad(t2.speed::text, 2, '0')
		from
		(
			select t1.height,
			       public.fn_get_temperature_deviation(t1.height, var_ground.delta_temperature) as deviation,
			       case
			           when var_input < var_min_input then 0
			           else (par_params.wind_direction + public.fn_get_wind_angle_increment(t1.height, par_equipment_id)) % 60
			       end as direction,
			       case
			           when var_input < var_min_input then 0
			           else public.fn_get_wind_speed(t1.height, par_equipment_id, var_input)
			       end as speed
			from public.calc_correction_heights t1
		) as t2
		order by t2.height;
	end;
	$body$;

	raise notice 'Типы и функции расчета созданы';
end
$do$;
