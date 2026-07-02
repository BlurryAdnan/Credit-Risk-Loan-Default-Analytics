CREATE DATABASE credit_risk_db;
USE credit_risk_db;

CREATE TABLE branches (
  branch_id INT PRIMARY KEY,
  branch_name VARCHAR(100),
  region VARCHAR(50)
);

CREATE TABLE customers (
  customer_id INT PRIMARY KEY,
  full_name VARCHAR(100),
  dob DATE,
  gender VARCHAR(10),
  city VARCHAR(50),
  state VARCHAR(50),
  income_bracket VARCHAR(20),
  employment_type VARCHAR(30),
  credit_score INT,
  signup_date DATE
);

CREATE TABLE loans (
  loan_id INT PRIMARY KEY,
  customer_id INT,
  branch_id INT,
  loan_type VARCHAR(30),
  loan_amount DECIMAL(12,2),
  interest_rate DECIMAL(5,2),
  loan_term_months INT,
  disbursement_date DATE,
  loan_status VARCHAR(20),
  FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
  FOREIGN KEY (branch_id) REFERENCES branches(branch_id)
);

CREATE TABLE repayments (
  repayment_id INT PRIMARY KEY,
  loan_id INT,
  due_date DATE,
  payment_date DATE,
  amount_due DECIMAL(10,2),
  amount_paid DECIMAL(10,2),
  days_late INT,
  FOREIGN KEY (loan_id) REFERENCES loans(loan_id)
);

CREATE TABLE credit_bureau_scores (
  score_id INT PRIMARY KEY,
  customer_id INT,
  score_date DATE,
  score INT,
  bureau_name VARCHAR(30),
  FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

CREATE TABLE collateral (
  collateral_id INT PRIMARY KEY,
  loan_id INT,
  collateral_type VARCHAR(30),
  collateral_value DECIMAL(12,2),
  FOREIGN KEY (loan_id) REFERENCES loans(loan_id)
);




-- Northbridge Finance: Credit Risk Analytics
-- SQL Analysis Queries
-- ================================================

-- Query 1: PAR Bucket Analysis - Portfolio at Risk 
-- Question: How much loan exposure sits in each risk bucket?

WITH latest_repayment AS (
  SELECT 
    r.*,
    ROW_NUMBER() OVER (PARTITION BY r.loan_id ORDER BY r.due_date DESC) AS rn
  FROM repayments r
  WHERE r.due_date <= CURDATE()
)
SELECT
  CASE
    WHEN lr.days_late = 0 THEN 'Current'
    WHEN lr.days_late BETWEEN 1 AND 29 THEN '1-29 DPD'
    WHEN lr.days_late BETWEEN 30 AND 59 THEN 'PAR 30'
    WHEN lr.days_late BETWEEN 60 AND 89 THEN 'PAR 60'
    ELSE 'PAR 90+'
  END AS risk_bucket, COUNT(*) AS loan_count, SUM(l.loan_amount) AS total_exposure

FROM latest_repayment lr
JOIN loans l ON l.loan_id = lr.loan_id
WHERE lr.rn = 1
GROUP BY risk_bucket
ORDER BY total_exposure DESC;

-- Query 2: Default Rate by Credit Score Band
-- Question: Does credit score actually predict default?

SELECT
  CASE
    WHEN cbs.score >= 750 THEN 'Excellent (750+)'
    WHEN cbs.score >= 650 THEN 'Good (650-749)'
    WHEN cbs.score >= 550 THEN 'Fair (550-649)'
    ELSE 'Poor (<550)'
  END AS score_band,
  COUNT(DISTINCT l.loan_id) AS total_loans,
  SUM(CASE WHEN l.loan_status = 'Defaulted' THEN 1 ELSE 0 END) AS defaulted_loans,
  ROUND(SUM(CASE WHEN l.loan_status = 'Defaulted' THEN 1 ELSE 0 END) / COUNT(DISTINCT l.loan_id) * 100, 2) AS default_rate_pct,
  SUM(l.loan_amount) AS total_exposure
  
FROM loans l
JOIN customers c ON c.customer_id = l.customer_id
JOIN credit_bureau_scores cbs ON cbs.customer_id = c.customer_id
WHERE cbs.score_date = (
  SELECT MAX(score_date) FROM credit_bureau_scores WHERE customer_id = c.customer_id
)
GROUP BY score_band ORDER BY default_rate_pct DESC;

-- Query 3: Cohort / Vintage Analysis
-- Question: How do loan cohorts perform as they age?

SET @analysis_date = '2023-06-30';

WITH cohort AS (
  SELECT 
    loan_id,
    DATE_FORMAT(disbursement_date, '%Y-%m') AS cohort_month,
    loan_status,
    TIMESTAMPDIFF(MONTH, disbursement_date, @analysis_date) AS months_on_book
  FROM loans
)

SELECT 
  cohort_month,
  COUNT(*) AS cohort_size,
  ROUND(SUM(CASE WHEN months_on_book >= 6  AND loan_status = 'Defaulted' THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS default_rate_6m,
  ROUND(SUM(CASE WHEN months_on_book >= 12 AND loan_status = 'Defaulted' THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS default_rate_12m,
  ROUND(SUM(CASE WHEN months_on_book >= 18 AND loan_status = 'Defaulted' THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS default_rate_18m
FROM cohort GROUP BY cohort_month HAVING MAX(months_on_book) >= 6 ORDER BY cohort_month;


-- Query 4: Branch Analysis
-- Question: Which Branch carries the most risk?

WITH branch_stats AS (
	SELECT
    b.branch_id,
    b.branch_name,
    b.region,
    COUNT(l.loan_id) AS total_loans,
    SUM(CASE WHEN l.loan_status = 'Defaulted' THEN 1 ELSE 0 END) AS defaulted_loans,
    ROUND(SUM(CASE WHEN l.loan_status = 'Defaulted' THEN 1 ELSE 0 END) / COUNT(l.loan_id) * 100, 2) AS default_rate_pct
FROM branches b 
JOIN loans l ON l.branch_id = b.branch_id
GROUP BY b.branch_id, b.branch_name, b.region
)	

SELECT
branch_name,
region,
total_loans,
default_rate_pct,
RANK() OVER (ORDER BY default_rate_pct DESC) AS national_risk_rank FROM branch_stats
ORDER BY region, national_risk_rank;

-- Query 5: Collateral Analysis - Loss Given Default
-- Question: How much loss does collateral reduce?

SELECT
	 l.loan_type,
     COUNT(l.loan_id) AS defaulted_loan_count,
     SUM(l.loan_amount) AS total_exposure,
     SUM(IFNULL(c.collateral_value, 0)) AS total_recovered,
     SUM(GREATEST(0, l.loan_amount - IFNULL(c.collateral_value, 0))) AS total_loss,
     ROUND(SUM(GREATEST(0, l.loan_amount - IFNULL(c.collateral_value, 0))) / SUM(l.loan_amount) * 100, 2) AS lgd_pct

FROM loans l 
LEFT JOIN collateral c ON c.loan_id = l.loan_id
WHERE l.loan_status = 'Defaulted'
GROUP BY l.loan_type ORDER BY lgd_pct DESC

-- View: loan_level risk status
-- Purpose: reusable per-loan risk classification, feeds Power BI

CREATE VIEW par_view AS

SELECT
	l.loan_id,
    l.customer_id,
    l.loan_type,
    l.loan_amount,
    l.loan_status,
    lr.days_late,
  CASE
    WHEN lr.days_late = 0 THEN 'Current'
    WHEN lr.days_late BETWEEN 1 AND 29 THEN '1-29 DPD'
    WHEN lr.days_late BETWEEN 30 AND 59 THEN 'PAR 30'
    WHEN lr.days_late BETWEEN 60 AND 89 THEN 'PAR 60'
    ELSE 'PAR 90+'
  END AS risk_bucket
  
  FROM (SELECT
    r.*,
    ROW_NUMBER() OVER (PARTITION BY r.loan_id ORDER BY r.due_date DESC) AS rn
    FROM repayments r
    WHERE r.due_date <= CURDATE() 
) lr
JOIN loans l ON l.loan_id = lr.loan_id
WHERE lr.rn = 1;


-- Stored Procedure: loan_type_risk
-- Purpose: returns risk bucket breakdown for a given loan type

DELIMITER $

CREATE PROCEDURE loan_type_risk (
IN loantype_filter VARCHAR(20)
)
BEGIN
	SELECT
		risk_bucket,
        COUNT(*) AS loan_count,
        SUM(loan_amount) AS total_exposure
	FROM par_view
    WHERE loan_type = loantype_filter
	GROUP BY risk_bucket;
END $
DELIMITER ;

#CALL loan_type_risk('Auto');
