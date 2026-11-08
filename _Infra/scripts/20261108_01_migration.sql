-- Миграция справочников Таблица 2 и Таблица 3 (скрипт 2026-11-08)
-- Содержит учебный скрипт 20261102.sql без изменений и этапы его исправления.
-- Для работы нужны объекты из учебного примера: тип interpolation_type и функция fn_calc_interpolation(numeric, interpolation_type),
-- таблица calc_temperature_correction и таблица measurement_equipment (ДМК - 1, ВР - 2).
-- В файле должен быть только этот do-блок: внутри него commit между этапами, при отправке пакетом с другими командами commit не сработает.
do $do$
begin

	-- Этап 0. Очистка, чтобы скрипт можно было запускать повторно
	begin
		drop table if exists public.calc_correction;
		drop table if exists public.calc_correction_types;
		drop table if exists public.calc_correction_headers;
		drop table if exists public.calc_correction_heights;
		drop sequence if exists public.calc_correction_seq;
		drop sequence if exists public.calc_correction_types_seq;
		drop sequence if exists public.calc_correction_headers_seq;
		drop sequence if exists public.calc_correction_height_seq;

		-- Учебный скрипт переименовывает таблицу поправок, возвращаем имя, чтобы он отработал еще раз
		if to_regclass('public.calc_correction_temperature') is not null
		   and to_regclass('public.calc_temperature_correction') is null then
			alter table public.calc_correction_temperature rename to calc_temperature_correction;
		end if;
	end;
	commit;

	-- Этап 1. Учебный скрипт 20261102.sql (как есть)
	begin

	-- Создаем новые структуры
	begin
		
		-- Таблица стандартных высот
		create sequence calc_correction_height_seq;
		create table calc_correction_heights
		(
		        id integer primary key not null default nextval('public.calc_correction_height_seq'),
		        height integer not null
		);
		
		
		insert into calc_correction_heights(height)
		values(200),(400),(800),(1200),(1600),(2000),(2400),(3000),(4000);
	
		comment on table calc_correction_heights is 'Таблица стандартных высот';
		comment on column calc_correction_heights.id is 'Уникальный код';
		comment on column calc_correction_heights.height is 'Высота';
	
		-- Справочник типов таблиц корректировок
		create sequence calc_correction_types_seq;
		create table calc_correction_types
		(
		        id integer not null primary key default nextval('public.calc_correction_types_seq'),
		        parent_id integer,
		        measurment_equipment_id integer,
		        description text not null,
		        header_values integer[]
		);
	
		comment on table calc_correction_types is 'Справочник типов таблиц с собственными заголовками';
		comment on column calc_correction_types.id is 'Уникальный код';
		comment on column calc_correction_types.parent_id is 'Уникальный код владельца - тип таблицы';
		comment on column calc_correction_types.measurment_equipment_id is 'Тип оборудования';
		comment on column calc_correction_types.description is 'Описание к таблице';
		comment on column calc_correction_types.header_values is 'Значения в заголовке таблице';

		-- Универсальная таблица корректировок
		create sequence calc_correction_seq;
		create table calc_correction
		(
		        id integer not null primary key default nextval('public.calc_correction_seq'),
		        height_id integer not null,
		        type_id integer not null,
		        row_values integer[]
		);

		comment on table calc_correction is 'Универсальная таблица корректировок';
		comment on column calc_correction.id is 'Уникальный код';
		comment on column calc_correction.height_id is 'Код высоты';
		comment on column calc_correction.type_id is 'Код типа таблиц';
		comment on column calc_correction.row_values is 'Значения с корректировками';

	end;	

	-- Добавляем данные
	begin

		
		insert into calc_correction_types(  description, header_values)
		values( 'Таблица 2', array[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 30, 40, 50]),  -- 1
		( 'Таблица 3, скорость среднего ветра', null), -- 2
		( 'Таблица 3, направление среднего ветра', null);       -- 3

		insert into calc_correction_types( description, parent_id, measurment_equipment_id, header_values)
		values
		('Таблица 3, Скорость среднего ветра (ВР)', 2, 2, array[40, 50, 60, 70, 80, 90, 100, 110, 120, 130, 140, 150]), -- 4
		('Таблица 3, Направление среднего ветра (ВР)',3, 2, array[40, 50, 60, 70, 80, 90, 100, 110, 120, 130, 140, 150]), -- 5
		('Таблица 3, Скорость среднего ветра (ДМК)',2, 1, array[3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]), -- 6
		('Таблица 3, Направление среднего ветра (ДМК)',3, 1, array[3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]); -- 7
		
		insert into calc_correction_types( description, parent_id)
		values('Таблица 2, Положительные температуры', 1 ), -- 8
		('Таблица 2, Отрицательные температуры', 1 ) --9
		;

		
		insert into calc_correction(height_id, type_id, row_values )
		-- Таблица 2, отрицптельные значения
		values(1, 9, array[-1, -2, -3, -4, -5, -6, -7, -8, -8, -9, -20, -29, -39, -49]), -- 200
		(2, 9, array[-1, -2, -3, -4, -5, -6, -6, -7, -8, -9, -19, -29, -38, -48]), -- 400
		(3, 9, array[-1, -2, -3, -4, -5, -6, -6, -7, -7, -8, -18, -28, -37, -46]), -- 800
		(4, 9, array[-1, -2, -3, -4, -4, -5, -5, -6, -7, -8, -17, -26, -35, -44]), -- 1200
		(5, 9, array[-1, -2, -3, -3, -4, -4, -5, -6, -7, -7, -17, -25, -34, -42]), -- 1600
		(6, 9, array[-1, -2, -3, -3, -4, -4, -5, -6, -6, -7, -16, -24, -32, -40]), -- 2000
		(7, 9, array[-1, -2, -2, -3, -4, -4, -5, -5, -6, -7, -15, -23, -31, -38]), -- 2400
		(8, 9, array[-1, -2, -2, -3, -4, -4, -4, -5, -5, -6, -15, -22, -30, -37]), -- 3000
		(9, 9, array[-1, -2, -2, -3, -4, -4, -4, -4, -5, -6, -14, -20, -27, -34]), -- 4000
		-- Таблица 2, положитеьные значения
		(1, 8, array[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 30]), -- 200
		(2, 8, array[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 30]), -- 400
		(3, 8, array[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 30]), -- 800
		(4, 8, array[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 30]), -- 1200
		(5, 8, array[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 30]), -- 1600
		(6, 8, array[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 30]), -- 2000
		(7, 8, array[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 30]), -- 2400
		(8, 8, array[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 30]), -- 3000
		(9, 8, array[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 30]), -- 4000
		-- Таблица 3, Скорость среднего ветра (ВР)
		(1, 4, array[3, 4, 5, 6, 7, 7, 8, 9, 10, 11, 12, 12]), -- 200
		(2, 4, array[4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14 ,15]), -- 400
		(3, 4, array[4, 5, 6, 7, 8, 9, 10, 11, 13, 14, 15 ,16]), -- 800
		(4, 4, array[4, 5, 7, 8, 8, 9, 11, 12, 13, 15 ,15, 16]), -- 1200
		(5, 4, array[4, 6, 7, 8, 9, 10, 11, 13, 14, 15, 17, 17]), -- 1600
		(6, 4, array[4, 6, 7, 8, 9, 10, 11, 13, 14, 16, 17, 18]), -- 2000
		(7, 4, array[4, 6, 8, 9, 9, 10, 12, 14, 15, 16, 18, 19]), -- 2400
		(8, 4, array[5, 6, 8, 9, 10, 11, 12, 14, 15, 17, 18, 19]), -- 3000
		(9, 4, array[5, 6, 8, 9, 10, 11, 12, 14, 16, 18, 19, 20]), -- 4000
		-- Таблица 3, Направление среднего ветра (ВР)
		(1, 5, array[0]), -- 200
		(2, 5, array[1]), -- 400
		(3, 5, array[2]), -- 800
		(4, 5, array[2]), -- 1200
		(5, 5, array[3]), -- 1600
		(6, 5, array[3]), -- 2000
		(7, 5, array[3]), -- 2400
		(8, 5, array[4]), -- 3000
		(9, 5, array[4]), -- 4000
		-- Таблица 3,Скорость среднего ветра (ДМК)
		(1, 6, array[4,6,8,9,10,12,14,15,16,18,20,21,22]), -- 200
		(2, 6, array[5,7,10,11,12,14,17,18,20,22,23,25,27]), -- 400
		(3, 6, array[5,8,10,11,13,15,18,19,21,23,25,27,28]), -- 800
		(4, 6, array[5,8,11,12,13,16,19,20,22,24,26,28,30]), -- 1200
		(5, 6, array[6,8,11,13,14,17,20,21,23,25,27,29,32]), -- 1600
		(6, 6, array[6,9,11,13,14,17,20,21,24,26,28,30,32]), -- 2000
		(7, 6, array[6,9,12,14,15,18,21,22,25,27,29,32,34]), -- 2400
		(8, 6, array[6,9,12,14,15,18,21,23,25,28,30,32,36]), -- 3000
		(9, 6, array[6,10,12,14,16,19,22,24,26,29,32,34,36]), -- 4000
		-- 'Таблица 3, Направление среднего ветра (ДМК)
		(1, 7, array[1]), -- 200
		(2, 7, array[2]), -- 400
		(3, 7, array[3]), -- 800
		(4, 7, array[3]), -- 1200
		(5, 7, array[4]), -- 1600
		(6, 7, array[4]), -- 2000
		(7, 7, array[4]), -- 2400
		(8, 7, array[5]), -- 3000
		(9, 7, array[5]) -- 4000
		;
		
	end;

	-- Прочее
	begin
		-- Наименование подправлю
		alter table public.calc_temperature_correction rename to calc_correction_temperature;
		
				
		CREATE OR REPLACE FUNCTION public.fn_calc_temperature_interpolation(
			par_temperature numeric)
		    RETURNS numeric
		    LANGUAGE 'plpgsql'
		    COST 100
		    VOLATILE PARALLEL UNSAFE
		AS $BODY$
				        declare 
				                var_interpolation intepolation_type;
				                var_result numeric(8,2) default 0;
				                var_min_temparure numeric(8,2) default 0;
				                var_max_temperature numeric(8,2) default 0;
				                var_denominator numeric(8,2) default 0;
				        begin
				
				                                raise notice 'Расчет интерполяции для температуры %', par_temperature;
				
				                -- Проверим, возможно температура совпадает со значением в справочнике
				                if exists (select 1 from public.calc_correction_temperature where temperature = par_temperature ) then
				                begin
				                        select correction 
				                        into  var_result 
				                        from  public.calc_correction_temperature
				                        where 
				                                temperature = par_temperature;
				                end;
				                else    
				                begin
				                        -- Получим диапазон в котором работают поправки
				                        select min(temperature), max(temperature) 
				                        into var_min_temparure, var_max_temperature
				                        from public.calc_correction_temperature;
				
				                        if par_temperature < var_min_temparure or   
				                           par_temperature > var_max_temperature then
				
				                                raise exception 'Некорректно передан параметр! Невозможно рассчитать поправку. Значение должно укладываться в диаппазон: %, %',
				                                        var_min_temparure, var_max_temperature;
				                        end if;   
				
				                        -- Получим граничные параметры
				
				                        select x0, y0, x1, y1 
				                                                 into var_interpolation.x0, var_interpolation.y0, var_interpolation.x1, var_interpolation.y1
				                        from
				                        (
				                                select t1.temperature as x0, t1.correction as y0
				                                from public.calc_correction_temperature as t1
				                                where t1.temperature <= par_temperature
				                                order by t1.temperature desc
				                                limit 1
				                        ) as leftPart
				                        cross join
				                        (
				                                select t1.temperature as x1, t1.correction as y1
				                                from public.calc_correction_temperature as t1
				                                where t1.temperature >= par_temperature
				                                order by t1.temperature 
				                                limit 1
				                        ) as rightPart;
				
				                        raise notice 'Граничные значения %', var_interpolation;
				                        var_result :=  fn_calc_interpolation( par_temperature,  var_interpolation);
				                                                 
				                end;
				                end if;
				
				                                return var_result;
				
				end;
				
		$BODY$;
		
		ALTER FUNCTION public.fn_calc_temperature_interpolation(numeric)
		    OWNER TO admin;
		
		COMMENT ON FUNCTION public.fn_calc_temperature_interpolation(numeric)
		    IS 'Функция для расчета интерполяции для метео приближенный';
	end;
	end;
	commit;


	-- Этап 4. Справочник заголовков и изменение справочника типов таблиц
	begin

		create sequence public.calc_correction_headers_seq;
		create table public.calc_correction_headers
		(
			id integer not null primary key default nextval('public.calc_correction_headers_seq'),
			description text not null,
			header_values integer[] not null
		);

		comment on table public.calc_correction_headers is 'Справочник заголовков таблиц корректировок';
		comment on column public.calc_correction_headers.id is 'Уникальный код';
		comment on column public.calc_correction_headers.description is 'Описание заголовка';
		comment on column public.calc_correction_headers.header_values is 'Значения колонок, порядок совпадает с порядком значений в строках calc_correction';

		insert into public.calc_correction_headers(description, header_values)
		values
			('Таблица 2: отклонение приземной виртуальной температуры, градусы',
			 array[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 30, 40, 50]),
			('Таблица 3 (ВР): дальность сноса ветровых пуль Дг, м',
			 array[40, 50, 60, 70, 80, 90, 100, 110, 120, 130, 140, 150]),
			('Таблица 3 (ДМК): скорость приземного ветра V0, м/с',
			 array[3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]);

		-- Справочник типов
		alter table public.calc_correction_types add column header_id integer;

		comment on column public.calc_correction_types.header_id is 'Код заголовка таблицы, null - у таблиц без колонок (направление ветра) и у групп';

		-- Таблица 2 (типы 1, 8, 9)
		update public.calc_correction_types
		set header_id = (select t1.id from public.calc_correction_headers t1 where t1.description like 'Таблица 2:%')
		where id in (1, 8, 9);

		-- Таблица 3, скорость среднего ветра (ВР)
		update public.calc_correction_types
		set header_id = (select t1.id from public.calc_correction_headers t1 where t1.description like 'Таблица 3 (ВР)%')
		where id = 4;

		-- Таблица 3, скорость среднего ветра (ДМК)
		update public.calc_correction_types
		set header_id = (select t1.id from public.calc_correction_headers t1 where t1.description like 'Таблица 3 (ДМК)%')
		where id = 6;

		-- Приращение угла (типы 5 и 7) от дальности сноса и скорости ветра не зависит, в строках по одному значению, заголовок им не нужен
		alter table public.calc_correction_types drop column header_values;

		-- Опечатка в названии колонки
		alter table public.calc_correction_types rename column measurment_equipment_id to measurement_equipment_id;

		-- Связи
		alter table public.calc_correction_types add constraint fk_calc_correction_types_parent
			foreign key (parent_id) references public.calc_correction_types (id);
		alter table public.calc_correction_types add constraint fk_calc_correction_types_equipment
			foreign key (measurement_equipment_id) references public.measurement_equipment (id);
		alter table public.calc_correction_types add constraint fk_calc_correction_types_header
			foreign key (header_id) references public.calc_correction_headers (id);
		alter table public.calc_correction add constraint fk_calc_correction_heights
			foreign key (height_id) references public.calc_correction_heights (id);
		alter table public.calc_correction add constraint fk_calc_correction_types
			foreign key (type_id) references public.calc_correction_types (id);

	end;
	commit;

	-- Этап 5. Проверка справочников
	begin

		-- Для каждой таблицы по одной строке на каждую стандартную высоту
		if exists
		(
			select 1
			from public.calc_correction_types t1
			cross join public.calc_correction_heights t2
			where t1.id in (4, 5, 6, 7, 8, 9)
			  and not exists (select 1 from public.calc_correction t3 where t3.type_id = t1.id and t3.height_id = t2.id)
		) then
			raise exception 'В справочнике calc_correction не хватает данных';
		end if;

		-- Значений в строке не больше, чем колонок в заголовке
		if exists
		(
			select 1
			from public.calc_correction t1
			inner join public.calc_correction_types t2 on t2.id = t1.type_id
			inner join public.calc_correction_headers t3 on t3.id = t2.header_id
			where cardinality(t1.row_values) > cardinality(t3.header_values)
		) then
			raise exception 'Количество значений в строке больше количества колонок заголовка';
		end if;

		-- Таблица 2: отрицательные значения только отрицательные, положительные только положительные
		if exists
		(
			select 1
			from public.calc_correction t1
			cross join lateral unnest(t1.row_values) as t2(cell_value)
			where (t1.type_id = 9 and t2.cell_value >= 0)
			   or (t1.type_id = 8 and t2.cell_value <= 0)
		) then
			raise exception 'В Таблице 2 нарушен знак значений';
		end if;

		raise notice 'Справочники Таблица 2 и Таблица 3 исправлены и заполнены';
	end;
	commit;

end
$do$;
