-- 2026-10-24
do $do$
declare
	var_updated integer;
begin

	-- Этап 1. Константы 
	begin
		drop function if exists public.fn_get_meteo_constant(text);
		drop table if exists public.calc_parameter_limits;
		drop table if exists public.calc_meteo_constants;

		-- Допустимые диапазоны значений параметров (из ТЗ)
		create table public.calc_parameter_limits
		(
			measurement_parameter_type_id integer not null,
			min_value numeric(10,2) not null,
			max_value numeric(10,2) not null,
			constraint pk_calc_parameter_limits primary key (measurement_parameter_type_id),
			constraint fk_calc_parameter_limits_types foreign key (measurement_parameter_type_id)
				references public.measurement_parameter_types (id),
			constraint ck_calc_parameter_limits_range check (min_value <= max_value)
		);

		comment on table public.calc_parameter_limits is 'Допустимые диапазоны значений параметров';
		comment on column public.calc_parameter_limits.measurement_parameter_type_id is 'Уникальный код типа параметра';
		comment on column public.calc_parameter_limits.min_value is 'Минимальное допустимое значение';
		comment on column public.calc_parameter_limits.max_value is 'Максимальное допустимое значение';

		-- У высоты метеопоста границ в ТЗ нет, поэтому ее тут нет
		insert into public.calc_parameter_limits(measurement_parameter_type_id, min_value, max_value)
		values
			(2, -58, 58), -- Температура
			(3, 500, 900), -- Давление
			(4, 0, 59), -- Направление ветра
			(5, 0, 15), -- Скорость ветра
			(6, 0, 150); -- Дальность сноса пуль

		-- Константы для расчета Метео приближенный
		create table public.calc_meteo_constants
		(
			code text not null,
			constant_value numeric(10,2) not null,
			description text,
			constraint pk_calc_meteo_constants primary key (code)
		);

		comment on table public.calc_meteo_constants is 'Константы для расчета Метео приближенный';
		comment on column public.calc_meteo_constants.code is 'Код константы';
		comment on column public.calc_meteo_constants.constant_value is 'Значение';
		comment on column public.calc_meteo_constants.description is 'Описание';

		insert into public.calc_meteo_constants(code, constant_value, description)
		values
			('normal_pressure', 750, 'Табличное (нормальное) давление, мм рт. ст.'),
			('normal_temperature', 15.9, 'Табличная (нормальная) температура, градусы Цельсия'),
			('pressure_negative_offset', 500, 'Признак отрицательного отклонения давления: к модулю прибавляется это число'),
			('temperature_negative_offset', 50, 'Признак отрицательного отклонения температуры: к модулю прибавляется это число'),
			('minutes_step', 10, 'Шаг минут в ДДЧЧМ (последняя цифра - десятки минут)');

		-- Получение константы по коду
		create function public.fn_get_meteo_constant(par_code text)
		returns numeric
		language plpgsql
		stable
		as $body$
		declare
			var_value numeric;
		begin
			select t1.constant_value
			into var_value
			from public.calc_meteo_constants t1
			where t1.code = par_code;

			if not found then
				raise exception 'Константа % не найдена', par_code;
			end if;

			return var_value;
		end;
		$body$;

		raise notice 'Таблицы констант и функция fn_get_meteo_constant созданы';
	end;
	commit;

	-- Этап 2. Ошибки входных параметров DDL, типы, функция проверки, заполнение
	begin
		drop function if exists public.fn_check_measurement_params(public.measurement_param_list_type);
		drop type if exists public.measurement_param_list_type;
		drop type if exists public.measurement_param_type;

		-- 1. Расширяем DDL: информация об ошибках в пачке
		alter table public.measurement_batchs add column if not exists is_error boolean not null default false;
		alter table public.measurement_batchs add column if not exists error_count integer not null default 0;
		alter table public.measurement_batchs add column if not exists error_description text;

		comment on column public.measurement_batchs.is_error is 'Флаг: есть ошибка во входных параметрах';
		comment on column public.measurement_batchs.error_count is 'Количество ошибок во входных параметрах';
		comment on column public.measurement_batchs.error_description is 'Описание ошибок (через "; ")';

		-- 2. Новые типы данных
		-- Один параметр
		create type public.measurement_param_type as
		(
			parameter_type_id integer,
			measurement_value numeric(10,2)
		);

		-- Список параметров пачки вместе с оборудованием
		create type public.measurement_param_list_type as
		(
			equipment_id integer,
			items public.measurement_param_type[]
		);

		-- 3. Функция проверки. Возвращает строку со списком ошибок, если ошибок нет - пустую строку
		create function public.fn_check_measurement_params(par_list public.measurement_param_list_type)
		returns text
		language plpgsql
		stable
		as $body$
		declare
			var_result text;
		begin
			if par_list.items is null or cardinality(par_list.items) = 0 then
				return 'Пачка пустая, параметры не переданы';
			end if;

			with
			param_items as (
				select u.parameter_type_id, u.measurement_value
				from unnest(par_list.items) as u
			),
			item_stat as (
				select t1.parameter_type_id, count(*) as cnt
				from param_items t1
				group by t1.parameter_type_id
			),
			-- Какие параметры ожидаются для этого оборудования
			expected as (
				select t1.id, t1.name
				from public.measurement_parameter_types t1
				where t1.measurement_equipment_id is null
				   or t1.measurement_equipment_id = par_list.equipment_id
			),
			errors as (
				-- Не указано оборудование
				select 0 as err_order, 0 as type_id, 'Не указано оборудование'::text as msg
				where par_list.equipment_id is null

				union all

				-- Нет обязательного параметра
				select 1, t1.id, 'Нет параметра "' || t1.name || '"'
				from expected t1
				left join item_stat t2 on t2.parameter_type_id = t1.id
				where t2.parameter_type_id is null

				union all

				-- Параметр передан несколько раз
				select 2, t1.id, 'Дублируется параметр "' || t1.name || '" (значений: ' || t2.cnt || ')'
				from expected t1
				inner join item_stat t2 on t2.parameter_type_id = t1.id
				where t2.cnt > 1

				union all

				-- Параметр от другого оборудования
				select 3, t2.parameter_type_id, 'Лишний параметр "' || t3.name || '" для данного оборудования'
				from item_stat t2
				inner join public.measurement_parameter_types t3 on t3.id = t2.parameter_type_id
				left join expected t1 on t1.id = t2.parameter_type_id
				where t1.id is null

				union all

				-- Неизвестный код параметра
				select 4, t2.parameter_type_id, 'Неизвестный код параметра ' || coalesce(t2.parameter_type_id::text, 'null')
				from item_stat t2
				left join public.measurement_parameter_types t3 on t3.id = t2.parameter_type_id
				where t3.id is null

				union all

				-- Значение не заполнено
				select 5, t1.parameter_type_id, 'Параметр "' || t3.name || '" без значения'
				from param_items t1
				inner join public.measurement_parameter_types t3 on t3.id = t1.parameter_type_id
				where t1.measurement_value is null

				union all

				-- Значение вне допустимого диапазона
				select 6, t1.parameter_type_id,
				       '"' || t3.name || '" = ' || trim_scale(t1.measurement_value)
				       || ' вне диапазона ' || trim_scale(t2.min_value) || '..' || trim_scale(t2.max_value)
				from param_items t1
				inner join public.calc_parameter_limits t2 on t2.measurement_parameter_type_id = t1.parameter_type_id
				inner join public.measurement_parameter_types t3 on t3.id = t1.parameter_type_id
				where t1.measurement_value < t2.min_value
				   or t1.measurement_value > t2.max_value
			)
			select string_agg(t1.msg, '; ' order by t1.err_order, t1.type_id)
			into var_result
			from errors t1;

			return coalesce(var_result, '');
		end;
		$body$;

		-- 4. Заполняем информацию об ошибках для уже существующих пачек
		with
		batch_lists as (
			select t1.id as batch_id,
			       row(
			           t1.measurement_equipment_id,
			           coalesce(
			               array_agg(row(t2.measurement_parameter_type_id, t2.measurement_value)::public.measurement_param_type order by t2.id)
			                   filter (where t2.id is not null),
			               array[]::public.measurement_param_type[]
			           )
			       )::public.measurement_param_list_type as param_list
			from public.measurement_batchs t1
			left join public.measurement_input_params t2 on t2.measurement_batch_id = t1.id
			group by t1.id, t1.measurement_equipment_id
		),
		checked as (
			select t1.batch_id, public.fn_check_measurement_params(t1.param_list) as errors
			from batch_lists t1
		)
		update public.measurement_batchs as b
		set is_error = (c.errors <> ''),
		    error_count = case when c.errors = '' then 0 else cardinality(string_to_array(c.errors, '; ')) end,
		    error_description = nullif(c.errors, '')
		from checked c
		where c.batch_id = b.id;

		get diagnostics var_updated = row_count;
		raise notice 'Обновлено пачек: %', var_updated;
	end;
	commit;

	-- Этап 3. Функции Метео приближенный: ДДЧЧМ, ВВВВ, БББТТ
	begin
		drop function if exists public.fn_meteo_bbbtt(numeric, numeric);
		drop function if exists public.fn_meteo_vvvv(numeric);
		drop function if exists public.fn_meteo_ddchhm(timestamp);

		-- ДДЧЧМ: день месяца, час, десятки минут
		create function public.fn_meteo_ddchhm(par_started timestamp)
		returns text
		language plpgsql
		stable
		as $body$
		begin
			if par_started is null then
				return null;
			end if;

			return to_char(par_started, 'DDHH24')
				|| floor(extract(minute from par_started) / public.fn_get_meteo_constant('minutes_step'))::integer::text;
		end;
		$body$;

		-- ВВВВ: высота метеопоста, метры, 4 цифры
		create function public.fn_meteo_vvvv(par_height numeric)
		returns text
		language plpgsql
		immutable
		as $body$
		declare
			var_height integer;
		begin
			if par_height is null or round(par_height) < 0 or round(par_height) > 9999 then
				return null;
			end if;

			var_height := round(par_height);

			return lpad(var_height::text, 4, '0');
		end;
		$body$;

		-- БББТТ: БББ - отклонение давления от табличного, ТТ - отклонение виртуальной температуры от табличной.
		-- Отрицательные отклонения кодируются прибавлением смещения (500 для давления, 50 для температуры)
		create function public.fn_meteo_bbbtt(par_temperature numeric, par_pressure numeric)
		returns text
		language plpgsql
		stable
		as $body$
		declare
			var_pressure_offset integer := public.fn_get_meteo_constant('pressure_negative_offset');
			var_temperature_offset integer := public.fn_get_meteo_constant('temperature_negative_offset');
			var_delta_pressure integer;
			var_delta_temperature integer;
			var_virtual_temperature numeric;
		begin
			if par_temperature is null or par_pressure is null then
				return null;
			end if;

			-- Отклонение давления
			var_delta_pressure := round(par_pressure - public.fn_get_meteo_constant('normal_pressure'));

			-- Виртуальная температура: температура + поправка из таблицы (линейная интерполяция)
			var_virtual_temperature := par_temperature
				+ public.fn_calc_interpolation(par_temperature, public.fn_get_interpolation_for_correction(par_temperature));

			-- Отклонение температуры
			var_delta_temperature := round(var_virtual_temperature - public.fn_get_meteo_constant('normal_temperature'));

			-- Не помещается в формат
			if abs(var_delta_pressure) >= var_pressure_offset or abs(var_delta_temperature) >= var_temperature_offset then
				return null;
			end if;

			if var_delta_pressure < 0 then
				var_delta_pressure := abs(var_delta_pressure) + var_pressure_offset;
			end if;

			if var_delta_temperature < 0 then
				var_delta_temperature := abs(var_delta_temperature) + var_temperature_offset;
			end if;

			return lpad(var_delta_pressure::text, 3, '0') || lpad(var_delta_temperature::text, 2, '0');
		end;
		$body$;

		raise notice 'Функции fn_meteo_ddchhm, fn_meteo_vvvv, fn_meteo_bbbtt созданы';
	end;
	commit;

end
$do$;