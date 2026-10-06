-- Анализ данных измерений 
-- 2026-10-02

-- 1. Одинаковое ли количество измерений у сотрудников
-- Считаем пачки по каждому сотруднику. Через left join, чтобы тот, у кого пачек нет совсем, тоже показался с нулем
select t1.name as fio, coalesce(inner_t2.cnt_batchs, 0) as cnt_batchs
from public.employees as t1
left join
(
    -- Подзапрос
    select employee_id, count(*) as cnt_batchs
    from public.measurement_batchs
    group by employee_id
) as inner_t2 on t1.id = inner_t2.employee_id
order by t1.name;

-- 2. Есть ли пустые пачки
-- Сначала группируем параметры по коду пачки, потом цепляем к пачкам через left join.
-- Если для пачки в группировке ничего нет, значит она пустая. Заодно смотрим, чья она
select t1.id as batch_id, t1.started, t3.name as fio
from public.measurement_batchs as t1
left join
(
    -- Подзапрос
    select measurement_batch_id, count(*) as cnt_records
    from public.measurement_input_params
    group by measurement_batch_id
) as inner_t2 on t1.id = inner_t2.measurement_batch_id
inner join public.employees as t3 on t3.id = t1.employee_id
where inner_t2.measurement_batch_id is null
order by t1.id;

-- 3. У всех ли пачек по 5 параметров
-- Пустые пачки тут не видно, их мы уже нашли в запросе 2
select t1.id as batch_id, t1.started, t3.name as fio, inner_t2.cnt_records
from public.measurement_batchs as t1
inner join
(
    -- Подзапрос
    select measurement_batch_id, cnt_records from
    (
        -- Подзапрос
        select measurement_batch_id, count(*) as cnt_records
        from public.measurement_input_params t1
        group by measurement_batch_id
    ) as t1
    where cnt_records <> 5
) as inner_t2 on t1.id = inner_t2.measurement_batch_id
inner join public.employees as t3 on t3.id = t1.employee_id
order by t1.id;


-- 4. Все ли значения в допустимых диапазонах
-- Диапазоны берем из ТЗ:
-- 2 Температура: -58..58
-- 3 Давление: 500..900
-- 4 Направление ветра: 0..59
-- 5 Скорость ветра: 0..15
-- 6 Дальность сноса пуль: 0..150
-- 1 Высота: в ТЗ границ нет, поэтому ее не проверяем
-- В подзапросе только плохие значения, а left join показывает все пачки:
-- у кого есть плохое значение, там будет "Некорректно", у остальных "Корректно"
select t1.id as batch_id, t1.started,
       coalesce(inner_t2.check_result, 'Корректно') as check_result,
       inner_t2.parameter_name, inner_t2.measurement_value
from public.measurement_batchs as t1
left join
(
    -- Подзапрос
    select t2.measurement_batch_id, t3.name as parameter_name, t2.measurement_value,
           cast('Некорректно' as varchar(20)) as check_result
    from public.measurement_input_params as t2
    inner join public.measurement_parameter_types as t3 on t3.id = t2.measurement_parameter_type_id
    where (t2.measurement_parameter_type_id = 2 and (t2.measurement_value < -58 or t2.measurement_value > 58))
       or (t2.measurement_parameter_type_id = 3 and (t2.measurement_value < 500 or t2.measurement_value > 900))
       or (t2.measurement_parameter_type_id = 4 and (t2.measurement_value < 0   or t2.measurement_value > 59))
       or (t2.measurement_parameter_type_id = 5 and (t2.measurement_value < 0   or t2.measurement_value > 15))
       or (t2.measurement_parameter_type_id = 6 and (t2.measurement_value < 0   or t2.measurement_value > 150))
) as inner_t2 on t1.id = inner_t2.measurement_batch_id
order by t1.id;

-- 5. Правильные ли единицы измерения у параметров
-- Выводим только те параметры, где единица не совпала или вообще не указана
select * from
(
    -- Подзапрос
    select t1.id, t1.name as parameter_name, t1.unit_id,
           t2.name as current_unit,
           case t1.id
               when 1 then 'Метр'
               when 2 then 'Градус Цельсия'
               when 3 then 'Миллиметры ртутного столба'
               when 4 then 'Большое деление угломера'
               when 5 then 'Метр в секунду'
               when 6 then 'Метр'
           end as expected_unit
    from public.measurement_parameter_types as t1
    left join public.units as t2 on t2.id = t1.unit_id
) as inner_t2
where current_unit is null
   or current_unit <> expected_unit
order by id;