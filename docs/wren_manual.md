# คู่มือ Wren ฉบับสมบูรณ์ (ใช้สอน + ลงมือทำได้เลย)

> ไฟล์เดียวจบ ตั้งแต่ติดตั้ง → ถามข้อมูล → เพิ่มตาราง → memory → แก้ปัญหา
> ตัวอย่างทุกอันใช้ของจริงจากโปรเจกต์นี้ (เลขจริงจาก seed) — copy ไปรันตามได้
> เหมาะกับ: คนที่จะเอาไป **สอนต่อ** และคนที่ **เพิ่งเริ่ม** อยากใช้เป็น

**เอกสารอื่นในโฟลเดอร์ `docs/`** (ไฟล์นี้รวมทุกอย่าง ที่เหลือคือเจาะลึกเฉพาะเรื่อง):
- `wren_concept.md` — concept เน้นทำความเข้าใจ
- `wren_playbook.md` — สคริปต์ demo 4–5 กับดัก
- `wren_recipe.md` — checklist คำถามใหม่ + ทางลัด
- `wren_reference.md` — ตาราง CLI lookup
- `index.html` — เวอร์ชัน interactive (เปิดในเบราว์เซอร์)

---

## สารบัญ

0. [Wren คืออะไร แก้ปัญหาอะไร](#0)
1. [สถาปัตยกรรม — 5 ชิ้นส่วน](#1)
2. [ติดตั้ง + ตั้งค่า](#2)
3. [seed demo DB + 5 กับดัก](#3)
4. [วงจร build / index / load — หัวใจ](#4)
5. [ถามข้อมูล (query)](#5)
6. [Memory เชิงลึก](#6)
7. [ตัวอย่างเต็ม — เพิ่มตารางใหม่ end-to-end](#7)
8. [เพิ่มคำถามใหม่ (recipe + ทางลัด)](#8)
9. [instructions.md — กติกาธุรกิจ](#9)
10. [แก้ปัญหา (Troubleshooting)](#10)
11. [Cheat sheet — คำสั่งทั้งหมด](#11)

---

<a id="0"></a>
## 0. Wren คืออะไร แก้ปัญหาอะไร

**Wren = semantic layer (ชั้นความหมาย) คั่นระหว่างคำถาม กับ ฐานข้อมูลจริง**

ปัญหาเวลาให้คน (หรือ LLM) เขียน SQL ตรงๆ บน DB จริง:
- ตารางมีชื่อสับสน — `customers_v1` (ตาย) vs `customers_v2` (ใช้จริง) จะรู้ได้ไง?
- คอลัมน์เป็นเลขเปล่า — `status = 2` แปลว่าอะไร?
- กติกาธุรกิจซ่อนอยู่ในหัวคน — "ลูกค้า active" นับยังไง? "revenue" รวมอะไรบ้าง?
- คอลัมน์ลับ — `national_id` ไม่ควรให้ทุกคนเห็น

Wren แก้โดยให้เราถามผ่าน **ชื่อ model** (เช่น `customers`) ไม่ใช่ตารางจริง แล้ว Wren แปลให้:

```
คำถาม "ลูกค้ามีกี่คน"
   │
   ▼  Wren (semantic layer)
   │   - customers → public.customers_v2  (ไม่ใช่ v1)
   │   - เห็นเฉพาะคอลัมน์ที่ประกาศ (national_id ถูกซ่อน)
   │   - รู้กติกา (active = status 2 + paid_at 90 วัน)
   ▼
SQL จริงที่ถูกต้อง → PostgreSQL → คำตอบ
```

**ผลลัพธ์:** ถามด้วยภาษาคนหรือ SQL ชื่อง่าย แล้วได้ SQL ที่ตรงตาราง + ถูกกติกา โดยไม่ต้องจำ schema จริง

---

<a id="1"></a>
## 1. สถาปัตยกรรม — 5 ชิ้นส่วน

Wren project ประกอบด้วยไฟล์ config ที่ทำงานร่วมกัน (config คือ "source", `target/` กับ `.wren/` คือของ generated):

```
my-wren-project/
├── wren_project.yml          # ① ผูกทุกอย่าง: catalog, schema, data_source, profile
├── connection.yml            # ② datasource config (อ่าน ${PG_*} จาก env)
├── models/                   # ③ นิยามตาราง — 1 โฟลเดอร์ = 1 model
│   ├── customers_v2/metadata.yml   #   name: customers → table: customers_v2
│   ├── orders/metadata.yml
│   ├── products/metadata.yml
│   └── order_items/metadata.yml
├── relationships.yml         # ④ join ระหว่าง model
├── instructions.md           # ⑤ กติกาธุรกิจที่ SQL บอกไม่ได้
├── queries.yml               #    คู่ NL↔SQL ที่ curate ไว้ (seed memory recall)
├── demo_db/seed_wren_demo.sql#    สคริปต์ seed PostgreSQL
├── target/mdl.json           #    [generated] compile จาก config — ห้ามแก้มือ
└── .wren/memory/             #    [generated] LanceDB index ของ memory
```

### ③ models/<name>/metadata.yml — หัวใจของ indirection

```yaml
name: customers                    # ← ชื่อที่ใช้ query (alias)
properties:
  description: "Current (v2) customer records..."   # agent อ่าน description ด้วย
table_reference:
  catalog: ""
  schema: public
  table: customers_v2              # ← ตารางจริงใน DB
primary_key: customer_id
columns:                           # ← เห็นเฉพาะที่ list ไว้
  - name: customer_id
    type: INT
    not_null: true
  - name: first_name
    type: TEXT
  # ... (ไม่ใส่ national_id → ถูกซ่อนอัตโนมัติ = masking by omission)
```

**กลไกสำคัญ 2 อย่าง:**
1. **เปลี่ยนชื่อตาราง** — `name: customers` ชี้ไป `table: customers_v2` → คนถาม `customers` ไม่มีทางโดน `customers_v1` ที่ตายแล้ว
2. **ซ่อนคอลัมน์ด้วยการไม่ประกาศ** — `national_id` มีในตารางจริง แต่ไม่อยู่ใน `columns:` → agent มองไม่เห็น query ไม่ได้

### ④ relationships.yml — join สำเร็จรูป

```yaml
relationships:
  - name: order_customers
    models: [orders, customers]
    join_type: MANY_TO_ONE
    condition: orders.customer_id = customers.customer_id
  - name: item_orders
    models: [order_items, orders]
    join_type: MANY_TO_ONE
    condition: order_items.order_id = orders.order_id
  - name: item_products
    models: [order_items, products]
    join_type: MANY_TO_ONE
    condition: order_items.product_id = products.product_id
```

> condition อ้าง **ชื่อ model** ไม่ใช่ตารางจริง · `MANY_TO_ONE` = หลาย order_items ต่อ 1 order

### ⑤ instructions.md — ความหมายที่ SQL เขียนไม่ได้

```markdown
## Definitions
- "active customer" = ลูกค้าที่มี order status = 2 (paid) ใน 90 วันล่าสุด
- "revenue" = SUM(orders.total) เฉพาะ status = 2
- "revenue รายสินค้า" = SUM(order_items.unit_price * quantity) + join orders status=2 — ห้ามใช้ products.price

## Status codes
1=pending, 2=paid, 3=shipped, 4=refunded, 5=cancelled
```

> **ไฟล์นี้ load-bearing** — แก้นิยามที่นี่ = เปลี่ยนความหมายของ SQL ที่ generate ออกมา

### queries.yml — คู่ NL↔SQL ที่ curate

```yaml
version: 1
pairs:
  - nl: "revenue รายสินค้า top 5"
    sql: "SELECT p.name, SUM(oi.quantity * oi.unit_price) AS revenue FROM order_items oi JOIN ..."
```

> สอน Wren ว่าคำถามนี้ตอบด้วย SQL แบบนี้ → ครั้งหน้า `recall` เจอ ใช้เป็นตัวอย่าง

---

<a id="2"></a>
## 2. ติดตั้ง + ตั้งค่า

### 2.1 ติดตั้ง Wren (ครั้งเดียว)

```bash
python3 -m venv ~/.venvs/wren            # สร้าง virtual env แยก
source ~/.venvs/wren/bin/activate        # เข้า venv (prompt จะขึ้น (wren))
pip install "wrenai[postgres,memory]"    # ติดตั้ง + ตัวต่อ postgres + memory
pip install pylance                      # (เผื่อ memory dump/list — ดู Troubleshooting)
```

### 2.2 ตั้งค่า DB credential

```bash
cp .env.example .env                     # คัดลอก template
# แก้ค่าจริงใน .env: PG_HOST, PG_PORT, PG_DATABASE, PG_USER, PG_PASSWORD
```

`.env` ถูก gitignore (credential ไม่หลุด) · `connection.yml` อ่านค่าผ่าน `${PG_*}`

### 2.3 ⚠️ ทุกครั้งที่เปิด terminal ใหม่ ต้องทำ 3 อย่างนี้ก่อน

```bash
cd ~/Desktop/work/my-wren-project        # 1. เข้าโฟลเดอร์ project
source ~/.venvs/wren/bin/activate        # 2. เข้า venv (ไม่งั้น `wren` เป็นคนละตัว)
export $(grep -v '^#' .env | xargs)      # 3. โหลด env (ไม่งั้น psql/wren ต่อ DB ไม่ได้)
```

> **อาการถ้าลืม:** ลืมข้อ 2 → `wren: command not found` หรือไม่มี subcommand `memory` · ลืมข้อ 3 → `psql: connection ... failed: No such file or directory` (เพราะ `$PG_HOST` ว่าง เลย default ไป local socket)

---

<a id="3"></a>
## 3. seed demo DB + 5 กับดัก

### 3.1 รัน seed (ครั้งแรก)

```bash
psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DATABASE" -f demo_db/seed_wren_demo.sql
```

จะได้ตาราง (deterministic — รันกี่ครั้งเลขเท่าเดิม):

| ตารางจริง | model | แถว | บทบาท |
|---|---|---|---|
| `customers_v1` | — (ไม่ map) | 350 | ตารางตาย เหยื่อล่อ |
| `customers_v2` | `customers` | 200 | ตัวจริง — `email/phone/national_id` คอลัมน์ลับ |
| `orders` | `orders` | 1200 | `status` เลข 1-5, มี `created_at` + `paid_at` |
| `products` | `products` | 40 | `category_code` เลข 1-5, `price` = list ปัจจุบัน, `is_active` |
| `order_items` | `order_items` | 3000 | line item, `unit_price` = ราคาตอนขายจริง |

### 3.2 กับดักทั้ง 5 (ทำไม raw SQL ผิด แต่ Wren รอด)

1. **ตารางตาย** — `customers_v1` (350 แถวปนข้อมูลมั่ว) vs `customers_v2` (200 จริง). คนเขียน SQL เองมักหยิบ v1 → นับเกิน. Wren map `customers` → v2 เสมอ
2. **status เลขเปล่า** — `2=paid`. ไม่รู้รหัส = กรอง revenue ผิด. instructions.md บอกไว้
3. **คอลัมน์ลับ** — `national_id` ไม่อยู่ใน model → query ไม่ได้ (masking)
4. **created_at vs paid_at** — "active/revenue" ใช้ `paid_at` (วันจ่าย) ไม่ใช่ `created_at` (วันสมัคร/วันสร้าง order)
5. **list price vs ราคาขายจริง** — `products.price` = ราคา list "ปัจจุบัน" (สูงกว่าตอนขาย ~15%). revenue รายสินค้าต้องใช้ `order_items.unit_price × quantity` + กรอง `status=2` ห้ามใช้ `products.price`

### 3.3 พิสูจน์กับดักด้วยตัวเลขจริง

ท้ายไฟล์ `seed_wren_demo.sql` มี query เทียบ — รันแล้วได้:

```
กับดัก #1 (active customers):
  WRONG (v1, ไม่กรอง status, ใช้ created_at) = 195
  CORRECT (v2, status=2, paid_at 90 วัน)     = 57

กับดัก #5 (revenue รายสินค้า):
  WRONG (products.price, ไม่กรอง status)     = 2,328,750
  CORRECT (unit_price, status=2)             = 570,000
```

> ต่างกัน 3-4 เท่า "ดูถูกแต่ผิด" — นี่คือเหตุผลที่ต้องมี semantic layer

---

<a id="4"></a>
## 4. วงจร build / index / load — หัวใจที่ต้องเข้าใจ

Config คือ source. ต้อง "compile" ก่อนถึงจะมีผล. **มี 3 คำสั่งที่ทำคนละหน้าที่ — นี่คือจุดที่คนสับสนบ่อยสุด:**

| คำสั่ง | อ่านอะไร | สร้าง/อัปเดตอะไร | ใช้เมื่อ |
|---|---|---|---|
| `wren context build` | `models/`, `relationships.yml` | `target/mdl.json` | แก้ model หรือ relationship |
| `wren memory index` | `target/mdl.json`, `instructions.md` | schema items + auto browse queries ใน `.wren/memory/` | แก้ instructions.md / เพิ่ม model |
| `wren memory load queries.yml` | `queries.yml` | คู่ NL↔SQL ใน store | แก้ queries.yml |

### ⚠️ Gotcha สำคัญที่สุด: queries.yml เข้า store ด้วย `load` ไม่ใช่ `index`

```
wren memory index           → สร้างแค่ auto browse queries ("List all products", "Total X in Y")
                              ❌ ไม่ดึงคู่ curate จาก queries.yml เข้า recall
wren memory load queries.yml → ✅ import คู่ที่เราเขียนเข้า store จริง
wren memory dump            → ⚠️ ทิศกลับ! export store เขียนทับ queries.yml (อย่ารันมั่ว)
```

**อาการถ้าใช้ผิด:** `index` แล้ว `recall "สินค้าขายดี"` ได้แต่ `"List all products"` (auto) ไม่เจอคู่ที่เขียนเอง → เพราะยังไม่ได้ `load`

### สูตรจำง่าย (แก้อะไร → รันอะไร)

```
แก้ models/*.yml หรือ relationships.yml   →  wren context build
แก้ instructions.md                       →  wren context build && wren memory index
แก้ queries.yml                           →  wren memory load queries.yml
เพิ่ม model ใหม่                          →  wren context build && wren memory index
                                             (+ wren memory load queries.yml ถ้าเพิ่มคู่ด้วย)
```

> ลำดับบังคับ: `context build` **ต้องมาก่อน** `memory index` เสมอ (index อ่าน mdl.json ที่ build สร้าง)

---

<a id="5"></a>
## 5. ถามข้อมูล (query)

### 5.1 รัน SQL ผ่านชื่อ model

```bash
# นับลูกค้า (customers = model → จริงคือ customers_v2)
wren --sql "SELECT COUNT(*) FROM customers" -o table
# → 200

# revenue รวม (กรอง status=2 ตามกติกา)
wren --sql "SELECT SUM(total) FROM orders WHERE status = 2" -o table

# join ข้ามตาราง — สินค้าขายดี (relationships ทำให้ join ได้)
wren --sql "SELECT p.name, SUM(oi.quantity) AS qty
            FROM order_items oi
            JOIN products p ON p.product_id = oi.product_id
            JOIN orders o ON o.order_id = oi.order_id
            WHERE o.status = 2
            GROUP BY p.name ORDER BY qty DESC LIMIT 5" -o table
```

`-o` เลือก output: `table` (อ่านง่าย) · `json` (เอาไปต่อ jq) · `csv`

### 5.2 ดู SQL ที่ Wren แปลจริง (ไม่แตะ DB)

```bash
# dry-plan = expand ชื่อ model → ตาราง/คอลัมน์จริง โดยไม่ยิง DB
wren dry-plan --sql "SELECT first_name FROM customers LIMIT 5"
# จะเห็น customers ถูกแทนด้วย public.customers_v2

# dry-run = validate กับ DB จริง แต่ไม่คืน row (เช็คว่า SQL ใช้ได้ไหม)
wren dry-run --sql "SELECT first_name FROM customers"
```

> ใช้ `dry-plan` ตอนสงสัยว่า model map ถูกไหม / คอลัมน์มีจริงไหม ก่อนรันจริง

### 5.3 ดูว่า model มีคอลัมน์อะไรบ้าง

```bash
wren memory describe 2>/dev/null | grep -A12 -iE 'orders|customers'
# หรือดูไฟล์ตรงๆ
cat models/orders/metadata.yml
```

---

<a id="6"></a>
## 6. Memory เชิงลึก

Memory = คลังคู่ NL↔SQL ที่ Wren ใช้เป็นตัวอย่าง (few-shot) เวลา agent เขียน SQL. เก็บใน LanceDB ที่ `.wren/memory/`

### 6.1 คำสั่งทั้งหมด

```bash
wren memory recall -q "คำถาม"            # หาคู่ที่ใกล้สุด (semantic) — distance ต่ำ = ใกล้
wren memory fetch  -q "คำถาม"            # ดู context ทั้งก้อนที่ agent จะดึง (schema + นิยาม)
wren memory store --nl "..." --sql "..." # เก็บ 1 คู่เข้า store ตรงๆ (ไม่ผ่านไฟล์ ไม่ git track)
wren memory load queries.yml             # import คู่จาก queries.yml เข้า store
wren memory dump                         # ⚠️ export store → เขียนทับ queries.yml
wren memory index                        # index schema + สร้าง auto browse queries
wren memory list                         # ดูคู่ทั้งหมดใน store (ต้องมี pylance)
wren memory forget                       # ลบคู่
wren memory reset                        # ล้างทุกตาราง เริ่มใหม่
wren memory status                       # สถิติ index
```

### 6.2 recall — distance หมายถึงอะไร

```bash
wren memory recall -q "สินค้าขายดี" -l 3
```
```
dist 0      สินค้าขายดี top 5 ตามจำนวน   ← ตรงเป๊ะ (0 = เหมือนเป๊ะ)
dist 0.506  revenue รายสินค้า top 5      ← ใกล้เคียง
dist 0.712  สินค้าที่ยังขายอยู่มีกี่ตัว   ← ห่างขึ้น
```
> distance ยิ่งต่ำยิ่งใกล้ · `-l` = จำนวนผล · `-o json` เอาไปต่อ jq ได้

### 6.3 store vs load vs queries.yml — เลือกอันไหน

| วิธี | git track? | ใช้เมื่อ |
|---|---|---|
| `wren memory store --nl --sql` | ❌ (เข้า `.wren/` ที่ gitignore) | จดเร็วๆ ใช้ส่วนตัว ไม่อยากแชร์ |
| เพิ่มใน `queries.yml` + `memory load` | ✅ (queries.yml อยู่ใน git) | อยากให้ทีม clone ไปแล้วได้ด้วย — **แนะนำ** |

> `.wren/memory/` ถูก gitignore → ของที่ `store` ตรงๆ จะหายตอน clone ใหม่. ใส่ใน `queries.yml` ถึงจะถาวร

### 6.4 recall สวยๆ (อ่านง่าย) — function ใน ~/.zshrc

```bash
wmr() {
  wren memory recall -q "$1" -l "${2:-3}" -o json \
    | jq -r '.[] | "dist \((._distance*1000|round)/1000)  \(.nl_query)\n    \(.sql_query)\n"'
}
# เรียก: wmr "สินค้าขายดี"   ·   wmr "revenue" 5
```

---

<a id="7"></a>
## 7. ตัวอย่างเต็ม — เพิ่มตารางใหม่ end-to-end

โจทย์จริง: เพิ่ม `products` + `order_items` เข้า demo (พร้อมกับดัก #5). นี่คือ **ลำดับที่ถูกต้อง** ทำตามได้เลย

### ขั้น 1 — เพิ่ม data ใน DB

แก้ `demo_db/seed_wren_demo.sql` เพิ่ม `CREATE TABLE products / order_items` + INSERT แล้วรัน:
```bash
export $(grep -v '^#' .env | xargs)
psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DATABASE" -f demo_db/seed_wren_demo.sql
```
ดูท้าย output: `INSERT 0 40` (products), `INSERT 0 3000` (order_items) = สำเร็จ

### ขั้น 2 — สร้าง model metadata (1 โฟลเดอร์/ตาราง)

`models/products/metadata.yml`:
```yaml
name: products
properties:
  description: "Products. price = current list price (drifts up). For per-product revenue use order_items.unit_price, NOT this."
table_reference: { catalog: "", schema: public, table: products }
primary_key: product_id
columns:
  - { name: product_id,    type: INT,     not_null: true }
  - { name: name,          type: TEXT,    not_null: true }
  - { name: category_code, type: INT,     not_null: true }
  - { name: price,         type: DECIMAL, not_null: true }
  - { name: is_active,     type: BOOLEAN, not_null: true }
  - { name: created_at,    type: TIMESTAMP, not_null: true }
```
`models/order_items/metadata.yml`:
```yaml
name: order_items
properties:
  description: "Order line items. unit_price = price at sale time (source of truth for revenue)."
table_reference: { catalog: "", schema: public, table: order_items }
primary_key: item_id
columns:
  - { name: item_id,    type: INT, not_null: true }
  - { name: order_id,   type: INT, not_null: true }
  - { name: product_id, type: INT, not_null: true }
  - { name: quantity,   type: INT, not_null: true }
  - { name: unit_price, type: DECIMAL, not_null: true }
```

> **Type ที่ Wren MDL รองรับ:** `VARCHAR · INTEGER · DOUBLE · DATE · TIMESTAMP · BOOLEAN · DECIMAL · JSON`
> `INT`/`TEXT` ใช้ได้ (alias) · เงินใช้ `DECIMAL` (ไม่ใส่ precision เช่น `DECIMAL(10,2)`) · bool ใช้ `BOOLEAN` (ไม่ใช่ `BOOL`)
> ⚠️ จุดพลาดบ่อย: `primary_key` ต้องชี้ไปคอลัมน์ที่มีจริงใน `columns:` (ลืมใส่ = build พัง)

### ขั้น 3 — เพิ่ม relationships

`relationships.yml` (มี key `relationships:` อันเดียว ห้ามซ้ำ):
```yaml
relationships:
  - { name: order_customers, models: [orders, customers],     join_type: MANY_TO_ONE, condition: orders.customer_id = customers.customer_id }
  - { name: item_orders,     models: [order_items, orders],   join_type: MANY_TO_ONE, condition: order_items.order_id = orders.order_id }
  - { name: item_products,   models: [order_items, products], join_type: MANY_TO_ONE, condition: order_items.product_id = products.product_id }
```
> ⚠️ มี `relationships:` ซ้ำ 2 อัน → error "Map keys must be unique" (เอา item ทั้งหมดไว้ใต้ key เดียว)

### ขั้น 4 — เพิ่มกติกาใน instructions.md

```markdown
- category_code: 1=Electronics 2=Apparel 3=Food 4=Books 5=Home
- "revenue รายสินค้า" = SUM(order_items.unit_price * quantity) + join orders กรอง status=2 — ห้ามใช้ products.price
- "สินค้า active" = is_active = true
```

### ขั้น 5 — เพิ่มคู่ใน queries.yml

```yaml
  - nl: "สินค้าขายดี top 5 ตามจำนวน"
    sql: "SELECT p.name, SUM(oi.quantity) AS qty FROM order_items oi JOIN products p ON p.product_id = oi.product_id JOIN orders o ON o.order_id = oi.order_id WHERE o.status = 2 GROUP BY p.name ORDER BY qty DESC LIMIT 5"
  - nl: "revenue รายสินค้า top 5"
    sql: "SELECT p.name, SUM(oi.quantity * oi.unit_price) AS revenue FROM order_items oi JOIN products p ON p.product_id = oi.product_id JOIN orders o ON o.order_id = oi.order_id WHERE o.status = 2 GROUP BY p.name ORDER BY revenue DESC LIMIT 5"
```

### ขั้น 6 — compile ทั้งหมด (ตามลำดับ!)

```bash
wren context build                  # 1. แตะ model+relationship → rebuild mdl.json
wren context build && wren memory index   # 2. แตะ instructions.md → re-index
wren memory load queries.yml        # 3. แตะ queries.yml → load เข้า store (ไม่ใช่ index!)
```
ผ่าน = `Built: 4 models, 0 views → target/mdl.json`

### ขั้น 7 — verify

```bash
wren --sql "SELECT COUNT(*) FROM products" -o table        # → 40
wren --sql "SELECT COUNT(*) FROM order_items" -o table     # → 3000
wren dry-plan --sql "SELECT name, price FROM products LIMIT 3"   # ดู expand → public.products
wmr "สินค้าขายดี"                                          # recall เจอคู่เรา dist ต่ำ ✅
```

ครบ — ตอนนี้ถามเรื่อง products ได้แล้ว recall จับได้

---

<a id="8"></a>
## 8. เพิ่มคำถามใหม่ (recipe + ทางลัด)

ไม่ต้องทำครบทุกขั้นเสมอ — เลือกตามความมั่นใจ:

### ระดับ 1 — แค่อยากได้คำตอบ (1 คำสั่ง)
field มั่นใจครบ → ยิงเลย จบ
```bash
wren --sql "SELECT ..." -o table
```

### ระดับ 2 — อยากเก็บไว้ใช้ซ้ำ (+1 คำสั่ง)
```bash
wren --sql "SELECT ..." -o table
wren memory store --nl "คำถาม" --sql "..."   # จดเข้า memory ตรง (ไม่ git track)
```

### ระดับ 3 — อยาก git track ให้ทีมได้ด้วย (ครบ)
```bash
wren memory recall -q "คำถาม"               # 1. เผื่อมีของเดิม (ข้ามได้)
wren dry-plan --sql "SELECT ..."            # 2. เช็ค field ถูก (ข้ามได้ถ้าชัวร์)
wren --sql "SELECT ..." -o table            # 3. รันจริง
# 4. append คู่ใหม่ใน queries.yml (indent 2 space ใต้ pairs:)
wren memory load queries.yml                # 5. โหลดเข้า store
wren memory recall -q "คำถาม"               # 6. ยืนยัน dist ต่ำ
```

### เมื่อไหร่ต้องแตะอะไร

| คำถามต้องการ | เพิ่มที่ | คำสั่งหลัง |
|---|---|---|
| field+join ครบแล้ว แค่อยากเก็บ | `queries.yml` | `memory load queries.yml` |
| คอลัมน์ที่ DB มีแต่ model ไม่ประกาศ | `models/<t>/metadata.yml` | `context build` |
| join ตารางใหม่ที่ยังไม่ผูก | `relationships.yml` | `context build` |
| ศัพท์ธุรกิจใหม่ (VIP/churn) | `instructions.md` | `context build && memory index` |

---

<a id="9"></a>
## 9. instructions.md — กติกาธุรกิจ

ที่เก็บความหมายที่ SQL เขียนตรงๆ ไม่ได้. ทั้งคนและ LLM อ่าน. ตัวอย่างเพิ่มนิยามใหม่:

```markdown
## Definitions
- "VIP" = ลูกค้าที่ซื้อรวม > 10,000 (status 2)
- "churn" = ไม่มี order paid ใน 180 วัน
```
หลังแก้:
```bash
wren context build && wren memory index
wren memory fetch -q "VIP customer"   # เช็คว่า context ดึงนิยามมาจริง
```

> **เก็บให้ sync กับ SQL:** ถ้า instructions บอก "revenue = status 2" แต่ queries.yml เขียน `status = 3` → ขัดกัน agent งง. แก้ที่เดียวให้ตรงกัน

---

<a id="10"></a>
## 10. แก้ปัญหา (Troubleshooting)

| อาการ | สาเหตุ | แก้ |
|---|---|---|
| `psql: connection ... No such file or directory` | ลืม `export $(... .env ...)` → `$PG_HOST` ว่าง | โหลด env ก่อน (ข้อ 2.3) |
| `wren: command not found` / ไม่มี subcommand `memory` | ไม่ได้อยู่ใน venv | `source ~/.venvs/wren/bin/activate` |
| `recall` ได้แต่ "List all products" ไม่เจอคู่ที่เขียน | ลืม `memory load` (ใช้ `index` อย่างเดียว) | `wren memory load queries.yml` |
| queries.yml โดนเขียนทับด้วยคู่ auto | เผลอรัน `wren memory dump` | `git checkout queries.yml` กู้คืน |
| `memory dump/list` crash `No module named 'lance'` | ขาด pylance | `pip install pylance` |
| build error `Map keys must be unique` | `relationships:` ซ้ำ 2 อันใน yaml | รวมเป็น key เดียว |
| build พัง เรื่อง primary_key | `primary_key` ชี้คอลัมน์ที่ไม่มีใน `columns:` | เพิ่มคอลัมน์นั้น หรือแก้ชื่อ |
| query ได้เลขผิด/สูงเกิน | context เก่า (ลืม build/index/load) หรือ SQL ตกหลุมกับดัก | regenerate + เทียบกับ instructions.md |
| `-d postgres` แล้ว recall "No results" | datasource filter ไม่ตรง — ปกติไม่ต้องใส่ `-d` | เอา `-d` ออก |

### ทอง: หลังแก้ config "ทุกครั้ง" regenerate ก่อนถาม

ไม่งั้น query วิ่งบน context เก่า → ผลเพี้ยนแบบเงียบๆ

---

<a id="11"></a>
## 11. Cheat sheet — คำสั่งทั้งหมด

```bash
# เตรียม (ทุก terminal ใหม่)
cd ~/Desktop/work/my-wren-project && source ~/.venvs/wren/bin/activate && export $(grep -v '^#' .env | xargs)

# seed DB (ครั้งแรก)
psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DATABASE" -f demo_db/seed_wren_demo.sql

# compile (เลือกตามที่แก้)
wren context build                         # แก้ model/relationship
wren context build && wren memory index    # แก้ instructions.md / เพิ่ม model
wren memory load queries.yml               # แก้ queries.yml  ← load ไม่ใช่ index!

# ถาม
wren --sql "SELECT ..." -o table|json|csv  # รันจริง (ชื่อ model)
wren dry-plan --sql "..."                  # ดู SQL ที่ expand (ไม่แตะ DB)
wren dry-run  --sql "..."                  # validate กับ DB (ไม่คืน row)

# memory
wren memory recall -q "..." -l 3           # หาคู่ใกล้สุด
wren memory fetch  -q "..."                # ดู context ที่ agent ดึง
wren memory store  --nl "..." --sql "..."  # เก็บ 1 คู่ (ไม่ git track)
wren memory load queries.yml [--upsert]    # import queries.yml (--upsert ทับ SQL เดิม)
wren memory reset                          # ล้างเริ่มใหม่
wren memory index --no-seed                # index schema ไม่สร้าง auto browse

# profile (DB connection)
wren profile list / debug / switch <name>
```

---

*คู่มือนี้อ้างอิงสถานะจริงของ repo · ตัวเลขจาก seed (deterministic) · คำสั่งทดสอบกับ wren CLI ในโปรเจกต์นี้*
