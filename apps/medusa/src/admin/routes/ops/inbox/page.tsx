import React from "react";
import { Container, Heading } from "@medusajs/ui";

const InboxPage = () => {
  // In a real build, we'd inject this env var or fetch config
  const chatwootUrl = "https://support.example.com/dashboard";

  return (
    <Container
      className="h-full w-full p-0 flex flex-col"
      style={{ height: "calc(100vh - 60px)" }}
    >
      <iframe
        src={chatwootUrl}
        className="w-full h-full border-0"
        title="Support Inbox"
      />
    </Container>
  );
};

export const config = {
  link: {
    label: "Inbox",
    icon: "ChatBubbleLeftRight",
  },
};

export default InboxPage;
