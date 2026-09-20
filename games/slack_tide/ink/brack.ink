// =============================================================================
// Captain Isolde Brack — retired Warden, Far Wend landing
// =============================================================================
//
// The satchel's intended recipient, and the Assize's route in every seed.
// Gift: Lull-Cutter (nerve 7, mercy 4). Dry, procedural, has buried more
// friends than she has left, and treats that as a fact rather than a wound.
// =============================================================================

INCLUDE patterns.ink

VAR npc_id = "brack"
VAR location = "far_wend_landing"
VAR npc_standing = "neutral"


=== brack ===
{ flag("delivered_satchel_intact"):
    - true: She has the satchel open on the table already, and does not
            look up. "You're the one who carried this. Sit if you're
            staying. I'm not going to make small talk about a dead man's
            handwriting."
    - else: She stands the way old soldiers stand, which is to say she does
            not slouch even alone. "Warden business is Warden business. If
            you're here about Harrow, say so plainly. I've no patience left
            for the roundabout kind."
}
- (hub)
+ ["Just passing through."] -> smalltalk
+ [Ask about the Weir gates.] -> weir
+ [Ask what she knows of Doon.] -> about_doon
+ { flag("seals_broken") && not flag("brack_knows_seal") } ["I opened the satchel before it reached you."] -> confess_seal
+ [Ask about calling the Assize.] -> assize
+ [Leave.] -> END


= smalltalk
"Passing through is a fine thing to be, at your age." She allows herself
something almost like a smile. "I did thirty years of not passing through.
Recommend the passing-through version, on balance."
-> hub


= weir
"The Lesser Gate takes a boat and a strong stomach. The old cistern route
takes neither, if you don't mind the dark and the smell of it." She traces
a line on an old chart without looking at it - she has traced this line
before. "Whichever way you go, you'll need the seal or a welcome or a very
good reason. The Weir does not open for people who simply want in."
~ learn("t_weir_gates", 0.55)
-> hub


= about_doon
Something in her posture changes - not softer, exactly, but less armoured.
"Ilsabet Doon buried a husband the river never gave back, and then she
took the one job on this coast that puts her within sight of where it
happened, every day, forever." She sets down what she was holding. "I have
told her to leave that post more times than I can count. She has told me,
every time, that someone has to keep it. I no longer know which of us is
being kind when we have that conversation."
~ learn("p_doon", 0.70)
~ learn("s_doon_husband", 0.70)
-> hub


= confess_seal
For a long moment she says nothing at all, and the nothing is worse than
anything she could have said. "That satchel was addressed to me." Flat,
controlled, the voice of someone who has delivered worse news than this and
knows how to sit with it. "I won't pretend it doesn't matter. But you told
me, which most wouldn't, and there is a version of this where that counts
for something." She looks at you properly. "Don't do it again."
~ set_flag("brack_knows_seal")
~ adjust_standing(npc_id, -3)
-> hub


= assize
"The Assize convenes on proof, not suspicion. Bring them a case that holds
together under questions asked by people paid to find the holes in it, and
they will act. Bring them a feeling, however strongly held, and you will
have wasted a morning and some of my patience." She taps the table once,
precisely. "Ten tallies to call it. I'd have it be worth your ten."
~ learn("r_assize_call", 0.70)
-> hub
