# WrenAI — คู่มือทำความเข้าใจ (Concept Guide)

> 📘 **ไฟล์นี้ = concept / ทำความเข้าใจ** (WHY + mental model เท่านั้น ไม่ใช่ hands-on)
> · อยากได้ครบ + ลงมือทำจริง (คำสั่งเต็ม, โครงไฟล์) → **`wren_manual.md`** (ไฟล์ master)
> · อยากดู demo เล่น trap จริงในไฟล์ seed → **`wren_playbook.md`**

คู่มืออ่านเพื่อ "เข้าใจภาพรวม" ของ Wren — ทำไมต้องมี, แก้ปัญหาอะไร, แต่ละชิ้นทำงานยังไง
ในเอกสารนี้ถ้าอ้างคำสั่งจะอ้างสั้น ๆ แล้วชี้ไป `wren_manual.md` สำหรับรายละเอียดเต็ม

---

## 1. Wren คืออะไร (ประโยคเดียว)

> **Wren = ชั้นกลาง (semantic layer) ที่อยู่ระหว่าง "คนถาม" กับ "ฐานข้อมูลจริง"**

คนถามเป็นภาษาคน หรือเขียน SQL ด้วย **ชื่อที่เข้าใจง่าย** → Wren แปลเป็น SQL จริงที่ตรงกับ
ตาราง/คอลัมน์/กติกาธุรกิจ ก่อนส่งลง PostgreSQL

เปรียบเทียบ:

```
ไม่มี Wren:   คน/AI ──เขียน SQL เอง──▶ PostgreSQL   (ต้องรู้ตารางจริงทุกอย่างเอง)

มี Wren:      คน/AI ──ถาม──▶ [ Wren layer ] ──SQL ที่ถูก──▶ PostgreSQL
                              ▲ รู้ชื่อจริง, join, นิยามธุรกิจ, คอลัมน์ลับ
```

Wren **ไม่ใช่** ฐานข้อมูลใหม่ ไม่เก็บข้อมูลซ้ำ — มันคือ "ชั้นความรู้" ที่ครอบ DB เดิมไว้

---

## 2. ปัญหาที่ Wren แก้

ฐานข้อมูลจริงมักรก: ตารางตายปนตารางใช้งาน, สถานะเป็นเลขเปล่า, คอลัมน์ลับปนข้อมูลทั่วไป,
คอลัมน์เวลาหลายตัวที่ความหมายต่างกัน

คนใหม่ (หรือ AI) ที่ไม่รู้ "บริบท" พวกนี้ → เขียน SQL ผิดแบบ **เงียบ ๆ** (ได้เลขออกมา แต่ผิด)

Wren ย้ายบริบทพวกนี้ออกจาก "หัวคน" มาเก็บเป็น **ไฟล์ config** ที่ทั้งคนและ AI อ่านได้
ผลคือใครถามก็ได้คำตอบมาตรฐานเดียวกัน

5 กับดักที่เจอบ่อย (รายละเอียด+เลขจริงดูใน `wren_playbook.md`):

| กับดัก | ไม่มี Wren | มี Wren แก้ด้วย |
|---|---|---|
| ตารางตาย v1 ปน v2 | นับผิดตาราง | alias model + ไม่ map v1 |
| `status` เป็นเลข (2=paid?) | ไม่กรอง / กรองผิด | `instructions.md` |
| คอลัมน์ลับ (national_id) | SELECT เห็นหมด รั่ว | masking (ตัด column จาก model) |
| `created_at` vs `paid_at` | กรองเวลาผิดตัว | `instructions.md` |
| list price ≠ ราคาขายจริง | คูณ `products.price` → revenue เกินจริง | `order_items.unit_price` + `instructions.md` |

> กับดักที่ 5 แอบเนียนสุด: `products.price` คือ **ราคา list ปัจจุบัน** (สูงกว่าตอนขายจริง ~15%
> เพราะปรับราคาขึ้นทีหลัง) ส่วนราคาที่ลูกค้าจ่ายจริงถูกตรึงไว้ที่ `order_items.unit_price`
> ตอนสั่ง รายได้รายสินค้าจึงต้องคิดจาก `order_items.unit_price * quantity` แล้ว join `orders`
> กรอง `status = 2` — ห้ามหยิบ `products.price` มาคูณ ไม่งั้นได้ตัวเลขพองเกินจริงแบบเงียบ ๆ

---

## 3. เทียบ "มี vs ไม่มี Wren" — 2 ระดับ

### 3.1 ระดับคนเขียน SQL เอง (ยังไม่มี AI)

ปัญหาอยู่ที่ **ความรู้กระจุกอยู่ในหัวคนเก่า**

| | ไม่มี Wren | มี Wren |
|---|---|---|
| รู้ว่าใช้ตารางไหน | ต้องไปถามรุ่นพี่ / เดา | model มี 1 ชื่อชัด (`customers`) |
| รู้ว่า status 2 = paid | จำเอง / เปิด doc เก่า | เขียนใน `instructions.md` |
| คนใหม่เข้าทีม | งงเป็นเดือน | อ่าน config ไฟล์เดียวเข้าใจ |
| ทุกคนได้เลขตรงกัน | ไม่ — ต่างคนต่างเขียน | ใช่ — นิยามกลางที่เดียว |

→ ค่าของ Wren ตรงนี้ = **เอกสารบริบทที่ "บังคับใช้ได้"** ไม่ใช่ doc ที่ไม่มีใครอ่าน

### 3.2 ระดับใช้ AI (text-to-SQL)

ปัญหาอยู่ที่ **AI เดา (hallucinate)** เพราะไม่รู้บริบท

```
ไม่มี Wren:
  คน: "revenue เดือนนี้เท่าไร"
  AI:  เห็นแค่ชื่อตาราง orders → เดา SUM(total) → 502,200 (ผิด รวม refund ด้วย)

มี Wren:
  คน: "revenue เดือนนี้เท่าไร"
  AI:  fetch context → เจอ "revenue = SUM(total) WHERE status=2"
       → SUM(total) WHERE status=2 → 143,640 (ถูก)
```

Wren = "ป้อนบริบทให้ AI ก่อนมันเขียน SQL" → ลดการมั่ว
ยิ่งใช้ ผ่าน **memory** ยิ่งแม่นขึ้นเรื่อย ๆ (ดูข้อ 5)

---

## 4. องค์ประกอบ 5 ชิ้นที่ต้องเข้าใจ

```
              ┌─────────────────────────────────────────┐
   ถาม  ─────▶│  Wren semantic layer                    │─────▶ PostgreSQL
              │                                          │
              │  1. models/        ชื่อ + map ตารางจริง  │
              │  2. relationships  join ระหว่างตาราง     │
              │  3. instructions.md  นิยามธุรกิจ          │
              │  4. queries.yml    คู่ NL↔SQL ที่ curate │
              │  5. memory/        ความจำ (vector)        │
              └─────────────────────────────────────────┘
```

### 1) models/ — "พจนานุกรมชื่อ"
แต่ละ model = 1 ตารางที่ agent มองเห็น
- `name` = ชื่อที่เอาไว้ถาม (เช่น `customers`)
- `table_reference` = ตารางจริง (เช่น `public.customers_v2`)
- `columns` = คอลัมน์ที่ **ยอมให้เห็น** — ไม่ประกาศ = มองไม่เห็น = masking อัตโนมัติ

> หัวใจ: ชื่อ model ≠ ชื่อตารางจริงก็ได้ → ซ่อนความรก/เปลี่ยนตารางเบื้องหลังได้โดยคำถามไม่ต้องเปลี่ยน

โปรเจกต์ตัวอย่างมี **5 model**: `customers` (→ ตารางจริง `customers_v2`, 200 แถว),
`orders` (1,200), `products` (40), `order_items` (3,000) — ส่วน `customers_v1` (350 แถว) เป็น
**ตารางตายที่จงใจไม่ map** ไว้ จึงถามถึงไม่ได้เลย (กับดักที่ 1)

### 2) relationships.yml — "แผนที่ join"
บอกว่าตารางไหนต่อกับตารางไหนยังไง (เช่น `orders.customer_id = customers.customer_id`, many_to_one)
→ ถามข้ามตารางได้โดยไม่ต้องเขียน JOIN เอง / AI ไม่ join มั่ว

### 3) instructions.md — "กติกาธุรกิจภาษาคน"
นิยามที่ SQL บอกไม่ได้: "active คืออะไร", "revenue นับยังไง", "status เลขไหนแปลว่าอะไร"
ทั้งคนและ AI อ่านอันนี้ → ตีความตรงกัน

### 4) queries.yml — "คลังคำถามที่ curate ไว้"
คู่ "คำถาม↔SQL" ที่เราคัดมาเองว่าถูกต้อง เก็บเป็นไฟล์ git-tracked (ต่างจาก `.wren/memory/`
ที่เป็น generated ไม่เข้า git) → เป็น **source of truth ของความจำ** ที่ review ได้ใน PR
ไฟล์นี้คือช่องทาง "สอน" คำถามที่เจอบ่อยให้ตอบแม่นแน่นอน แล้ว load เข้า memory ทีหลัง (ดูข้อ 5)

### 5) .wren/memory/ — "ความจำ" (สำคัญ ดูข้อ 5)
เก็บ context + คู่ "คำถาม↔SQL" เป็น vector เพื่อค้นด้วย **ความหมาย** — เป็นปลายทางที่ของจาก
`queries.yml` และคำสั่ง `store` ไหลมารวมกัน

---

## 5. Memory — เข้าใจให้ลึก (จุดที่งงบ่อยสุด)

Memory คือ "สมุดโน้ตอัจฉริยะ" ของ Wren — ค้นด้วย **ความหมาย** ไม่ใช่ตรงตัวอักษร

### 5.1 มี 3 คำสั่งหลัก

| คำสั่ง | เปรียบเทียบ | ทำอะไร |
|---|---|---|
| `fetch` | "เปิดสมุดดูบริบทรอบ ๆ" | ดึง context (schema + นิยาม) ที่เกี่ยวกับคำถาม ให้ AI ใช้ |
| `recall` | "เคยมีคนถามแบบนี้ไหม" | หา **คู่ NL↔SQL เก่า** ที่ความหมายใกล้คำถาม |
| `store` | "จดคำตอบที่ถูกไว้" | บันทึกคู่ NL↔SQL ใหม่ ให้ครั้งหน้า recall เจอ |

> **จุดที่พลาดบ่อย: `load` ≠ `index`** — คู่ใน `queries.yml` เข้าคลัง recall ด้วย
> `wren memory load queries.yml` เท่านั้น **ไม่ใช่** `wren memory index`
> เชิง concept: `index` แค่ทำ auto-browse จากตัว schema/model (ให้ AI เดินดูได้ว่ามีตารางอะไร)
> **ไม่ได้ดึงคู่ curate เข้า recall** ส่วน `load` คือตัวที่ยัดคู่ NL↔SQL จาก `queries.yml`
> เข้าไปเป็น vector ให้ recall เจอจริง ๆ — สองอย่างนี้จึงต้องสั่งแยกกัน

### 5.2 recall อ่านผลยังไง — `distance`

`recall` คืนผลเรียงตาม **distance = ระยะห่างความหมาย** → **ยิ่งต่ำ ยิ่งใกล้**

```
$ wren memory recall --query "สมัครวันนี้กี่คน"
  dist 0.735  ลูกค้ามีกี่คน          ← ใกล้สุด (แต่ยังไม่ตรง!)
  dist 1.367  List all customers
  dist 1.398  Total customer_id in orders
```

จุดที่ต้องเข้าใจ:
- recall **ไม่ได้เขียน SQL ใหม่** — แค่ "หยิบของเก่าที่คล้ายมาโชว์"
- **คล้าย ≠ ถูก** — บนสุด "ลูกค้ามีกี่คน" คือนับ*ทั้งหมด* ไม่ใช่*วันนี้*
- dist 0.7+ ถือว่ายังห่าง (ตรงจริงมักอยู่ ~0.1–0.3)
- ถ้าไม่มีของตรง → เขียน SQL เอง แล้ว `store` ไว้ → ครั้งหน้าจะเจอ dist ต่ำ

### 5.3 วงจรที่ทำให้ "ยิ่งใช้ยิ่งฉลาด"

```
        ┌──────────────────────────────────────┐
        ▼                                        │
   ถามคำถาม ──▶ recall ──เจอตรงไหม?             │
                          │                       │
                  ไม่เจอ  │  เจอ                  │
                          ▼     ▼                 │
                 เขียน SQL ใหม่  ใช้เลย           │
                          │                       │
                          ▼                       │
                       รันจริง ──▶ store ─────────┘
                                   (จดไว้ครั้งหน้าเจอ)
```

ครั้งแรกอาจไม่มีอะไรให้ recall → สอนมันด้วย `store`
ใช้ไปเรื่อย ๆ คลังโตขึ้น → recall แม่นขึ้น → AI เขียน SQL ผิดน้อยลง

---

## 6. Workflow ตั้งแต่ folder เปล่า (ภาพรวม)

```
1. ติดตั้ง + ต่อ DB        wren profile add ...        (ใส่ credential)
2. scaffold โครง           wren context init           (ได้โครงไฟล์เปล่า)
3. ลบ example ทิ้ง
4. สร้าง models/ + rel      (เขียนเอง หรือให้ AI generate จาก schema)
5. ใส่กติกาธุรกิจ          แก้ instructions.md
6. compile                 wren context build          (ได้ target/mdl.json)
7. index schema            wren memory index           (auto-browse จาก model)
8. load คู่ที่ curate      wren memory load queries.yml (ดึง NL↔SQL เข้า recall)
9. ถามได้แล้ว              ภาษาคน หรือ wren --sql ...
```

> ขั้น 7 กับ 8 ทำคนละหน้าที่ (ดูข้อ 5.1) — `index` ทำให้ AI เห็น schema, `load` ทำให้ recall
> เจอคู่ที่เรา curate รายละเอียดคำสั่ง + ตัวอย่างไฟล์เต็ม → ดู `wren_manual.md`

---

## 7. เคสตัวอย่าง: "สมัครวันนี้กี่คน + ใครล่าสุด" (ไม่แก้ code)

โจทย์ถามใหม่ ที่ยังไม่มีใน memory — ขั้นตอนคิด:

**1. เช็คก่อนว่าข้อมูลพอไหม** — ต้องมีคอลัมน์เวลาสมัคร
→ `customers.created_at` มีอยู่แล้ว ✅ → **ไม่ต้องเพิ่ม model/column อะไร**

**2. ลอง recall** — เผื่อเคยถาม
```bash
wren memory recall --query "สมัครวันนี้กี่คน"
# ผล dist สูง ไม่ตรง → ต้องเขียนเอง
```

**3. เขียน SQL + รันจริง**
```bash
# กี่คน
wren --sql "SELECT COUNT(*) FROM customers WHERE created_at::date = current_date" -o table
# ใครล่าสุด
wren --sql "SELECT first_name, last_name, created_at FROM customers ORDER BY created_at DESC LIMIT 1" -o table
```

**4. store เก็บไว้** — ครั้งหน้า recall เจอเลย
```bash
wren memory store \
  --nl "มีคนสมัครสมาชิกวันนี้กี่คน" \
  --sql "SELECT COUNT(*) FROM customers WHERE created_at::date = current_date"
```

สรุปสิ่งที่ "เพิ่ม": **ไม่แตะ code / model เลย** — แค่ (option) เพิ่มคู่ NL↔SQL ลง memory ผ่าน `store`
หรือใส่ลง `queries.yml` แล้ว `wren memory load queries.yml` ก็ได้ (config ไม่ใช่ code)
> หมายเหตุ: ใช้ `memory load` ไม่ใช่ `memory index` — `index` สร้างแค่ auto browse queries ไม่ดึงคู่ curate เข้า recall

---

## 8. สรุป mental model

| คำถามในใจ | คำตอบสั้น |
|---|---|
| Wren คืออะไร | ชั้นแปลความหมายระหว่างคน/AI กับ DB |
| แก้ปัญหาอะไร | บริบทที่อยู่แต่ในหัวคน → ทำให้ SQL ผิดเงียบ |
| เก็บบริบทไว้ไหน | models (ชื่อ/mask) · relationships (join) · instructions (กติกา) · queries.yml (คู่ curate) |
| ความจำทำงานยังไง | fetch (บริบท) · recall (ของเก่าคล้าย) · store (จดใหม่) — `load` ดึง queries.yml เข้า recall, `index` แค่ browse schema |
| ยิ่งใช้ยิ่งดีเพราะ | store สะสมตัวอย่าง → recall แม่นขึ้น |
| ถามใหม่ที่ไม่มีในคลัง | recall ไม่เจอ → เขียนเอง → store |