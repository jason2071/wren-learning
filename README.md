# my-wren-project

โปรเจกต์เรียนรู้ **WrenAI** — semantic SQL layer ครอบ PostgreSQL
ให้คน/AI ถามข้อมูลด้วยภาษาคนหรือ SQL ชื่อง่าย แล้ว Wren แปลเป็น SQL จริงที่ตรงตาราง + กติกาธุรกิจ

มาพร้อม demo seed ที่จงใจฝัง **4 กับดัก** (ตารางตาย v1/v2, status เลขเปล่า, คอลัมน์ลับ, created_at vs paid_at)
เพื่อเทียบ raw SQL (ตกหลุม) กับ Wren (รอด)

---

## เอกสาร (อ่านตามลำดับนี้)

| ไฟล์ | เนื้อหา | อ่านเมื่อ |
|---|---|---|
| [`docs/wren_concept_guide.md`](docs/wren_concept_guide.md) | concept — Wren คืออะไร, memory ทำงานยังไง | รอบแรก ให้เห็นภาพ |
| [`docs/wren_demo_playbook.md`](docs/wren_demo_playbook.md) | เล่น 4 กับดักจริง + เลขจริงจาก seed | ตอนจะ demo |
| [`docs/wren_reference.md`](docs/wren_reference.md) | โครงไฟล์ + ตาราง CLI | ตอนลงมือ lookup |

---

## โครงสร้าง project

```text
my-wren-project/
├── wren_project.yml          # metadata + profile ที่ผูก
├── connection.yml            # datasource config (อ่านค่าจาก ${PG_*})
├── models/                   # นิยามตาราง — 1 โฟลเดอร์ต่อ 1 model
│   ├── customers_v2/         #   name: customers (alias) → table: customers_v2
│   └── orders/
├── relationships.yml         # join: orders → customers (many_to_one)
├── instructions.md           # กติกาธุรกิจ (active, revenue, status codes)
├── queries.yml               # คู่ NL↔SQL สำหรับ recall
├── demo_db/seed_wren_demo.sql# seed PostgreSQL + 4 กับดัก
├── docs/                     # เอกสาร 3 ไฟล์ (ตารางบน)
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

> dist ต่ำ = ใกล้ (0 = ตรงเป๊ะ). รายละเอียดเพิ่มใน [playbook](docs/wren_demo_playbook.md)

---

## หลังแก้ config ทุกครั้ง

```bash
wren context build                       # แก้ models/*.yml, relationships.yml
wren context build && wren memory index  # ถ้าแตะ instructions.md / queries.yml
```

---

## หมายเหตุ

- `.env`, `target/`, `.wren/` ถูก gitignore — credential ไม่หลุด, ไฟล์ generated สร้างใหม่ได้
- clone มาแล้วต้องทำ step 2–4 เองเพื่อ regenerate
- WrenAI รีโครงสร้างใหญ่ (พ.ค. 2026) — เวอร์ชันปัจจุบันเน้น context layer ผ่าน CLI + skills
  คำสั่ง/field อ้างอิงจาก `wren docs connection-info <ds>` เป็นหลัก
- อ้างอิงทางการ: [Canner/WrenAI](https://github.com/Canner/WrenAI) (GenBI Classic เก่าอยู่ branch `legacy/v1`)
