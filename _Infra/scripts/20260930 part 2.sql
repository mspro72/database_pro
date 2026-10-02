-- Миграционный скрипт
-- 2026-09-30

-- 0. Очистка таблиц с данными (чтобы избежать дублей при перезапуске)
delete from measurment_input_params;
delete from measurment_batchs;


-- 1. Исправление опечаток в наименованиях колонок
-- Переименовываем emploee_id в employee_id в таблице пачек
alter table measurment_batchs rename column emploee_id to employee_id;

-- 2. Дополняем справочники (добавляем недостающие данные для тестов)

-- Добавляем недостающую должность (Сержант)
insert into military_positions(id, description)
values(3, 'Сержант');


-- Добавляем еще двух пользователей (Иванов и Сидоров)
insert into employees(id, name, birthday, military_position_id)
values
(2, 'Иванов Петр Иванович', '1985-03-12', 1),
(3, 'Сидоров Алексей Викторович', '1990-11-05', 3)
;

-- 3. Создаем 20 пачек измерений (10 для ДМК и 10 для ВР) за один месяц

-- Пачки для оборудования id=1 (ДМК) - пользователь Воловиков (id=1)
insert into measurment_batchs(id, employee_id, measurment_equipment_id, started)
values
(1, 1, 1, '2026-08-01 08:00:00'),
(2, 1, 1, '2026-08-02 08:15:00'),
(3, 1, 1, '2026-08-03 08:30:00'),
(4, 1, 1, '2026-08-04 08:45:00'),
(5, 1, 1, '2026-08-05 09:00:00'),
(6, 1, 1, '2026-08-06 09:15:00'),
(7, 1, 1, '2026-08-07 09:30:00'),
(8, 1, 1, '2026-08-08 09:45:00'),
(9, 1, 1, '2026-08-09 10:00:00'),
(10, 1, 1, '2026-08-10 10:15:00');

-- Пачки для оборудования id=2 (ВР) - пользователь Иванов (id=2)
insert into measurment_batchs(id, employee_id, measurment_equipment_id, started)
values
(11, 2, 2, '2026-08-11 11:00:00'),
(12, 2, 2, '2026-08-12 11:15:00'),
(13, 2, 2, '2026-08-13 11:30:00'),
(14, 2, 2, '2026-08-14 11:45:00'),
(15, 2, 2, '2026-08-15 12:00:00'),
(16, 2, 2, '2026-08-16 12:15:00'),
(17, 2, 2, '2026-08-17 12:30:00'),
(18, 2, 2, '2026-08-18 12:45:00'),
(19, 2, 2, '2026-08-19 13:00:00'),
(20, 2, 2, '2026-08-20 13:15:00');

-- 4. Наполняем таблицу параметров (ровно по 10 измерений на тип)

-- 4.1. Параметры для ДМК (Equipment ID = 1)
-- Используем типы: 1(Высота), 2(Температура), 3(Давление), 4(Направление), 5(Скорость)

-- Высота (type_id=1)
insert into measurment_input_params(id, measurment_batch_id, measurement_parameter_type_id, measurement_value)
select id, id, 1, (100 + id * 5)::numeric(10,2) from measurment_batchs where id between 1 and 10;

-- Температура (type_id=2)
insert into measurment_input_params(id, measurment_batch_id, measurement_parameter_type_id, measurement_value)
select id + 100, id, 2, (10 + (id % 10) * 1.5)::numeric(10,2) from measurment_batchs where id between 1 and 10;

-- Давление (type_id=3)
insert into measurment_input_params(id, measurment_batch_id, measurement_parameter_type_id, measurement_value)
select id + 200, id, 3, (1010 + (id % 10) * 2.1)::numeric(10,2) from measurment_batchs where id between 1 and 10;

-- Направление ветра (type_id=4)
insert into measurment_input_params(id, measurment_batch_id, measurement_parameter_type_id, measurement_value)
select id + 300, id, 4, (id * 30 % 360)::numeric(10,2) from measurment_batchs where id between 1 and 10;

-- Скорость ветра (type_id=5)
insert into measurment_input_params(id, measurment_batch_id, measurement_parameter_type_id, measurement_value)
select id + 400, id, 5, (2 + (id % 10) * 0.8)::numeric(10,2) from measurment_batchs where id between 1 and 10;


-- 4.2. Параметры для ВР (Equipment ID = 2)
-- Используем типы: 4(Направление), 5(Скорость), 6(Дальность)

-- Направление ветра (type_id=4)
insert into measurment_input_params(id, measurment_batch_id, measurement_parameter_type_id, measurement_value)
select id + 500, id, 4, (id * 25 % 360)::numeric(10,2) from measurment_batchs where id between 11 and 20;

-- Скорость ветра (type_id=5)
insert into measurment_input_params(id, measurment_batch_id, measurement_parameter_type_id, measurement_value)
select id + 600, id, 5, (5 + (id % 10) * 1.2)::numeric(10,2) from measurment_batchs where id between 11 and 20;

-- Дальность сноса пуль (type_id=6)
insert into measurment_input_params(id, measurment_batch_id, measurement_parameter_type_id, measurement_value)
select id + 700, id, 6, (100 + (id % 10) * 15.5)::numeric(10,2) from measurment_batchs where id between 11 and 20;


-- Наименование иаблиц меняем
alter table public.measurment_batchs rename to measurement_batchs;
alter table public.measurment_equipment rename to measurement_equipment;
alter table public.measurment_input_params rename to measurement_input_params;
alter table public.measurement_input_params rename column measurment_batch_id to measurement_batch_id;
alter table public.measurement_parameter_types rename column measurment_equipment_id to measurement_equipment_id;

