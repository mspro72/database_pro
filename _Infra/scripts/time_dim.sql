do $$
begin
    create sequence seq_dim_time;

    create table dim_time
    (
        id bigint primary key default nextval('public.seq_dim_time'),
        date_start date,
        date_end date,
        month_name text,
        year int,
        quarter_num int,
        quarter_name text
    );
end $$;

select * from dim_time;