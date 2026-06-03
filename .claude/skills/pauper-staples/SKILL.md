---
name: pauper-staples
description: >
  Scrapes MTG Pauper staples data from mtgdecks.net using Chrome, then updates
  the Pauperfall repo with fresh card popularity scores and deck counts.
user-invocable: true
argument-hint: ""
allowed-tools: Bash, Read, Write, Edit
---

# Pauper Staples Scraper

Scrape MTG Pauper card staples from mtgdecks.net using Claude in Chrome,
then update the Pauperfall repository with fresh data.

## IMPORTANT: No fallbacks

If the Chrome MCP tools are unavailable or any scraping step fails, output
`ERROR:` with a description and **stop immediately**. Do NOT attempt alternative
download methods, HTTP scraping, or any other fallback. It is far better to fail
and alert than to commit wrong data.

## Steps

### 1. Navigate and load all cards

Use the `mcp__claude-in-chrome__navigate` tool to go to:
```
https://mtgdecks.net/Pauper/staples
```

Then use `mcp__claude-in-chrome__javascript_tool` to click the "Load More"
button repeatedly until ALL cards are loaded. Use this JavaScript approach:

```javascript
(async () => {
  const isButtonVisible = () => {
    const btn = document.querySelector('button#ajaxMore');
    if (!btn) return false;
    const style = window.getComputedStyle(btn);
    return style.display !== 'none' && style.visibility !== 'hidden' && btn.offsetParent !== null;
  };
  while (isButtonVisible()) {
    document.querySelector('button#ajaxMore').click();
    await new Promise(r => setTimeout(r, 2000));
  }
  return document.querySelectorAll('#loadMoreCardsRow > div').length + ' cards loaded';
})()
```

**Done condition:** All cards are loaded when `button#ajaxMore` is no longer visible
on the page (the site hides it once there are no more results).

**Important:** The page loads ~100 cards at a time. There are ~4400+ cards total,
so this will take many clicks. If the javascript_tool has a timeout, break it into
multiple calls — click several times per call, then check if the button is still visible.

### 2. Extract card data

Once all cards are loaded, use `mcp__claude-in-chrome__javascript_tool` to extract
the data:

```javascript
(() => {
  const cards = document.querySelectorAll('#loadMoreCardsRow > div');
  const result = {};
  cards.forEach(card => {
    const nameEl = card.querySelector('b.text-center');
    const btns = card.querySelectorAll('div.btn-group div.btn');
    if (!nameEl || btns.length < 3) return;
    const name = nameEl.textContent.trim();
    const popularity = parseInt(btns[0].textContent.replace(/[^0-9]/g, ''), 10);
    const decks = parseInt(btns[2].textContent.replace(/[^0-9]/g, ''), 10);
    if (name && !isNaN(popularity) && !isNaN(decks)) {
      result[name] = { popularityScore: popularity, decks: decks };
    }
  });
  return JSON.stringify(result);
})()
```

### 3. Sort and format

Sort the extracted data by `popularityScore` descending, then by `decks` descending.
Write it as pretty-printed JSON (2-space indent) to:
```
.claude/skills/pauper-staples/repos/pauperfall/public/mtg_pauper_staples.json
```

The format must be:
```json
{
  "Card Name": {
    "popularityScore": 100,
    "decks": 24549
  },
  ...
}
```

### 4. Validate

After writing, verify:
- The file is valid JSON
- It contains at least 4000 cards
- The first entry has the highest popularity score
- Each entry has both `popularityScore` (number) and `decks` (number)

If validation fails, output `ERROR:` and do NOT proceed to commit.

### 5. Commit and push

```bash
cd .claude/skills/pauper-staples/repos/pauperfall
git add public/mtg_pauper_staples.json
git commit -m "Update pauper staples data from mtgdecks.net"
git push
```

### 6. Output

On success output:
```
SUCCESS: Updated <N> cards. Top 5: <card1>, <card2>, <card3>, <card4>, <card5>
```

If any step fails, output `ERROR: <description>` and stop.
