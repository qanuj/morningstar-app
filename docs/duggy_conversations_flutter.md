# Duggy Conversations - Flutter App PRD

## Overview
A new screen called "Conversations" where each club has a group chat.  
Messages must support JSON-based content format so we can later handle text, images, files, etc.  
Default is `{"type": "text", "body": "message here"}`.  

---

## Core Requirements
1. **Conversation Screen**
   - List of clubs → tap → open chat view.
   - Render message content based on `type`.
     - `type: text` → render markdown (bold, italic, underline, strikethrough, lists).
     - Future-proof: placeholder for `image`, `file`, `video`.
   - Input box sends content as JSON.

2. **Message Lifecycle**
   - On send → optimistic update with `{"type": "text", "body": "msg"}`.
   - Status ticks (✓, ✓✓, ✓✓ blue).
   - Update status from API responses.

3. **Offline Support**
   - Local DB schema stores `content` as JSON.
   - Background sync to push unsent messages and fetch new ones.
   - Full offline chat experience.

---

## Data Handling
- Example local storage entry:
  ```json
  {
    "messageId": "msg_001",
    "clubId": "club_123",
    "senderId": "user_123",
    "content": {
      "type": "text",
      "body": "Hello team!"
    },
    "createdAt": "2025-08-30T10:30:00Z",
    "status": "sent"
  }
  ```

---

## Background Sync
- Poll API every X seconds/minutes.
- Sync unsent → server.
- Fetch new messages → local DB.
- Merge into UI seamlessly.

---

## Phases

### Phase 1 - UI + Local DB
- Conversations screen.
- Message rendering (support `type: text` + markdown).
- Local DB with JSON content.

### Phase 2 - API Integration
- Hook POST/GET.
- Status tick updates.

### Phase 3 - Offline + Sync
- Background sync loop.
- Retry unsent messages.
- Expand renderer to handle other content types (images, etc.).
