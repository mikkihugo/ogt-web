import { OpsDb } from "./service";
import { GoogleGenerativeAI } from "@google/generative-ai";

export class AiOpsService {
  private ops: OpsDb;
  private genAI: GoogleGenerativeAI;
  private model: any;

  constructor() {
    this.ops = OpsDb.getInstance();
    // User Requirement: Use Gemini AI Studio
    // Model: gemini-pro
    const apiKey = process.env.GEMINI_API_KEY || "mock_key";
    this.genAI = new GoogleGenerativeAI(apiKey);
    this.model = this.genAI.getGenerativeModel({ model: "gemini-pro" });
  }

  /**
   * The Core AI Logic: RAG (Retrieval Augmented Generation)
   * We retrieve operational context from our specialized tables and feed it to Gemini.
   */
  async ask(question: string): Promise<string> {
    // 1. Context Retrieval (The "Brain" access)
    // Future Upgrade: Use 'models/embedding-001' + pgvector for Semantic Search
    const context = await this.retrieveContext(question);

    // 2. Gemini Call
    try {
      if (!process.env.GEMINI_API_KEY) {
        return `[Mock Mode] Gemini API Key missing in .env. \n\nContext found (${context.length} chars):\n${context.substring(0, 200)}...`;
      }

      const prompt = `
            You are the "Adaptive Logistics Engine" AI. 
            You explain operational decisions to the human operator.
            
            CONTEXT DATA (Grounding from Postgres):
            ${context}

            USER QUESTION:
            ${question}

            ANSWER (Explain "Why" based on the data, be concise):
            `;

      const result = await this.model.generateContent(prompt);
      const response = await result.response;
      return response.text();
    } catch (err: any) {
      return `AI Error (Gemini): ${err.message}`;
    }
  }

  private async retrieveContext(question: string) {
    let context = "";
    const runner = await this.ops.getQueryRunner();

    // 1. Generate Query Embedding (Local Jina V2 CPU)
    let queryVector: number[] = [];
    try {
      queryVector = await (this as any).generateEmbedding(question);
    } catch (e) {
      console.warn(
        "Embedding generation failed, falling back to keyword search",
        e,
      );
    }

    // 2. Hybrid Search: Vector (Semantic) + SQL (Keyword)

    if (queryVector.length > 0) {
      // Semantic Search via PgVector
      // Find similar events (history)
      const vectorQuery = `
                SELECT 
                    event_type, meta, created_at,
                    1 - (embedding <=> $1) as similarity
                FROM dropship.event_history
                ORDER BY similarity DESC
                LIMIT 5
            `;
      // pgvector needs string format '[1,2,3]'
      const vectorStr = `[${queryVector.join(",")}]`;

      const { rows: semanticRows } = await runner.query(vectorQuery, [
        vectorStr,
      ]);
      context += `Semantic Matches (History): ${JSON.stringify(semanticRows)}\n`;
    }

    // 3. Keyword Fallback/Augmentation (Specific Entities)
    // ... (Keep existing keyword logic for specific lookup precision)
    if (question.toLowerCase().includes("supplier")) {
      const { rows } = await runner.query(
        `SELECT name, reliability_score FROM dropship.supplier`,
      );
      context += `Supplier Current Status: ${JSON.stringify(rows)}\n`;
    }

    // 3. Fetch Suppressed Products
    if (
      question.toLowerCase().includes("product") ||
      question.includes("suppress")
    ) {
      const { rows } = await runner.query(`
                SELECT * FROM dropship.product_metrics WHERE suppressed = TRUE
            `);
      context += `Suppressed Products (High Return Rate): ${JSON.stringify(rows)}\n`;
    }

    if (context === "") {
      context =
        "No specific database records found for this query. Answer based on general knowledge of the system.";
    }

    return context;
  }
}
