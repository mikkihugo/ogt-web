-- Add localhost domains for development
INSERT INTO ops.shop_domain (domain, shop_id, is_primary) VALUES
('orgasmtoy.localhost', 'orgasm_toy', false),
('ownorgasm.localhost', 'own_orgasm', false),
('admin.localhost', 'orgasm_toy', false) -- Admin usually is global, but domain check might happen
ON CONFLICT (domain) DO NOTHING;
