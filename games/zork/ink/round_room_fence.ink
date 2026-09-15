// =============================================================================
// The Round Room fence — integration demo
// =============================================================================
// Demonstrates the whole stack in one scene:
//
//   * built entirely on the shared pattern library (barter / interrogate /
//     confide / persuade) — no bespoke transaction logic here
//   * the key choice is gated on THREE different systems at once:
//       a physical asset  (zorkmids to pay with)
//       a piece of knowledge (knows the trapdoor is real)
//       a relationship threshold (the fence must trust you)
//   * on success it grants BOTH a new physical asset and new knowledge
//   * context (location, time of day, standing tier) arrives as Ink variables
//     from CoreContextBuilder; everything volatile is an external function, so
//     a purchase made here is visible to the very next condition below.
//
// Compile:
//   tools/inklecate/inklecate.exe -o games/zork/ink/round_room_fence.ink.json \
//       games/zork/ink/round_room_fence.ink
// =============================================================================

INCLUDE patterns.ink

// Pushed by CoreContextBuilder before the conversation starts.
VAR location = ""
VAR time_of_day = "day"
VAR npc_id = "fence"
VAR npc_standing = "neutral"
VAR npc_standing_score = 0.0

CONST FENCE = "fence"
CONST COIN = "zorkmid"
CONST LANTERN_PRICE = 3

-> round_room_fence


=== round_room_fence ===
A figure sits in the shadow of the far archway, sorting trinkets by touch alone.
{ time_of_day == "night": The lamp at his elbow is guttering. | He does not look up. }
{ npc_standing == "stranger" || npc_standing == "neutral":
    "Don't know you," he says. "Don't much want to."
- else:
    "Back again," he says, almost warmly.
}
-> offers


=== offers ===
+ [Ask about the house on the hill.]
    -> ask_about_house
+ { knows("know_trapdoor") } [Mention what is under the rug.]
    -> tell_him_about_trapdoor
+ { standing_at_least(FENCE, "friendly") } [Ask what he has for sale.]
    -> his_wares
+ [Leave him to his sorting.]
    -> leave


// --- interrogate: he will only talk once he tolerates you --------------------
=== ask_about_house ===
"The white house," you say. "Boarded up. Who lived there?"
// Trust 0.4: he is a fence, not a historian. What he says arrives as a
// *rumour* — heard_of() will be true, but knows() will not, until something
// corroborates it.
-> interrogate("rumor_rug_worthless", FENCE, "neutral", 0.4, 1) ->
{
    - interrogate_result == INTERROGATE_TOLD:
        "Nothing in it," he says, too quickly. "Rug on the floor hides nothing but dust."
        You are fairly sure that is a lie.
    - interrogate_result == INTERROGATE_ALREADY_KNEW:
        "I've told you that story already."
    - else:
        He looks through you as though you had not spoken.
}
-> offers


// --- confide: spend knowledge to buy standing --------------------------------
=== tell_him_about_trapdoor ===
"There's a trap door," you say. "Under the rug. I've seen it."
-> confide("know_trapdoor", FENCE, 30, "told_fence_about_trapdoor") ->
{ confide_result == CONFIDE_ACCEPTED:
    For the first time he looks directly at you.
    "Now that," he says, "is worth something. Ask me about my wares."
- else:
    You realise you have nothing solid to tell him.
}
-> offers


// --- barter: the three-way gate ----------------------------------------------
=== his_wares ===
He spreads a cloth. On it: a brass lantern, dented but whole.
"Three zorkmids," he says. "For you."
+ { has_asset(COIN, LANTERN_PRICE) } [Buy the lantern (3 zorkmids).]
    -> buy_lantern
+ { not has_asset(COIN, LANTERN_PRICE) } [You cannot afford it.]
    "Come back when you're richer," he says.
    -> offers
+ [Decline.]
    -> offers


=== buy_lantern ===
-> barter("brass_lantern", 1, COIN, LANTERN_PRICE, FENCE, "friendly") ->
{
    - barter_result == BARTER_BOUGHT:
        Coins change hands. The lantern is heavier than it looks.
        // Both kinds of asset move in the same beat: an object AND a secret.
        ~ learn("know_grue", 0.9)
        "One more thing, free," he says. "Don't go down there dark. There are grues."
        // Immediately visible to the next condition, in this same conversation:
        { has_asset("brass_lantern", 1):
            You have what you came for.
        }
    - barter_result == BARTER_TOO_POOR:
        You count your coins, and come up short.
    - else:
        "Not for you," he says, and folds the cloth away.
}
-> offers


=== leave ===
He has already gone back to his sorting.
-> END
