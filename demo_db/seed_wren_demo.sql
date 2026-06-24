-- ============================================================
-- WrenAI Demo Seed (PostgreSQL)
-- จงใจใส่ "กับดัก" 5 อย่างที่ทำให้ LLM เขียน SQL ผิดแบบเงียบ ๆ:
--   1) มีตาราง customer ซ้ำ: customers_v1 (ตายแล้ว) กับ customers_v2 (ใช้จริง)
--   2) orders.status เป็นตัวเลข ไม่มีคำอธิบาย
--   3) customers_v2 มีคอลัมน์ลับ: email, phone, national_id
--   4) มีทั้ง created_at และ paid_at -> นิยาม "active" ต้องใช้ตัวที่ถูก
--   5) products.price (list ปัจจุบัน) vs order_items.unit_price (ราคาตอนขายจริง)
--      + category_code เลขเปล่า + is_active (discontinued)
--
-- รันด้วย: psql "<conn-string>" -f seed_wren_demo.sql
-- ============================================================

DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS products;
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

-- ---------- products: category เป็นเลข + ราคา list ปัจจุบัน ----------
-- กับดักที่ 5: products.price คือราคา list "ตอนนี้" (ขยับขึ้นเรื่อย ๆ)
--   ห้ามใช้คำนวณ revenue ย้อนหลัง -> ต้องใช้ order_items.unit_price (ราคาตอนขายจริง)
-- category_code เป็นเลข 1..5: 1=Electronics 2=Apparel 3=Food 4=Books 5=Home
-- is_active=false = เลิกขายแล้ว แต่ยังมีใน order เก่า
CREATE TABLE products (
    product_id    INTEGER PRIMARY KEY,
    name          TEXT NOT NULL,
    category_code INTEGER NOT NULL,
    price         NUMERIC(10,2) NOT NULL,   -- ราคา list ปัจจุบัน (drift; ไม่ใช่ราคาขายจริงย้อนหลัง)
    is_active     BOOLEAN NOT NULL,         -- false = discontinued
    created_at    TIMESTAMP NOT NULL
);

-- ---------- order_items: line item ต่อ 1 order ----------
-- unit_price = ราคา "ตอนขายจริง" -> source of truth ของ revenue รายสินค้า
CREATE TABLE order_items (
    item_id    INTEGER PRIMARY KEY,
    order_id   INTEGER NOT NULL REFERENCES orders(order_id),
    product_id INTEGER NOT NULL REFERENCES products(product_id),
    quantity   INTEGER NOT NULL,
    unit_price NUMERIC(10,2) NOT NULL       -- ราคาตอนขาย (มัก < products.price ปัจจุบัน)
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

-- 40 products (ราคา list ปัจจุบัน = base * 1.15; ~11% discontinued)
INSERT INTO products (product_id, name, category_code, price, is_active, created_at)
SELECT
    g,
    (ARRAY['Widget','Gadget','Gizmo','Doohickey','Thingamajig'])[1 + (g % 5)] || ' ' || g,
    1 + (g % 5),                                     -- category 1..5
    round(((100 + (g % 20) * 25) * 1.15)::numeric, 2),  -- list price "ตอนนี้" (สูงกว่าตอนขายจริง)
    (g % 9) <> 0,                                    -- ทุก ๆ ตัวที่ 9 = discontinued
    now() - ((g % 500) || ' days')::interval
FROM generate_series(1, 40) AS g;

-- 3000 order items: unit_price = ราคา base (ตอนขายจริง) < products.price ปัจจุบัน
INSERT INTO order_items (item_id, order_id, product_id, quantity, unit_price)
SELECT
    g,
    1 + (g % 1200),                                  -- กระจายลง 1200 orders
    1 + (g * 13) % 40,                               -- กระจายไป 40 products
    1 + (g % 3),                                     -- qty 1..3
    (100 + ((1 + (g * 13) % 40) % 20) * 25)::numeric -- ราคา base ตอนขาย (ไม่บวก 15%)
FROM generate_series(1, 3000) AS g;

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

-- ------------------------------------------------------------
-- กับดักที่ 5: revenue รายสินค้า — ใช้ราคาผิดคอลัมน์
-- ------------------------------------------------------------

-- ❌ ใช้ products.price (list ปัจจุบัน) + ไม่กรอง status -> สูงเกินจริง ~15%+
SELECT 'WRONG (list price)' AS label, round(SUM(oi.quantity * p.price), 2) AS revenue
FROM order_items oi
JOIN products p ON p.product_id = oi.product_id;

-- ✅ ใช้ order_items.unit_price (ราคาตอนขายจริง) + เฉพาะ order ที่ paid
SELECT 'CORRECT (sale price, paid only)' AS label, round(SUM(oi.quantity * oi.unit_price), 2) AS revenue
FROM order_items oi
JOIN orders o ON o.order_id = oi.order_id
WHERE o.status = 2;