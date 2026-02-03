# Future Development Ideas

A collection of potential enhancements and investigations for MatrixRain Screensaver.

---

## 🖥️ Intel Mac Compatibility

**Status:** Not implemented  
**Priority:** Medium  
**Effort:** ~15 minutes

### Current State
- Build targets Apple Silicon only (`arm64`/`arm64e`)
- macOS 14.0+ requirement (last version supporting Intel)

### Required Changes
1. Update Xcode project to build Universal Binary:
   ```
   ARCHS = "arm64 x86_64"
   ```
2. Update screensaver target:
   ```
   ARCHS = "arm64e x86_64"
   ```
3. Optionally lower deployment target to macOS 12.0 or 13.0 for broader Intel support
4. Test on Intel hardware or under Rosetta 2
5. Update README badges

### Trade-offs
- Binary size increases ~2x for Universal
- Intel Macs may have slower video export (limited hardware H.264 encoding)
- Need Intel Mac or Rosetta for testing

---

## 🔄 Seamless Video Loop

**Status:** Investigation needed  
**Priority:** Medium  
**Effort:** TBD

### Problem
When the screensaver video loops, there's a visible "jump" where the animation abruptly resets. This is noticeable for users watching the screensaver for extended periods.

### Proposed Solutions

#### Option 1: Fade to Black (Recommended First Try)
Let all columns naturally drain off the bottom of the screen before the loop point:
- Stop spawning new columns ~5 seconds before end
- Allow existing columns to complete their fall
- Brief black screen (~0.5s) before loop
- New columns spawn from top at video start
- **Pros:** Simple to implement, natural looking
- **Cons:** Brief interruption in the rain effect

#### Option 2: Crossfade Blend
Blend the last N seconds with the first N seconds during video export:
- Render extra frames at the end
- Alpha-blend end frames over start frames
- Creates smooth transition
- **Pros:** No visible cut point
- **Cons:** Complex export logic, potential visual artifacts during blend

#### Option 3: State Matching
Ensure the visual state at the end matches the start:
- Use deterministic RNG with fixed seed
- Calculate exact loop duration where column positions align
- **Pros:** Perfect seamless loop
- **Cons:** Constrains duration options, complex timing math

#### Option 4: Ping-Pong Playback
Play video forward, then backward:
- Modify AVPlayerLooper or create custom looping logic
- Doubles perceived video duration
- **Pros:** Easy to implement in player
- **Cons:** Reverse rain might look unnatural

#### Option 5: Long Crossfade in Player
Handle the transition in the screensaver player instead of export:
- Use two overlapping AVPlayerLayers
- Fade between them at loop point
- **Pros:** No export changes needed
- **Cons:** More complex player code, double memory usage

### Recommended Approach
Start with **Option 1 (Fade to Black)** as it's the simplest and most natural. Add a "Seamless Loop" toggle in export settings that:
1. Stops spawning new columns 5 seconds before end
2. Allows existing columns to drain
3. Adds 0.5s black padding at end

If that doesn't feel right, investigate **Option 5 (Player Crossfade)** next.

---

## 📋 Other Ideas

_Add future enhancement ideas below:_

- [ ] Audio support (optional ambient soundtrack)
- [ ] Multiple video profiles (switch between exported videos)
- [ ] Custom character sets (user-defined glyphs)
- [ ] Screen-specific settings for multi-monitor setups
- [ ] Menu bar quick-access for settings
