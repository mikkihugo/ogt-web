-- Configure the 2 initial Luxury Brands
-- 1. OrgasmToy.com (The Flagship Store)
INSERT INTO ops.shop (id, name, shop_type, default_region, currency_code, default_locale, theme_config, marketing_config)
VALUES (
    'orgasm_toy', 
    'OrgasmToy', 
    'store', 
    'reg_us', -- Assuming US for now, or global
    'USD', 
    'en', 
    '{
        "id": "luxury",
        "font": "Playfair Display",
        "colors": {
            "primary": "#000000",
            "secondary": "#D4AF37", 
            "accent": "#500000",
            "background": "#ffffff"
        },
        "radius": "0px"
    }'::jsonb,
    '{"meta_pixel_id": "Pixel_OT", "ga4_measurement_id": "G-OT"}'::jsonb
) ON CONFLICT (id) DO UPDATE SET 
    name = EXCLUDED.name,
    theme_config = EXCLUDED.theme_config;

-- 2. OwnOrgasm.com (The Content/Wellbeing Hub)
INSERT INTO ops.shop (id, name, shop_type, default_region, currency_code, default_locale, theme_config, marketing_config)
VALUES (
    'own_orgasm', 
    'OwnOrgasm', 
    'blog', 
    'reg_us', 
    'USD', 
    'en', 
    '{
        "id": "wellbeing",
        "font": "Cormorant Garamond",
        "colors": {
            "primary": "#2C3E50",
            "secondary": "#E0F7FA",
            "accent": "#FF6F61",
            "background": "#FDFBF7"
        },
        "radius": "4px"
    }'::jsonb,
    '{"ga4_measurement_id": "G-OO"}'::jsonb
) ON CONFLICT (id) DO UPDATE SET 
    name = EXCLUDED.name,
    theme_config = EXCLUDED.theme_config;

-- Map Domains
INSERT INTO ops.shop_domain (domain, shop_id, is_primary) VALUES
('orgasmtoy.com', 'orgasm_toy', true),
('www.orgasmtoy.com', 'orgasm_toy', false),
('ownorgasm.com', 'own_orgasm', true),
('www.ownorgasm.com', 'own_orgasm', false)
ON CONFLICT (domain) DO UPDATE SET shop_id = EXCLUDED.shop_id;
