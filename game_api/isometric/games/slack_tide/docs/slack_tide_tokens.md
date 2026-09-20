# Slack Tide - Information Token List

75 tokens. **Generated** from `slack_tide_spec.json` by `tools/convert_slack_tide.py`; edit the spec, not this file.

`truth` is `always` (true in every seed) or `culprit=A/B/C` (true only when that culprit is the hidden cause). Members of one group are mutually exclusive by seed, so exposing a false answer corroborates the true one.

## beast (9)

| ID | Name | Journal text | Truth | Group | Base | Sells |
|---|---|---|---|---|---|---|
| `b_wight_slack` | Wights rise at slack | Silt-wights only rise at slack water. | always |  | 55 | 5 |
| `b_wight_salt` | Salt stops a wight | A line of salt stops a silt-wight. A warded wick banishes it. | always |  | 55 | 5 |
| `b_wight_pleads` | Some wights remember | Some silt-wights are drowned laborers who still remember. They can be led up, not cut down. | always |  | 55 | 5 |
| `b_gulcher_iron` | Gulchers shy from iron | Gulchers shy from iron. Scatter nails on the steps. | always |  | 55 | 5 |
| `b_lull_sound` | The lullhound hunts by sound | The lullhound hunts by sound, not sight. | always |  | 55 | 5 |
| `b_lull_decoy` | A clatter draws it off | A clatter thrown down a passage pulls the lullhound away from you. | always |  | 55 | 5 |
| `b_kelp_tribute` | The kelpmother takes eels | The kelpmother takes three fresh eels and asks nothing more. | always |  | 55 | 5 |
| `b_collector_toll` | Pay the Collector | The Pale Collector wants three drowned marks. He is not fought. He is paid. | always |  | 90 | 5 |
| `b_choir_wick` | The Choir fears flame | The Sunken Choir cannot abide open flame. A warded wick hurts it. | always |  | 55 | 5 |

## case (15)

| ID | Name | Journal text | Truth | Group | Base | Sells |
|---|---|---|---|---|---|---|
| `c1a` | The Weirkeeper works the sluice | The Weirkeeper closes the night sluice with her own hands at the third bell. | culprit=A | q1 | 55 | 14 |
| `c1b` | Hirelings work the sluice | Men paid in Tally coin close the night sluice at the third bell. | culprit=B | q1 | 55 | 14 |
| `c1c` | Nobody works the sluice | No hand touches the night sluice. It closes on its own, humming. | culprit=C | q1 | 55 | 14 |
| `c2a` | Harrow was silenced | Warden-Courier Harrow was silenced at the Weir gatehouse by Doon's oath-guards for what she saw. | culprit=A | q2 | 55 | 14 |
| `c2b` | Harrow was chased | Tally House men chased Harrow off the Marl wharf for the sluice log and she went into the water. | culprit=B | q2 | 60 | 14 |
| `c2c` | Harrow was taken by the Stairs | The Stairs pulled Harrow under. The marks on her are gulcher, not man. | culprit=C | q2 | 55 | 14 |
| `c3a` | The satchel holds Doon's plea | The satchel holds Doon's own letter to the Wardens, begging for bell-founders before the Weir fails. | culprit=A | q3 | 70 | 14 |
| `c3b` | The satchel holds the log | The satchel holds a page of the night-sluice log naming a paid crew. | culprit=B | q3 | 70 | 14 |
| `c3c` | The satchel holds a hum chart | The satchel holds a chart of hum-marks along the causeway, drawn in Harrow's hand. | culprit=C | q3 | 70 | 14 |
| `c4a` | It begins at the gatehouse | The Long Slack begins at the Weir gatehouse, where the sluice is held shut. | culprit=A | q4 | 55 | 14 |
| `c4b` | It begins at the Marl sluice-house | The Long Slack begins at the Marl Cross sluice-house, where the crew works to a Tally chit. | culprit=B | q4 | 70 | 14 |
| `c4c` | It begins beneath the Steps | The Long Slack begins in the Underworks under the Salt Steps, where the water hums. | culprit=C | q4 | 90 | 14 |
| `c5a` | Only the Assize can free Doon | Only the Wardens' Assize can release Doon from her oath. Then she will open the gate. | culprit=A | q5 | 55 | 14 |
| `c5b` | Expose the ledger | Break the consortium's hold: expose the ledger and the sluice crew will walk. | culprit=B | q5 | 70 | 14 |
| `c5c` | Ring the Bell | Ring the Bell of Turning at the third bell of Full Slack and the Choir will sleep. | culprit=C | q5 | 70 | 14 |

## economy (9)

| ID | Name | Journal text | Truth | Group | Base | Sells |
|---|---|---|---|---|---|---|
| `e_hearsay_half` | Hearsay sells at half | The counting-house buys hearsay at half price and corroborated facts at full. | always |  | 55 | 5 |
| `e_spread_drops` | A sold secret loses value | Once a secret is sold, it spreads. Each buyer pays less than the last. | always |  | 55 | 5 |
| `e_goldie_discount` | Goldie rewards fair dealers | Goldie takes a tenth off for anyone who has never cheated a customer. | always |  | 55 | 5 |
| `e_scrap_price` | Brass sells at Marl | Salvaged brass fittings fetch four tallies each at the Marl scrapyard. | always |  | 55 | 5 |
| `e_smuggler_tip` | Smugglers tip to be ignored | Smugglers on the dusk run pay a few tallies to be ignored. Taking it costs you something else. | always |  | 60 | 5 |
| `e_fare_hike` | Fares double after the first week | Fares double after the first week, and tips with them. | always |  | 55 | 5 |
| `e_customs_bribe` | The cellar costs eight | Wimble opens the cellar for eight tallies if nobody is looking. | always |  | 60 | 5 |
| `e_eel_market` | Eels cost six a bundle | A bundle of three fresh eels is six tallies at Toma's hut or the Marl market. | always |  | 55 | 5 |
| `e_boat_hire` | Boat hire is thirty | Fen hires a seaworthy boat for thirty tallies. A skiff for the Rocks is four. | always |  | 55 | 5 |

## evidence (5)

| ID | Name | Journal text | Truth | Group | Base | Sells |
|---|---|---|---|---|---|---|
| `ev_a_lantern` | Doon's lantern log | A lantern log in Doon's hand: a trimmed wick and a mark at every third bell of the night. | culprit=A | ev_a | 70 | 12 |
| `fg_a_lantern` | A lantern log, too fresh | A lantern log said to be Doon's. The ink is still tacky. | culprit!=A | ev_a | 60 | 12 |
| `ev_b_paystub` | Tally chit for the sluice crew | A Tally House chit dated the night before the first Long Slack, made out to 'sluice crew'. | culprit=B | ev_b | 70 | 12 |
| `fg_b_paystub` | A Tally chit, seal off | A Tally House chit made out to 'sluice crew'. The seal is a shade off. | culprit!=B | ev_b | 60 | 12 |
| `ev_c_hum` | The stone hums | Stand on the Salt Steps at slack and the stone hums up through your boots. | culprit=C |  | 90 | 12 |

## people (13)

| ID | Name | Journal text | Truth | Group | Base | Sells |
|---|---|---|---|---|---|---|
| `p_hesper` | Hesper prizes a kept word | Hesper values a kept word above a full purse. She will lend the Patience to someone who leaves honestly. | always |  | 55 | 5 |
| `p_doss` | Discount Doss by half | Doss embroiders. Halve whatever he tells you. | always |  | 90 | 5 |
| `p_cobb` | Ma Cobb hears the Reach | Ma Cobb hears the whole Reach for the price of a warm cup. | always |  | 55 | 5 |
| `p_fen` | Fen is good before noon | Fen Aldous is reliable on tides before noon and worthless after gin. | always |  | 55 | 5 |
| `p_ottoline` | Ottoline pays double for the unique | Ottoline pays double for what nobody else has. | always |  | 55 | 5 |
| `p_croy` | Croy keeps a wick-staff | Ansel Croy keeps an old wick-staff in the lamp room. He says it should have been laid down with the crew. He gives to the merciful who hold their hand. | always |  | 55 | 5 |
| `p_wenna` | Wenna keeps a tide-bell | Sister Wenna keeps a bell that turned tides in her mother's day. She only speaks to people who can wait. | always |  | 55 | 5 |
| `p_vosk` | Vosk never broke a seal | Dame Vosk caught a forged ledger by the smell of the ink. She trusts only those who have never broken a seal. | always |  | 55 | 5 |
| `p_toma` | Toma deals fair or not at all | Toma Reedhand pays and charges fair. Cheat him once and he will never speak to you again. | always |  | 55 | 5 |
| `p_yarrow` | Yarrow's glass catches lies | Yarrow Thistle's glass is said to catch a lie. She parts with it only to someone who never told one. | always |  | 55 | 5 |
| `p_brack` | Brack's blade drank the Lull | Captain Brack's blade drank the Lull once. She gives it to the brave who are not cruel. | always |  | 55 | 5 |
| `p_doon` | Doon answers to her oath | Ilsabet Doon has kept the Weir since her husband died there. She answers to her oath before anyone. | always |  | 55 | 5 |
| `p_corvin` | Corvin's pouch bears the Tally seal | Corvin Ashe carries a pouch stamped with the Tally seal and has a nervous temper. | always |  | 55 | 5 |

## place (10)

| ID | Name | Journal text | Truth | Group | Base | Sells |
|---|---|---|---|---|---|---|
| `t_lowebb` | The Steps are dry at ebb | The Salt Steps are dry only in the first hour of dawn and dusk ebb. | always |  | 70 | 5 |
| `t_slack_grows` | Each slack runs longer | Each slack lasts longer than the last, by about a quarter hour every third day. | always |  | 55 | 5 |
| `t_third_stair` | The third stair is rotten | The third landing of the Salt Steps is rotten. Bring rope. | always |  | 90 | 5 |
| `t_heron_stones` | Follow the heron-stones | Reedwick's safe path follows the heron-stones. Step off them and the marsh keeps your boots. | always |  | 55 | 5 |
| `t_old_coin` | Drowned marks still spend | Drowned marks, the old coin, turn up along the Steps and still spend with the Pale Collector. | always |  | 90 | 5 |
| `t_weir_gates` | Three gates, one small | The Weir has three gates. Only the Lesser Gate opens to a small boat at slack. | always |  | 55 | 5 |
| `t_cistern_way` | The cistern goes under the Weir | Under the Salt Steps the Bellmaker's cistern runs beneath the Weir, if you know the knock. | always |  | 55 | 5 |
| `t_lighthouse` | Croy's lamp calls the ferry | Croy's lamp at Far Wend is the only working signal lamp and can call the ferry after dark. | always |  | 55 | 5 |
| `t_customs_cellar` | The old ledgers are in the cellar | The old sluice ledgers are shelved in the Customs House cellar. | always |  | 60 | 5 |
| `t_full_slack` | Full Slack stops the ferry | When slack lasts a full day the ferry will not run. Hesper calls it Full Slack. | always |  | 55 | 5 |

## route (7)

| ID | Name | Journal text | Truth | Group | Base | Sells |
|---|---|---|---|---|---|---|
| `r_word_1` | Turning Word: first | The first Turning Word is 'Ebb'. Fen sings it when drunk. | always |  | 55 | 8 |
| `r_word_2` | Turning Word: second | The second Turning Word is 'Hold'. It is in the nursery rhyme Ma Cobb hums. | always |  | 55 | 8 |
| `r_word_3` | Turning Word: third | The third Turning Word is 'Turn'. It is cut into the plaque at the Lesser Gate. | always |  | 90 | 8 |
| `r_third_bell` | The turn is done at the third bell | The turning is done at the third bell, and only during Full Slack. | always |  | 55 | 8 |
| `r_gate_seal` | The gatehouse door knows a master seal | The gatehouse door answers to a Customs master seal. | always |  | 60 | 8 |
| `r_cistern_knock` | Knock twice, pause, once | At the Bellmaker's cistern, knock twice, pause, then once. | always |  | 55 | 8 |
| `r_assize_call` | Three witnesses convene the Assize | Three witnesses' worth of corroborated tokens will convene the Wardens' Assize at Far Wend. | always |  | 55 | 8 |

## secret (7)

| ID | Name | Journal text | Truth | Group | Base | Sells |
|---|---|---|---|---|---|---|
| `s_doss_skims` | Doss skims the fares | Doss skims a tenth of the fares on the Marl run and Hesper does not know. | always |  | 90 | 10 |
| `s_hesper_mortgage` | The Patience is mortgaged | The Patience is mortgaged to Tally & Prewitt, due at month's end. | always |  | 60 | 10 |
| `s_ottoline_ledger` | The real ledger is under the stair | The counting-house's real ledger sits under the third stair. | always |  | 70 | 10 |
| `s_corvin_brother` | Corvin's brother drowned | Corvin's brother drowned in the Stairs. He hates the Reach for it. | always |  | 55 | 10 |
| `s_doon_husband` | Doon's husband died at the Weir | Doon's husband drowned in the Weir's first flood. She has not left the gatehouse since. | always |  | 55 | 10 |
| `s_wimble_sells` | Wimble sells the records | Clerk Wimble sells access to the records if paid and unobserved. | always |  | 60 | 10 |
| `s_marl_smugglers` | Smugglers use the Marl wharf | Smugglers use the Marl Cross wharf at dusk. | always |  | 90 | 10 |

