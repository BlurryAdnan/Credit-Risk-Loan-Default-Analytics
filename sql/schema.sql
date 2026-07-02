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