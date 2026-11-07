import type { NextRequest } from "next/server";
import { query } from "@/lib/db";
import type { AppUser } from "@/lib/auth";

export async function audit(req: NextRequest, user: AppUser, action: string, entity: string, entityId: number | string | null, details: unknown = {}) {
  const ip = req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? "";
  await query("INSERT INTO audit_log(user_id,action,entity,entity_id,details,ip_address) VALUES($1,$2,$3,$4,$5::jsonb,$6)",
    [user.id,action,entity,entityId,JSON.stringify(details),ip]);
}
