# WrenAI — โครงไฟล์ & ตัวอย่างการเล่น

เอกสารอ้างอิงสำหรับ knowledge sharing — ครอบคลุมโครงสร้าง project ของ WrenAI
และตัวอย่างใช้งานหลายแบบ (ผูกกับ demo seed PostgreSQL: `customers_v2` / `orders`)

---

## 1. โครงไฟล์ทั้งหมดของ Wren project

หลัง setup ครบ โฟลเดอร์ project จะหน้าตาแบบนี้:

```text
my-wren-project/
├── wren_project.yml        # metadata ของ project (catalog, schema, profile ที่ผูก)
├── models/                 # นิยามตาราง — 1 โฟลเดอร์ต่อ 1 ตาราง
│   ├── customers/
│   │   └── metadata.yml    # schema + description ของตาราง
│   └── orders/
│       └── metadata.yml
├── views/                  # SQL view ที่ใช้ซ้ำ (view ที่อธิบายดี = recall example ชั้นดี)
├── relationships.yml       # นิยาม join ระหว่างตาราง
├── instructions.md         # business rule ภาษาคน (นิยาม metric, naming, ข้อห้าม)
├── target/
│   └── mdl.json            # manifest ที่ compile แล้ว (เกิดตอน context build)
└── .wren/
    └── memory/             # LanceDB index (เกิดตอน memory index, auto-managed)
```

แยกออกจาก project (เก็บแบบ global):

```text
~/.wren/profiles.yml        # credential ต่อ DB — per-environment, ไม่ commit
```

### แต่ละชิ้นทำอะไร

| ชิ้น | หน้าที่ | ต้องแก้เอง |
|---|---|---|
| `wren_project.yml` | metadata + profile ที่ผูก. `catalog`/`schema` เป็น namespace ของ Wren เอง ไม่เกี่ยวกับ DB จริง | auto |
| `models/*/metadata.yml` | บอกว่า model นี้ map ไปตารางจริงไหน (`table_reference`) + column ไหนให้ agent เห็น | ✅ หลัก |
| `relationships.yml` | join path เช่น orders → customers (many_to_one). ผิด = query ผิดเงียบ | ✅ สำคัญ |
| `instructions.md` | นิยามธุรกิจ เช่น "active = paid ใน 90 วัน". agent อ่านอันนี้ | ✅ |
| `views/` | view สำเร็จรูปสำหรับคำถามที่ถามบ่อย | เสริม |
| `target/mdl.json` | manifest ที่ engine ใช้จริง — สร้างจาก `context build` | auto |
| `.wren/memory/` | vector index สำหรับ retrieve context + recall query เก่า | auto |
| `~/.wren/profiles.yml` | host/port/user/password — เก็บแยก เพื่อ share project ได้ปลอดภัย | ✅ ครั้งแรก |

---

## 2. ตัวอย่างไฟล์ (map กับ demo seed)

### `models/customers/metadata.yml`

```yaml
name: customers                # alias — ตารางจริงคือ customers_v2
table_reference:
  schema: public
  table: customers_v2          # ผูกตารางจริง (ไม่ใช่ v1 ที่ตายแล้ว)
primary_key: customer_id
columns:
  - { name: customer_id, type: INT, not_null: true }
  - { name: first_name, type: TEXT }
  - { name: last_name,  type: TEXT }
  - { name: email, type: TEXT }   # ยัง expose (playbook Trap 3 ให้ลบเพื่อ mask)
  - { name: phone, type: TEXT }   # ยัง expose
  - { name: created_at, type: TIMESTAMP }
  # national_id ไม่ประกาศ = agent มองไม่เห็น (masked แล้ว)
```

### `models/orders/metadata.yml`

```yaml
name: orders
table_reference:
  schema: public
  table: orders
primary_key: order_id
columns:
  - { name: order_id,    type: INTEGER, is_primary_key: true }
  - { name: customer_id, type: INTEGER }
  - { name: status,      type: INTEGER }
  - { name: total,       type: DECIMAL }
  - { name: created_at,  type: TIMESTAMP }
  - { name: paid_at,     type: TIMESTAMP }
```

### `relationships.yml`

```yaml
relationships:
  - name: order_customers
    models: [orders, customers]
    join_type: MANY_TO_ONE
    condition: orders.customer_id = customers.customer_id
```

### `instructions.md`

```markdown
## Definitions
- "active customer" = ลูกค้าที่มี order status = 2 (paid) ใน 90 วันล่าสุด
- ใช้ paid_at สำหรับการกรองเวลา ไม่ใช่ created_at
- "revenue" = SUM(orders.total) เฉพาะ status = 2

## Status codes
- 1 = pending, 2 = paid, 3 = shipped, 4 = refunded, 5 = cancelled

## Rules
- ใช้ตาราง customers (map ไป customers_v2) เท่านั้น ห้ามแตะ customers_v1
```

---

## 3. ตัวอย่างการเล่น — หลายแบบ

### แบบ A: ติดตั้ง + ต่อ DB (ครั้งเดียว)

```bash
python3 -m venv ~/.venvs/wren && source ~/.venvs/wren/bin/activate
pip install "wrenai[postgres,memory]"

wren profile add demo-pg --interactive     # หรือ --ui / --from-file
wren context init
rm -rf models/example_model views/example_view   # ลบ placeholder
wren context set-profile demo-pg
```

### แบบ B: ให้ Claude Code generate MDL อัตโนมัติ

```bash
cd ~/my-wren-project && claude
```
แล้วสั่ง:
```text
Use the /wren skill to explore the database and generate the MDL
for all tables. The data source is PostgreSQL.
```

### แบบ C: ถามเป็นภาษาคน (ผ่าน agent)

```text
ลูกค้า active มีกี่คน
สินค้าขายดี top 5 ตาม revenue
แนวโน้มยอด order รายเดือน
```
เบื้องหลัง: fetch context → recall ตัวอย่างเก่า → เขียน SQL กับชื่อ model → execute → store

### แบบ D: รัน SQL ตรง ๆ ผ่าน CLI

```bash
wren --sql "SELECT COUNT(DISTINCT customer_id) FROM orders WHERE status = 2" -o table
```

### แบบ E: ส่อง SQL ที่ถูก expand จริง (ก่อนรัน) — ดีสำหรับ debug

```bash
wren dry-plan --sql "SELECT first_name FROM customers LIMIT 5"
# เห็นว่า customers ถูก resolve เป็น public.customers_v2 + ตัด column ลับออก
```

### แบบ F: validate SQL กับ DB จริง โดยไม่คืน row

```bash
wren dry-run --sql "SELECT * FROM orders WHERE status = 2"
```

### แบบ G: เล่นกับ memory

```bash
wren memory status                          # ดูสถานะ index
wren memory fetch --query "active customers" # ดูว่า agent ดึง context อะไร
wren memory recall --query "top products"    # หา query เก่าที่คล้ายกัน
wren memory store --nl "active customers" \  # บันทึก NL-SQL ที่ถูกไว้ recall
  --sql "SELECT COUNT(DISTINCT customer_id) FROM orders WHERE status=2 AND paid_at >= now() - interval '90 days'"
```

### แบบ H: แก้ instructions/MDL แล้ว rebuild

```bash
# แก้ instructions.md หรือ models/*.yml เสร็จ
wren context validate     # เช็คโครงสร้าง/reference
wren context build        # compile -> target/mdl.json
wren memory index         # re-index ให้ memory รู้ของใหม่
```

### แบบ I: query ผ่าน cube (ถ้ามี cube ใน MDL)

```bash
wren cube list
wren cube query \
  --cube order_metrics \
  --measures revenue \
  --time-dimension "created_at:month"
# agent ไม่ต้องเขียน GROUP BY / DATE_TRUNC เอง -> error น้อยลง
```

### แบบ J: ดู field ที่ connector ต้องการ (source of truth)

```bash
wren docs connection-info postgres
wren docs connection-info mssql
```

### แบบ K: เปลี่ยน/ดู profile

```bash
wren profile list            # ดูทั้งหมด + ตัวที่ active
wren profile debug           # ดู config (secret ถูก mask)
wren profile switch other-db
```

---

## 4. ตาราง CLI ที่ใช้บ่อย

| งาน | คำสั่ง |
|---|---|
| รัน SQL | `wren --sql "SELECT ..." -o table` |
| ดู SQL ที่ expand | `wren dry-plan --sql "..."` |
| validate SQL | `wren dry-run --sql "..."` |
| ดู context ของ project | `wren context show` |
| build manifest | `wren context build` |
| fetch context | `wren memory fetch --query "..."` |
| recall query เก่า | `wren memory recall --query "..."` |
| store NL-SQL | `wren memory store --nl "..." --sql "..."` |
| re-index memory | `wren memory index` |

---

## 5. flow สรุป

```text
profile add        ->  ต่อ DB (credential)
context init       ->  scaffold โครง project
(ลบ example)
generate MDL       ->  เขียน models/ + relationships.yml (ให้ agent ทำได้)
แก้ instructions.md ->  ใส่นิยามธุรกิจ
context build      ->  ได้ target/mdl.json
memory index       ->  ได้ .wren/memory/
ถามได้             ->  agent เขียน SQL ผ่าน semantic layer
```

> หมายเหตุ: WrenAI รีโครงสร้างใหญ่ (พ.ค. 2026) — แอป GenBI เก่าถูก sunset
> (อยู่ branch `legacy/v1`) เวอร์ชันปัจจุบันเน้น context layer ผ่าน CLI + skills
> คำสั่ง/field อ้างอิงจาก `wren docs connection-info <ds>` เป็นหลัก เพราะตรงกับเวอร์ชันที่ติดตั้ง
