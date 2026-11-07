import { config } from "dotenv";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { query } from "../src/lib/db";

config({ path: ".env.local" });

async function main() {
  const source = await readFile(resolve("migrations/001_init.sql"), "utf8");
  for (const statement of source.split(";").map((s) => s.trim()).filter(Boolean)) {
    await query(statement);
  }
  console.log("PostgreSQL schema is up to date.");
}

main().catch((error: unknown) => { console.error(error); process.exit(1); });
