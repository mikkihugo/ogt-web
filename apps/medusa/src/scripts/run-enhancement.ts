import { OpsDb } from "../modules/ops/service";
import * as fs from "fs";
import * as path from "path";

const run = async () => {
    console.log("🛠️  Enhancing Shop Configuration Schema...");
    const ops = OpsDb.getInstance();
    const client = await ops.getQueryRunner();

    try {
        const sql = fs.readFileSync(path.join(__dirname, "enhance-shop-config.sql"), "utf-8");
        await client.query(sql);
        console.log("✅ Schema updated successfully.");
    } catch (e: any) {
        console.error("❌ Migration failed:", e.message);
    } finally {
        process.exit(0);
    }
};

run();
