// =============================================================================
// Corvin Ashe — Tally House agent, Marl Cross counting-house
// =============================================================================
//
// The worked example of the core mechanic, ported from actors.json as proof
// that Ink can carry this game's depth. Every mechanic appears here:
//
//   * a knowledge CHECK always offered as text, which only WORKS at reliability
//     (knows() IS the 0-100 reliability model, so the gate is one word instead
//     of a hand-maintained min_reliability number on every branch)
//   * a BLUFF that costs him for the day
//   * an ITEM grant, a STANDING shift, and value-bearing choices
//   * a mercy route and a cruelty route that BOTH work and lead apart
//
// Topic unlocking is the thing to notice: `brother` is not a branch you find
// in here, it is held open by knowing s_corvin_brother from ANY source - Cobb
// overheard, Fen drunk, or the customs cellar. No counter-gate.
// =============================================================================

INCLUDE patterns.ink

VAR npc_id = "corvin"
VAR location = "tally_house"
VAR time_of_day = "day"
VAR npc_standing = "neutral"


=== corvin ===
{ flag("corvin_closed_today"):
    He is copying figures and does not look up. Whatever opening you had this
    morning, you have spent it.
    -> END
}
{ flag("corvin_cracked"):
    - true: He looks up at once. Since he told you, he has been watching the
            door more than the ledger.
    - else: He is copying a column of figures and has copied the same line
            twice. "Yes? The desk is Prewitt's. If it's business it's hers."
}
- (hub)
+ ["Long day?"] -> smalltalk
+ [Ask about the night sluice.] -> sluice
+ { knows("s_corvin_brother") } [Ask about his brother.] -> brother
+ { flag("corvin_cracked") && not flag("has_paystub") } ["Show me the chit."] -> chit
+ ["You look like a man who's been paid to forget something."] -> needle
+ [Leave him to it.] -> END


= smalltalk
"Long month." He rubs his eyes with the back of a wrist, ink and all, and now
there is ink on his face and he does not know it. "I came here to count. That's
all I wanted to do, honestly - count things, go home. Nobody tells you the
counting is the least of it."
-> hub


// --- The check ---------------------------------------------------------------
// All three answers are always offered. Saying one is free; being BELIEVED is
// not. knows() reads false for anything under the belief threshold, so a rumour
// picked up from Doss at 25 lands as a bluff however confidently it is phrased.

= sluice
He does not look up, and the not-looking-up is the whole answer. "The sluice
closes itself. Nobody's touched it. It's a mechanism. It does what mechanisms do."
+ ["Men paid in Tally coin close it at the third bell."]
    { knows("c1b"): -> called_b | -> bluffed }
+ ["The Weirkeeper closes it with her own hands."]
    { knows("c1a"): -> called_a | -> bluffed }
+ ["Nothing touches it. It closes on its own, humming."]
    { knows("c1c"): -> called_c | -> bluffed }
+ [Let it go.] -> hub


= called_b
The pen stops. A blot spreads on the ledger and he watches it spread. "You've
seen the log." It comes out of him all at once, low and fast: "Four of them.
They come down the Marl side at the second bell and they are gone by the fourth,
and they are paid out of a chit I write myself. I write it. I have written it
eleven times." He puts both hands flat on the desk. "I did not know what it was
for. I want that said. I did not know."
~ set_flag("corvin_cracked")
~ adjust_standing(npc_id, -5)
-> hub


= called_a
He blinks. "Doon? The Weirkeeper?" Genuine confusion, and then something worse -
relief. "That would - yes. That would make more sense than what I have been
telling myself." He lets out a breath. "She has the only hands on that gate. If
it is her, then it is not us, and I would very much like it not to be us."
~ set_flag("corvin_cracked")
-> hub


= called_c
For the first time he looks straight at you. "You've heard it too." His voice
drops. "I stayed late on the ninth. I heard the sluice go over and there was
nobody on the walk, and it was not a machine sound. Machines don't hold a note."
He swallows. "I have not said that to anyone, because saying it makes me the
sort of man who says that sort of thing."
~ set_flag("corvin_cracked")
-> hub


= bluffed
He looks up properly for the first time, and you can see him decide you are
guessing. "No," he says, and the relief in it is insulting. "No, you don't know
that. You heard it at the Lantern and thought you'd try it on me." He goes back
to his column. "Come back when you've got something. Or don't."
~ set_flag("corvin_closed_today")
-> END


= chit
"I can't - " He stops. He looks at the door. Then he tears the top sheet off his
blotter, folds it once, and pushes it across without letting go a second longer
than he has to. "That's a copy. I made it on the ninth because I was frightened.
If Prewitt asks, you took it."
~ give_asset("sluice_log_page", 1)
~ learn("ev_b_paystub", 0.7)
~ set_flag("has_paystub")
~ adjust_standing(npc_id, -10)
-> hub


// --- The brother: a mercy route and a cruelty route, both real ---------------

= brother
"Who told you about Tam." Flat. Then, because you clearly already know: "He went
down the Salt Steps on a salvage pull when I was nine. They brought up his hat."
He sets the pen down. "That is why I took a desk job on a river I hate. So there
would be one Ashe who died of a chest cold."
+ [Say nothing. Wait.] -> brother_mercy
+ ["I'm sorry."] -> brother_mercy
+ ["Then help me stop it happening to someone else."] -> brother_lever


= brother_mercy
The quiet goes on long enough to be uncomfortable and then long enough to be
something else. "Nobody waits," he says eventually. "They say the sorry and then
they move it along." He wipes his face, finds the ink, stares at his hand. "The
hum. On the ninth. You should know that I heard it, and you should know that I
have been pretending I didn't, and I would like one person on this river to know
both of those things."
~ learn("p_corvin", 0.55)
~ learn("c1c", 0.55)
~ adjust_standing(npc_id, 5)
~ set_flag("corvin_trusts")
-> hub


= brother_lever
He looks at you with an expression that is almost admiring and entirely cold.
"There it is." He nods slowly. "You waited a whole four seconds before you made
him useful." He turns back to the ledger. "Everyone on this river is a lever to
somebody. I had hoped to reach the end of the week before I was one to you."
~ learn("p_corvin", 0.55)
~ adjust_standing(npc_id, -5)
-> hub


= needle
"Get out." He stands, and he is shaking, and it is not fear. "You think you're
the first? People come in here twice a week to tell me what I look like. I know
what I look like. I have a mirror and a conscience and both are in better repair
than you'd think." He points at the door. "Out."
~ adjust_standing(npc_id, -10)
~ set_flag("corvin_closed_today")
-> END
