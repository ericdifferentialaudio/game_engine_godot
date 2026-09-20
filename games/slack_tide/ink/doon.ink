// =============================================================================
// Ilsabet Doon — Weirkeeper, Lisle Harrow's widow
// =============================================================================
//
// GATED: only speaks once the player holds s_doon_husband AND mercy >= 5.
// The gate is enforced by topics.json / the session driver, not in here —
// this file assumes you have already earned the conversation.
//
// The moral centre of seed A. She is not lying about anything. The Choir
// sings with her dead husband's voice; she knows it is not him; she holds
// the gate anyway. Turning the tide (any seed) silences it forever. If the
// player opened Harrow's satchel on Day 2, she knows, and it changes the
// first line.
// =============================================================================

INCLUDE patterns.ink

VAR npc_id = "doon"
VAR location = "weir_gatehouse"
VAR npc_standing = "neutral"


=== doon ===
{ flag("seals_broken") && flag("satchel_from_doon"):
    She has known since the day it happened. Somewhere between the ferry and
    here, Brack told her a deckhand opened her husband's last letter, and she
    has had eleven days to decide what to do with that. She does not look
    away from you now. "You read it, then. His hand, on a page meant for
    Brack, not for you. Say something, or don't - I've stopped needing
    either from strangers."
- else:
    She keeps the gatehouse the way some people keep a grave: swept, exact,
    every rope coiled the same direction it was coiled the day the water took
    him. She does not turn from the sluice wheel. "You're the new hand.
    Hesper's boy. I know why you've come, and I know it isn't kindness."
}
- (hub)
+ ["I'm not here to judge you."] -> smalltalk
+ { knows("s_doon_husband") } [Ask about the voice under the Weir.] -> voice
+ { flag("seals_broken") } ["I opened the satchel. I should have told you sooner."] -> confess
+ { flag("corvin_cracked") || knows("c1b") >= 0 } [Tell her what you've learned about the sluice.] -> tell_case
+ [Ask what would make her open the gate.] -> terms
+ [Leave her to the water.] -> END


= smalltalk
"Everyone's not here to judge me. And then they ask the one question anyway."
She finally looks at you - not unkindly, just tired past the point where
kindness costs her anything. "Ask it. I'd rather you ask it than dance
around it for a week like Fen does."
-> hub


// --- The truth, given freely once she trusts you enough to be asked -------

= voice
"You've heard it, then." Not a question. She sets down the rope she was
coiling. "It started the week the tide stopped. A voice, under the Weir, and
it uses his. Not his words - he never had that many words - but his voice,
saying things a drowned man would have no way to say." She turns the wheel a
half-turn, checking it, though it does not need checking. "I know it isn't
him. I have known that since the second night. It does not change what my
hands do when it calls."
~ learn("s_doon_husband", 1.0)
~ learn("p_doon", 0.90)
-> hub


= confess
She is quiet long enough that you think she will not answer at all.
"Fidelity," she says eventually, "is supposed to mean something. You broke a
seal that was never yours to break, and you're telling me now because it's
convenient now, not because it was right then." She goes back to the rope.
"I'm not going to pretend that doesn't matter. But you're here, and you
said it plainly, and plainly is more than most people manage with me."
~ adjust_standing(npc_id, 3)
~ set_flag("doon_forgave_the_seal")
-> hub


= tell_case
You lay it out - what you have, what it points to, what it would mean for
her if it is true.
+ { knows("c1a") } ["It's you. You close the sluice yourself, every third bell."]
    -> called_a
+ { knows("c1b") } ["It isn't you. It's the Tally House, paying men to throttle the sluice."]
    -> called_b
+ { knows("c1c") } ["It isn't anyone. Something under the Weir has learned its own name."]
    -> called_c
+ [Admit you're still guessing.] -> hub


= called_a
She does not flinch, which is its own answer. "Yes. I hold the gate at the
third bell, every night, and I have told myself eleven different reasons why
until I stopped believing any of them." She meets your eyes for the first
time since you arrived. "Now you know what turning the tide costs, and who
pays it. Go on and be right about it somewhere else, if you like. Most
people do."
~ learn("c1a", 1.0)
~ learn("c5a", 0.85)
~ adjust_standing(npc_id, 2)
-> hub


= called_b
Something crosses her face that is almost relief and immediately ashamed of
being relief. "The Tally House." She says it slowly, testing whether it
holds her weight. "That would mean it was never me at all. That would mean
eleven months of my own hands on that wheel were for nothing I needed to
do." She does not know whether to thank you or resent you for it, and settles
on neither. "Get your proof solid before you say it to the Assize. I want it
to be true. Wanting is not the same as it being so."
~ learn("c1b", 0.85)
-> hub


= called_c
She goes very still. "A name." Not disbelief - recognition. "He used to say
the old stories got the shape of it right and the reason wrong. I thought
that was a thing he said to sound clever at parties." She looks toward the
Weir, the direction you cannot see it from here but everyone in this
gatehouse always faces anyway. "If that's true, then nobody did this. It
just finally understood what it was."
~ learn("c1c", 0.85)
~ learn("c4a", 0.70)
-> hub


// --- What it takes to open the gate willingly ------------------------------

= terms
"Willingly." She turns that word over like it costs her something to hold.
"Bring me the Assize's word that I'm released from an oath nobody living
remembers me swearing - that's one road. Or bring me a reason to believe
he's already at rest, that the voice is not him and never needed protecting
from being silenced." Her hand goes still on the wheel. "Either one. I am
not attached to suffering for its own sake. I have simply not been given
a better offer."
~ learn("c5a", 0.75)
~ learn("r_third_bell", 0.55)
-> hub
