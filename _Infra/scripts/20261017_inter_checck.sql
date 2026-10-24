-- Скрипт 2. Проверки расчета интерполяции
do $do$
declare
	var_row record;
	var_params public.intepolation_type;
	var_actual numeric;
	var_status text;
	var_failed integer := 0;
begin
	for var_row in
		select *
		from (values
			(100::numeric, 4.5::numeric),
			(-10, 0.5),
			(20, 1.0),
			(27.5, 2.75),
			(30, 3.5),
			(35, 4.0),
			(50, 4.5),
			(-20, 0.5)
		) as t(temperature, expected)
	loop
		var_params := public.fn_get_interpolation_for_correction(var_row.temperature);
		var_actual := public.fn_calc_interpolation(var_row.temperature, var_params);

		if abs(var_actual - var_row.expected) < 0.001 then
			var_status := 'TRUE';
		else
			var_status := 'FALSE';
			var_failed := var_failed + 1;
		end if;

		raise notice 't=% | x0=% y0=% x1=% y1=% | ожидалось % получено % | %',
			var_row.temperature, var_params.x0, var_params.y0, var_params.x1, var_params.y1,
			var_row.expected, var_actual, var_status;
	end loop;

	if var_failed > 0 then
		raise exception 'Проверок не пройдено: %', var_failed;
	end if;

	raise notice 'Все проверки пройдены';
end
$do$;

