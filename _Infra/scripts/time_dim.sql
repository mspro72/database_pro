do $$
declare
    d date := date '2020-01-01';
    end_date date := date '2023-12-01';
    month_names text[] := array['Январь','Февраль','Март','Апрель','Май','Июнь',
                                'Июль','Август','Сентябрь','Октябрь','Ноябрь','Декабрь'];
    m int;
    q int;
begin
    create table dim_time
    (
        id bigint primary key,
        date_start date not null,
        date_end date not null,
        month_name text,
        year int,
        quarter_num int,
        quarter_name text
    );

    while d <= end_date loop
        m := extract(month from d)::int;
        q := extract(quarter from d)::int;

        insert into dim_time(id, date_start, date_end, month_name, year, quarter_num, quarter_name)
        values (
            extract(year from d)::int * 100 + m,
            d,
            (d + interval '1 month' - interval '1 day')::date,
            month_names[m],
            extract(year from d)::int,
            q,
            q || ' квартал'
        );

        d := (d + interval '1 month')::date;
    end loop;
end $$;

select * from dim_time;