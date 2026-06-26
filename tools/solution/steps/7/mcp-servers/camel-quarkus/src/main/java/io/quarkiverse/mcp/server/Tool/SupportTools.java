package org.acme;

import io.quarkiverse.mcp.server.Tool;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;

import org.apache.camel.ProducerTemplate;

import java.util.HashMap;
import java.util.Map;

@ApplicationScoped
public class SupportTools {

    @Inject
    ProducerTemplate producerTemplate;


    @Tool(description = "Amends an invoice")
    public String amendInvoice(String id, String prompt) {

        Map<String, Object> headers = new HashMap<>();
        headers.put("id", id);
        headers.put("prompt", prompt);

        return producerTemplate.requestBodyAndHeaders(
                "direct:tool-amend-invoice",
                null,
                headers,
                String.class);
    }


    @Tool(description = "Creates a ticket in HelpDesk")
    public String createTicket(String subject, String content, String invoiceUrl) {

        Map<String, Object> headers = new HashMap<>();
        headers.put("subject", subject);
        headers.put("content", content);
        headers.put("invoiceUrl", invoiceUrl);

        return producerTemplate.requestBodyAndHeaders(
                "direct:tool-create-ticket",
                null,
                headers,
                String.class);
    }


    @Tool(description = "Shares a ticket with customer")
    public String shareTicket(String ticketId) {
        return producerTemplate.requestBodyAndHeader(
                "direct:tool-share-ticket",
                null,
                "ticketId",
                ticketId,
                String.class);
    }

}
