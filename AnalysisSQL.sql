--Inspecting Data
SELECT * FROM [dbo].[sales_data]

--Checking unique values
SELECT DISTINCT STATUS FROM [dbo].[sales_data]
SELECT DISTINCT YEAR_ID FROM [dbo].[sales_data]
SELECT DISTINCT PRODUCTLINE FROM [dbo].[sales_data]
SELECT DISTINCT COUNTRY FROM [dbo].[sales_data]
SELECT DISTINCT DEALSIZE FROM [dbo].[sales_data]
SELECT DISTINCT TERRITORY FROM [dbo].[sales_data]


--ANALYSIS

----1. Grouping sales by Product line
SELECT PRODUCTLINE, sum(sales) as Revenue
FROM [dbo].[sales_data]
GROUP BY PRODUCTLINE
ORDER BY 2 DESC


SELECT YEAR_ID, sum(sales) as Revenue
FROM [dbo].[sales_data]
GROUP BY YEAR_ID
ORDER BY 2 DESC


SELECT DEALSIZE, sum(sales) as Revenue
FROM [dbo].[sales_data]
GROUP BY DEALSIZE
ORDER BY 2 DESC


----2. What was the best month for sales in a specific year? How much was earned that month?
SELECT MONTH_ID, sum(sales) as Revenue, count(ORDERNUMBER) Frequency
FROM [dbo].[sales_data]
WHERE YEAR_ID = 2003 --change year_id to see each year
GROUP BY MONTH_ID
ORDER BY 2 DESC

---2.1. November seems to be the month with highest sales, what product do they sell in November
SELECT MONTH_ID, PRODUCTLINE, sum(sales) as Revenue, count(ORDERNUMBER) Frequency
FROM [dbo].[sales_data]
WHERE YEAR_ID = 2004 AND MONTH_ID = 11 --change year_id to see each year
GROUP BY MONTH_ID, PRODUCTLINE
ORDER BY 3 DESC
---It's Classic Cars


----3. Who is our best customer - use RFM Analysis
DROP TABLE IF EXISTS #rfm
;WITH rfm as
(
SELECT CUSTOMERNAME,
	sum(sales) MonetaryValue,
	avg(sales) AvgMonetaryValue,
	count(ORDERNUMBER) Frequency,
	max(ORDERDATE) last_order_date,
	(select max(ORDERDATE) from [dbo].[sales_data]) max_order_date,
	DATEDIFF(DD, max(ORDERDATE), (select max(ORDERDATE) from [dbo].[sales_data])) Recency
FROM [dbo].[sales_data]
GROUP BY CUSTOMERNAME 
),
rfm_calc as
(
SELECT r.*,
	NTILE(4) OVER (ORDER BY Recency desc) rfm_recency,
	NTILE(4) OVER (ORDER BY Frequency) rfm_frequency,
	NTILE(4) OVER (ORDER BY MonetaryValue) rfm_monetary
	from rfm r
)
SELECT 
	c.*, rfm_recency + rfm_frequency + rfm_monetary as rfm_cell,
	cast(rfm_recency as varchar) + cast(rfm_frequency as varchar) + cast(rfm_monetary as varchar) as rfm_cell_string
INTO #rfm
FROM rfm_calc c


SELECT CUSTOMERNAME, rfm_recency, rfm_frequency, rfm_monetary,
	CASE
		WHEN rfm_cell_string in (111,112,121,122,123,132,211,212,114,141) then 'lost customers'
		WHEN rfm_cell_string in (133,134,143,244,334,343,344,144) then 'slipping away, cannot lose'
		WHEN rfm_cell_string in (311,411,331) then 'new customers'
		WHEN rfm_cell_string in (222,223,233,322) then 'potential churners'
		WHEN rfm_cell_string in (323,333,321,422,332,432) then 'active'
		WHEN rfm_cell_string in (433,434,443,444) then 'loyal'
	END rfm_segment
FROM #rfm


----What products are most often sold together?
SELECT DISTINCT ORDERNUMBER, STUFF(

	(SELECT ',' + PRODUCTCODE
	FROM [dbo].[sales_data] p
	WHERE ORDERNUMBER IN 
	(
		SELECT ORDERNUMBER
		FROM (
		SELECT ORDERNUMBER, count(*) rn
		FROM [dbo].[sales_data]
		WHERE STATUS = 'Shipped'
		GROUP BY ORDERNUMBER
		) m
		WHERE rn = 3
	)
	AND p.ORDERNUMBER = s.ORDERNUMBER
		FOR xml path (''))
		, 1, 1, '') ProductCodes
FROM [dbo].[sales_data] s
ORDER BY 2 DESC
