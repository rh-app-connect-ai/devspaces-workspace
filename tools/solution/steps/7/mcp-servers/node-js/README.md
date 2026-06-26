# MCP Get PDF URL Server

A Model Context Protocol (MCP) server that provides invoice PDF URL retrieval functionality using **Streamable HTTP** transport in **stateless mode** (compatible with langchain4j MCP clients).

## Tool

### getInvoicePDFurl

Get the PDF URL of an invoice by its ID.

**Parameters:**
- `id` (string, required): The invoice ID

**Returns:**
- A string containing the PDF URL for the specified invoice

## Installation

```bash
npm install
```

## Configuration

The server can be configured via `application.properties` file or environment variables (env vars take precedence).

**application.properties:**
```properties
# MCP Server Configuration
server.port=9090

# S3 Configuration
s3.access.key=YOUR_ACCESS_KEY
s3.secret.key=YOUR_SECRET_KEY
s3.endpoint=https://s3-endpoint.example.com
s3.bucket=your-bucket-name
s3.region=us-east-1
s3.presigned.url.expiry=3600
```

**Environment variables:**
- `PORT` - Server port (default: 9090)
- `S3_ACCESS_KEY` - S3 access key
- `S3_SECRET_KEY` - S3 secret key
- `S3_ENDPOINT` - S3 endpoint URL
- `S3_BUCKET` - S3 bucket name
- `S3_REGION` - S3 region (default: us-east-1)
- `PRESIGNED_URL_EXPIRY` - Presigned URL expiration in seconds (default: 3600)

## Usage

### Running the server

```bash
npm start
```

The server runs on port **9090** by default (to avoid clashing with port 9090).

You can change the port using the PORT environment variable:

```bash
PORT=9092 npm start
```

### Configuring in your MCP Client

Use the following URL to configure your MCP client:

```
http://localhost:9090/mcp
```

For MCP clients that support Streamable HTTP, add this configuration:

```json
{
  "mcpServers": {
    "invoice-pdf": {
      "url": "http://localhost:9090/mcp"
    }
  }
}
```

**Transport Protocol:** This server uses **Streamable HTTP** transport, the current MCP standard for remote/HTTP-based servers.

**Note:** This server uses port 9090 to avoid clashing with your existing MCP server on port 9090.

### Health Check

You can verify the server is running by accessing:

```
http://localhost:9090/health
```

## Transport Details

This MCP server uses **Streamable HTTP** transport in **stateless mode**:
- Each request creates a new server instance (no session state)
- Compatible with langchain4j MCP clients
- Supports POST request/response for JSON-RPC messages
- Suitable for cloud deployment and multi-client scenarios

**Stateless mode** (`sessionIdGenerator: undefined`) means:
- No session IDs are tracked
- Each request is independent
- No in-memory session state
- Ideal for serverless/stateless deployments

**Alternative:** For stateful mode with session management, use `sessionIdGenerator: () => randomUUID()` to track persistent sessions.

## Implementation Notes

- **S3 Object Key Pattern**: Invoice PDFs are expected to be stored with the key pattern `invoice_{id}.pdf`
- **Presigned URLs**: The server generates presigned S3 URLs that expire after the configured time (default 1 hour)
- **S3-Compatible Storage**: Works with AWS S3 and S3-compatible storage (like OpenShift storage, MinIO, etc.)
