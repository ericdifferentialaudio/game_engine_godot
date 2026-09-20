// =============================================================================
// Sister Wenna — bell-hermit, Cormorant Rocks
// =============================================================================
//
// Seed C's route, and the keeper of the Bell of Turning (gift: patience 7,
// nerve 4). Patient in the literal sense - she has been listening to
// something for longer than anyone else alive, and it has taught her not
// to rush an answer.
// =============================================================================

INCLUDE patterns.ink

VAR npc_id = "wenna"
VAR location = "cormorant_rocks"
VAR npc_standing = "neutral"


=== wenna ===
She sits with the Bell in her lap the way other people sit with a cat -
absent-mindedly, entirely used to its weight. "You came all this way to ask
a hermit a question. That's either very wise or very desperate. I find it's
usually both."
- (hub)
+ ["What are you listening for?"] -> smalltalk
+ [Ask about the creatures below.] -> beast
+ [Ask what she has witnessed at the Steps.] -> evidence
+ [Ask about the way through the cistern.] -> route
+ [Ask about the sluice, and who closes it.] -> case_q1
+ [Ask what begins the Long Slack.] -> case_q4
+ [Ask how to settle it, in the end.] -> case_q5
+ [Leave her to her listening.] -> END


= smalltalk
"Everything. That's the honest answer." She turns the Bell a half-turn in
her lap, unconsciously, the way Doon turns her wheel. "Most people listen
for what they expect to hear. I stopped expecting a long time ago. It's
made me a much better listener and a much worse guest at supper."
-> hub


= beast
"The wight that pleads is not lying to you - it remembers being a person,
and some part of it still believes that matters." She says it without
sentiment, a fact reported rather than mourned. "Lead it up gently and it
will follow. Strike it and you'll have only proven it right about what
people do." She is quieter on the Choir: "That one I would not fight even
if fighting worked. Fighting has never once worked on a thing that only
wants to be heard."
~ learn("b_wight_pleads", 0.70)
~ learn("b_choir_wick", 0.55)
-> hub


= evidence
"Stand on the Salt Steps at slack water and put your boots flat on the
stone. You'll feel it before you hear it - a hum, low, patient, older than
the Weir itself." She says this as a fact she has verified personally,
which she has. "Everyone who feels it names someone different for it. I
have stopped correcting them. Naming is how frightened people cope, and I
was frightened myself, once."
~ learn("ev_c_hum", 0.90)
-> hub


= route
"The cistern remembers a knock, if you bring salt and a light and the
patience not to hurry it." She sets the Bell aside, carefully, the way you
set aside something that has waited longer than you have been alive. "The
water there does not want to hurt you. It wants to be asked properly. Most
things do, in my experience, and most people never think to try."
~ learn("t_cistern_way", 0.70)
~ learn("r_cistern_knock", 0.55)
-> hub


= case_q1
"Nothing closes that sluice. Not a hand, not a paid crew, not a spirit with
a grudge." She says it plainly, the way she says everything. "It closes on
its own, and it hums when it does, and the hum has a shape if you listen
long enough to learn it. I have had four hundred years less practice than
it has had existing, and I still recognise a shape when I hear one."
~ learn("c1c", 1.0)
-> hub


= case_q4
"It begins under the Salt Steps, in the Underworks, where the old binding
was cut into the stone." She is not guessing; this is closer to reporting a
fact she has confirmed with her own ears. "The Long Slack is not a flood or
a drought. It is a very old thing clearing its throat before it speaks."
~ learn("c4c", 1.0)
-> hub


= case_q5
"Ring the Bell at the third bell of Full Slack, and it will settle - for a
time. Or." She pauses, weighing whether to say the rest. "Or you read it the
name in Harrow's chart, and you ask instead of command. I don't know which
is kinder. I know which one I would want done to me, if I were the one who
had waited four centuries to be understood instead of used."
~ learn("c5c", 1.0)
~ learn("r_third_bell", 0.85)
-> hub
