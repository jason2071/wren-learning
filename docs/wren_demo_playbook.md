# WrenAI — Demo Playbook (เล่นจริง เห็นความต่าง)

คู่มือลงมือ: ปลด "กับดัก" ใน demo seed ทีละอัน แล้วเทียบ raw SQL (ตกหลุม) vs Wren (รอด)

> seed: `demo_db/seed_wren_demo.sql` — มี **4 กับดัก** ในตัวเดียว (350 `customers_v1` / 200 `customers_v2` / 1200 `orders`)
> **ไม่ต้อง seed หลายแบบ** ความต่างอยู่ที่ config layer ปลดกับดัก ไม่ใช่ data

---

## กับดักทั้ง 4

| # | กับดัก | raw SQL พลาดยังไง | Wren แก้ด้วย |
|---|---|---|---|
| 1 | `customers_v1` (ตาย) ปนกับ `v2` | LLM count/join ตาราง v1 ผิด | alias model + ลบ v1 |
| 2 | `status` เป็นเลขเปล่า | ไม่รู้ 2=paid | `instructions.md` |
| 3 | คอลัมน์ลับ `email/phone/national_id` | SELECT เห็นหมด | masking (ตัด column จาก model) |
| 4 | `created_at` vs `paid_at` | กรองเวลาผิดตัว | `instructions.md` |

จุดสำคัญ: ตอน config ยังไม่ตั้ง Wren = passthrough → ตกหลุมเหมือน raw SQL ทุกประการ

---

## เคสเทียบ — เห็นความต่างชัด ๆ (เลขจริงจาก seed)

ถามคำถามเดียวกัน 4 ข้อ → คน/LLM ที่เขียน SQL ตรง ๆ ได้เลข **ผิด** ส่วน Wren ที่มี layer ได้เลข **ถูก**

### เคส 1 — "ลูกค้ามีกี่คน" (Trap 1: v1/v2)

| | SQL | ผล |
|---|---|---|
| ❌ raw (เจอ v1 ก่อน) | `SELECT COUNT(*) FROM customers_v1` | **350** (ตารางตาย) |
| ✅ Wren | `SELECT COUNT(*) FROM customers` → resolve `customers_v2` | **200** |

ต่าง 150 คน — LLM ไม่รู้ว่า v1 ตายแล้ว เลือกผิดเงียบ ๆ

### เคส 2 — "revenue รวมเท่าไร" (Trap 2: status เลขเปล่า)

| | SQL | ผล |
|---|---|---|
| ❌ raw (ไม่กรอง status) | `SELECT SUM(total) FROM orders` | **502,200** (รวม pending/refunded/cancelled) |
| ✅ Wren (instructions: revenue = status 2) | `SELECT SUM(total) FROM orders WHERE status=2` | **143,640** |

raw เป่ายอด **3.5 เท่า** เพราะไม่รู้ว่า 2=paid

### เคส 3 — "ลูกค้า active 90 วันมีกี่คน" (Trap 4: created_at vs paid_at)

| | SQL | ผล |
|---|---|---|
| ❌ raw (ใช้ created_at, ไม่กรอง paid) | `... WHERE created_at >= now()-interval '90 days'` | **195** |
| ✅ Wren (instructions: paid_at + status 2) | `... WHERE status=2 AND paid_at >= now()-interval '90 days'` | **57** |

ต่าง **3.4 เท่า** — เลือก timestamp ผิด + ลืมกรอง paid

### เคส 4 — "ขอ national_id ลูกค้า" (Trap 3: คอลัมน์ลับ)

| | คำสั่ง | ผล |
|---|---|---|
| ❌ raw | `SELECT national_id FROM customers_v2` | คืนเลขบัตรจริง — **ข้อมูลรั่ว** |
| ✅ Wren (mask) | `wren dry-plan ... national_id ...` | **error: column ไม่รู้จัก** |

agent มองไม่เห็น column ที่ไม่ประกาศใน model = กันรั่วตั้งแต่ต้นทาง

> ตัวเลขพวกนี้มาจาก seed ปัจจุบัน (350/200/1200 rows) รันเองยืนยันได้ด้วย `wren --sql "..." -o table`

---

## เตรียม shell (ทุกครั้งก่อนรัน wren)

```bash
cd ~/Desktop/work/my-wren-project
source ~/.venvs/wren/bin/activate
export $(grep -v '^#' .env | xargs)
```

---

## Trap 3 — Masking (เริ่มอันนี้, เห็นชัดสุด)

**ก่อนแก้ — พิสูจน์ว่ายังทะลุ:**
```bash
wren dry-plan --sql "SELECT first_name, national_id FROM customers_v2 LIMIT 3"
# SQL ที่ expand มี national_id โผล่ออกมา = ยังไม่ mask
```

**แก้** `models/customers_v2/metadata.yml` → ลบ 3 block column ลับ ออกจาก `columns:`
```yaml
  - name: email          # ❌ ลบ
    type: TEXT
  - name: phone          # ❌ ลบ
    type: TEXT
  - name: national_id    # ❌ ลบ
    type: TEXT
```
เหลือ `customer_id, first_name, last_name, created_at`

**build + verify:**
```bash
wren context build
wren dry-plan --sql "SELECT first_name, national_id FROM customers_v2 LIMIT 3"
# หลัง: error column ไม่รู้จัก = masked ✅
```

---

## Trap 2 + 4 — Business semantics

**แก้** `instructions.md` (repo นี้ใส่ไว้ให้แล้ว — ดูว่ามีครบ) → ควรมี:
```markdown
## Definitions
- "active customer" = ลูกค้าที่มี order status = 2 (paid) ใน 90 วันล่าสุด
- ใช้ paid_at สำหรับกรองเวลา ไม่ใช่ created_at
- "revenue" = SUM(orders.total) เฉพาะ status = 2

## Status codes
1=pending, 2=paid, 3=shipped, 4=refunded, 5=cancelled
```

**build + index** (instructions เข้า memory):
```bash
wren context build && wren memory index
wren memory fetch --query "active customer revenue"
# เห็น context ดึงนิยาม status/paid_at มา → ถามภาษาคน agent เขียน status=2 AND paid_at>=... ถูกเอง
# (raw SQL ต้องเดาเลขเอง)
```

---

## Trap 1 — v1/v2 versioning

**ลบ model ตาย:**
```bash
rm -rf models/customers_v1
```

**(option) alias** `customers`→v2:
- `models/customers_v2/metadata.yml`: บรรทัดแรก `name: customers_v2` → `name: customers` (คง `table_reference.table: customers_v2` ไว้)
- `relationships.yml`: เปลี่ยน `customers_v2` → `customers` ทั้งใน `models:` และ `condition:`

**build + verify:**
```bash
wren context build
wren dry-plan --sql "SELECT first_name FROM customers LIMIT 5"
# customers resolve เป็น public.customers_v2; customers_v1 query ไม่ได้แล้ว = dead table ถูกซ่อน
```

---

## NL Setup — เล่นแบบถามภาษาคน (ผ่าน agent)

ให้ agent เขียน SQL เองโดยใช้ layer + memory — เห็นค่าจริงของ Wren (เคส 2/4 ชัดสุด)

**1. เข้า venv + env (ครั้งเดียวต่อ session)**
```bash
cd ~/Desktop/work/my-wren-project
source ~/.venvs/wren/bin/activate
export $(grep -v '^#' .env | xargs)
```

**2. ใส่ curated NL-SQL pairs ลง `queries.yml`** (ช่วย recall ให้แม่น)
```bash
cat > queries.yml <<'EOF'
version: 1
pairs:
  - nl: "ลูกค้ามีกี่คน"
    sql: "SELECT COUNT(*) FROM customers"
  - nl: "revenue รวมเท่าไร"
    sql: "SELECT SUM(total) FROM orders WHERE status = 2"
  - nl: "ลูกค้า active 90 วันมีกี่คน"
    sql: "SELECT COUNT(DISTINCT customer_id) FROM orders WHERE status = 2 AND paid_at >= now() - interval '90 days'"
  - nl: "ยอดขายรายเดือน"
    sql: "SELECT date_trunc('month', paid_at) AS month, SUM(total) AS revenue FROM orders WHERE status = 2 GROUP BY 1 ORDER BY 1"
EOF
```

**3. build + index** (instructions.md + queries.yml เข้า memory)
```bash
wren context build
wren memory index
```

**4. verify ว่า agent ดึง context ถูก**
```bash
wren memory status
wren memory fetch  --query "active customer revenue"
wren memory recall --query "ลูกค้ามีกี่คน"
```

**5. ถาม NL จริง** — 2 ทาง:
```bash
# ทาง A: claude cli ใน project (ใช้ /wren skill) แล้วพิมพ์ภาษาคน เช่น "ลูกค้ามีกี่คน"
claude

# ทาง B: recall เอา SQL มาดูแล้วรันเอง
wren memory recall --query "revenue รวมเท่าไร"
wren --sql "SELECT SUM(total) FROM orders WHERE status = 2" -o table
```

> หมายเหตุ: `memory dump` ใช้ไม่ได้ (ขาด module `lance`) แต่ index/fetch/recall ปกติ ไม่กระทบ NL

---

## เกร็ด

- `wren_project.yml` ชี้ `profile: example`, active = `my-wren-project` — ทั้งคู่ postgres 5433/example เหมือนกัน ใช้ได้ อยากตรงก็ `wren context set-profile my-wren-project`
- แก้ yml/md ทุกครั้ง → `wren context build` (+ `wren memory index` ถ้าแตะ `instructions.md` / `queries.yml`)
- เทียบ before/after ใช้ `wren dry-plan` (ดู SQL expand) ดีสุด — ไม่แตะ DB
- รัน SQL จริง: `wren --sql "..." -o table` · validate ไม่คืน row: `wren dry-run --sql "..."`

## ลำดับเล่นแนะนำ

1. Trap 3 (masking) — เห็นชัดสุด เริ่มที่นี่
2. Trap 2+4 (instructions) — ถามภาษาคนแล้วดู SQL ที่ agent เขียน
3. Trap 1 (versioning) — alias + ลบ v1
