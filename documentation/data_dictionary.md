# Data Dictionary

This document describes the key tables used in the Superstore BI data model.

---

# Fact Table

## fact_sales

| Column         | Description                  |
| -------------- | ---------------------------- |
| sales_key      | Surrogate key for fact table |
| order_id       | Unique order identifier      |
| row_id         | Line item identifier         |
| order_date_key | Foreign key to dim_date      |
| ship_date_key  | Foreign key to dim_date      |
| customer_key   | Foreign key to dim_customer  |
| product_key    | Foreign key to dim_product   |
| ship_mode      | Shipping method              |
| sales          | Revenue for the order line   |
| quantity       | Quantity sold                |
| discount       | Discount applied             |
| profit         | Profit for the transaction   |

### Derived Fields

| Column              | Description                                |
| ------------------- | ------------------------------------------ |
| margin_pct          | Profit divided by sales                    |
| profit_missing_flag | Indicates missing profit value             |
| extreme_loss_flag   | Flag for transactions where profit ≤ -1000 |

---

# Dimension Tables

## dim_customer

| Column        | Description                  |
| ------------- | ---------------------------- |
| customer_key  | Surrogate key                |
| customer_id   | Business customer identifier |
| customer_name | Customer name                |
| segment       | Customer segment             |
| region        | Sales region                 |
| state         | Customer state               |
| city          | Customer city                |

---

## dim_product

| Column       | Description          |
| ------------ | -------------------- |
| product_key  | Surrogate key        |
| product_id   | Product identifier   |
| category     | Product category     |
| sub_category | Product sub-category |
| product_name | Product name         |

---

## dim_date

| Column        | Description              |
| ------------- | ------------------------ |
| date_key      | Surrogate key (YYYYMMDD) |
| calendar_date | Full date                |
| year          | Calendar year            |
| quarter       | Calendar quarter         |
| month         | Month number             |
| month_name    | Month name               |
| day_of_month  | Day of month             |
| week_of_year  | Week number              |
