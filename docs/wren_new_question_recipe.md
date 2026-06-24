# Recipe: มีคำถามใหม่ ต้องทำยังไง

checklist ใช้ซ้ำได้ทุกคำถามใหม่ — พิมพ์อะไร, แอดไฟล์ไหน, รันยังไง
ตัวอย่างจริงในไฟล์นี้: **"order ล่าสุด ใครเป็นคนสั่ง"**

---

## TL;DR — 6 ขั้น

```
1. แปลคำถาม → ใช้ field/ตารางอะไร
2. เช็ค model มี field พอไหม          (ขาด → แอด column ใน models/*/metadata.yml)
3. recall ก่อน                        wren memory recall -q "..."
4. เขียน SQL + รันจริง                wren --sql "..." -o table
5. เก็บลง queries.yml (append)         แล้ว memory load queries.yml
6. recall ซ้ำ ยืนยันจำได้
```

> ส่วนใหญ่ **ไม่ต้องแตะ code/model** — แค่เพิ่มคู่ NL↔SQL ลง `queries.yml` (config ไม่ใช่ code)

---

## ทางลัด — ไม่ต้องรันทุกคำสั่ง

6 ขั้นข้างบนคือ "ครบเครื่อง". จริงๆ **ลัดได้** เลือกตามความมั่นใจ:

### ระดับ 1 — แค่อยากได้คำตอบ (เร็วสุด, 1 คำสั่ง)
field มั่นใจว่าครบ → ยิง SQL เลย จบ ไม่ต้อง build/index/store/recall
```bash
wren --sql "SELECT ... " -o table
```

### ระดับ 2 — อยากเก็บไว้ใช้ซ้ำ (+1 คำสั่ง)
```bash
wren --sql "SELECT ..." -o table          # ได้คำตอบ
wren memory store --nl "คำถาม" --sql "..."  # จดไว้ — store เข้า memory ตรง ไม่ต้อง build/index
```

### ระดับ 3 — ไม่ชัวร์ field / อยาก git track (ครบ)
```bash
wren memory recall -q "คำถาม"             # 1 เผื่อมีของเดิม (ข้ามได้ถ้ามั่นใจไม่มี)
wren dry-plan --sql "SELECT ..."          # 2 ดู expand เช็ค field ถูก (ข้ามได้ถ้าชัวร์)
wren --sql "SELECT ..." -o table          # 3 รันจริง
echo '  - nl: ...' >> queries.yml          # 4 append (git track)
wren memory load queries.yml              # 5 เข้า store (แตะแค่ queries.yml ไม่ต้อง build)
```

### ลำดับบังคับ (ห้ามสลับ — มี dependency)
- แตะ **model/relationship/instructions** → `context build` ก่อน (build เขียน `target/mdl.json`)
- เพิ่ม column/relationship → `context build` **ต้องก่อน** รัน SQL ที่ใช้ field ใหม่
- แตะ **`queries.yml`** → `wren memory load queries.yml` (ไม่ต้อง build) — ⚠️ ดู gotcha ล่าง
- `store` ไม่ขึ้นกับ build/load — เข้า memory ทันที

### เช็คทุกอันไหม? — ไม่
- `recall` / `dry-plan` / `describe` = เครื่องมือ **debug** ใช้ตอน "ไม่ชัวร์" เท่านั้น ปกติข้าม
- กลุ่ม A (field ครบ) → ระดับ 1–2 พอ. แตะ model/instructions เมื่อไหร่ค่อยขึ้นระดับ 3 + build

> rule of thumb: **ตอบเฉยๆ = 1 คำสั่ง · เก็บถาวร = +store หรือ +queries.yml → memory load**

---

## ⚠️ Gotcha — queries.yml เข้า store ด้วย `load` ไม่ใช่ `index`

ตรงนี้พลาดกันบ่อย. ในเวอร์ชันนี้:

| คำสั่ง | ทำอะไร | ผล |
|---|---|---|
| `wren memory index` | index schema + **generate auto browse queries** (List all X, Total X...) | ใส่คู่ auto ลง store. **ไม่ดึง queries.yml curate เข้า recall** |
| `wren memory load queries.yml` | **import คู่จาก queries.yml → store** | ← นี่คือตัวที่ทำให้ recall เจอคู่ที่คุณเขียน |
| `wren memory dump` | **export store → เขียนทับ queries.yml** | ทิศตรงข้าม — ⚠️ ทับไฟล์ curate ของคุณ อย่ารันมั่ว |

**อาการถ้าใช้ผิด:** `index` แล้ว recall ได้แต่ `"List all products"` (auto) ไม่เจอ `"สินค้าขายดี"` ที่เขียนเอง → เพราะคู่ curate ยังไม่ถูก `load`.

**ตรวจว่าคู่เข้าจริง:**
```bash
wren memory load queries.yml --dry-run    # validate + นับ ไม่เขียน
wren memory load queries.yml              # โหลดจริง (default skip ตัวซ้ำ)
wren memory load queries.yml --upsert     # แก้ SQL ของ nl เดิม → ทับ
wren memory recall -q "คำถาม"             # ต้องเจอคู่ของเรา dist ต่ำ
```

**เริ่มสะอาด** (ตัด auto browse + คู่เก่าทิ้ง):
```bash
wren memory reset
wren memory index --no-seed               # schema อย่างเดียว ไม่มี auto browse
wren memory load queries.yml              # ใส่ curated
```
> `index --no-seed` = ข้ามการ generate auto browse · `index --no-queries` = ข้าม auto-load queries.yml

---

## เตรียม shell (ทุกครั้งก่อนรัน)

```bash
cd ~/Desktop/work/my-wren-project
source ~/.venvs/wren/bin/activate
export $(grep -v '^#' .env | xargs)
```

---

## ขั้น 1 — แปลคำถาม → ต้องใช้อะไร

"order ล่าสุด ใครเป็นคนสั่ง" แตกเป็น:
- **order ล่าสุด** → ตาราง `orders` เรียงตาม `created_at DESC` เอา 1 แถว
- **ใครสั่ง** → ชื่อคน อยู่ตาราง `customers` → ต้อง **join** `orders.customer_id = customers.customer_id`

ต้องมี: `orders.created_at`, `orders.customer_id`, `customers.first_name/last_name`, relationship orders↔customers

---

## ขั้น 2 — เช็ค model มี field พอไหม

ดูว่า column ที่ต้องใช้ประกาศใน model แล้วหรือยัง:

```bash
# ดู column ที่ orders/customers เปิดให้เห็น
wren memory describe 2>/dev/null | grep -A12 -iE 'orders|customers'
# หรือดูไฟล์ตรงๆ
cat models/orders/metadata.yml models/customers_v2/metadata.yml
```

ผลในโปรเจกต์นี้: **ครบหมดแล้ว** ✅
- `orders`: created_at ✓ customer_id ✓
- `customers`: first_name ✓ last_name ✓
- `relationships.yml`: `order_customers` (orders→customers) ✓

→ **ไม่ต้องแอดอะไรใน model**

> **ถ้าขาด** column (เช่นอยากได้ field ที่ยังไม่ประกาศ) → เพิ่มใน `models/<table>/metadata.yml` ใต้ `columns:` แล้ว `wren context build`
> ```yaml
> columns:
>   - name: shipped_at      # ตัวอย่างเพิ่ม column ใหม่
>     type: TIMESTAMP
> ```
> **ถ้าขาด relationship** (อยาก join ตารางที่ยังไม่ผูก) → เพิ่ม block ใน `relationships.yml` แล้ว build

---

## ขั้น 3 — recall ก่อน (เผื่อเคยถาม)

```bash
wren memory recall -q "order ล่าสุด ใครสั่ง" -l 3
```

ผลจริง — ไม่มีของตรง (dist สูง):
```text
dist 0.697  orders with customers details
dist 0.751  List all orders
```
dist 0.7+ = ยังห่าง → **ต้องเขียนเอง**

---

## ขั้น 4 — เขียน SQL + รันจริง

```bash
wren --sql "SELECT o.order_id, o.created_at, c.first_name, c.last_name
FROM orders o JOIN customers c ON o.customer_id = c.customer_id
ORDER BY o.created_at DESC LIMIT 1" -o table
```

ผลจริง:
```text
 order_id          created_at  first_name last_name
      365  2026-06-18 09:49:30        Krit    Srisuk
```

> อยากเช็ค SQL ที่ Wren expand (customers → customers_v2) ก่อนยิง DB: `wren dry-plan --sql "..."`

---

## ขั้น 5 — เก็บลง memory (ครั้งหน้า recall เจอ)

**ทาง A — append `queries.yml`** (แนะนำ: git track ได้)
```bash
# ⚠️ ใช้ >> (append) ไม่ใช่ > (overwrite). indent 2 space ใต้ pairs:
cat >> queries.yml <<'EOF'
  - nl: "order ล่าสุด ใครเป็นคนสั่ง"
    sql: "SELECT o.order_id, o.created_at, c.first_name, c.last_name FROM orders o JOIN customers c ON o.customer_id = c.customer_id ORDER BY o.created_at DESC LIMIT 1"
EOF

wren memory load queries.yml   # ← โหลดคู่ใหม่เข้า store (ดู Gotcha ด้านบน)
# แก้ SQL ของ nl เดิม: wren memory load queries.yml --upsert
```

**ทาง B — store ทีเดียว** (ไม่ผ่านไฟล์, ไม่ git track)
```bash
wren memory store \
  --nl "order ล่าสุด ใครเป็นคนสั่ง" \
  --sql "SELECT o.order_id, o.created_at, c.first_name, c.last_name FROM orders o JOIN customers c ON o.customer_id = c.customer_id ORDER BY o.created_at DESC LIMIT 1"
```

---

## ขั้น 6 — recall ซ้ำ ยืนยัน

```bash
wren memory recall -q "order ล่าสุด ใครสั่ง" -l 3
# คราวนี้คู่ที่เพิ่งเก็บขึ้นบนสุด dist ต่ำมาก ✅
```

---

## เคสเพิ่มเติม — แบบไหน "ข้าม" แบบไหน "ต้องเพิ่ม"

หลักตัดสิน 1 ประโยค: **คำถามต้องใช้ field/join/นิยาม ที่ layer ยังไม่มีไหม?**
- มีครบ → **ข้าม** (เขียน SQL ได้เลย, อย่างมากแค่ append `queries.yml`)
- ขาด → **เพิ่ม** ที่ชั้นที่ขาด ก่อนถาม

```
คำถามใหม่
   │
   ├─ field + join ครบใน model?  ──ใช่──▶  เขียน SQL ได้เลย  (ข้าม)
   │            │ไม่
   │            ├─ ขาด column      ──▶  เพิ่ม models/<t>/metadata.yml  + build
   │            ├─ ขาด join        ──▶  เพิ่ม relationships.yml        + build
   │            └─ column ลับ(mask) ──▶  ปกติ "ห้ามเปิด" — ตอบไม่ได้โดยตั้งใจ
   │
   └─ มีศัพท์ที่ต้องนิยาม? (VIP/churn) ──▶  เพิ่ม instructions.md      + build + index
```

### กลุ่ม A — ข้ามได้ (field+join ครบ, แค่เขียน SQL → option append queries.yml)

| คำถาม | SQL ย่อ | ผลจริง |
|---|---|---|
| ลูกค้าซื้อเยอะสุด | `orders JOIN customers, SUM(total) WHERE status=2 GROUP BY name ORDER BY DESC LIMIT 1` | **Suda Charoen 12,360** |
| ลูกค้าที่ไม่เคยสั่งเลย | `customers LEFT JOIN orders ... WHERE o.order_id IS NULL` | **0 คน** |
| order ยังไม่จ่ายมีกี่ใบ | `COUNT(*) FROM orders WHERE status=1` | **240 ใบ** |
| สมัครวันนี้กี่คน | `COUNT(*) FROM customers WHERE created_at::date=current_date` | (ดู queries.yml) |

ทั้งหมดใช้ field ที่ประกาศแล้ว + relationship เดิม → **ไม่แตะ model**

### กลุ่ม B — ต้องเพิ่ม **column** (DB มี แต่ model ไม่ประกาศ)

ตัวอย่าง: "ขอ national_id ลูกค้า" — `customers_v2` ใน DB **มี** `national_id` แต่ model ไม่ประกาศ → masked → query ไม่ได้

```bash
wren dry-plan --sql "SELECT national_id FROM customers LIMIT 1"
# error: column ไม่รู้จัก = ถูก mask อยู่
```

ถ้า**จำเป็นจริง**ถึงเพิ่มใน `models/customers_v2/metadata.yml`:
```yaml
columns:
  - name: national_id      # ⚠️ ข้อมูลลับ — เปิดเฉพาะกรณีมีสิทธิ์จริง
    type: TEXT
```
แล้ว `wren context build`. **โดย default ไม่ควรเปิด** — masking ออกแบบมากันรั่ว ([playbook](wren_demo_playbook.md) Trap 3)

### กลุ่ม C — ต้องเพิ่ม **relationship** (ตารางใหม่ที่ยังไม่ผูก)

ตัวอย่าง: เพิ่มตาราง `order_items` แล้วถาม "สินค้าชิ้นไหนขายดี" → ต้อง:
1. สร้าง `models/order_items/metadata.yml` (ประกาศ table + columns)
2. เพิ่ม block ใน `relationships.yml`:
```yaml
  - name: order_items_to_orders
    models: [order_items, orders]
    join_type: MANY_TO_ONE
    condition: order_items.order_id = orders.order_id
```
3. `wren context build` → ถาม join ข้ามได้

> โปรเจกต์นี้มีแค่ `customers` + `orders` → เคสนี้เป็นตัวอย่างสมมติ

### กลุ่ม D — ต้องเพิ่ม **นิยาม** ใน instructions.md (ศัพท์ธุรกิจใหม่)

field ครบ แต่ "ศัพท์" ยังไม่มีความหมาย → AI เดาไม่ได้ ต้องนิยามก่อน

| คำถาม | ปัญหา | เพิ่มใน instructions.md |
|---|---|---|
| ลูกค้า **VIP** มีกี่คน | "VIP" คืออะไร? | `"VIP" = ลูกค้าที่ซื้อรวม > 10,000 (status 2)` |
| ลูกค้า **churn** | "churn" คือ? | `"churn" = ไม่มี order paid ใน 180 วัน` |

```bash
# แก้ instructions.md เพิ่มนิยาม แล้ว:
wren context build && wren memory index
wren memory fetch -q "VIP customer"   # เช็คว่า context ดึงนิยามมา
```

---

## สรุป: แตะไฟล์ไหนบ้าง?

| สถานการณ์ | แอดไฟล์ไหน | คำสั่ง |
|---|---|---|
| field ครบแล้ว (เคสนี้) | `queries.yml` เท่านั้น | `memory load queries.yml` (ไม่ต้อง build) |
| ขาด column | `models/<t>/metadata.yml` | + `context build` |
| ขาด join | `relationships.yml` | + `context build` |
| ต้องนิยามศัพท์ใหม่ | `instructions.md` | + `context build` + `memory index` |

**กฎจำง่าย:** แตะ `models/`/`relationships.yml` → `context build` · แตะ `instructions.md` → `context build` + `memory index` · แตะ `queries.yml` → `memory load queries.yml`
