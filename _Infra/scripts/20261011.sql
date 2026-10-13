-- Миграционный скрипт на PL/pgSQL
-- 2026-10-11

-- Транзакция 1. Таблицы и счетчики
do $$
begin
begin
	-- Удаляем старое
	drop table if exists public.measurement_input_params cascade;
	drop table if exists public.measurement_batchs cascade;
	drop table if exists public.measurement_parameter_types cascade;
	drop table if exists public.employees cascade;
	drop table if exists public.military_positions cascade;
	drop table if exists public.measurement_equipment cascade;
	drop table if exists public.units cascade;
	drop table if exists public.base_units cascade;
	drop table if exists public.virtual_temperature_corrections cascade;

	drop sequence if exists public.seq_measurement_input_params;
	drop sequence if exists public.seq_measurement_batchs;
	drop sequence if exists public.seq_measurement_parameter_types;
	drop sequence if exists public.seq_employees;
	drop sequence if exists public.seq_military_positions;
	drop sequence if exists public.seq_measurement_equipment;
	drop sequence if exists public.seq_units;
	drop sequence if exists public.seq_base_units;
	drop sequence if exists public.seq_virtual_temperature_corrections;

	-- 1. Базовые единицы измерения
	create sequence public.seq_base_units start with 1;
	create table public.base_units
	(
		id integer default nextval('public.seq_base_units'),
		name text
	);
	comment on table public.base_units is 'Базовые единицы измерения';
	comment on column public.base_units.id is 'Уникальный код';
	comment on column public.base_units.name is 'Наименование';

	-- 2. Единицы измерения
	create sequence public.seq_units start with 1;
	create table public.units
	(
		id integer default nextval('public.seq_units'),
		name text,
		base_unit_id integer,
		convert_factor numeric(12,4)
	);
	comment on table public.units is 'Единицы измерения';
	comment on column public.units.id is 'Уникальный код';
	comment on column public.units.name is 'Наименование';
	comment on column public.units.base_unit_id is 'Уникальный код базовой единицы измерения';
	comment on column public.units.convert_factor is 'Коэффициент пересчета в базовую единицу';

	-- 3. Должности
	create sequence public.seq_military_positions start with 1;
	create table public.military_positions
	(
		id integer default nextval('public.seq_military_positions'),
		description character varying(255)
	);
	comment on table public.military_positions is 'Справочник должностей';
	comment on column public.military_positions.id is 'Уникальный код';
	comment on column public.military_positions.description is 'Описание';

	-- 4. Пользователи
	create sequence public.seq_employees start with 1;
	create table public.employees
	(
		id integer default nextval('public.seq_employees'),
		name text,
		birthday timestamp,
		military_position_id integer
	);
	comment on table public.employees is 'Пользователи';
	comment on column public.employees.id is 'Уникальный код';
	comment on column public.employees.name is 'ФИО';
	comment on column public.employees.birthday is 'Дата рождения';
	comment on column public.employees.military_position_id is 'Уникальный код должности';

	-- 5. Типы оборудования
	create sequence public.seq_measurement_equipment start with 1;
	create table public.measurement_equipment
	(
		id integer default nextval('public.seq_measurement_equipment'),
		short_name character varying(50),
		description text
	);
	comment on table public.measurement_equipment is 'Измерительное оборудование';
	comment on column public.measurement_equipment.id is 'Уникальный код';
	comment on column public.measurement_equipment.short_name is 'Краткое наименование';
	comment on column public.measurement_equipment.description is 'Описание';

	-- 6. Типы параметров
	create sequence public.seq_measurement_parameter_types start with 1;
	create table public.measurement_parameter_types
	(
		id integer default nextval('public.seq_measurement_parameter_types'),
		name text,
		unit_id integer,
		measurement_equipment_id integer
	);
	comment on table public.measurement_parameter_types is 'Справочник типов параметров';
	comment on column public.measurement_parameter_types.id is 'Уникальный код';
	comment on column public.measurement_parameter_types.name is 'Наименование';
	comment on column public.measurement_parameter_types.unit_id is 'Уникальный код единицы измерения';
	comment on column public.measurement_parameter_types.measurement_equipment_id is 'Уникальный код оборудования (пусто, если параметр общий)';

	-- 7. Пачки
	create sequence public.seq_measurement_batchs start with 1;
	create table public.measurement_batchs
	(
		id integer default nextval('public.seq_measurement_batchs'),
		employee_id integer,
		measurement_equipment_id integer,
		started timestamp default now()
	);
	comment on table public.measurement_batchs is 'Пачки';
	comment on column public.measurement_batchs.id is 'Уникальный код';
	comment on column public.measurement_batchs.employee_id is 'Уникальный код пользователя';
	comment on column public.measurement_batchs.measurement_equipment_id is 'Уникальный код оборудования';
	comment on column public.measurement_batchs.started is 'Дата измерения';

	-- 8. Параметры
	create sequence public.seq_measurement_input_params start with 1;
	create table public.measurement_input_params
	(
		id integer default nextval('public.seq_measurement_input_params'),
		measurement_batch_id integer,
		measurement_parameter_type_id integer,
		measurement_value numeric(10,2)
	);
	comment on table public.measurement_input_params is 'Таблица с параметрами';
	comment on column public.measurement_input_params.id is 'Уникальный код';
	comment on column public.measurement_input_params.measurement_batch_id is 'Уникальный код пачки';
	comment on column public.measurement_input_params.measurement_parameter_type_id is 'Уникальный код типа параметра';
	comment on column public.measurement_input_params.measurement_value is 'Значение';

	-- 9. Расчет температуры, таблица 1 (виртуальная поправка)
	create sequence public.seq_virtual_temperature_corrections start with 1;
	create table public.virtual_temperature_corrections
	(
		id integer default nextval('public.seq_virtual_temperature_corrections'),
		description character varying(50),
		temp_from numeric(5,1),
		temp_to numeric(5,1),
		correction numeric(3,1)
	);
	comment on table public.virtual_temperature_corrections is 'Расчет температуры. Таблица 1: виртуальная поправка';
	comment on column public.virtual_temperature_corrections.id is 'Уникальный код';
	comment on column public.virtual_temperature_corrections.description is 'Диапазон температуры как в ТЗ';
	comment on column public.virtual_temperature_corrections.temp_from is 'Температура от (пусто для строки "Ниже 0")';
	comment on column public.virtual_temperature_corrections.temp_to is 'Температура до (для строки "Ниже 0" граница не включается)';
	comment on column public.virtual_temperature_corrections.correction is 'Виртуальная поправка';

	raise notice 'Транзакция 1: таблицы и счетчики созданы';
end;
commit;



-- Транзакция 2. Тестовые данные
begin
	insert into public.base_units(id, name)
	values
		(1, 'Метр'),
		(2, 'Градус Цельсия'),
		(3, 'Миллиметр ртутного столба'),
		(4, 'Метр в секунду'),
		(5, 'Большое деление угломера');

	insert into public.units(id, name, base_unit_id, convert_factor)
	values
		(1, 'Метр', 1, 1),
		(2, 'Километр', 1, 1000),
		(3, 'Градус Цельсия', 2, 1),
		(4, 'Миллиметр ртутного столба', 3, 1),
		(5, 'Метр в секунду', 4, 1),
		(6, 'Большое деление угломера', 5, 1);

	insert into public.military_positions(id, description)
	values
		(1, 'Рядовой'),
		(2, 'Лейтенант'),
		(3, 'Сержант');

	insert into public.employees(id, name, birthday, military_position_id)
	values
		(1, 'Тунгусов Павел Алексеевич', '2007-10-17', 2),
		(2, 'Иванов Иван Иванович', '1985-03-12', 1),
		(3, 'Хатуев Руслан Алексеевич', '1990-11-05', 3);

	insert into public.measurement_equipment(id, short_name, description)
	values
		(1, 'ДМК', 'Десантный метео комплекс'),
		(2, 'ВР', 'Ветровое ружье');

	-- Единицы по ТЗ направление ветра в больших делениях угломера, скорость в м/с, дальность сноса в метрах
	insert into public.measurement_parameter_types(id, name, unit_id, measurement_equipment_id)
	values
		(1, 'Высота метеопоста', 1, null),
		(2, 'Температура', 3, null),
		(3, 'Давление', 4, null),
		(4, 'Направление ветра', 6, null),
		(5, 'Скорость ветра', 5, 1),
		(6, 'Дальность сноса пуль', 1, 2);

	-- 3 пачки ДМК (1-3) и 3 пачки ВР (4-6), у каждого сотрудника по две
	insert into public.measurement_batchs(id, employee_id, measurement_equipment_id, started)
	values
		(1, 1, 1, '2026-08-01 08:00:00'),
		(2, 2, 1, '2026-08-02 08:15:00'),
		(3, 3, 1, '2026-08-03 08:30:00'),
		(4, 1, 2, '2026-08-04 09:00:00'),
		(5, 2, 2, '2026-08-05 09:15:00'),
		(6, 3, 2, '2026-08-06 09:30:00');

	-- В каждой пачке по 5 параметров. ДМК: типы 1-5, ВР: типы 1, 2, 3, 4, 6
	insert into public.measurement_input_params(id, measurement_batch_id, measurement_parameter_type_id, measurement_value)
	values
		-- Пачка 1 (ДМК)
		(1, 1, 1, 100), (2, 1, 2, 15), (3, 1, 3, 750), (4, 1, 4, 10), (5, 1, 5, 3),
		-- Пачка 2 (ДМК)
		(6, 2, 1, 120), (7, 2, 2, 18.5), (8, 2, 3, 755), (9, 2, 4, 15), (10, 2, 5, 6),
		-- Пачка 3 (ДМК)
		(11, 3, 1, 90), (12, 3, 2, 5), (13, 3, 3, 745), (14, 3, 4, 42), (15, 3, 5, 9),
		-- Пачка 4 (ВР)
		(16, 4, 1, 100), (17, 4, 2, 12), (18, 4, 3, 748), (19, 4, 4, 30), (20, 4, 6, 40),
		-- Пачка 5 (ВР)
		(21, 5, 1, 150), (22, 5, 2, 25), (23, 5, 3, 765), (24, 5, 4, 5), (25, 5, 6, 85),
		-- Пачка 6 (ВР)
		(26, 6, 1, 80), (27, 6, 2, -10), (28, 6, 3, 740), (29, 6, 4, 55), (30, 6, 6, 120);

	-- Расчет температуры, таблица 1 из ТЗ
	insert into public.virtual_temperature_corrections(id, description, temp_from, temp_to, correction)
	values
		(1, 'Ниже 0', null, 0, 0),
		(2, '0 - 5', 0, 5, 0.5),
		(3, '10 - 15', 10, 15, 1),
		(4, '20', 20, 20, 1.5),
		(5, '25', 25, 25, 2),
		(6, '30', 30, 30, 3.5),
		(7, '40', 40, 40, 4.5);

	-- Следующее значение счетчика = максимальный код + 1
	perform setval('public.seq_base_units', (select max(id) from public.base_units));
	perform setval('public.seq_units', (select max(id) from public.units));
	perform setval('public.seq_military_positions', (select max(id) from public.military_positions));
	perform setval('public.seq_employees', (select max(id) from public.employees));
	perform setval('public.seq_measurement_equipment', (select max(id) from public.measurement_equipment));
	perform setval('public.seq_measurement_parameter_types', (select max(id) from public.measurement_parameter_types));
	perform setval('public.seq_measurement_batchs', (select max(id) from public.measurement_batchs));
	perform setval('public.seq_measurement_input_params', (select max(id) from public.measurement_input_params));
	perform setval('public.seq_virtual_temperature_corrections', (select max(id) from public.virtual_temperature_corrections));

	raise notice 'Транзакция 2: тестовые данные добавлены';
end;
commit;


-- Транзакция 3. Ограничения и связи
begin
	-- Обязательные поля
	alter table public.base_units alter column id set not null;
	alter table public.base_units alter column name set not null;
	alter table public.units alter column id set not null;
	alter table public.units alter column name set not null;
	alter table public.units alter column base_unit_id set not null;
	alter table public.units alter column convert_factor set not null;
	alter table public.military_positions alter column id set not null;
	alter table public.military_positions alter column description set not null;
	alter table public.employees alter column id set not null;
	alter table public.employees alter column name set not null;
	alter table public.employees alter column military_position_id set not null;
	alter table public.measurement_equipment alter column id set not null;
	alter table public.measurement_equipment alter column short_name set not null;
	alter table public.measurement_parameter_types alter column id set not null;
	alter table public.measurement_parameter_types alter column name set not null;
	alter table public.measurement_parameter_types alter column unit_id set not null;
	alter table public.measurement_batchs alter column id set not null;
	alter table public.measurement_batchs alter column employee_id set not null;
	alter table public.measurement_batchs alter column measurement_equipment_id set not null;
	alter table public.measurement_batchs alter column started set not null;
	alter table public.measurement_input_params alter column id set not null;
	alter table public.measurement_input_params alter column measurement_batch_id set not null;
	alter table public.measurement_input_params alter column measurement_parameter_type_id set not null;
	alter table public.measurement_input_params alter column measurement_value set not null;
	alter table public.virtual_temperature_corrections alter column id set not null;
	alter table public.virtual_temperature_corrections alter column description set not null;
	alter table public.virtual_temperature_corrections alter column correction set not null;

	-- Первичные ключи
	alter table public.base_units add constraint pk_base_units primary key (id);
	alter table public.units add constraint pk_units primary key (id);
	alter table public.military_positions add constraint pk_military_positions primary key (id);
	alter table public.employees add constraint pk_employees primary key (id);
	alter table public.measurement_equipment add constraint pk_measurement_equipment primary key (id);
	alter table public.measurement_parameter_types add constraint pk_measurement_parameter_types primary key (id);
	alter table public.measurement_batchs add constraint pk_measurement_batchs primary key (id);
	alter table public.measurement_input_params add constraint pk_measurement_input_params primary key (id);
	alter table public.virtual_temperature_corrections add constraint pk_virtual_temperature_corrections primary key (id);

	-- Уникальность
	alter table public.base_units add constraint uq_base_units_name unique (name);
	alter table public.units add constraint uq_units_name unique (name);
	alter table public.measurement_equipment add constraint uq_measurement_equipment_short_name unique (short_name);
	-- В одной пачке один тип параметра встречается только один раз
	alter table public.measurement_input_params
		add constraint uq_measurement_input_params_batch_type unique (measurement_batch_id, measurement_parameter_type_id);

	-- Внешние ключи
	alter table public.units
		add constraint fk_units_base_unit foreign key (base_unit_id) references public.base_units (id);
	alter table public.employees
		add constraint fk_employees_military_position foreign key (military_position_id) references public.military_positions (id);
	alter table public.measurement_parameter_types
		add constraint fk_parameter_types_unit foreign key (unit_id) references public.units (id);
	alter table public.measurement_parameter_types
		add constraint fk_parameter_types_equipment foreign key (measurement_equipment_id) references public.measurement_equipment (id);
	alter table public.measurement_batchs
		add constraint fk_batchs_employee foreign key (employee_id) references public.employees (id);
	alter table public.measurement_batchs
		add constraint fk_batchs_equipment foreign key (measurement_equipment_id) references public.measurement_equipment (id);
	alter table public.measurement_input_params
		add constraint fk_input_params_batch foreign key (measurement_batch_id) references public.measurement_batchs (id);
	alter table public.measurement_input_params
		add constraint fk_input_params_parameter_type foreign key (measurement_parameter_type_id) references public.measurement_parameter_types (id);

	-- Проверки
	alter table public.units add constraint ck_units_convert_factor check (convert_factor > 0);
	alter table public.virtual_temperature_corrections
		add constraint ck_temperature_corrections_range check (temp_from is null or temp_to is null or temp_to >= temp_from);
	alter table public.virtual_temperature_corrections
		add constraint ck_temperature_corrections_value check (correction >= 0);

	raise notice 'Транзакция 3: ограничения и связи созданы';
	end;
	commit;
end $$;
