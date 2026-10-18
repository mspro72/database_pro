-- Скрипт 1. Тип и функции для интерполяции поправки температуры
do $do$
begin
	drop function if exists public.fn_calc_interpolation(numeric, public.intepolation_type);
	drop function if exists public.fn_get_interpolation_for_correction(numeric);
	drop type if exists public.intepolation_type;

	-- Структура для интерполяции
	create type public.intepolation_type as
	(
		x0 numeric(6,2),
		y0 numeric(6,2),
		x1 numeric(6,2),
		y1 numeric(6,2)
	);

	-- Определение параметров интерполяции по температуре
	create function public.fn_get_interpolation_for_correction(par_temperature numeric)
	returns public.intepolation_type
	language plpgsql
	stable
	as $body$
	declare
		var_result public.intepolation_type;
	begin
		select
			coalesce(
				(select max(t1.temperature) from public.calc_temperature_correction t1 where t1.temperature <= p.target_temp),
				p.target_temp
			) as x0,
			coalesce(
				(select t3.correction from public.calc_temperature_correction t3
				 where t3.temperature = (select max(t1.temperature) from public.calc_temperature_correction t1 where t1.temperature <= p.target_temp)),
				(select t4.correction from public.calc_temperature_correction t4
				 where t4.temperature = (select min(t2.temperature) from public.calc_temperature_correction t2))
			) as y0,
			coalesce(
				(select min(t1.temperature) from public.calc_temperature_correction t1 where t1.temperature >= p.target_temp),
				p.target_temp
			) as x1,
			coalesce(
				(select t3.correction from public.calc_temperature_correction t3
				 where t3.temperature = (select min(t1.temperature) from public.calc_temperature_correction t1 where t1.temperature >= p.target_temp)),
				(select t4.correction from public.calc_temperature_correction t4
				 where t4.temperature = (select max(t2.temperature) from public.calc_temperature_correction t2))
			) as y1
		into var_result
		from (select par_temperature as target_temp) p;

		return var_result;
	end;
	$body$;

	-- Расчет линейной интерполяции
	create function public.fn_calc_interpolation(par_x numeric, par_interpolation public.intepolation_type)
	returns numeric
	language plpgsql
	immutable
	as $body$
	begin
		if par_interpolation.x1 = par_interpolation.x0 then
			return par_interpolation.y0;
		end if;

		return par_interpolation.y0
			+ (par_x - par_interpolation.x0) * (par_interpolation.y1 - par_interpolation.y0)
			/ (par_interpolation.x1 - par_interpolation.x0);
	end;
	$body$;

	raise notice 'Тип и функции интерполяции созданы';
end
$do$;