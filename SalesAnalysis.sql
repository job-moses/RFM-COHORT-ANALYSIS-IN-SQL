SELECT  TOP 100
       [InvoiceNo]
      ,[StockCode]
      ,[Description]
      ,[Quantity]
      ,[InvoiceDate]
      ,[UnitPrice]
      ,[CustomerID]
      ,[Country]
  FROM [OnlineRetail].[dbo].[OnlineRetail]


SELECT COUNT(CustomerID) from [OnlineRetail].[dbo].[OnlineRetail] as Sales_Record
----There are is total of 406829 sales record--


----- DATA CLEANING---------------------------------------------------------------------------------------------------------------
  --Check for duplicate--
; with duplicate as(
					SELECT * 
						    ,ROW_NUMBER()OVER(PARTITION BY [InvoiceNo],[StockCode],[InvoiceDate],[CustomerID] ORDER BY [CustomerID]) AS RowNum
					FROM   [OnlineRetail].[dbo].[OnlineRetail]
							
				   )
SELECT * FROM duplicate WHERE RowNum > 1

-------- 10,679 rows are duplicates--------------

----- select clean data  into a tempTable(#onlineRetail) for analysis------------
; with duplicate as(
					SELECT * 
						    ,ROW_NUMBER()OVER(PARTITION BY [InvoiceNo],[StockCode],[InvoiceDate],[CustomerID] ORDER BY [CustomerID]) AS RowNum
					FROM   [OnlineRetail].[dbo].[OnlineRetail]
							
				   )
SELECT * INTO #OnlineRetail
FROM duplicate 
WHERE RowNum = 1 AND [Quantity]>0 AND [UnitPrice] > 0;


--------------------------------------------------------------------------------------------------------------------------------------------------
----- Sales by Year-------

select top 200 * from #OnlineRetail

SELECT YEAR(InvoiceDate) SalesYear,
		SUM(ROUND((Quantity* UnitPrice),2)) as Sales
FROM  #OnlineRetail
GROUP BY YEAR(InvoiceDate) 

----- Sales Span Accross 2010 -  2011 with highest sales in 2011---

SELECT YEAR(InvoiceDate) SalesYear,
       MONTH(InvoiceDate) SalesMonth,
		SUM(ROUND((Quantity* UnitPrice),2)) as Sales
FROM  #OnlineRetail
GROUP BY YEAR(InvoiceDate),MONTH(InvoiceDate) 
ORDER BY 1,2

------ sale start december 2010 tiill december 2011

SELECT 
       MONTH(InvoiceDate) SalesMonth,
		SUM(ROUND((Quantity* UnitPrice),2)) as Sales
FROM  #OnlineRetail
GROUP BY MONTH(InvoiceDate) 
ORDER BY 2 DESC
--November records peack of sales

SELECT Country,
       SUM(ROUND((Quantity* UnitPrice),2)) as Sales
FROM #OnlineRetail
GROUP BY Country
ORDER BY 2 DESC

----- United Kingdom top as country with highest sales followed by Netherlands


----customers with the highest orders and quantity-----
SELECT CustomerID,
		COUNT(InvoiceDate) TotalOrders,
		SUM(ROUND((Quantity* UnitPrice),2)) as TotalSales,
		SUM(Quantity) as TotalQuantity
FROM #OnlineRetail
Group by CustomerID
order by 2 DESc, 3 DESC

-----To futher under undersatand customer engagement over time, let perform cohort analysis to understand customer buying pattern--

-------------------------------------------------------------------------------------------------------------------------------------
------Cohort Analysis----

DROP TABLE IF EXISTS #cohort
SELECT  
			CustomerID,
			CAST(MAX(InvoiceDate) AS date) CustomerLastDate,
			DATEFROMPARTS( YEAR(min(InvoiceDate)), MONTH(min(InvoiceDate)),1) CohortDate
INTO #cohort FROM    #OnlineRetail 
GROUP  BY CustomerID

SELECT *  FROM #cohort

SELECT  b.*,CustomerLastDate,CohortDate
							
INTO #CohortData FROM  #cohort a
INNER  JOIN #OnlineRetail b ON a.CustomerID = b.CustomerID



;WITH Cohort
AS(
	SELECT aaaa.*,
			CohortIndex = year_diff * 12 + month_diff +1
		
	FROM(
			SELECT  aaa.*,
					year_diff = CustomerLastYear - CohortYear,
					month_diff = CustomerLastMonth - CohortMonth
			FROM(
				SELECT   aa.*,
						YEAR(CustomerLastDate) CustomerLastYear,
						Month(CustomerLastDate) CustomerLastMonth,
						YEAR(CohortDate) CohortYear,
						Month(CohortDate) CohortMonth		
				FROM(

					SELECT  b.*,
							a.CustomerLastDate,
							a.CohortDate
				   FROM  #cohort a
                   INNER  JOIN #OnlineRetail b ON a.CustomerID = b.CustomerID
				)aa	
			)aaa
	  )aaaa
) 
SELECT * INTO #CohortRetention FROM Cohort;

SELECT * from #CohortRetention;

SELECT CohortDate as CohortPeriod,
             ROUND((1.0 * [1]/[1] * 100),2) as 'Month 1' ,
			 ROUND((1.0 * [2]/[1] * 100),2) as 'Month 2',
			 ROUND((1.0 * [3]/[1] * 100),2) as 'Month 3',
			 ROUND((1.0 * [4]/[1] * 100),2) as 'Month 4',
			 ROUND((1.0 * [5]/[1] * 100),2) as 'Month 5',
			 ROUND((1.0 * [6]/[1] * 100),2) as 'Month 6',
			 ROUND((1.0 * [7]/[1] * 100),2) as 'Month 7',
			 ROUND((1.0 * [8]/[1] * 100),2) as 'Month 8',
			 ROUND((1.0 * [9]/[1] * 100),2) as 'Month 9',
			 ROUND((1.0 * [10]/[1] * 100),2) as 'Month 10',
			 ROUND((1.0 * [11]/[1] * 100 ),2)as 'Month 11',
			 ROUND((1.0 * [12]/[1] * 100 ),2)as 'Month 12',
			 ROUND((1.0 * [13]/[1] * 100 ),2)as 'Month 13'
FROM(
		SELECT *
		FROM(
				SELECT DISTINCT CustomerID,
						CohortDate,
						CohortIndex
				From #CohortRetention 
				)tbl
		pivot(
				COUNT(CustomerID)
				for CohortIndex in(
									[1],[2],[3],[4],[5],[6],[7],[8],[9],[10],[11],[12],[13]
									)
			) as pivot_tbl
)a order by CohortDate;
-----------------------------------------------------------------------------------------------------------------------

------ Customer segmentatation base on Recency, Frequency, Monetary value
----RFM ANALYSIS--------

--Recency :  How recently did customer purchase
--Frequency: How often did customer purchase
--Monetary:  How much do they spend

SELECT a.*,
      ROUND((Quantity* UnitPrice),2) as Sales
INTO #RfmTable FROM #OnlineRetail a

; WITH RFM AS(
	SELECT  aaaa.*,
			CASE
				WHEN RF IN (8,7) THEN 'loyal'
				WHEN RF IN (6,5) THEN 'potential'
				WHEN RF IN (4) THEN 'slipping away'
				WHEN RF IN (3,2,1) THEN 'lost'
			END AS Customer_Segment

	FROM(
		SELECT aaa.*,
				R+F as RF
		FROM(
			SELECT aa.*,
					NTILE(4) OVER(ORDER BY Recency ) as R,
					NTILE(4) OVER(ORDER BY Frequency ) as F,
					NTILE(4)OVER(ORDER BY Monetary) AS M
			FROM (
				SELECT a.*,
						DATEDIFF(dd,CustomerLastPurchase,lastPurchase) Recency 
				FROM(
						SELECT a.CustomerID,
								(SELECT CAST(MAX(InvoiceDate)as DATE) FROM #RfmTable) LastPurchase,
								CAST( MAX(a.InvoiceDate) as DATE) CustomerLastPurchase,
									SUM(a.Sales) as Monetary,
								COUNT(InvoiceNo) Frequency
						FROM  #RfmTable a
						GROUP BY a.CustomerID 
					)a 
			  )aa
		)aaa
	)aaaa
	
) select * into #RFM from RFM ORDER BY R DESC,F DESC;



SELECT Customer_Segment,
       COUNT(*)  SegmentCount
FROM #RFM
Group by Customer_Segment order by 2 DESC


/* 
    Customer_Segment	SegmentCount
     potential	           2692
     slipping away	       832
      lost	               436
       loyal	           378
	   */
-------------------------------------------------------------------------------------------------------