import { Kysely, PostgresDialect } from 'kysely'
import { Pool } from 'pg'

// 1. Define Database Interfaces
export interface SupplierTable {
    id: string
    name: string
    email: string
    reliability_score: number
    created_at: Date
}

export interface EventHistoryTable {
    id: number
    event_type: 'routing_decision' | 'price_change' | 'supplier_score_update'
    entity_id: string
    actor: string
    meta: any
    created_at: Date
}

// Map schema to tables
export interface DropshipDatabase {
    'dropship.supplier': SupplierTable
    'dropship.event_history': EventHistoryTable
}

// 2. Factory for Kysely Instance
// Uses the same connection logic as standard Pool but wraps it in Kysely
export function createOpsQueryBuilder(connectionString: string) {
    return new Kysely<DropshipDatabase>({
        dialect: new PostgresDialect({
            pool: new Pool({
                connectionString,
            }),
        }),
    })
}
