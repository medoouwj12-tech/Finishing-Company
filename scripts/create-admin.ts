import { config } from "dotenv";
import bcrypt from "bcryptjs";
import { query } from "../src/lib/db";

config({ path: ".env.local" });

async function main() {
  const email = process.env.ADMIN_EMAIL?.trim().toLowerCase();
  const name = process.env.ADMIN_NAME?.trim();
  const password = process.env.ADMIN_PASSWORD;
  if (!email || !name || !password || password.length < 12) {
    throw new Error("حدد ADMIN_EMAIL وADMIN_NAME وكلمة مرور ADMIN_PASSWORD لا تقل عن 12 حرفًا.");
  }
  const existing = await query<{ id: number }>("SELECT id FROM users WHERE email=$1", [email]);
  if (existing.length) throw new Error("هذا البريد مسجل بالفعل.");
  const hash = await bcrypt.hash(password, 12);
  await query("INSERT INTO users(name,email,password_hash,role) VALUES($1,$2,$3,'owner')", [name,email,hash]);
  console.log(`تم إنشاء حساب المالك: ${email}`);
}

main().catch((error: unknown) => { console.error(error); process.exit(1); });
