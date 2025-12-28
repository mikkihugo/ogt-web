import { OpsDb } from "../modules/ops/service";

// Enable pgvector and add embedding column for RAG
const run = async () => {
    const ops = OpsDb.getInstance();
    const client = await ops.getQueryRunner();

    console.log("🧠 Enabling PgVector & Jina Embeddings...");

    try {
        await client.query("CREATE EXTENSION IF NOT EXISTS vector;");

        // Add embedding column to event_history
        // Jina Small EN is 512 dimensions
        await client.query(`
            ALTER TABLE dropship.event_history 
            ADD COLUMN IF NOT EXISTS embedding vector(512);
        `);

        // Add index for fast retrieval
        await client.query(`
            CREATE INDEX IF NOT EXISTS event_history_embedding_idx 
            ON dropship.event_history 
            USING hnsw (embedding vector_cosine_ops);
        `);

        console.log("✅ Vector search enabled.");
    } catch (e: any) {
        console.error("Failed to enable vectors:", e.message);
    } finally {
        process.exit(0);
    }
};

run();
