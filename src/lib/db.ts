import { neon } from "@neondatabase/serverless";

const url = process.env.DATABASE_URL;
if (!url && process.env.NODE_ENV !== "production") {
  // Delay the useful error until a database operation is requested.
}

export function getSql() {
  if (!process.env.DATABASE_URL) throw new Error("DATABASE_URL غير مضبوط");
  return neon(process.env.DATABASE_URL);
}

export async function query<T = Record<string, unknown>>(text: string, params: unknown[] = []): Promise<T[]> {
  const sql = getSql();
  return await sql.query(text, params as never[]) as T[];
}
