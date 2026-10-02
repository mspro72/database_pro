-- Миграционный скрипт
-- 2026-09-23
drop table if exists military_ranks;
drop table if exists employees;
drop table if exists measurment_types;
drop table if exists measurment_input_params;
drop table if exists measurment_baths;

-- 1. Справочник должностей
create table military_ranks
(
	id integer,
	description character varying(255)
);

comment on table military_ranks is 'Справочник должностей';
comment on column military_ranks.id is 'Уникальный код';
comment on column military_ranks.description is 'Описание';

-- Заполняем данные
insert into military_ranks(id, description)
values(1,'Рядовой'),(2,'Лейтенант');

-- 2. Пользователя
create table employees
(
    id integer,
	name text,
	birthday timestamp ,
	military_rank_id integer
);

comment on table employees is 'Пользователи';
comment on column employees.id is 'Уникальный код';
comment on column employees.name is 'Наименование';
comment on column employees.birthday is 'Дата рождения';
comment on column employees.military_rank_id is 'Уникальный код должности';

-- Заполняем данные
insert into employees(id, name, birthday,military_rank_id )  
values(1, 'Тунгусов Павел Алексеевич','2007-10-17', 2);

-- 3. Устройства для измерения
create table measurment_types
(
   id integer,
   short_name  character varying(50),
   description text 
);

comment on table measurment_types is 'Измерительное оборудование';
comment on column measurment_types.id is 'Уникальный код';
comment on column measurment_types.short_name is 'Краткое наименование';
comment on column measurment_types.description is 'Описание';

-- Заполняем данные
insert into measurment_types(id, short_name, description)
values(1, 'ДМК', 'Десантный метео комплекс'),
(2,'ВР','Ветровое ружье');


-- 4. Таблица с параметрами
create table measurment_input_params
(
    id integer,
	measurment_bath_id integer,
	height numeric(8,2) default 0,
	temperature numeric(8,2) default 0,
	pressure numeric(8,2) default 0,
	wind_direction numeric(8,2) default 0,
	wind_speed numeric(8,2) default 0
);

comment on table measurment_input_params is 'Таблица с параметрами';
comment on column measurment_input_params.id is 'Уникальный код';
comment on column measurment_input_params.measurment_bath_id is 'Уникальный код пачки';
comment on column measurment_input_params.height is 'Высота';
comment on column measurment_input_params.temperature is 'Температура';
comment on column measurment_input_params.pressure is 'Давление';
comment on column measurment_input_params.wind_direction is 'Направление ветка';
comment on column measurment_input_params.wind_speed is 'Скорость ветра';

-- Заполняем данные
insert into measurment_input_params(id, measurment_bath_id, height, temperature, pressure, wind_direction,wind_speed )
values(1, 1, 100,12,34,0.2,45);



-- 5. Таблица с историей
create table measurment_baths
(
	id integer ,
	emploee_id integer,
	measurment_type_id integer,
	started timestamp default now()
);

comment on table measurment_baths is 'Пачки';
comment on column measurment_baths.emploee_id is 'Уникальный код пользователя';
comment on column measurment_baths.measurment_type_id is 'Уникальный код оборудования';
comment on column measurment_baths.started is 'Дата измерения';

-- Заполняем данные
insert into measurment_baths(id, emploee_id, measurment_type_id, started)
values(1, 1, 1, '2026-09-01'),(2,1,2, '2026-09-02');

---------------------------------------------------
-- Итоговый запрос
---------------------------------------------------

select *
from measurment_baths, measurment_input_params, measurment_types, employees, military_ranks
where
        -- Связь пачка - пользователи
	    employees.id = measurment_baths.emploee_id
		-- Связь должность - пользователь
	and employees.military_rank_id = military_ranks.id
	   -- Связь пачка - тип оборудования
	and measurment_types.id = measurment_baths.measurment_type_id
	   -- Связь пачка - параетры
	and measurment_input_params.measurment_bath_id = measurment_baths.id;