-- Миграционный скрипт
-- 2026-09-30

-- Исправляем наименования
alter table military_ranks rename to military_positions;
alter table employees rename column military_rank_id to military_position_id;
alter table measurment_types rename to measurment_equipment;
alter table measurment_baths rename column measurment_type_id to measurment_equipment_id;
alter table measurment_baths rename to measurment_batchs;
alter table measurment_input_params rename column measurment_bath_id to measurment_batch_id;



-- Справочник базовых единиц измерений
create table base_units
(
    id integer,
	name text
);

comment on table base_units is 'Базовые единицы измерения';
comment on column base_units.id is 'Уникальный код';
comment on column base_units.name is 'Наименование';

insert into base_units (id, name)
values 
	(1, 'Метр'),
	(2 ,'Градус'),
	(3, 'Паскаль');


-- 	Справочник единиц измерения
create table units
(
    id integer,
	name text,
	base_unit_id integer,
	convert_factor integer
);

comment on table units is 'Единицы измерения';
comment on column units.id is 'Уникальный код';
comment on column units.name is 'Наименование';
comment on column units.base_unit_id is 'Уникальный код базовой единицы измерения';
comment on column units.convert_factor is 'Коэффициент пересчета';

insert into units(id, name, base_unit_id, convert_factor)
values
   (1, 'Киллометр', 1, 1000),
   (2, 'Градус', 2, 1),
   (3, 'Паскаль', 3, 1),
   (4, 'Метр', 1, 1),
   (5, 'Миллиметры ртутного столба', null, null),
   (6, 'Метр в секунду', null, null);

-- Справочник типов параметров
create table measurement_parameter_types
(
   id integer,
   name text,
   unit_id integer,
   measurment_equipment_id integer
);

comment on table measurement_parameter_types is 'Справочник типов параметров';
comment on column measurement_parameter_types.id is 'Уникальный код';
comment on column measurement_parameter_types.name is 'Наименование';
comment on column measurement_parameter_types.unit_id is 'Уникальный код единицы измерения';
comment on column measurement_parameter_types.measurment_equipment_id is 'Уникальный код оборудования';

insert into measurement_parameter_types(id, name, unit_id, measurment_equipment_id)
values
   (1, 'Высота метеопаста', 4, null),
   (2, 'Температура', 2, null),
   (3, 'Давление', 5, null),
   (4, 'Направление ветра', null, null),
   (5, 'Скорость ветра', 6, 1),
   (6, 'Дальность сноса пуль', null, 2);

-- Меняем данные в основной таблицы параметров
alter table measurment_input_params add measurement_parameter_type_id integer;
alter table measurment_input_params add measurement_value numeric(10,2);


-- Переносим данные
-- select * from public.measurment_input_params

-- Высота
insert into public.measurment_input_params(id, measurment_batch_id, measurement_parameter_type_id, measurement_value)
select 2, measurment_batch_id, 1, height as measurement_value
from	measurment_input_params where id = 1;

-- Температура
insert into public.measurment_input_params(id, measurment_batch_id, measurement_parameter_type_id, measurement_value)
select 3, measurment_batch_id, 2, temperature as measurement_value
from	measurment_input_params where id = 1;

-- Давление
insert into public.measurment_input_params(id, measurment_batch_id, measurement_parameter_type_id, measurement_value)
select 4, measurment_batch_id, 3, pressure as measurement_value
from	measurment_input_params where id = 1;

-- Направление ветра
insert into public.measurment_input_params(id, measurment_batch_id, measurement_parameter_type_id, measurement_value)
select 5, measurment_batch_id, 4, wind_direction as measurement_value
from	measurment_input_params where id = 1;

-- Скорость ветка
insert into public.measurment_input_params(id, measurment_batch_id, measurement_parameter_type_id, measurement_value)
select 6, measurment_batch_id, 5, wind_speed as measurement_value
from	measurment_input_params where id = 1;

-- Дальность сноса пуль
insert into public.measurment_input_params(id, measurment_batch_id, measurement_parameter_type_id, measurement_value)
values (7, 1, 6, 0);

-- Удаляем старые данные и колонки
delete from measurment_input_params where id = 1;
alter table measurment_input_params drop column height;
alter table measurment_input_params drop column temperature;
alter table measurment_input_params drop column pressure;
alter table measurment_input_params drop column wind_direction;
alter table measurment_input_params drop column wind_speed;



---------------------------------------------------
-- Итоговый запрос
---------------------------------------------------

select *
from measurment_batchs, measurment_input_params, measurment_equipment, employees, military_positions,
     -- Новые таблицы
	 measurement_parameter_types, units, base_units
where
        -- Связь пачка - пользователи
	    employees.id = measurment_batchs.emploee_id
		-- Связь должность - пользователь
	and employees.military_position_id = military_positions.id
	   -- Связь пачка - тип оборудования
	and measurment_equipment.id = measurment_batchs.measurment_equipment_id
	   -- Связь пачка - параетры
	and measurment_input_params.measurment_batch_id = measurment_batchs.id
	-- Тип параметра - параметр
	and measurement_parameter_types.id = measurment_input_params.measurement_parameter_type_id
	-- Тип параметра - единица измерения
	and units.id = measurement_parameter_types.unit_id
	-- Единица измиерения - базовая единица
	and base_units.id = units.base_unit_id;




  

