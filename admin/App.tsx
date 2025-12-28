import { Refine } from "@refinedev/core";
import dataProvider from "@refinedev/simple-rest";
import { HeadlessInferencer } from "@refinedev/inferencer/headless";

const API_URL = import.meta.env.VITE_API_URL || "http://localhost:8080/api";

function App() {
  return (
    <Refine
      dataProvider={dataProvider(API_URL)}
      resources={[
        {
          name: "products",
          list: "/products",
          show: "/products/:id",
        },
        {
          name: "orders",
          list: "/orders",
          show: "/orders/:id",
        },
        {
          name: "sync",
          list: "/sync", // Hacky resource to trigger sync? Or custom page.
        },
      ]}
    >
      {/* Auto-inferred UI for rapid development */}
      <HeadlessInferencer />
    </Refine>
  );
}

export default App;
