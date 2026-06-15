---
name: flight-search
description: >
  Search Expedia and Google Flights for flight options based on user's travel
  dates and time preferences. Sends a ranked report via sapo notify with prices,
  options that match the user's constraints, and cheaper alternatives that may
  violate those constraints.
user-invocable: true
argument-hint: "[origin] [destination] [outbound-date] [return-date]"
allowed-tools: Bash, mcp__claude-in-chrome__tabs_context_mcp, mcp__claude-in-chrome__tabs_create_mcp, mcp__claude-in-chrome__navigate, mcp__claude-in-chrome__read_page, mcp__claude-in-chrome__javascript_tool, mcp__claude-in-chrome__browser_batch, mcp__claude-in-chrome__find, mcp__claude-in-chrome__get_page_text
---

# Flight Search

Search Expedia and Google Flights for flights matching the user's travel preferences,
then deliver a ranked report via `sapo notify`.

## IMPORTANT: No fallbacks

If Chrome MCP tools are unavailable or a search step fails, output `ERROR: <description>`
and stop immediately. Do NOT invent or guess flight prices or links.

## Step 0: Gather travel details

Use `AskUserQuestion` to collect all required details in a single prompt. Ask:

1. **Origin** — departure city or airport code (e.g. "New York" or "JFK")
2. **Destination** — arrival city or airport code
3. **Outbound date** — date of departure (YYYY-MM-DD)
4. **Return date** — date of return, or "one-way" if not round trip
5. **Preferred departure time** — e.g. "morning (before noon)", "afternoon (noon–6pm)", "evening (after 6pm)", or "no preference"
6. **Preferred return time** — same options, or "no preference"
7. **Number of passengers** — adults (default 1)
8. **Cabin class** — Economy, Premium Economy, Business, or First (default Economy)

If the user provided arguments when invoking the skill (origin, destination, outbound-date,
return-date), pre-fill those and only ask for the remaining details.

## Step 1: Get a browser tab

Use `mcp__claude-in-chrome__tabs_context_mcp` (with `createIfEmpty: true`) to get a tab.
Create a new tab with `mcp__claude-in-chrome__tabs_create_mcp` for this search session.
Remember the tab ID for all subsequent browser steps.

## Step 2: Search Google Flights

### 2a. Navigate to Google Flights

Build the Google Flights URL using the collected parameters:

```
https://www.google.com/travel/flights/search?tfs=CBwQAhoeEgoyMDI1LTA3LTE1agcIARIDSkZLcgcIARIDTEFYGh4SCjIwMjUtMDctMjJqBwgBEgNMQVhyBwgBEgNKRksqAggB
```

Actually, navigate directly to:
```
https://www.google.com/travel/flights
```

Then use `mcp__claude-in-chrome__javascript_tool` to fill in the search form, or use
`mcp__claude-in-chrome__find` to locate and interact with the input fields.

Google Flights search approach:
- Navigate to `https://www.google.com/travel/flights`
- Use `mcp__claude-in-chrome__read_page` with `filter: "interactive"` to find form fields
- Fill origin, destination, dates, passenger count, cabin class
- Submit the search
- Wait for results (use `mcp__claude-in-chrome__javascript_tool` with a small delay if needed)

### 2b. Extract Google Flights results

After results load, use `mcp__claude-in-chrome__javascript_tool` to extract flight data:

```javascript
(() => {
  const results = [];
  // Flight result cards — selector may vary, use what's present in the DOM
  const cards = document.querySelectorAll('[data-ved] li, .pIav2d, ul[role="list"] li');
  cards.forEach((card, i) => {
    if (i >= 20) return; // cap at 20 results
    const text = card.innerText;
    if (!text || text.length < 20) return;
    results.push(text.trim().substring(0, 500));
  });
  return JSON.stringify(results);
})()
```

If the JS extraction doesn't work well, fall back to `mcp__claude-in-chrome__get_page_text`
and parse the visible text content to identify flight options, airlines, times, prices, and stops.

Also capture the current URL after search (it contains search parameters useful for the
booking link).

### 2c. Capture the Google Flights search URL

After results load, run:
```javascript
window.location.href
```
Save this as `google_flights_url` — it's the link to include in the report.

## Step 3: Search Expedia Flights

### 3a. Navigate to Expedia Flights

Navigate to Expedia flights search. Build the URL directly if possible, otherwise navigate
to `https://www.expedia.com/Flights` and fill the form.

Direct URL format for Expedia round-trip:
```
https://www.expedia.com/Flights-Search?trip=roundtrip&leg1=from:{ORIGIN},to:{DEST},departure:{DATE}TANYT&leg2=from:{DEST},to:{ORIGIN},departure:{RETURN_DATE}TANYT&passengers=adults:{ADULTS},children:0,infantsinlap:0&options=cabinclass:{CLASS}&mode=search
```

Where:
- `{ORIGIN}` / `{DEST}` = airport codes or city names
- `{DATE}` / `{RETURN_DATE}` = date in `MM/DD/YYYY` format
- `{ADULTS}` = number of adult passengers
- `{CLASS}` = `coach`, `premiumcoach`, `business`, or `first`

For one-way: use `trip=oneway` and only `leg1`.

### 3b. Extract Expedia results

After results load, use `mcp__claude-in-chrome__get_page_text` to get visible text, then
parse it to identify:
- Airline name
- Departure time and arrival time
- Number of stops and layover info
- Total price (per person and total)
- Duration

Also try JS extraction:
```javascript
(() => {
  const cards = document.querySelectorAll('[data-test-id="offer-listing"], .uitk-card, [class*="FlightCard"]');
  const results = [];
  cards.forEach((card, i) => {
    if (i >= 20) return;
    results.push(card.innerText.trim().substring(0, 600));
  });
  return JSON.stringify(results);
})()
```

### 3c. Capture the Expedia search URL

Save `window.location.href` as `expedia_url`.

## Step 4: Compile and rank results

From the raw extracted text, parse and structure each flight option:

```
{
  airline: string,
  departure_time: string,         // e.g. "8:30 AM"
  arrival_time: string,
  return_departure_time: string,  // for round trips
  return_arrival_time: string,
  stops: string,                  // "Nonstop", "1 stop", "2 stops"
  duration: string,               // e.g. "5h 30m"
  price: number,                  // total price in USD
  source: "Expedia" | "Google Flights",
  booking_url: string,            // direct link to purchase
  matches_time_pref: boolean      // true if departure time matches user's preference
}
```

**Time preference matching:**
- Morning = departs before 12:00 PM
- Afternoon = departs 12:00 PM – 6:00 PM
- Evening = departs after 6:00 PM

**Deduplication:** If the same flight (same airline, times, price) appears on both
Expedia and Google Flights, keep both links but show it as one entry.

**Ranking:**
1. Flights matching the user's time preference, sorted by price ascending
2. Flights NOT matching the user's time preference (cheaper alternatives), sorted by price ascending

## Step 5: Format and send the report

Build a report message and send it via `sapo notify`. Keep it concise — this goes to
a notification. Use this format:

```
✈️ {ORIGIN} → {DEST} | {OUTBOUND_DATE}{RETURN_DATE_PART} | {ADULTS} pax

✅ PREFERRED OPTIONS (departs {TIME_PREF}):
1. {Airline} {dep}→{arr} {stops} {duration} — ${price}
   🔗 Expedia: {url}  |  Google: {url}
2. ...
(up to 5 preferred options)

💸 CHEAPER ALTERNATIVES (outside preferred time):
1. {Airline} {dep}→{arr} {stops} {duration} — ${price}
   🔗 Expedia: {url}  |  Google: {url}
2. ...
(up to 3 cheaper alternatives)

Searched: {timestamp}
```

If NO options match the time preference, skip the preferred section and label all
results as "ALL OPTIONS".

If only one source had results, note that in the report (e.g., "Note: Expedia returned
no results; showing Google Flights only").

Use:
```bash
sapo notify "{message}"
```

## Step 6: Output

On success: `SUCCESS: Report sent. Found {N} preferred + {M} alternative flights.`
On failure: `ERROR: <description>`
