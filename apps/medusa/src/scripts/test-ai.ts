import { MedusaContainer } from "@medusajs/framework";
import { AiOpsService } from "../modules/ops/ai.service";

export default async function (container: MedusaContainer) {
  console.log("🤖 Testing AI Ops Service (Gemini Pro)...");

  if (!process.env.GEMINI_API_KEY) {
    console.warn("⚠️ GEMINI_API_KEY not found in process.env");
  }

  const ai = new AiOpsService();

  const question = "Why is this system called Adaptive Logistics?";
  console.log(`\n❓ Question: ${question}`);

  try {
    const answer = await ai.ask(question);
    console.log(`\n💡 Answer:\n${answer}`);
  } catch (e: any) {
    console.error("❌ AI Error:", e.message);
  }
}
