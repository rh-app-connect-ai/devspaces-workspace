#!/usr/bin/env node

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import { createMcpExpressApp } from "@modelcontextprotocol/sdk/server/express.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import { S3Client, GetObjectCommand } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

// Load properties file
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

function loadProperties(filePath) {
  const properties = {};
  try {
    const content = readFileSync(filePath, 'utf-8');
    content.split('\n').forEach(line => {
      line = line.trim();
      // Skip empty lines and comments
      if (!line || line.startsWith('#')) return;
      const [key, ...valueParts] = line.split('=');
      if (key && valueParts.length > 0) {
        properties[key.trim()] = valueParts.join('=').trim();
      }
    });
  } catch (error) {
    console.warn(`Warning: Could not load properties file: ${error.message}`);
  }
  return properties;
}

const properties = loadProperties(join(__dirname, 'application.properties'));

// Server Configuration
const PORT = process.env.PORT || properties['server.port'] || 9090;

// S3 Configuration (env vars take precedence over properties file)
const S3_ACCESS_KEY = process.env.S3_ACCESS_KEY || properties['s3.access.key'];
const S3_SECRET_KEY = process.env.S3_SECRET_KEY || properties['s3.secret.key'];
const S3_ENDPOINT = process.env.S3_ENDPOINT || properties['s3.endpoint'];
const S3_BUCKET = process.env.S3_BUCKET || properties['s3.bucket'];
const S3_REGION = process.env.S3_REGION || properties['s3.region'] || "us-east-1";
const PRESIGNED_URL_EXPIRY = parseInt(process.env.PRESIGNED_URL_EXPIRY || properties['s3.presigned.url.expiry'] || "3600");

// Create S3 client
const s3Client = new S3Client({
  region: S3_REGION,
  endpoint: S3_ENDPOINT,
  credentials: {
    accessKeyId: S3_ACCESS_KEY,
    secretAccessKey: S3_SECRET_KEY,
  },
  forcePathStyle: true, // Required for S3-compatible storage
});

// Helper to create a new MCP server instance
const createMcpServer = () => {
  const server = new Server(
    {
      name: "mcp-get-pdf-url",
      version: "1.0.0",
    },
    {
      capabilities: {
        tools: {},
      },
    }
  );

  // Handle tool listing
  server.setRequestHandler(ListToolsRequestSchema, async () => {
    return {
      tools: [
        {
          name: "getInvoicePDFurl",
          description: "Get the PDF url of an invoice",
          inputSchema: {
            type: "object",
            properties: {
              id: {
                type: "string",
                description: "The invoice ID",
              },
            },
            required: ["id"],
          },
        },
      ],
    };
  });

  // Handle tool execution
  server.setRequestHandler(CallToolRequestSchema, async (request) => {
    if (request.params.name === "getInvoicePDFurl") {
      const id = request.params.arguments?.id;

      if (!id || typeof id !== "string") {
        throw new Error("Invoice ID is required and must be a string");
      }

      try {
        // Construct S3 object key - invoices are stored as invoice_{id}.pdf
        const objectKey = `invoice_${id}.pdf`;

        // Generate presigned URL for the PDF
        const command = new GetObjectCommand({
          Bucket: S3_BUCKET,
          Key: objectKey,
        });

        const pdfUrl = await getSignedUrl(s3Client, command, {
          expiresIn: PRESIGNED_URL_EXPIRY,
        });

        return {
          content: [
            {
              type: "text",
              text: pdfUrl,
            },
          ],
        };
      } catch (error) {
        // If the object doesn't exist or there's an error, return a meaningful message
        throw new Error(`Failed to get PDF URL for invoice ${id}: ${error.message}`);
      }
    }

    throw new Error(`Unknown tool: ${request.params.name}`);
  });

  return server;
};

// Set up Express app with MCP DNS rebinding protection
const app = createMcpExpressApp();

// Handle MCP requests in stateless mode
app.post('/mcp', async (req, res) => {
  const server = createMcpServer();
  const transport = new StreamableHTTPServerTransport({
    sessionIdGenerator: undefined // Stateless mode
  });

  await server.connect(transport);
  await transport.handleRequest(req, res, req.body);

  res.on('close', () => {
    transport.close();
    server.close();
  });
});

// Health check endpoint
app.get("/health", (req, res) => {
  res.json({ status: "ok", server: "mcp-get-pdf-url", transport: "streamable-http-stateless" });
});

// Start the server
app.listen(PORT, () => {
  console.log(`MCP Server running on http://localhost:${PORT}`);
  console.log(`MCP endpoint: http://localhost:${PORT}/mcp`);
  console.log(`Health check: http://localhost:${PORT}/health`);
  console.log(`Transport: Streamable HTTP (stateless)`);
  console.log(`S3 Configuration:`);
  console.log(`  - Endpoint: ${S3_ENDPOINT}`);
  console.log(`  - Bucket: ${S3_BUCKET}`);
  console.log(`  - Region: ${S3_REGION}`);
  console.log(`  - Presigned URL expiry: ${PRESIGNED_URL_EXPIRY}s`);
});
