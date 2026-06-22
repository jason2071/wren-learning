# User Instructions

Add custom rules or guidelines for LLM-based query generation here.

## Definitions
- "active customer" = ลูกค้าที่มี order status = 2 (paid) ใน 90 วันล่าสุด
- ใช้ paid_at สำหรับกรองเวลา ไม่ใช่ created_at
- "revenue" = SUM(orders.total) เฉพาะ status = 2
- "สมัครสมาชิก" / "register" = customers.created_at (วันที่สร้าง record ลูกค้า)
- "สมัครวันนี้" = customers.created_at::date = current_date

## Status codes
1=pending, 2=paid, 3=shipped, 4=refunded, 5=cancelled
