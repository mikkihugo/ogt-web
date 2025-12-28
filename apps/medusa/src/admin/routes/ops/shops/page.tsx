// @ts-nocheck
import {
  Container,
  Heading,
  Table,
  Button,
  Input,
  Textarea,
  Toaster,
  useToast,
} from "@medusajs/ui";
import { useState, useEffect } from "react";
import { RouteConfig } from "@medusajs/admin";
import { ChatBubbleLeftRight } from "@medusajs/icons";

// Define Data Type based on our API
type Shop = {
  id: string;
  name: string;
  domains: { domain: string; is_primary: boolean }[];
  marketing_config: any;
  theme_config: any; // We will edit this as JSON
};

const ShopManagement = () => {
  const [shops, setShops] = useState<Shop[]>([]);
  const [loading, setLoading] = useState(true);
  const { toast } = useToast();

  // Fetch on Mount
  useEffect(() => {
    fetch("/admin/ops/shops")
      .then((res) => res.json())
      .then((data) => {
        setShops(data.shops || []);
        setLoading(false);
      })
      .catch((err) =>
        toast({
          title: "Error",
          description: "Failed to load shops",
          variant: "error",
        }),
      );
  }, []);

  // Simple JSON Editor Component (Stubbed for brevity)
  const [editing, setEditing] = useState<Shop | null>(null);

  const handleSave = async (shop: Shop) => {
    // Validation: Parse structure
    try {
      await fetch("/admin/ops/shops", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(shop),
      });
      toast({ title: "Success", description: "Shop saved" });
      window.location.reload();
    } catch (e) {
      toast({ title: "Error", description: "Save failed", variant: "error" });
    }
  };

  if (loading) return <div>Loading Ops Data...</div>;

  if (editing) {
    return (
      <Container>
        <Heading>Edit Shop: {editing.name}</Heading>
        <div className="flex flex-col gap-4 mt-4">
          <Input
            label="Name"
            value={editing.name}
            onChange={(e) => setEditing({ ...editing, name: e.target.value })}
          />

          <label>Marketing Config (JSON)</label>
          <Textarea
            rows={5}
            value={JSON.stringify(editing.marketing_config, null, 2)}
            onChange={(e) => {
              try {
                setEditing({
                  ...editing,
                  marketing_config: JSON.parse(e.target.value),
                });
              } catch {}
            }}
          />

          <label>Theme Tokens (JSON)</label>
          <Textarea
            rows={5}
            value={JSON.stringify(editing.theme_config, null, 2)}
            onChange={(e) => {
              try {
                setEditing({
                  ...editing,
                  theme_config: JSON.parse(e.target.value),
                });
              } catch {}
            }}
          />

          <div className="flex gap-2">
            <Button onClick={() => handleSave(editing)}>Save Changes</Button>
            <Button variant="secondary" onClick={() => setEditing(null)}>
              Cancel
            </Button>
          </div>
        </div>
      </Container>
    );
  }

  return (
    <Container>
      <div className="flex justify-between items-center mb-6">
        <Heading level="h1">Multi-Shop Management</Heading>
        <Button
          onClick={() =>
            setEditing({
              id: "new_shop",
              name: "New Shop",
              domains: [],
              marketing_config: {},
              theme_config: {},
            })
          }
        >
          Create Shop
        </Button>
      </div>

      <Table>
        <Table.Header>
          <Table.Row>
            <Table.HeaderCell>ID</Table.HeaderCell>
            <Table.HeaderCell>Name</Table.HeaderCell>
            <Table.HeaderCell>Actions</Table.HeaderCell>
          </Table.Row>
        </Table.Header>
        <Table.Body>
          {shops.map((shop) => (
            <Table.Row key={shop.id}>
              <Table.Cell>{shop.id}</Table.Cell>
              <Table.Cell>{shop.name}</Table.Cell>
              <Table.Cell>
                <Button variant="secondary" onClick={() => setEditing(shop)}>
                  Edit Config
                </Button>
              </Table.Cell>
            </Table.Row>
          ))}
        </Table.Body>
      </Table>
      <Toaster />
    </Container>
  );
};

export const config: RouteConfig = {
  link: {
    label: "Shops",
    icon: ChatBubbleLeftRight, // Just a placeholder icon
  },
};

export default ShopManagement;
