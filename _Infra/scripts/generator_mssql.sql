-- ед. измерения
select 'insert into dim_ranges(external_id, name, factor) values ('
    + cast(t.ID as varchar(20)) + ','
    + isnull('''' + replace(t.sizeid, '''', '''''') + '''', 'null') + ','
    + isnull(cast(t.portionrate as varchar(40)), 'null') + ');' as [sql]
from [size] t

-- базовые ед. измерения
select 'insert into dim_base_ranges(external_id, group_id, short_name, name) values ('
    + cast(t.ID as varchar(20)) + ','
    + isnull(cast(t.GroupID as varchar(20)), 'null') + ','
    + isnull('''' + replace(t.ShortName, '''', '''''') + '''', 'null') + ','
    + isnull('''' + replace(t.[Description], '''', '''''') + '''', 'null') + ');' as [sql]
from bm_classifierSizes t

-- категории если 0 то null
select 'insert into dim_category(external_id, name, parent_id) values ('
    + cast(t.id as varchar(20)) + ','
    + isnull('''' + replace(t.description, '''', '''''') + '''', 'null') + ','
    + case when coalesce(t.ParentID, 0) = 0 then 'null' else cast(t.ParentID as varchar(20)) end
    + ');' as [sql]
from category t

-- поставщики
select 'insert into dim_vendors(external_id, name, parent_id, parent_name) values ('
    + cast(t1.id as varchar(20)) + ','
    + isnull('''' + replace(t1.clientid, '''', '''''') + '''', 'null') + ','
    + isnull(cast(t2.vendorgroupid as varchar(20)), 'null') + ','
    + isnull('''' + replace(t2.description, '''', '''''') + '''', 'null') + ');' as [sql]
from vendors t1
left join vendorgroup t2 on t1.clientgroup = t2.vendorgroupid
union all
select N'insert into dim_vendors(external_id, name, parent_id, parent_name) values (0,''Без поставщика'',null,null);'

-- продукты
select 'insert into dim_product(external_id, productid, product_name) values ('
    + cast(t.id as varchar(20)) + ','
    + isnull('''' + replace(t.productid, '''', '''''') + '''', 'null') + ','
    + isnull('''' + replace(t.description, '''', '''''') + '''', 'null') + ');' as [sql]
from product t

-- сотрудники
select 'insert into dim_personnel(external_id, fullname) values ('
    + cast(personid as varchar(20)) + ','''
    + replace(ltrim(rtrim(isnull(lastname, '') + ' ' + isnull(firstname, '') + ' ' + isnull(middlename, ''))), '''', '''''')
    + ''');' as [sql]
from personnel

-- Склад все операции 
select 'insert into dim_storage(operation_date, operation_id, operation_name, productid, product_name, vendor_id, vendor_name, range_id, range_name, product_count, amount) values ('
    + isnull('''' + convert(varchar(23), t.DateAdd, 121) + '''', 'null') + ','
    + cast(t.OperationID as varchar(20)) + ','
    + isnull('''' + replace(ot.Description, '''', '''''') + '''', 'null') + ','
    + cast(t.ProductID as varchar(20)) + ','
    + isnull('''' + replace(p.description, '''', '''''') + '''', 'null') + ','
    + cast(t.VendorID as varchar(20)) + ','
    + isnull('''' + replace(v.clientid, '''', '''''') + '''', '''Без поставщика''') + ','
    + cast(t.RangeID as varchar(20)) + ','
    + isnull('''' + replace(coalesce(z.description, c.ShortName), '''', '''''') + '''', 'null') + ','
    + cast(cast(t.[Count] as decimal(18,4)) as varchar(40)) + ','
    + cast(cast(t.Amount as decimal(18,2)) as varchar(40)) + ');' as [sql]
from bm_StorageOperations t
left join bm_StorageOperationsType ot on ot.ID = t.OperationID
left join product p on p.id = t.ProductID
left join vendors v on v.id = t.VendorID
left join [size] z on z.ID = t.RangeID
left join bm_classifierSizes c on c.ID = t.RangeID
