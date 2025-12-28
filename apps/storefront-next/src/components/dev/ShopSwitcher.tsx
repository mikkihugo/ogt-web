"use client";

import { useState } from "react";

export function DevShopSwitcher() {
  /* 
     Dev Tool: Hardcoded shops for local development convenience.
     These match the seeded data in apps/medusa/src/scripts/seed.ts.
  */
  const [isOpen, setIsOpen] = useState(false);
  const shops = [
    {
      id: "orgasm_toy",
      name: "OrgasmToy",
      domain: "http://orgasmtoy.localhost",
    },
    {
      id: "own_orgasm",
      name: "OwnOrgasm",
      domain: "http://ownorgasm.localhost",
    },
    {
      id: "funnel_gadget",
      name: "Funnel Test",
      domain: "http://best-gadget-ever.localhost",
    },
    {
      id: "admin_dashboard",
      name: "Admin Dashboard",
      domain: "http://admin.localhost/app",
    },
  ];

  if (process.env.NODE_ENV === "production") return null;

  return (
    <div className="fixed bottom-4 right-4 z-50">
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="bg-black text-white px-3 py-2 rounded-md shadow-lg text-xs font-mono hover:bg-gray-800"
      >
        Dev: Switch Shop ▲
      </button>

      {isOpen && (
        <div className="absolute bottom-full right-0 mb-2 bg-white border border-gray-200 rounded-md shadow-xl w-48 overflow-hidden">
          {shops.map((s) => (
            <a
              key={s.id}
              href={s.domain}
              className="block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 border-b last:border-0"
            >
              {s.name}
            </a>
          ))}
        </div>
      )}
    </div>
  );
}
