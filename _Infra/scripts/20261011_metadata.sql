-- Метаданные 2026-10-11

select row_number() over (order by inner_t1.type_order, inner_t1.name) as "№",
       inner_t1.name as "Наименование",
       inner_t1.type_name as "Тип"
from
(
    -- Таблицы
    select 1 as type_order, table_name as name, 'Таблица' as type_name
    from information_schema.tables
    where table_schema = 'public'
      and table_type = 'BASE TABLE'

    union all

    -- Счетчики
    select 2, sequence_name, 'Счетчик (sequence)'
    from information_schema.sequences
    where sequence_schema = 'public'

) as inner_t1
order by 1;
