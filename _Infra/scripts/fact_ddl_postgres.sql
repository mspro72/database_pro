do $$
begin

-- drop table if exists fact_purchases cascade;
-- drop sequence if exists seq_fact_purchases cascade;

-- факт закупки
create sequence seq_fact_purchases;
create table fact_purchases
(
    id bigint default nextval('public.seq_fact_purchases') not null,
    external_id bigint not null,
    product_id bigint not null,
    range_id bigint,
    category_id bigint not null,
    vendor_id bigint not null,
    quantity numeric(18,4) not null,
    amount numeric(18,2) not null,
    date_add timestamp default now(),
    time_id bigint not null
);
alter sequence seq_fact_purchases owned by fact_purchases.id;

-- ключи и связи с ресурсами
alter table fact_purchases add constraint pk_fact_purchases primary key (id);
alter table fact_purchases add constraint uq_fact_purchases_external unique (external_id);
alter table fact_purchases add constraint fk_fact_purchases_product foreign key (product_id) references dim_product (id);
alter table fact_purchases add constraint fk_fact_purchases_range foreign key (range_id) references dim_ranges (id);
alter table fact_purchases add constraint fk_fact_purchases_category foreign key (category_id) references dim_category (id);
alter table fact_purchases add constraint fk_fact_purchases_vendor foreign key (vendor_id) references dim_vendors (id);
alter table fact_purchases add constraint fk_fact_purchases_time foreign key (time_id) references dim_time (id);

end $$;
