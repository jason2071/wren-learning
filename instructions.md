# User Instructions

Add custom rules or guidelines for LLM-based query generation here.

## Definitions
- "active customer" = ลูกค้าที่มี order status = 2 (paid) ใน 90 วันล่าสุด
- ใช้ paid_at สำหรับกรองเวลา ไม่ใช่ created_at
- "revenue" = SUM(orders.total) เฉพาะ status = 2
- "สมัครสมาชิก" / "register" = customers.created_at (วันที่สร้าง record ลูกค้า)
- "สมัครวันนี้" = customers.created_at::date = current_date
- category_code: 1=Electronics 2=Apparel 3=Food 4=Books 5=Home
- "revenue รายสินค้า" = SUM(order_items.unit_price * quantity) + join orders กรอง status=2 — ห้ามใช้ products.price
- "สินค้า active" = is_active = true

## Status codes
1=pending, 2=paid, 3=shipped, 4=refunded, 5=cancelled
