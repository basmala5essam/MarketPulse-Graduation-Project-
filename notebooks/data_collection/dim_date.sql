
-- ==========================================
-- DIM_DATE
-- Generate calendar dates: 2021-01-01 to 2025-12-31
-- ==========================================

CREATE TABLE gold.dim_date (
    date_key INT PRIMARY KEY,
    [date] DATE NOT NULL,
    [year] INT NOT NULL,
    [quarter] INT NOT NULL,
    month_number INT NOT NULL,
    month_name NVARCHAR(20) NOT NULL,
    year_month CHAR(7) NOT NULL,
    week_start DATE NOT NULL,
    is_trading_day BIT NOT NULL,
    is_month_end_trading_day BIT NOT NULL
);

-- Generate all calendar dates
WITH Calendar AS (
    SELECT CAST('2021-01-01' AS DATE) AS calendar_date

    UNION ALL

    SELECT DATEADD(DAY, 1, calendar_date)
    FROM Calendar
    WHERE calendar_date < '2025-12-31'
),
TradingDays AS (
    SELECT DISTINCT [date]
    FROM silver.market_clean
),
MonthEndTradingDays AS (
    SELECT
        [date],
        ROW_NUMBER() OVER (
            PARTITION BY YEAR([date]), MONTH([date])
            ORDER BY [date] DESC
        ) AS rn
    FROM TradingDays
)
INSERT INTO gold.dim_date (
    date_key,
    [date],
    [year],
    [quarter],
    month_number,
    month_name,
    year_month,
    week_start,
    is_trading_day,
    is_month_end_trading_day
)
SELECT
    CONVERT(INT, CONVERT(CHAR(8), c.calendar_date, 112)),
    c.calendar_date,
    YEAR(c.calendar_date),
    DATEPART(QUARTER, c.calendar_date),
    MONTH(c.calendar_date),
    DATENAME(MONTH, c.calendar_date),
    CONVERT(CHAR(7), c.calendar_date, 120),

    -- Monday as the beginning of the week
    DATEADD(
        DAY,
        -(DATEDIFF(DAY, '19000101', c.calendar_date) % 7),
        c.calendar_date
    ),

    CASE WHEN td.[date] IS NOT NULL THEN 1 ELSE 0 END,

    CASE
        WHEN me.[date] IS NOT NULL THEN 1
        ELSE 0
    END

FROM Calendar c
LEFT JOIN TradingDays td
    ON c.calendar_date = td.[date]
LEFT JOIN MonthEndTradingDays me
    ON c.calendar_date = me.[date]
    AND me.rn = 1

OPTION (MAXRECURSION 0);
