-- 1. Список параметров с ошибками
-- Параметры раскладываем по колонкам (проекция), для каждой пачки вызываем функцию проверки.
with
batch_lists as (
	select t1.id as batch_id,
	       t1.measurement_equipment_id,
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
	select t1.batch_id,
	       t1.measurement_equipment_id,
	       public.fn_check_measurement_params(t1.param_list) as errors
	from batch_lists t1
),
-- Если параметр передан дважды, показываем оба значения
params_pivot as (
	select t1.measurement_batch_id as batch_id,
	       string_agg(trim_scale(t1.measurement_value)::text, ' / ') filter (where t1.measurement_parameter_type_id = 1) as height,
	       string_agg(trim_scale(t1.measurement_value)::text, ' / ') filter (where t1.measurement_parameter_type_id = 2) as temperature,
	       string_agg(trim_scale(t1.measurement_value)::text, ' / ') filter (where t1.measurement_parameter_type_id = 3) as pressure,
	       string_agg(trim_scale(t1.measurement_value)::text, ' / ') filter (where t1.measurement_parameter_type_id = 4) as wind_direction,
	       string_agg(trim_scale(t1.measurement_value)::text, ' / ') filter (where t1.measurement_parameter_type_id = 5) as wind_speed,
	       string_agg(trim_scale(t1.measurement_value)::text, ' / ') filter (where t1.measurement_parameter_type_id = 6) as bullet_drift
	from public.measurement_input_params t1
	group by t1.measurement_batch_id
)
select c.batch_id as "№",
       e.short_name as "Тип оборудования",
       p.height as "Высота метеопоста",
       p.temperature as "Температура",
       p.pressure as "Давление",
       p.wind_direction as "Направление ветра",
       p.wind_speed as "Скорость ветра",
       p.bullet_drift as "Дальность сноса пуль",
       case when c.errors <> '' then 'Да' else 'Нет' end as "Флаг: Есть ошибка",
       nullif(c.errors, '') as "Описание ошибки"
from checked c
left join public.measurement_equipment e on e.id = c.measurement_equipment_id
left join params_pivot p on p.batch_id = c.batch_id
order by c.batch_id;


-- 2. Лучший стрелок
-- Считаем ошибки по каждому пользователю и ставим место по среднему числу ошибок на пачку.
-- Пользователи без пачек остаются в списке, но места не получают
with
batch_lists as (
	select t1.id as batch_id,
	       t1.employee_id,
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
	group by t1.id, t1.employee_id, t1.measurement_equipment_id
),
checked as (
	select t1.batch_id,
	       t1.employee_id,
	       case
	           when t1.errors = '' then 0
	           else cardinality(string_to_array(t1.errors, '; '))
	       end as error_count
	from
	(
		select b.batch_id, b.employee_id, public.fn_check_measurement_params(b.param_list) as errors
		from batch_lists b
	) as t1
),
user_stat as (
	select t1.id as employee_id,
	       t1.name as fio,
	       count(t2.batch_id) as cnt_batchs,
	       count(*) filter (where t2.error_count > 0) as cnt_bad_batchs,
	       coalesce(sum(t2.error_count), 0) as cnt_errors
	from public.employees t1
	left join checked t2 on t2.employee_id = t1.id
	group by t1.id, t1.name
),
ranked as (
	select t1.*,
	       case when t1.cnt_batchs > 0 then round(t1.cnt_errors::numeric / t1.cnt_batchs, 2) end as errors_per_batch,
	       case
	           when t1.cnt_batchs > 0 then
	               rank() over (order by case when t1.cnt_batchs > 0 then t1.cnt_errors::numeric / t1.cnt_batchs end nulls last)
	       end as place
	from user_stat t1
)
select t1.place as "Место",
       t1.fio as "Пользователь",
       t1.cnt_batchs as "Пачек",
       t1.cnt_bad_batchs as "Пачек с ошибками",
       t1.cnt_errors as "Ошибок",
       t1.errors_per_batch as "Ошибок на пачку",
       case when t1.place = 1 then 'Лучший стрелок' else '' end as "Итог"
from ranked t1
order by t1.place nulls last, t1.fio;


-- 3. Метео приближенный по пачкам без ошибок
with
batch_values as (
	select t1.measurement_batch_id as batch_id,
	       max(t1.measurement_value) filter (where t1.measurement_parameter_type_id = 1) as height,
	       max(t1.measurement_value) filter (where t1.measurement_parameter_type_id = 2) as temperature,
	       max(t1.measurement_value) filter (where t1.measurement_parameter_type_id = 3) as pressure
	from public.measurement_input_params t1
	group by t1.measurement_batch_id
),
meteo as (
	select b.id as batch_id,
	       public.fn_meteo_ddchhm(b.started) as ddchhm,
	       public.fn_meteo_vvvv(v.height) as vvvv,
	       public.fn_meteo_bbbtt(v.temperature, v.pressure) as bbbtt
	from public.measurement_batchs b
	inner join batch_values v on v.batch_id = b.id
	where not b.is_error
)
select t1.batch_id as "№",
       t1.ddchhm as "ДДЧЧМ",
       t1.vvvv as "ВВВВ",
       t1.bbbtt as "БББТТ",
       'Метео ' || t1.ddchhm || ' ' || t1.vvvv || ' ' || t1.bbbtt as "Бюллетень"
from meteo t1
order by t1.batch_id;
