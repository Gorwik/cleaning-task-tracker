# Frontend Serving from PostgreSQL: Asset Storage, Serving, and Integration

## Overview
You can serve HTML, CSS, JS, and other static assets directly from PostgreSQL using PostgREST and custom SQL functions. This enables versioned, auditable, and dynamic frontend delivery.

## Asset Storage
- Store HTML/CSS/JS in a dedicated table (e.g., `frontend_assets`)
- Use columns for asset name, content type, content, created/updated timestamps

**Example Table:**
```sql
CREATE TABLE app_frontend.frontend_assets (
    asset_id SERIAL PRIMARY KEY,
    asset_name VARCHAR(255) UNIQUE NOT NULL,
    content_type VARCHAR(100) NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

## Serving Functions
- Use SQL functions to serve assets with correct content-type and cache headers
- Example: `serve_html`, `serve_css`, `serve_js`

**Example Function:**
```sql
CREATE OR REPLACE FUNCTION app_functions.serve_html(p_asset_name TEXT DEFAULT 'index.html')
RETURNS TEXT AS $$
DECLARE
  v_content TEXT;
  v_content_type TEXT;
BEGIN
  SELECT content, content_type INTO v_content, v_content_type
  FROM app_frontend.frontend_assets
  WHERE asset_name = p_asset_name;
  IF v_content IS NULL THEN
    PERFORM set_config('response.status', '404', true);
    RETURN 'Asset not found';
  END IF;
  PERFORM set_config('response.headers', 'Content-Type: ' || v_content_type || '; charset=utf-8', true);
  PERFORM set_config('response.headers', 'Cache-Control: public, max-age=3600', true);
  RETURN v_content;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

## Security Considerations
- Set strict Content Security Policy (CSP) headers
- Use `SECURITY DEFINER` for serving functions
- Validate asset names and types

## Integration Patterns
- Use JavaScript API client to fetch assets and data from PostgREST endpoints
- Example: `fetch('/rpc/serve_html?asset_name=index.html')`

## Best Practices
- Version assets for rollback and audit
- Use caching and ETag headers for performance
- Separate frontend and backend schemas for security

## Navigation
- [Knowledge Base Home](./README.md)
- [Project README](../README.md) 