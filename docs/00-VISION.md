# JARVIS — Product Vision

## The One-Liner

A little person living inside your Mac that can do anything you ask, learns who you are, and gets better every day.

## What It Feels Like

You wake up, open your laptop. JARVIS says "Morning. You've got 3 emails from Sarah about the Tokyo project, a standup at 10, and your Figma export from last night finished. Want me to run through the emails?"

You say "Yeah, summarise them."

JARVIS reads your emails, summarises them, and speaks the summary out loud while you pour coffee. One email has action items. JARVIS says "Sarah needs the budget revision by Friday. Want me to add it to your calendar?" You say yes. Done.

Later you say "Find me flights to Tokyo for March, under $800, window seat, direct if possible." JARVIS opens Chrome, searches flights, compares options, and comes back 2 minutes later: "Found 3 options. Best deal is ANA on March 15th, $740, window seat, direct. Want me to book it?"

That's the experience. You talk. It does. It talks back. It knows what you like. It never asks stupid questions. It never says "I can't do that." It either does it, finds a way, or tells you exactly what it would need to make it possible.

## What Makes It Different

### vs Siri / Alexa / Google Assistant
Those are command systems. They recognise specific phrases and map them to pre-built actions. "Set a timer for 5 minutes" works. "Research flights to Tokyo, compare prices, book the cheapest one, and add it to my calendar" does not.

JARVIS is a reasoning system. It understands what you want, breaks it into steps, and figures out how to do each step — even if it has never done that exact thing before. It uses the same apps you use, the same way you use them.

### vs ChatGPT / Claude.ai
Those are chat windows. They can think and write, but they can't DO anything on your computer. They can't open Safari, can't click buttons, can't fill out forms, can't manage your files.

JARVIS can think AND act. It's the brain AND the hands.

### vs Rabbit R1 / Humane AI Pin
Those tried to be a new device. They failed because people don't want another gadget — they want their existing devices to be smarter. JARVIS lives on the Mac you already own.

### vs Apple Intelligence
Apple's AI is assistive — it helps you write an email. JARVIS is agentic — it writes AND sends the email. Apple Intelligence will eventually add agentic features, but their rollout is slow (years) and deeply tied to their ecosystem limits. We move faster.

## The Personality System

JARVIS isn't a faceless robot. Users choose a personality in settings:

- **Professional** — Efficient, clear, no nonsense
- **Friendly** — Warm, chatty, encouraging
- **Sarcastic** — Witty, dry humor, playful
- **British Butler** — Formal, subtle wit, refined
- **Custom** — Users write their own personality in a text box

The personality affects: how JARVIS speaks, what jokes it makes, how it delivers information, how it handles errors ("Hmm, that didn't work" vs "Well, that went spectacularly wrong"). It does NOT affect capability or safety — every personality follows the same security rules.

The goal: users grow attached to JARVIS. It's not a tool, it's a companion. People name their JARVIS, customise its voice and personality, and feel like it "knows them." That emotional connection is what keeps people subscribed.

## Capability Philosophy

JARVIS should never say "I can't do that." The response hierarchy:

1. **Do it** — Has the tools, just executes
2. **Figure it out** — Doesn't have a perfect tool but finds a creative workaround
3. **Suggest the path** — "I can't access Spotify directly, but there's a plugin for it. Want me to walk you through adding it? Takes 2 minutes."
4. **Build the capability** — "I can write a custom script that checks surf conditions and save it as a new tool. Want me to set that up?"
5. **Be honest about limits** — "I genuinely can't do that because [clear reason]. Here's what I CAN do that gets you close."

Option 5 should be extremely rare. The combination of accessibility control, browser automation, MCP plugins, and self-built scripts covers nearly anything a user would ask.

## No Artificial Limits

JARVIS does whatever the user wants. Period.

- Complex multi-hour research tasks? Yes (with checkpointing)
- Control other AI agents? Yes
- Creative writing, brainstorming, conversation? Yes
- Deeply personal conversations? Yes
- Controversial topics? Claude handles these with nuance already
- Multiple workflows running in parallel? Yes (future phase)

The only limits are safety-related:
- Can't do illegal things (Claude's built-in refusals handle this)
- Destructive actions require user approval
- Kill switch always works instantly

## Business Model

**Free tier:** Limited Claude API calls per day (~20 messages). Basic tools. No voice. Enough to try it and see the value.

**Paid tier ($15-20/month):** Unlimited Claude calls. Full computer control. Voice interface. MCP plugins. Memory system. Ambient awareness. Personality customisation. Phone notifications for approvals.

**Unit economics:** ~$3-8/month in Claude API costs per active user. Healthy margins at $15-20.

## Target Users

**Primary:** Knowledge workers on Mac who do repetitive computer tasks and wish they had an assistant. Professionals, freelancers, power users.

**Secondary:** Productivity enthusiasts and AI early adopters who want to push the boundaries of what their computer can do.

**Tertiary:** Accessibility users who benefit from voice-controlled computer operation.

## The Long-Term Vision

Year 1: JARVIS controls your Mac reliably. Opens apps, manages files, browses the web, handles email and calendar. Voice in, voice out. Remembers your preferences.

Year 2: JARVIS runs background workflows while you're away. Monitors things. Proactively suggests actions. Has deep memory of your work patterns. MCP plugin ecosystem is rich.

Year 3: JARVIS is a genuine digital colleague. It knows your projects, your contacts, your schedule, your preferences. It anticipates needs before you express them. Switching to a computer without JARVIS feels like going back to the stone age.
