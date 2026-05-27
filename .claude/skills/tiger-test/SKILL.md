---
name: tiger-test
description: Search Google for pictures of tigers and return the domain of the first result
user-invocable: true
argument-hint: ""
allowed-tools: Bash
chrome: true
prerequisites:
  - chrome-open
---

# Tiger Test

Search Google for pictures of tigers using Chrome and return the domain of the first result.

## IMPORTANT: No fallbacks

If Chrome MCP tools are unavailable, output `ERROR: Chrome MCP tools not available` and stop immediately.

## Steps

### 1. Navigate to Google search

Use `mcp__claude-in-chrome__navigate` to go to:
```
https://www.google.com/search?q=pictures+of+tigers
```

### 2. Extract the first result domain

Use `mcp__claude-in-chrome__javascript_tool` to extract the domain of the first search result:

```javascript
(() => {
  const first = document.querySelector('#search a[href^="http"]');
  if (!first) return 'ERROR: no result found';
  return new URL(first.href).hostname;
})()
```

### 3. Output

Output `SUCCESS: <domain>` where `<domain>` is the hostname of the first result.
