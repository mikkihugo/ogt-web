import { MedusaContainer } from "@medusajs/framework";
import { OpsDb } from "../modules/ops/service";
import fs from "fs";
import path from "path";

export default async function (container: MedusaContainer) {
    const ops = OpsDb.getInstance();
    const pool = await ops.getQueryRunner();

    // Read raw SQL file
    const sqlPath = path.resolve(__dirname, "phase8-product.sql");
    const sql = fs.readFileSync(sqlPath, "utf8");

    await pool.query(sql);
    console.log("✅ Applied Product Metrics Schema");
}
