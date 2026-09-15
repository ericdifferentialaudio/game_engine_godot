// =============================================================================
// Shared conversation patterns
// =============================================================================
//
// The repeatable shapes of a systemic conversation, written once. An NPC's own
// .ink file INCLUDEs this and tunnels into a pattern, supplying the specifics:
//
//     INCLUDE patterns.ink
//
//     - > barter("brass_lantern", 1, "zorkmid", 3, "fence", "friendly") ->
//       { barter_result == BARTER_BOUGHT: The fence slides it across. }
//
// Every pattern is a tunnel (`-> name(args) ->`) that returns to the caller and
// leaves its outcome in a global, so the caller decides what it *means*. The
// patterns own the mechanics; the calling file owns the voice.
//
// Key story beats should still be written bespoke. This library exists so the
// fiftieth informant does not have to be.
// =============================================================================

EXTERNAL knows(id)
EXTERNAL believes(id, min_belief)
EXTERNAL heard_of(id)
EXTERNAL learn(id, trust)
EXTERNAL has_asset(id, amount)
EXTERNAL asset_count(id)
EXTERNAL give_asset(id, amount)
EXTERNAL spend_asset(id, amount)
EXTERNAL lose_asset(id, amount)
EXTERNAL standing(npc)
EXTERNAL standing_at_least(npc, tier)
EXTERNAL adjust_standing(npc, delta)
EXTERNAL stat_at_least(stat_name, value)
EXTERNAL flag(flag_name)
EXTERNAL set_flag(flag_name)

// --- Outcome codes -----------------------------------------------------------
// Shared vocabulary so a caller can branch on what happened without parsing text.

CONST BARTER_BOUGHT = 1
CONST BARTER_TOO_POOR = 2
CONST BARTER_REFUSED = 3

CONST INTERROGATE_TOLD = 1
CONST INTERROGATE_STONEWALLED = 2
CONST INTERROGATE_ALREADY_KNEW = 3

CONST PERSUADE_WON = 1
CONST PERSUADE_LOST = 2

CONST CONFIDE_ACCEPTED = 1
CONST CONFIDE_NOTHING_TO_TELL = 2

VAR barter_result = 0
VAR interrogate_result = 0
VAR persuade_result = 0
VAR confide_result = 0


// =============================================================================
// barter — pay assets for an asset.
// =============================================================================
// Gate order matters: willingness first, then affordability. Being told "I
// don't deal with you" is a different scene from "you can't afford it", and
// the player must never be charged before a refusal is known.
//
//   goods_id       asset handed over on success
//   goods_amount   how many
//   currency_id    asset taken as payment
//   price          how much
//   npc            who is selling
//   min_tier       standing required to trade at all ("" = anyone)
// =============================================================================
=== barter(goods_id, goods_amount, currency_id, price, npc, min_tier) ===
~ barter_result = 0
{ min_tier != "" && not standing_at_least(npc, min_tier):
    ~ barter_result = BARTER_REFUSED
    ->->
}
{ not has_asset(currency_id, price):
    ~ barter_result = BARTER_TOO_POOR
    ->->
}
// spend_asset is the transaction guard: it only returns true if it actually
// took the payment, so goods can never be handed over for free.
{ spend_asset(currency_id, price):
    ~ give_asset(goods_id, goods_amount)
    ~ barter_result = BARTER_BOUGHT
- else:
    ~ barter_result = BARTER_TOO_POOR
}
->->


// =============================================================================
// interrogate — press an NPC for a piece of knowledge.
// =============================================================================
// Trust is passed through to `learn`, so what an NPC tells you is only as
// credible as the NPC. A shifty source produces a rumour the player does not
// yet *know* — which is the whole point of the reliability model.
//
//   secret_id   knowledge granted on success
//   npc         who is being pressed
//   min_tier    standing required to talk ("" = anyone)
//   trust       0..1 credibility of this source
//   annoyance   standing lost when they refuse (0 = no cost)
// =============================================================================
=== interrogate(secret_id, npc, min_tier, trust, annoyance) ===
~ interrogate_result = 0
{ knows(secret_id):
    ~ interrogate_result = INTERROGATE_ALREADY_KNEW
    ->->
}
{ min_tier != "" && not standing_at_least(npc, min_tier):
    { annoyance > 0:
        ~ adjust_standing(npc, 0 - annoyance)
    }
    ~ interrogate_result = INTERROGATE_STONEWALLED
    ->->
}
~ learn(secret_id, trust)
~ interrogate_result = INTERROGATE_TOLD
->->


// =============================================================================
// persuade — win someone over with a stat.
// =============================================================================
// Standing shifts either way, so persuasion is a real gamble rather than a
// free reroll: failing costs you ground with them.
//
//   stat_name    stat checked
//   threshold    value required
//   npc          who is being persuaded
//   win_delta    standing gained on success
//   lose_delta   standing lost on failure
// =============================================================================
=== persuade(stat_name, threshold, npc, win_delta, lose_delta) ===
~ persuade_result = 0
{ stat_at_least(stat_name, threshold):
    { win_delta != 0:
        ~ adjust_standing(npc, win_delta)
    }
    ~ persuade_result = PERSUADE_WON
- else:
    { lose_delta != 0:
        ~ adjust_standing(npc, 0 - lose_delta)
    }
    ~ persuade_result = PERSUADE_LOST
}
->->


// =============================================================================
// confide — give away something you know, to buy goodwill.
// =============================================================================
// The counterpart to interrogate: knowledge flows out instead of in, and buys
// standing rather than costing assets. Requires the player to actually know the
// thing, so it cannot be used to bluff.
//
//   secret_id   knowledge the player must hold
//   npc         who is being told
//   reward      standing gained
//   flag_name   flag set on success ("" = none), so the world can remember
// =============================================================================
=== confide(secret_id, npc, reward, flag_name) ===
~ confide_result = 0
{ not knows(secret_id):
    ~ confide_result = CONFIDE_NOTHING_TO_TELL
    ->->
}
~ adjust_standing(npc, reward)
{ flag_name != "":
    ~ set_flag(flag_name)
}
~ confide_result = CONFIDE_ACCEPTED
->->
