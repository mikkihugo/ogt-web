import { OpsDb } from "../ops/service";
import { Logger } from "@medusajs/types";

export interface OpsException {
  id: string;
  shop_id: string;
  type: string;
  severity: "low" | "medium" | "high" | "critical";
  entity_ref: Record<string, any>;
  status: "open" | "in_progress" | "resolved" | "ignored";
  assigned_to?: string;
  notes?: string;
}

export class ExceptionService {
  private ops: OpsDb;
  private static instance: ExceptionService;
  private logger?: Logger;

  constructor() {
    this.ops = OpsDb.getInstance();
  }

  static getInstance(): ExceptionService {
    if (!ExceptionService.instance) {
      ExceptionService.instance = new ExceptionService();
    }
    return ExceptionService.instance;
  }

  setLogger(logger: Logger) {
    this.logger = logger;
  }

  async raise(
    shopId: string,
    type: string,
    severity: OpsException["severity"],
    entityRef: Record<string, any>,
    notes?: string,
  ) {
    const id = `exc_${Date.now()}_${Math.random().toString(36).substring(7)}`;

    if (this.logger) {
      this.logger.warn(`[OpsException] ${type}: ${JSON.stringify(entityRef)}`);
    }

    const q = `
      INSERT INTO dropship.ops_exception (id, shop_id, type, severity, entity_ref, notes, status)
      VALUES ($1, $2, $3, $4, $5, $6, 'open')
      RETURNING *
    `;

    await this.ops
      .getQueryRunner()
      .then((pool) =>
        pool.query(q, [
          id,
          shopId,
          type,
          severity,
          JSON.stringify(entityRef),
          notes,
        ]),
      );
  }

  async listOpen(shopId?: string): Promise<OpsException[]> {
    let q = `SELECT * FROM dropship.ops_exception WHERE status = 'open'`;
    const params: any[] = [];
    if (shopId) {
      q += ` AND shop_id = $1`;
      params.push(shopId);
    }
    q += ` ORDER BY created_at DESC`;

    const { rows } = await this.ops
      .getQueryRunner()
      .then((pool) => pool.query(q, params));
    return rows;
  }
}
