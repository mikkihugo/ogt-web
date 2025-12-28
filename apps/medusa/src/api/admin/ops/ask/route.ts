import { MedusaRequest, MedusaResponse } from "@medusajs/framework";
import { AiOpsService } from "../../../../modules/ops/ai.service";

export const POST = async (req: MedusaRequest, res: MedusaResponse) => {
    const { question } = req.body as { question: string };

    if (!question) {
        res.status(400).json({ error: "No question provided" });
        return;
    }

    const ai = new AiOpsService();
    const answer = await ai.ask(question);

    res.status(200).json({
        question,
        answer,
        model: "adaptive-logic-v1"
    });
};
