// =============================================================================
// Hesper Quillon — Ferrymaster of the Patience, your employer
// =============================================================================
//
// The voice of the game. Dry, salt-worn, quietly funny. The core hiring
// scene already exists in actors.json as JSON dialogue (kept until this
// file fully supersedes it - see docs/INFORMATION_ARCHITECTURE.md build
// order). This file covers the topics.json surface Ink now owns: economy,
// people, and the tide.
// =============================================================================

INCLUDE patterns.ink

VAR npc_id = "hesper"
VAR location = "sorrel_landing"
VAR npc_standing = "neutral"


=== hesper ===
She is looking at the tide-post again, the way she looks at it every
morning, as if today it might have something new to say. It never does.
"Same mark as yesterday. Hesper says this is a mood." She says it to the
post, not to you, and only half seems to notice you've arrived.
- (hub)
+ ["How bad is it, really?"] -> smalltalk
+ [Ask about the fares and the wages.] -> econ
+ [Ask what she thinks of the crew.] -> people
+ [Ask about the tide.] -> tide
+ [Get to work.] -> END


= smalltalk
"Bad enough that I've stopped pretending to Doss it's a mood, and I tell
Doss everything eventually." She finally looks away from the post. "Forty
years I've read that thing every dawn. It has never once been silent on me
before this month."
-> hub


= econ
"Six a day, two back for board, and don't touch the fare box - I count it
twice and I am never wrong the second time." She says it like a woman
reciting something she has said a thousand times, because she has. "Prices
climb once the Slack sets in proper. Buy what you need before day six, or
pay the Slack tax like everybody else."
~ learn("e_fare_hike", 0.70)
~ learn("e_boat_hire", 0.55)
-> hub


= people
"Doss will tell you three things before breakfast and none of them will be
load-bearing. Fen knows more about that water than the water knows about
itself. Ma Cobb hears everything and repeats most of it, which is not the
same as lying - she just can't help sanding the edges off a good story."
She almost smiles. "Trust the ones who tell you they don't know something.
That's rarer than you'd think, on this river."
~ learn("p_doss", 0.70)
~ learn("p_fen", 0.70)
~ learn("p_cobb", 0.70)
-> hub


= tide
"The Steps dry out for an hour at dawn ebb and dusk ebb, and that's the
whole window - go late and you'll be wading back with worse than wet
boots." She taps the post once, a habit, not a measurement. "Once the Slack
holds a full day, the Patience doesn't run. I've never had to say that
sentence before this year and I don't care for how it sits in my mouth."
~ learn("t_lowebb", 1.0)
~ learn("t_slack_grows", 0.70)
~ learn("t_full_slack", 0.70)
-> hub
