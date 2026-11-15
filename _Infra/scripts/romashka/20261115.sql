-- Поиск ресурсов по направлениям.
SELECT 
    t.name AS TableName,
    SUM(p.rows) AS RowCounts
FROM sys.tables t
INNER JOIN sys.partitions p ON t.object_id = p.object_id
WHERE p.index_id IN (0, 1)
  AND t.name IN (
      'bm_StorageOperations', 'journal', 'bm_JournalSessions',
      'pricelist', 'product', 'personnel', 'vendors', 'stockperiod',
      'bm_HotButtons', 'receiving', 'orders', 'vendorgroup',
      'bm_WorkHours', 'bm_PaymentOperations', 'bm_Bampbar_History',
      'bm_Contracts', 'onhand', 'stock', 'storagesonhand'
  )
GROUP BY t.name
ORDER BY RowCounts DESC;

-- Анализ закупки продукции
SELECT TOP 10
    YEAR(op.DateAdd) AS Год,
    MONTH(op.DateAdd) AS Месяц,
    t.Description AS ТипОперации,
    COUNT(DISTINCT op.DocumentID) AS ЧислоДокументов,
    COUNT(DISTINCT op.ProductID) AS УникальныеТовары,
    SUM(op.[Count]) AS ОбщееКоличество,
    SUM(op.Amount) AS ОбщаяСумма
FROM bm_StorageOperations op
LEFT JOIN bm_StorageOperationsType t ON op.OperationID = t.ID
WHERE op.DateAdd IS NOT NULL
  AND (t.Factor = 1 OR op.VendorID IS NOT NULL)
GROUP BY YEAR(op.DateAdd), MONTH(op.DateAdd), t.Description
ORDER BY Год DESC, Месяц DESC;

-- Анализ продажи товара
SELECT TOP 10
    YEAR(j.dater) AS Год,
    MONTH(j.dater) AS Месяц,
    COUNT(DISTINCT j.receiptn) AS КоличествоЧеков,
    COUNT(DISTINCT j.id) AS УникальныеТовары,
    SUM(j.quantity) AS ОбщееКоличество,
    SUM(j.amount) AS ОбщаяСумма
FROM journal j
WHERE j.dater IS NOT NULL
GROUP BY YEAR(j.dater), MONTH(j.dater)
ORDER BY Год DESC, Месяц DESC;

-- Анализ взаимоотношений с поставщиками
SELECT TOP 10
    v.id AS IDПоставщика,
    COALESCE(NULLIF(v.lastname, ''), NULLIF(v.firstname, ''), v.clientid) AS НазваниеПоставщика,
    vg.description AS ГруппаПоставщика,
    COUNT(DISTINCT op.DocumentID) AS КоличествоПоставок,
    COUNT(DISTINCT op.ProductID) AS КоличествоSuppliedProducts,
    SUM(op.Amount) AS ОбщаяСуммаПокупки
FROM bm_StorageOperations op
INNER JOIN vendors v ON op.VendorID = v.id
LEFT JOIN vendorgroup vg ON v.clientgroup = vg.vendorgroupid
GROUP BY v.id, v.lastname, v.firstname, v.clientid, vg.description
ORDER BY ОбщаяСуммаПокупки DESC;

-- Анализ работы персонала
SELECT TOP 10
    p.personid AS IDСотрудника,
    LTRIM(RTRIM(ISNULL(p.lastname, '') + ' ' + ISNULL(p.firstname, ''))) AS ИмяСотрудника,
    DATEPART(YEAR, s.DateAdd) AS ГодАктивности,
    CASE WHEN DATEPART(QUARTER, s.DateAdd) IN (1, 2) THEN 1 ELSE 2 END AS Полугодие,
    DATEPART(QUARTER, s.DateAdd) AS КварталАктивности,
    COUNT(s.ID) AS КоличествоСессий,
    SUM(CASE WHEN s.IsError = 1 THEN 1 ELSE 0 END) AS КоличествоОшибок
FROM bm_JournalSessions s
INNER JOIN personnel p ON s.PersonID = p.personid
WHERE s.DateAdd IS NOT NULL
GROUP BY 
    p.personid, 
    p.lastname, 
    p.firstname, 
    DATEPART(YEAR, s.DateAdd),
    CASE WHEN DATEPART(QUARTER, s.DateAdd) IN (1, 2) THEN 1 ELSE 0 END,
    DATEPART(QUARTER, s.DateAdd)
ORDER BY ГодАктивности DESC, КварталАктивности DESC, КоличествоСессий DESC;

-- Анализ остатков
-- 5.1. Проверка последних зафиксированных остатков в разрезе складов и товаров
SELECT TOP 10
    p.id AS IDТовара,
    p.description AS НазваниеТовара,
    s.description AS НазваниеСклада,
    op.Rest AS ЗаписанныйОстаток,
    op.DateAdd AS ДатаОперации
FROM bm_StorageOperations op
INNER JOIN product p ON op.ProductID = p.id
LEFT JOIN storages s ON op.StorageID = s.id
WHERE op.Rest IS NOT NULL
ORDER BY op.DateAdd DESC;

-- 5.2. Проверка закрытых учётных периодов в stockperiod
SELECT TOP 10
    sp.id,
    sp.productid,
    sp.quantityopen,
    sp.quantityin,
    sp.quantityout,
    sp.quantityclose,
    sp.datestart,
    sp.datefinish
FROM stockperiod sp
ORDER BY sp.datefinish DESC;

