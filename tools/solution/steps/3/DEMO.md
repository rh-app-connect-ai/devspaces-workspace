# Test Shop - Demo Guide

## Context

This demo tells the story of a company modernizing its e-commerce platform while its backend supply chain systems still rely on EDI (Electronic Data Interchange).

The company has just launched a new customer-facing web portal to replace outdated ordering workflows. The long-term plan is to move all integrations to JSON and REST APIs, but the backend -- warehouse management, invoicing, shipping -- still runs entirely on EDI X12 messages. Rewriting everything at once isn't feasible.

So the first phase ships a modern frontend that still emits EDI under the hood. The visual datamapper on the backend is what makes this migration possible: it decouples the frontend evolution from the backend transformation. The business didn't have to wait for a full rewrite to launch.

When the team is ready to switch to JSON, the same datamapper handles that transition too -- no backend rewiring needed.

## What the Demo Shows

- **Modern storefront** -- a clean shopping basket UI served by Apache Camel, where customers browse products and place orders.
- **EDI under the hood** -- clicking "Place Order" builds and sends a valid X12 850 Purchase Order to a backend Camel integration service.
- **Backend processing** -- the backend ingests the EDI, uses a visual datamapper to transform it into XML, stores the transaction in a database, and generates a PDF invoice.
- **Invoice delivery** -- the frontend receives a link to the generated invoice and presents it to the customer.
- **Customer support** -- a floating chat button connects customers to a messaging platform where they can request order modifications or refunds.

## How the UI Works

The entire frontend is a single `index.html` file with no external dependencies.

- Products are displayed with an empty basket. The customer adjusts quantities using +/- buttons.
- "Place Order" is disabled until at least one item is added.
- On submit, the page constructs an EDI X12 850 message from the basket contents and POSTs it to `/ingest/x12`.
- On success, an invoice card slides in with a link to download the PDF. The button switches to "Start New Order", which resets the basket and clears the invoice.
- The customer support chat URL is loaded from `/api/config`, which reads the `support.url` property from `application.properties`.
- An expandable "EDI X12 850 Preview" section at the bottom lets presenters show the raw EDI being generated in real time as items are added.
