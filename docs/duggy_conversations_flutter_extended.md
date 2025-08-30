# Duggy Conversations - Flutter App PRD (Extended Message Types)

## Overview
Duggy Conversations already supports JSON-based messages (`{ "type": "text", "body": "..." }`).  
We are extending the Flutter app to handle new message types:  
- Image  
- Text with images  
- Link (URL previews)  
- Emoji-only messages  
- GIFs  
- Documents (PDF, Word, etc.)  

The API already supports these via `content` JSON. The Flutter app must handle sending, rendering, caching, and offline sync.

---

## Message Types & Content Format

1. **Text** (already implemented)
   ```json
   { "type": "text", "body": "Hello team" }
   ```

2. **Image**
   ```json
   { "type": "image", "url": "https://cdn.duggy.app/abc.jpg", "caption": "Team photo" }
   ```

3. **Text with Images**
   ```json
   { 
     "type": "text_with_images", 
     "body": "Great win today!", 
     "images": ["https://cdn.duggy.app/1.jpg", "https://cdn.duggy.app/2.jpg"] 
   }
   ```

4. **Link**
   ```json
   { "type": "link", "url": "https://espncricinfo.com/match123", "title": "Match Report", "description": "Brief summary...", "thumbnail": "https://cdn.link/thumb.png" }
   ```

5. **Emoji**
   ```json
   { "type": "emoji", "body": "🔥👏🏏" }
   ```

6. **GIF**
   ```json
   { "type": "gif", "url": "https://giphy.com/xyz.gif" }
   ```

7. **Document**
   ```json
   { "type": "document", "url": "https://cdn.duggy.app/match_rules.pdf", "name": "Tournament Rules.pdf", "size": "2MB" }
   ```

---

## App Behavior

### Sending
- User selects message type via composer (text field, file picker, image picker, emoji/GIF selector).
- Construct correct JSON and send to API.
- Optimistic UI update (✓ tick).
- Status updates (✓, ✓✓, ✓✓ blue).

### Rendering
- **Text** → Markdown renderer.  
- **Image** → Cached image preview, tap → full screen.  
- **Text with Images** → Show text + image grid.  
- **Link** → Generate preview card with title, description, thumbnail.  
- **Emoji** → Render in large size (emoji bubble).  
- **GIF** → Embedded animated player (autoplay in viewport).  
- **Document** → Show file icon, name, size, tap → open/download.  

### Offline Storage
- Local DB stores raw JSON `content`.  
- Assets (images, gifs, docs) cached in device storage for offline access.  
- Sync pushes unsent messages and fetches new ones.  

---

## Background Sync
- Same loop as before (poll every X seconds/minutes).
- Ensure non-text assets (images/docs) are cached progressively.  
- Retry uploads for images/docs if offline.  

---

## Phases

### Phase 1 - UI/Rendering
- Extend message bubble renderer to handle `image`, `text_with_images`, `link`, `emoji`, `gif`, `document`.
- Add UI components for each type.

### Phase 2 - Composer
- Add input tools:  
  - File picker (documents, images).  
  - Image upload with caption.  
  - Emoji picker.  
  - GIF search (e.g. GIPHY API).  
  - Auto-detect links in text → render as `link`.  

### Phase 3 - Offline & Sync
- Local DB stores JSON content.  
- Cache files/images/GIFs locally.  
- Retry upload for media/documents on reconnect.  
