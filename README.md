# Signal Room

A clickable prototype of **Signal** — an ambient agent for mid-level managers.

Signal follows a manager across Zoom, Jira, Slack and Gmail, reconstructs one
project from signals scattered across all four, and surfaces only the decision
that needs attention. It is not a dashboard and not a chatbot.

> Signal notices what needs your attention. Signal Room helps you decide.

## The demo

Scenario: **NAS Storage Expansion** — should Vendor A's deployment be approved
this quarter? Stage 3 of 5, currently **PENDING**.

1. Connect Zoom and Gmail, then Continue — Signal shrinks into the corner.
2. Switch apps in the dock. Zoom keeps Signal *on ear*; Gmail, Jira and Slack
   make it *digest*, then the chip reads **3**.
3. Click the orb → Decision Peek → Open project.
4. **Overview** — leadership intent vs execution reality, and the gap between.
5. **Timeline** — one project rebuilt from four tools, newest first.
6. **Evidence** — traces "Security should be okay" back 2 hops to someone who
   never said it.
7. **Stakeholders** — the Authority Map. The CEO holds the highest authority on
   the board and deliberately *no* standing on security compliance.
8. **Ask Security** → approve the draft → Sarah answers directly → the project
   updates everywhere at once.
9. **Decision** — Signal recommends, the manager decides.

Right-click the orb to put Signal to sleep. Click the wallpaper to start over.

## Three ideas the prototype argues for

- **Authority is contextual, not hierarchical.** Each dimension of a decision
  has its own final authority; seniority does not override it.
- **Source distance.** Evidence is tagged Direct (0 hops), Relayed (1),
  Indirect (2+) or Inferred. Authority and source distance are separate axes.
- **Voice coverage.** Signal names whose input is missing, rather than
  presenting partial data as complete.

## Running it

`index.html` is self-contained apart from two files beside it — open it
directly or serve the folder statically. No build step and no dependencies.

| file | |
|---|---|
| `index.html` | the whole prototype: markup, styles and logic |
| `runtime.js` | ~140-line renderer: `{{holes}}`, `sc-if`, `sc-for`, events |
| `wallpaper.webp` | desktop background |
| `icon-*.svg` | the source Signal icons the orb states are drawn from |

Typeface is Archivo (Google Fonts); it falls back to the system sans if that
does not load.
