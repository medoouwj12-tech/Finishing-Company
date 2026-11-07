import { createHash, randomBytes } from "node:crypto";
import { cookies } from "next/headers";
import { query } from "@/lib/db";

export type AppUser = { id: number; name: string; email: string; role: string; permissions: Record<string, string[]> };
const COOKIE = "fitout_session";
const hash = (value: string) => createHash("sha256").update(value).digest("hex");

export async function createSession(userId: number) {
  const token = randomBytes(32).toString("base64url");
  const expires = new Date(Date.now() + 1000 * 60 * 60 * 24 * 14);
  await query("INSERT INTO sessions(token_hash,user_id,expires_at) VALUES($1,$2,$3)", [hash(token),userId,expires]);
  const jar = await cookies();
  jar.set(COOKIE, token, { httpOnly: true, secure: process.env.NODE_ENV === "production", sameSite: "strict", path: "/", expires });
}

export async function currentUser(): Promise<AppUser | null> {
  const token = (await cookies()).get(COOKIE)?.value;
  if (!token) return null;
  const result = await query<AppUser>(
    "SELECT u.id,u.name,u.email,u.role,u.permissions FROM sessions s JOIN users u ON u.id=s.user_id WHERE s.token_hash=$1 AND s.expires_at>now() AND u.active=true LIMIT 1",
    [hash(token)],
  );
  return result[0] ?? null;
}

export async function destroySession() {
  const jar = await cookies();
  const token = jar.get(COOKIE)?.value;
  if (token) await query("DELETE FROM sessions WHERE token_hash=$1", [hash(token)]);
  jar.delete(COOKIE);
}

const rolePermissions: Record<string, Record<string, string[]>> = {
  owner: { "*": ["*"] },
  admin: { "*": ["*"] },
  accountant: { finance: ["read","create","approve","export"], invoices: ["read","create","approve","export"], customers: ["read"], projects: ["read"], reports: ["read","export"], suppliers: ["read"], purchases: ["read"] },
  project_manager: { projects: ["read","create","update"], boq: ["read","create","update"], tasks: ["read","create","update"], reports: ["read","create"], customers: ["read"], invoices: ["read","create"] },
  engineer: { projects: ["read"], boq: ["read","create","update"], tasks: ["read","update"], reports: ["read","create"], inventory: ["read"] },
  purchasing: { suppliers: ["read","create","update"], purchases: ["read","create","update","receive"], inventory: ["read"], projects: ["read"] },
  storekeeper: { inventory: ["read","create","issue","receive"], materials: ["read","create","update"], projects: ["read"] },
  hr: { employees: ["read","create","update"], labor: ["read","create"], tasks: ["read"], payroll: ["read","create","approve"] },
  sales: { customers: ["read","create","update"], projects: ["read","create"], invoices: ["read","create"], contracts: ["read","create"] },
  employee: { tasks: ["read","update"], projects: ["read"] },
};

export function can(user: AppUser, module: string, action: string) {
  const overrides = user.permissions?.[module];
  if (Array.isArray(overrides)) return overrides.includes(action) || overrides.includes("*");
  const perms = rolePermissions[user.role] ?? {};
  return (perms["*"] ?? []).includes("*") || (perms[module] ?? []).includes(action);
}

export async function requireUser(module: string, action: string) {
  const user = await currentUser();
  if (!user) throw Object.assign(new Error("يلزم تسجيل الدخول"), { status: 401 });
  if (!can(user,module,action)) throw Object.assign(new Error("ليست لديك صلاحية لتنفيذ هذه العملية"), { status: 403 });
  return user;
}
