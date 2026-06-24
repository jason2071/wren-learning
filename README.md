# my-wren-project

โปรเจกต์เรียนรู้ **WrenAI** — semantic SQL layer ครอบ PostgreSQL
ให้คน/AI ถามข้อมูลด้วยภาษาคนหรือ SQL ชื่อง่าย แล้ว Wren แปลเป็น SQL จริงที่ตรงตาราง + กติกาธุรกิจ

มาพร้อม demo seed ที่จงใจฝัง **5 กับดัก** (ตารางตาย v1/v2, status เลขเปล่า, คอลัมน์ลับ, created_at vs paid_at, list price vs ราคาตอนขายจริง)
เพื่อเทียบ raw SQL (ตกหลุม) กับ Wren (รอด)

📖 **เว็บคู่มือ (เปิดได้เลย):** https://jason2071.github.io/wren-learning/ — landing เลือก Interactive / คู่มือเต็ม

---

## เอกสาร (อ่านตามลำดับนี้)

| ไฟล์ | เนื้อหา | อ่านเมื่อ |
|---|---|---|
| [🌐 เว็บ landing](https://jason2071.github.io/wren-learning/) · [`docs/index.html`](docs/index.html) | **หน้าหลัก** — เลือก Interactive / คู่มือเต็ม | จุดเริ่ม |
| [`docs/html/interactive.html`](docs/html/interactive.html) | **Interactive (concept)** — Wren คืออะไร, 5 กับดัก, สถาปัตยกรรม, memory · flip cards, before/after toggle | อยากเข้าใจภาพ / สอนหน้าเวที |
| [`docs/html/manual.html`](docs/html/manual.html) · [`wren_manual.md`](docs/wren_manual.md) | **คู่มือ (how-to)** — ติดตั้ง→query→เพิ่มตาราง→memory→troubleshoot + cheat-sheet คำสั่งจริง | ลงมือทำ / อ้างอิงคำสั่ง |
| [`docs/wren_concept.md`](docs/wren_concept.md) | concept — Wren คืออะไร, memory ทำงานยังไง | รอบแรก ให้เห็นภาพ |
| [`docs/wren_playbook.md`](docs/wren_playbook.md) | เล่นกับดักจริง + เลขจริงจาก seed | ตอนจะ demo |
| [`docs/wren_recipe.md`](docs/wren_recipe.md) | recipe คำถามใหม่ — เพิ่มไฟล์ไหน รันอะไร ทางลัด | เจอคำถามใหม่ |
| [`docs/wren_reference.md`](docs/wren_reference.md) | โครงไฟล์ + ตาราง CLI | ตอนลงมือ lookup |

---

## โครงสร้าง project

```text
my-wren-project/
├── wren_project.yml          # metadata + profile ที่ผูก
├── connection.yml            # datasource config (อ่านค่าจาก ${PG_*})
├── models/                   # นิยามตาราง — 1 โฟลเดอร์ต่อ 1 model
│   ├── customers_v2/         #   name: customers (alias) → table: customers_v2
│   ├── orders/
│   ├── products/             #   name: products → table: products
│   └── order_items/          #   name: order_items → table: order_items
├── relationships.yml         # joins: order→customers, item→orders, item→products
├── instructions.md           # กติกาธุรกิจ (active, revenue, status codes)
├── queries.yml               # คู่ NL↔SQL สำหรับ recall
├── demo_db/seed_wren_demo.sql# seed PostgreSQL + 5 กับดัก
├── docs/                     # เอกสาร (ดูตารางบน)
├── target/                   # mdl.json (generated — gitignored)
└── .wren/                    # memory index (generated — gitignored)
```

---

## เริ่มใช้งาน

### 1. ติดตั้ง + venv
```bash
python3 -m venv ~/.venvs/wren && source ~/.venvs/wren/bin/activate
pip install "wrenai[postgres,memory]"
```

### 2. ตั้ง env (DB credential)
```bash
cp .env.example .env          # แล้วแก้ค่าจริงใน .env
export $(grep -v '^#' .env | xargs)
```

### 3. seed demo database (ครั้งแรก)
```bash
psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DATABASE" -f demo_db/seed_wren_demo.sql
```

### 4. build context + index memory
```bash
wren context build            # compile → target/mdl.json
wren memory index             # index → .wren/memory/
```

### 5. ถามได้แล้ว
```bash
# รัน SQL ตรง ๆ (ชื่อ model)
wren --sql "SELECT COUNT(*) FROM customers" -o table

# ดู SQL ที่ Wren expand จริง (customers → public.customers_v2)
wren dry-plan --sql "SELECT first_name FROM customers LIMIT 5"

# memory: หา query เก่าที่คล้าย
wren memory recall --query "ลูกค้ามีกี่คน"
```

### recall สวยๆ (อ่านง่าย)

table default รก — ใช้ `-o json | jq` เหลือ dist + nl + sql:

```bash
wren memory recall -q "ลูกค้ามีกี่คน" -l 3 -o json \
  | jq -r '.[] | "dist \((._distance*1000|round)/1000)  \(.nl_query)\n    \(.sql_query)\n"'
```

ทำเป็น function ใน `~/.zshrc` แล้วเรียก `wmr "คำถาม"`:

```bash
wmr() {
  wren memory recall -q "$1" -l "${2:-3}" -o json \
    | jq -r '.[] | "dist \((._distance*1000|round)/1000)  \(.nl_query)\n    \(.sql_query)\n"'
}
# wmr "สมัครวันนี้กี่คน"   ·   wmr "revenue" 5   (เอา 5 ผล)
```

> dist ต่ำ = ใกล้ (0 = ตรงเป๊ะ). รายละเอียดเพิ่มใน [playbook](docs/wren_playbook.md)

---

## หลังแก้ config ทุกครั้ง

```bash
wren context build                       # แก้ models/*.yml, relationships.yml → rebuild mdl.json
wren context build && wren memory index  # ถ้าแตะ instructions.md (re-index schema + instructions)
wren memory load queries.yml             # ถ้าแตะ queries.yml ← ใช้ load ไม่ใช่ index! (ดู note)
```

> ⚠️ **queries.yml เข้า store ด้วย `memory load` ไม่ใช่ `memory index`.**
> `index` สร้างแค่ auto browse queries — ไม่ดึงคู่ curate เข้า recall. `load` ต่างหากที่ import queries.yml → store.
> (`dump` = ทิศกลับ: export store → เขียนทับ queries.yml — อย่ารันมั่ว). รายละเอียด: [recipe › Gotcha](docs/wren_recipe.md)

---

## ตาราง & กับดัก (อ้างอิง)

### ตารางใน demo (หลัง seed)

| ตารางจริง | model name | แถว | หมายเหตุ |
|---|---|---|---|
| `customers_v1` | — (ไม่ map) | 350 | ตารางตาย เหยื่อล่อ |
| `customers_v2` | `customers` | 200 | ตัวจริง — `email/phone/national_id` เป็นคอลัมน์ลับ |
| `orders` | `orders` | 1200 | `status` เลข 1-5, มี `created_at` กับ `paid_at` |
| `products` | `products` | 40 | `category_code` เลข 1-5, `price` = list ปัจจุบัน, `is_active` (discontinued) |
| `order_items` | `order_items` | 3000 | line item, `unit_price` = ราคาตอนขายจริง |

### 5 กับดัก

1. **ตารางตาย** — `customers_v1` (350 แถว ปน) vs `customers_v2` (200 ตัวจริง) → ถ้าหยิบ v1 นับเกิน
2. **status เลขเปล่า** — `1=pending 2=paid 3=shipped 4=refunded 5=cancelled` → revenue ต้องกรอง `status=2`
3. **คอลัมน์ลับ** — `email/phone/national_id` ไม่อยู่ใน model `customers` → masked by omission
4. **created_at vs paid_at** — "active/revenue" ใช้ `paid_at` ไม่ใช่ `created_at` (วันสมัคร)
5. **list price vs ราคาขายจริง** — `products.price` คือ list ปัจจุบัน (สูงกว่า ~15%) → revenue รายสินค้าต้องใช้ `order_items.unit_price * quantity` + join `orders` กรอง `status=2`

> พิสูจน์ trap #5: query ท้าย `seed_wren_demo.sql` ให้ WRONG=2,328,750 vs CORRECT=570,000

### relationships (`relationships.yml`)

```
order_items → orders → customers     (item→order→customer)
order_items → products               (item→product)
```
ทั้งหมด `MANY_TO_ONE`. ไม่มี `orders → products` ตรงๆ — ต้องผ่าน `order_items`.

### Wren MDL — type ที่รองรับ

canonical types ([docs](https://docs.getwren.ai/oss/reference/mdl)):
`VARCHAR · INTEGER · DOUBLE · DATE · TIMESTAMP · BOOLEAN · DECIMAL · JSON`

- `INT`/`TEXT` ใช้ได้ (Wren รับเป็น alias — โปรเจกต์นี้ก็ใช้)
- เงินใช้ `DECIMAL` (ไม่ใส่ precision เช่น `DECIMAL(10,2)`)
- bool ใช้ `BOOLEAN` (ไม่ใช่ `BOOL`)
- หลังแก้ model → `wren context build` จะ validate type ให้เอง

> เอกสารทางการ: https://docs.getwren.ai/oss/introduction

---

## หมายเหตุ

- `.env`, `target/`, `.wren/` ถูก gitignore — credential ไม่หลุด, ไฟล์ generated สร้างใหม่ได้
- clone มาแล้วต้องทำ step 2–4 เองเพื่อ regenerate
- WrenAI รีโครงสร้างใหญ่ (พ.ค. 2026) — เวอร์ชันปัจจุบันเน้น context layer ผ่าน CLI + skills
  คำสั่ง/field อ้างอิงจาก `wren docs connection-info <ds>` เป็นหลัก
- อ้างอิงทางการ: [Canner/WrenAI](https://github.com/Canner/WrenAI) (GenBI Classic เก่าอยู่ branch `legacy/v1`)
