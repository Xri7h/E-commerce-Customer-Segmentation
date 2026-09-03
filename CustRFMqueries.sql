DROP DATABASE IF EXISTS ecommerce_customer_segmentation;
CREATE DATABASE ecommerce_customer_segmentation;
USE ecommerce_customer_segmentation;

DROP TABLE IF EXISTS customer_rfm;
CREATE TABLE customer_rfm(
    CustomerID INT,
    Recency INT,
    Frequency INT,
    MonetaryValue DECIMAL(15,2)
);

#if the csv is loaded or not
SELECT *
FROM customer_rfm
LIMIT 10;

#to check if count is same as before
SELECT COUNT(*) AS total_customers
FROM customer_rfm;


#if any missing values
SELECT
    SUM(CustomerID IS NULL) AS missing_customer_id,
    SUM(Recency IS NULL) AS missing_recency,
    SUM(Frequency IS NULL) AS missing_frequency,
    SUM(MonetaryValue IS NULL) AS missing_monetary
FROM customer_rfm;


#value which isnt possible
SELECT
    COUNT(*) AS invalid_values
FROM customer_rfm
WHERE Recency < 0
   OR Frequency <= 0
   OR MonetaryValue <= 0;
   
#if no duplicate,emptyy row received 
   SELECT
    CustomerID,
    COUNT(*) AS records
FROM customer_rfm
GROUP BY CustomerID
HAVING COUNT(*) > 1;


DROP TABLE IF EXISTS customer_rfm_clean;
CREATE TABLE customer_rfm_clean AS
WITH cleaned_data AS (
    SELECT DISTINCT
        CustomerID,
        Recency,
        Frequency,
        MonetaryValue

    FROM customer_rfm

    WHERE CustomerID IS NOT NULL
      AND Recency >= 0
      AND Frequency > 0
      AND MonetaryValue > 0
)


SELECT *
FROM cleaned_data;


DROP TABLE IF EXISTS customer_rfm_scored;
CREATE TABLE customer_rfm_score AS

WITH score_base AS (
    SELECT
        CustomerID,
        Recency,
        Frequency,
        MonetaryValue,

#for recency
        CASE 
            WHEN Recency <= 30  THEN 5
            WHEN Recency <= 60  THEN 4
            WHEN Recency <= 90  THEN 3
            WHEN Recency <= 180 THEN 2
            ELSE 1 
        END AS R_Score,

#for frequency
        CASE 
            WHEN Frequency >= 10 THEN 5
            WHEN Frequency >= 5  THEN 4
            WHEN Frequency >= 3  THEN 3
            WHEN Frequency >= 2  THEN 2
            ELSE 1 
        END AS F_Score,

#monetary
        CASE 
            WHEN MonetaryValue >= 500 THEN 5
            WHEN MonetaryValue >= 200 THEN 4
            WHEN MonetaryValue >= 100 THEN 3
            WHEN MonetaryValue >= 50  THEN 2
            ELSE 1 
        END AS M_Score

    FROM customer_rfm_clean
)

SELECT
    CustomerID,
    Recency,
    Frequency,
    MonetaryValue,
    R_Score,
    F_Score,
    M_Score,
    
#rfm score
    (R_Score + F_Score + M_Score) AS RFM_Score
FROM score_base;

#checking rfm
SELECT *
FROM customer_rfm_score
LIMIT 20;


SELECT
    R_Score,
    F_Score,
    M_Score,
    COUNT(*) AS customers
FROM customer_rfm_score
GROUP BY
    R_Score,
    F_Score,
    M_Score
ORDER BY
    R_Score DESC,
    F_Score DESC,
    M_Score DESC;


DROP TABLE IF EXISTS customer_segments;
CREATE TABLE customer_segments AS
WITH segmentation AS (

    SELECT
        CustomerID,
        Recency,
        Frequency,
        MonetaryValue,
        R_Score,
        F_Score,
        M_Score,
        RFM_Score,

        CASE
            WHEN R_Score >= 4
             AND F_Score >= 4
             AND M_Score >= 4
                THEN 'Champions'

            WHEN R_Score >= 3
             AND F_Score >= 4
                THEN 'Loyal Customers'

            WHEN R_Score >= 4
             AND F_Score <= 3
                THEN 'Potential Customers'

            WHEN R_Score <= 2
             AND (F_Score >= 3 OR M_Score >= 3)
                THEN 'At Risk'

            ELSE 'Lost Customers'

        END AS Segment

    FROM customer_rfm_score
)

SELECT *
FROM segmentation;

SELECT * FROM customer_segments;


SELECT
    Segment,
    COUNT(*) AS Customers,

    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS Customer_Percentage

FROM customer_segments
GROUP BY Segment
ORDER BY Customers DESC;



SELECT
    Segment,
    COUNT(*) AS Customers,
    ROUND(SUM(MonetaryValue), 2) AS Total_Value,
    ROUND(SUM(MonetaryValue) * 100.0 / SUM(SUM(MonetaryValue)) OVER(), 2) AS Value_Percentage

FROM customer_segments
GROUP BY Segment
ORDER BY Total_Value DESC;

SELECT
    Segment,
    COUNT(*) AS Customers,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS Customer_Percentage,
    ROUND(SUM(MonetaryValue), 2) AS Total_Value,
    ROUND(SUM(MonetaryValue) * 100.0 / SUM(SUM(MonetaryValue)) OVER(), 2) AS Value_Percentage

FROM customer_segments
GROUP BY Segment
ORDER BY Total_Value DESC;


SELECT
    CustomerID,
    Recency,
    Frequency,
    MonetaryValue,
    RFM_Score,
    Segment
FROM customer_segments
ORDER BY MonetaryValue DESC
LIMIT 20;


DROP TABLE IF EXISTS segment_strategy;
CREATE TABLE segment_strategy (
    Segment VARCHAR(50),
    Recommended_Action VARCHAR(255),
    Priority VARCHAR(20)
);


TRUNCATE TABLE segment_strategy;
INSERT INTO segment_strategy (Segment, Recommended_Action, Priority)
SELECT 
    Segment,
    CASE 
        WHEN Segment = 'Champions'           THEN 'VIP rewards, exclusive products, and referral programs'
        WHEN Segment = 'Loyal Customers'     THEN 'Cross-sell, and loyalty rewards'
        WHEN Segment = 'Potential Loyalists' THEN 'Welcome offers and second-purchase incentives'
        WHEN Segment = 'At Risk'             THEN 'Personalized win-back campaigns and targeted incentives'
        WHEN Segment = 'Lost Customers'      THEN 'Reactivation campaigns using controlled discounts'
        ELSE 'General brand awareness and engagement campaigns'
    END AS Recommended_Action,
    
    CASE 
        WHEN Segment = 'At Risk'             THEN 'Critical'
        WHEN Segment IN ('Champions', 'Loyal Customers') THEN 'High'
        WHEN Segment = 'Potential Loyalists' THEN 'Medium'
        ELSE 'Low'
    END AS Priority

FROM customer_segments
GROUP BY Segment;



DROP VIEW IF EXISTS view_customer_segmentation;
CREATE VIEW view_customer_segmentation AS
SELECT
    c.CustomerID,
    c.Recency,
    c.Frequency,
    c.MonetaryValue,
    c.RFM_Score,
    c.Segment,
    COALESCE(s.Recommended_Action, 'No strategy defined') AS Recommended_Action,
    COALESCE(s.Priority, 'Unassigned') AS Priority
FROM customer_segments c
LEFT JOIN segment_strategy s ON c.Segment = s.Segment;


SELECT *
FROM view_customer_segmentation
LIMIT 20;
