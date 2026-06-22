-- ============================================================
-- WrenAI Demo Seed (PostgreSQL)
-- จงใจใส่ "กับดัก" 4 อย่างที่ทำให้ LLM เขียน SQL ผิดแบบเงียบ ๆ:
--   1) มีตาราง customer ซ้ำ: customers_v1 (ตายแล้ว) กับ customers_v2 (ใช้จริง)
--   2) orders.status เป็นตัวเลข ไม่มีคำอธิบาย
--   3) customers_v2 มีคอลัมน์ลับ: email, phone, national_id
--   4) มีทั้ง created_at และ paid_at -> นิยาม "active" ต้องใช้ตัวที่ถูก
--
-- รันด้วย: psql "<conn-string>" -f seed_wren_demo.sql
-- ============================================================

DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS customers_v2;
DROP TABLE IF EXISTS customers_v1;

-- ---------- ตารางเก่า (ตายแล้ว แต่ยังอยู่ใน schema) ----------
CREATE TABLE customers_v1 (
    id          INTEGER PRIMARY KEY,
    name        TEXT,
    email       TEXT,
    signup_date TIMESTAMP
);

-- ---------- ตารางที่ทีมใช้จริง (มีคอลัมน์ลับ) ----------
CREATE TABLE customers_v2 (
    customer_id INTEGER PRIMARY KEY,
    first_name  TEXT,
    last_name   TEXT,
    email       TEXT,          -- secret
    phone       TEXT,          -- secret
    national_id TEXT,          -- secret
    created_at  TIMESTAMP
);

-- ---------- orders: status เป็นเลข 1..5 ----------
-- 1=pending, 2=paid, 3=shipped, 4=refunded, 5=cancelled
CREATE TABLE orders (
    order_id    INTEGER PRIMARY KEY,
    customer_id INTEGER REFERENCES customers_v2(customer_id),
    status      INTEGER NOT NULL,
    total       NUMERIC(10,2) NOT NULL,
    created_at  TIMESTAMP NOT NULL,   -- วันสร้าง order
    paid_at     TIMESTAMP             -- วันจ่ายจริง (null ถ้ายังไม่จ่าย)
);

-- ============================================================
-- Seed data (deterministic — รันกี่ครั้งตัวเลขก็เหมือนเดิม)
-- ============================================================

-- 200 ลูกค้าจริง ใน v2
INSERT INTO customers_v2 (customer_id, first_name, last_name, email, phone, national_id, created_at)
SELECT
    g,
    (ARRAY['Somchai','Suda','Anan','Nicha','Krit','Ploy','Wit','Mali'])[1 + (g % 8)],
    (ARRAY['Jaidee','Srisuk','Wong','Pinto','Charoen'])[1 + (g % 5)],
    'user' || g || '@example.com',
    '08' || lpad(((g * 12345) % 100000000)::text, 8, '0'),
    lpad(((g * 7777) % 1000000000000)::text, 13, '0'),
    now() - ((g % 700) || ' days')::interval
FROM generate_series(1, 200) AS g;

-- 350 แถวในตารางเก่า (inflated + ปนข้อมูลตาย) -> เหยื่อล่อให้ agent หยิบผิด
INSERT INTO customers_v1 (id, name, email, signup_date)
SELECT
    g,
    'legacy_user_' || g,
    'legacy' || g || '@example.com',
    now() - ((g % 1000) || ' days')::interval
FROM generate_series(1, 350) AS g;

-- 1200 orders กระจาย status และเวลา
INSERT INTO orders (order_id, customer_id, status, total, created_at, paid_at)
SELECT
    g,
    1 + (g * 7) % 200,                       -- กระจายไป 200 ลูกค้า
    CASE (g % 10)                            -- ถ่วงน้ำหนัก status
        WHEN 0 THEN 1 WHEN 1 THEN 1          -- pending  ~20%
        WHEN 2 THEN 2 WHEN 3 THEN 2 WHEN 4 THEN 2  -- paid ~30%
        WHEN 5 THEN 3                        -- shipped ~10%
        WHEN 6 THEN 4 WHEN 7 THEN 4          -- refunded ~20%
        ELSE 5                               -- cancelled ~20%
    END,
    round((100 + (g % 50) * 13)::numeric, 2),
    now() - ((g % 365) || ' days')::interval,
    CASE
        WHEN (g % 10) IN (2,3,4)             -- เฉพาะ paid ถึงจะมี paid_at
        THEN now() - ((g % 365) || ' days')::interval + interval '1 day'
        ELSE NULL
    END
FROM generate_series(1, 1200) AS g;

-- ============================================================
-- ตรวจผล: รัน 2 query นี้เทียบกัน = หัวใจของ demo
-- ============================================================

-- ❌ แบบที่ LLM มักเขียน (หยิบ v1, ไม่กรอง status, ใช้ created_at)
--    -> ได้ตัวเลข "ดูถูกแต่ผิด" และสูงเกินจริง
SELECT 'WRONG (no context)' AS label, COUNT(DISTINCT c.id) AS active_customers
FROM customers_v1 c
JOIN orders o ON o.customer_id = c.id
WHERE o.created_at >= now() - interval '90 days';

-- ✅ แบบที่ถูกตามนิยามทีม (v2, status=2 paid, ใช้ paid_at)
SELECT 'CORRECT (with context)' AS label, COUNT(DISTINCT customer_id) AS active_customers
FROM orders
WHERE status = 2
    AND paid_at >= now() - interval '90 days';