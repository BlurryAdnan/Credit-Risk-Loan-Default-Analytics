# Credit Risk & Loan Default Analytics
End-to-end credit risk analytics project built on a self-designed relational database, simulating a retail lending portfolio (Northbridge Finance, a fictional NBFC) to analyze loan default risk, portfolio health, and collateral-driven loss mitigation — the kind of analysis performed by credit risk teams at retail banks and NBFCs.
# Project Overview
This project covers the complete analytics pipeline: relational schema design, synthetic dataset generation with deliberately engineered risk relationships, advanced SQL analysis, and an interactive Power BI dashboard connected live to MySQL.
The goal was to answer five real credit risk questions:
1. Where is portfolio risk concentrated right now? (PAR 30/60/90 analysis)
2. Does credit score actually predict default, and is pricing risk-adjusted accordingly?
3. Does collateral meaningfully reduce losses on defaulted loans?
4. Is any branch underwriting at a materially higher risk level than others?
5. Is loan quality deteriorating over time, or is recent volatility just noise?
# Tech Stack
 
- **MySQL 8** — schema design, data storage, analytical SQL
- **Excel** — synthetic dataset generation (formula-driven, with deliberate risk correlations built in)
- **Power BI Desktop** — live connected interactive dashboard
- **DAX** — custom measures (Default Rate %, risk segmentation)
## Database Schema
 
Six related tables, built around a central `loans' table:
 
```
customers ──< loans >── branches
                │
                ├──< repayments
                └──< collateral
 
customers ──< credit_bureau_scores
```
 
- **customers** — demographic and credit profile (2,000 rows)
- **branches** — 5 branches across 4 regions
- **loans** — loan-level detail: amount, type, term, status (2,800 rows)
- **repayments** — installment level payment history (~91,000 rows)
- **credit_bureau_scores** — two score pulls per customer (historical + current)
- **collateral** — collateral records for secured loan types (Home, Auto)
Full schema (`CREATE TABLE` statements) in [`/sql/schema.sql`](./sql/schema.sql).
## Dataset Notes
 
The dataset is synthetically generated, not real customer data — no public dataset exists with the specific risk-correlated fields this project required (collateral value, cost-to-serve-style relationships between credit score and outcome). Default probability was deliberately scaled to credit score, loan amount was scaled to income bracket, and repayment lateness escalates realistically in the lead-up to a defaulted loan's final installment, rather than being purely random.
 
This was a conscious design decision: building the dataset from scratch, with intentional risk relationships baked in, made it possible to validate that every downstream SQL and DAX calculation was actually surfacing real signal rather than noise (see the credit-score-band default rate findings in the memo, where the data shows a clean, expected escalation from 2.70% to 32.54% default rate across score bands).
 
---
 
## SQL Highlights
 
All queries in [`/sql/analysis_queries.sql`](./sql/analysis_queries.sql). Selected techniques:
 
- **Window functions** — `ROW_NUMBER() OVER (PARTITION BY ... ORDER BY ...)` to identify each loan's most recent repayment status for PAR bucketing
- **Correlated subqueries** — pulling each customer's most recent bureau score for accurate score-band segmentation
- **Cohort/vintage analysis** — tracking default rates by disbursement-month cohort at 6/12/18-month maturity checkpoints, with `HAVING` used to suppress immature cohorts rather than showing misleading 0% rates
- **LEFT JOIN + NULL handling** — calculating Loss Given Default across secured and unsecured loan types using `IFNULL()` and `GREATEST()` to correctly floor losses at zero
- **A reusable view** (`par_view`) — loan-level risk bucket classification, built to feed both further SQL analysis and the Power BI dashboard directly
- **A stored procedure** (`loan_type_risk`) — parameterized risk breakdown callable by loan type
---
 
## Dashboard
 
Two-page interactive Power BI report, live-connected to MySQL via DirectQuery:
 
**Page 1 — Risk Overview + Vintage & Trend Analysis:** portfolio KPIs (total exposure, default rate, avg credit score), branch × risk-bucket matrix, PAR exposure breakdown, and a loan-type slicer panel and default rate and loan volume by disbursement year, used to test whether portfolio quality is improving, stable, or deteriorating over time.
 
Screenshots in [`/dashboard_screenshots`](./dashboard_screenshots).
 
---
 
## Key Findings (Summary)
 
| Finding | Result |
|---|---|
| Blended default rate | 10.36% across ₹2.09B exposure |
| Default rate, Excellent vs. Poor credit score | 2.70% vs. 32.54% |
| Loss Given Default, unsecured vs. secured | 100% vs. ~4-7% |
| Branch-level default rate variance | Tight, 9.30%–11.05%, no outlier |
| 2024 vintage default spike | Confirmed as sampling noise, not credit quality decline |

## Let's Connect
for any queries or collaboration, reach out via:-

- [Linkedin Profile](https://www.linkedin.com/in/mohd-adnan-521b37280/)
- Email- create.adnan.05@gmail.com
