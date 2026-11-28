do $$
begin

-- время (id = код месяца ГГГГММ, например 202011)
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

-- ед. измерени
create sequence seq_dim_ranges;
create table dim_ranges
(
    id bigint primary key default nextval('public.seq_dim_ranges'),
    external_id bigint unique not null,
    name text,
    factor float,
    date_add timestamp default now()
);

-- базовые ед. измерения
create sequence seq_dim_base_ranges;
create table dim_base_ranges
(
    id bigint primary key default nextval('public.seq_dim_base_ranges'),
    external_id bigint unique not null,
    group_id bigint,
    short_name text,
    name text,
    date_add timestamp default now()
);

-- поставщики external_id = 0 это Без поставщика
create sequence seq_dim_vendors;
create table dim_vendors
(
    id bigint primary key default nextval('public.seq_dim_vendors'),
    external_id bigint unique not null,
    name text,
    parent_id bigint,
    parent_name text,
    date_add timestamp default now()
);

-- категории
create sequence seq_dim_category;
create table dim_category
(
    id bigint primary key default nextval('public.seq_dim_category'),
    external_id bigint unique not null,
    name text,
    parent_id bigint,
    date_add timestamp default now()
);

--продукиы (productid в источнике строка, поэтому text)
create sequence seq_dim_product;
create table dim_product
(
    id bigint primary key default nextval('public.seq_dim_product'),
    external_id bigint unique not null,
    productid text,
    product_name text,
    date_add timestamp default now()
);

-- сотрудники
create sequence seq_dim_personnel;
create table dim_personnel
(
    id bigint primary key default nextval('public.seq_dim_personnel'),
    external_id bigint unique not null,
    fullname text,
    date_add timestamp default now()
);

-- склад одна строка одна складская операция (поступление или списание).
-- Периода (месяца) в таблице нет, он вычисляется из operation_date:
-- to_char(operation_date, 'YYYYMM')::bigint = dim_time.id
create sequence seq_dim_storage;
create table dim_storage
(
    id bigint primary key default nextval('public.seq_dim_storage'),
    operation_date timestamp,
    operation_id bigint,
    operation_name text,
    productid bigint,
    product_name text,
    vendor_id bigint,
    vendor_name text,
    range_id bigint,
    range_name text,
    product_count decimal(18,4),
    amount decimal(18,2),
    date_add timestamp default now()
);

end $$;
