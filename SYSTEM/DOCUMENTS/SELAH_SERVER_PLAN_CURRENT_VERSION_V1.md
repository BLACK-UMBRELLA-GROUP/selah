---
id: DOC-SELAH-0080
type: PLAN
status: DRAFT
feature: SERVER_PLAN
purpose: Document-only plan for SELAH's independent server; build only after 14 December 2026 on separate Founder approvals
links: [DOC-SELAH-0079, OA-SELAH-002, OA-SELAH-004, AD-AIOS-129, AD-AIOS-123, OA-AIOS-420]
owner: Codex
---

# SELAH server plan — current version V1

7 November 2026. **PROPOSED, not implemented.** Founder: “Plan now, build after trip (Recommended)” (AD-AIOS-129). This plan authorizes no setup or build.

## 1. What the app calls today

`SOURCE/lib` inventory, 7 November 2026. **Zero live draft calls:** `main.dart:41–48` disables the client/HTTP; provider config is empty. Retained contracts below are not deployed services. “SELAH has none yet” is the brief's baseline, not a live ownership audit.

**127 resources: 97 RPCs (94 literal + 3 helper targets), 29 tables/views, 1 bucket.** Source sites: 98 literal RPC + 2 dispatches; 93 relation calls; 7 storage operations (+1 local URL accessor); 1 Realtime channel/2 subscriptions; 13 remote Auth calls/8 methods. Counts are source sites, not runtime volume; helper selections add no dispatches.

Paths are under `SOURCE/lib`; service-owner filenames omit `services/`. RPC names are complete; T = tables/views. Screens include indirect consumers. Every retained remote contract is inactive in this draft. No Edge Function invoke sites.

| Owner / consuming screen | Retained calls | Ownership |
|---|---|---|
| `dev/dev_scenario_panel_v2.dart`; Developer scenario panel | RPC: selah_dev_shepherds_on_decided, selah_dev_set_seeker_plan, selah_dev_set_shepherds_on_decided, selah_dev_reset_account, selah_dev_set_shepherd_suggestions | SELAH has none yet |
| `screens/chat/chat_screen.dart`; Seeker chat | Realtime: messages:$convId | SELAH has none yet |
| `selah_ages_service.dart`; Browse/Connections/Journey cards | RPC: ages_for, ages_for_one | SELAH has none yet |
| `selah_auth.dart`; Welcome/security/recovery/account deletion | RPC: delete_own_account<br>T: profile_photos<br>Bucket: profile-photos<br>Auth: updateUser, signInWithIdToken, linkIdentityWithIdToken, verifyOTP, getUserIdentities, signInWithOtp, signOut | SELAH has none yet |
| `selah_consent_service.dart`; Consent/onboarding/profile editors | RPC: has_article9_consent<br>T: consents | SELAH has none yet |
| `selah_dashboard_updates_service.dart`; Seeker/Shepherd dashboards | RPC: selah_dashboard_updates | SELAH has none yet |
| `selah_developer_access.dart`; Developer gate / session freshness | Auth: refreshSession | SELAH has none yet |
| `selah_discovery_service.dart`; Browse/code search/Connections/hidden profiles | RPC: selah_preview_match_code, selah_consider_match_code, score_candidates, selah_reset_search<br>T: profiles, saves, likes, passes | SELAH has none yet |
| `selah_entitlement_service.dart`; Shepherd home/profile/Network | RPC: mentor_has_mentor_one | SELAH has none yet |
| `selah_family_messaging_service.dart`; Shepherd family chat/circle preview | RPC: selah_open_family_message_circle, selah_family_message_circles, selah_family_message_participants, selah_family_messages_v3, selah_send_family_message, selah_mark_family_messages_read, selah_set_family_message_muted, selah_report_family_message | SELAH has none yet |
| `selah_feedback_service.dart`; Settings feedback | RPC: selah_submit_feedback | SELAH has none yet |
| `selah_identity_verification_service.dart`; Verification/onboarding/Journey gate | RPC via helper: `selah_my_identity_verification_state`, `selah_record_identity_verification_consent`, `selah_delete_my_unstarted_identity_verification_attempt` | SELAH has none yet |
| `selah_initial_signup_draft_service.dart`; Role/account overview/onboarding | T: profiles | SELAH has none yet |
| `selah_journey_service.dart`; Journey/Connections/timeline/Past Journeys/Shepherd detail | RPC: selah_my_pause_states, selah_journey_busy_flags, selah_dev_seed_journey, promote_journey_to_active, selah_reveal_journey_compatibility, selah_journey_compatibility_state, selah_advance_stage, open_family_review, selah_may_request_new_journey_ids, selah_available_journey_return_ids, selah_expire_due_journey_requests, request_new_journey, respond_to_journey_request, resolve_family_review_if_due, transition_journey_pause, selah_pause_capacity_status, end_journey, selah_dev_set_journey_stage, selah_dev_set_counterpart_reveal, selah_compatibility_for_plus, selah_dev_set_compatibility, selah_dev_counterpart_complete, selah_dev_rewind_journey, selah_dev_set_plus_unlock<br>T: matches, profiles, journey_greetings, mentor_links, journey_phase_answers, journey_phase_ratings, journey_phase_checkpoints, journey_family_reviews, journey_family_answers, profile_unlocks | SELAH has none yet |
| `selah_match_service.dart`; Chat/timeline/Shepherd detail/dashboards | RPC: selah_mark_journey_messages_read, selah_milestone_attestation_state, selah_propose_milestone, selah_confirm_milestone<br>T: matches, profiles, selah_my_attempt_participation, conversations, timelines, timeline_milestones, messages | SELAH has none yet |
| `selah_mentor_journey_service.dart`; Shepherd Journey/workspace/dashboard/Seekers/family chat | RPC: selah_attempt_summary_for_shepherd, selah_counterpart_card, mentor_review_decision, reopen_family_review<br>T: selah_my_attempt_participation, matches, journey_family_reviews, timelines, timeline_milestones, journey_family_review_responses, conversations, messages | SELAH has none yet |
| `selah_mentor_link_service.dart`; My Shepherds/Network/code/invites/Journey/Connections | RPC: selah_my_personal_code, selah_rotate_my_personal_code, selah_preview_personal_code, selah_request_shepherd_link, selah_my_shepherd_requests, selah_accept_shepherd_request, selah_decline_shepherd_request, selah_cancel_shepherd_request, selah_shepherd_activity, selah_journey_main_shepherd_gate, selah_set_main_shepherd, selah_clear_main_shepherd, selah_remove_shepherd, selah_shepherd_history_consent, selah_main_shepherd_history_consent, selah_shepherd_journey_access, selah_revoke_mentor_invite, selah_decline_mentor_invite, selah_expire_due_mentor_invites, preview_mentor_invite, accept_mentor_invite<br>T: mentor_invites, profiles, mentor_links | SELAH has none yet |
| `selah_notification_prefs_service.dart`; Seeker/Shepherd notification settings | RPC: selah_notification_preferences, selah_set_notification_preference | SELAH has none yet |
| `selah_notification_service.dart`; Notifications/badges/Shepherd dashboards | T: notifications | SELAH has none yet |
| `selah_onboarding_answers_service.dart`; Values/bio onboarding; compatibility/profile editors | T: onboarding_answers | SELAH has none yet |
| `selah_photo_service.dart`; Onboarding/edit photos/profile cards | T: profile_photos<br>Bucket: profile-photos | SELAH has none yet |
| `selah_product_telemetry.dart`; Settings/help/code/upgrades/onboarding telemetry | RPC: selah_record_product_event | SELAH has none yet |
| `selah_profile_service.dart`; Profile/onboarding/home/privacy/advanced account | RPC: selah_reset_profile, selah_my_onboarding_progress, selah_set_profile_complete, selah_create_profile<br>T: profiles<br>Bucket: profile-photos | SELAH has none yet |
| `selah_report_service.dart`; Browse/Connections/hidden profiles/safety status | RPC: selah_my_safety_cases, selah_block_user, selah_unblock_user<br>T: profile_blocks, profile_reports | SELAH has none yet |
| `selah_seeker_details_service.dart`; Chapter 2/profile/unlocked compatibility | RPC: seeker_details_for_unlocked<br>T: seeker_details | SELAH has none yet |
| `selah_session_router.dart`; Welcome/AuthGate/recovery routing | RPC: selah_my_paid_access, ages_for_one<br>T: profiles, subscriptions | SELAH has none yet |
| `selah_shepherd_info_service.dart`; Compatibility Unlock+ (paid-name contract must change) | RPC: shepherds_for_unlocked | SELAH has none yet |
| `selah_shepherd_suggestion_service.dart`; Browse/Connections suggestions; developer panel | RPC: selah_mark_suggestions_seen<br>T: mentor_suggestions, profiles | SELAH has none yet |
| `selah_unlock_service.dart`; Unlock/Profile/Connections | RPC: selah_unlock_profile, unlock_balance, selah_debug_grant_credits<br>T: profile_unlocks | SELAH has none yet |

Storage: `_bucket` in `services/selah_photo_service.dart` resolves to `profile-photos`: upload, single/batch signed URLs, pinned-principal signing and removal. Auth/Profile also remove objects; bucket URL parsing is local. Nested `profile_photos(...)` reads are included above.

| Additional owner / surface | Call or absence | Ownership |
|---|---|---|
| `services/selah_auth.dart`; sign-in/security | Google SDK initialize/authenticate/signOut; two Apple credential-request sites. Auth methods above cover token exchange/linking, email change/recovery OTP, identity lookup and sign-out. `onAuthStateChange` is an SDK event stream. | SELAH has none yet |
| `services/selah_photo_service.dart:519`; photos | One explicit HTTPS `http.get(uri)`. Four cached-image-provider sites: `widgets/selah_profile_image.dart`; twice in `screens/browse/browse_screen.dart`; once in `screens/journey/journey_flow_screen.dart`. Dynamic URLs use storage or retained fixtures. | SELAH has none yet |
| `screens/chat/chat_screen.dart`; chat | `messages:$convId`: INSERT/UPDATE on `public.messages`, filtered by conversation. Filter is not server authorization. | SELAH has none yet |
| `services/selah_internal_preview_client.dart`; preview | Two generic `_inner.send(request)` forwarding sites, empty approved host, HTTP denied. No extra endpoint. | SELAH has none yet |
| Retained photo fixtures | `picsum.photos`: 12 URLs in `models/seeker_profile.dart`; templates in `services/selah_match_service.dart`, `services/selah_journey_service.dart`, `screens/connections/connections_screen.dart`. External fixtures, not SELAH storage. | SELAH has none yet |
| External links | `screens/subscription/upgrade_screen.dart`: Apple/Google subscription-management URLs; `screens/settings/help_support_screen.dart`: support mailto; `services/selah_app_invite.dart`: inert `https://selah.invalid`. No checkout, receipt validation or email sender. | SELAH has none yet |
| Verification; `services/selah_identity_verification_service.dart` | Adapter unavailable; Sumsub is an inherited interface/consent reference. No provider SDK transport or signed webhook. | SELAH has none yet |
| Notifications/commerce/requests | `services/selah_promotion_engine.dart`: APNs/FCM gateway unavailable. No SMS/push/purchase SDK/receipt-verification transport in lib. `services/selah_journey_request_repository.dart`: held read/write port, no endpoint. `help_articles` is comment-only, not a call. | SELAH has none yet |

`selah_dev_*`/`selah_debug_grant_credits` remain source references; listing them does not approve production exposure or provisioning.

## 2. What SELAH needs

Proposed OA-SELAH-002 work. LOCKs govern behaviour; inherited methods do not approve it. Missing production states need LOCKs and briefs.

| Service | Server responsibility | LOCK / dependency |
|---|---|---|
| Sign-in and roles | Independent identities, verified sessions, recovery, rate limits and revocation. Authorize current role/link membership, never editable user metadata or a client role switch. | LOCK 3 Seeker/Shepherd and invite; production sign-in/recovery states and provider still need approval. |
| Database/discovery | Own profiles, answers, links and Journeys; minimum authorized projections. Enforce exclusions, capacity and relationship state on the server. | LOCKs 4 Faith, 5 Marriage, 8 Browse, 14 Languages, 16 Marriage changes, 17 Values. |
| Photos/moderation | Private uploads with ownership/type/size checks, quarantine, moderation and authorized delivery/deletion; replace public-URL assumptions. | LOCK 8 profile photos; moderation operators and pending/rejected states need approval. |
| Verification | Independent identity/age provider; authenticated callbacks bound to the correct account. Minimize retained documents. | Inherited screens are not provider approval; assurance level and states remain open. |
| Safety/reporting | Block/hide/report/suspend across discovery, requests, messages and name access; restricted, audited case evidence. | Inherited safety screens; operational policy and production states need approval. |
| Messaging | Check participants, current permissions, blocks/end status and entitlement on every read/write and realtime subscription. | LOCK 3 roles, LOCK 20 Dashboard removes paid insights; name eligibility grants no Chat/View permission. |
| Requests/Journeys | Atomic send/accept/decline/end/Replace, pair/Journey binding, capacity checks, retry safety; persist both genuine yes through request/accept. | LOCKs 7/13 pauses/Replace, 19 Introduce, 21 stages; AD-AIOS-129 names. |
| Consent/scoring | Versioned consent and withdrawal; no unconsented faith processing; delete answers and invalidate derived scores. Only approved kept questions/deal-breakers. | LOCK 6 Consent, 14 Languages, 17/18 Values/Deal-breakers. |
| Receipts/credits | Trusted receipt validation, account/product binding, replay/refund handling and auditable ledger. Client balances/unlock flags are not authority. | Commerce inherited; products/pricing remain OA-SELAH-004. Never sell or withhold the peer Main name for payment. |
| Operations | Independent environments, least-privilege operators, scrubbed logs, monitoring, DB/photo restore and export/deletion processing. | OA-SELAH-002; recovery/retention targets and operators undecided. |

## 3. The four waiting LOCK changes

AD-AIOS-129: each real-app change ships with its server half. Current changes are offline only. Row conversion concerns future SELAH-owned rows, if any; no other-company migration.

| LOCK / row | Exact future server change | Paired app change | Acceptance test after authorization |
|---|---|---|---|
| LOCK 19 Introduce; queue 24 / row 16 | Suggestion-create service and stored suggestions. Authorize the linked Shepherd for the selected Seeker and that Seeker's discovery list; exclude existing requests/Journeys. No candidate/peer-Shepherd notification or disclosure of the Seeker's response. Idempotent retries. Limits/Additional Shepherd eligibility open. | Real HomeShell Introduce and My Selah suggestion read/dismiss/See replace old Network family-request paths together. Reconcile existing read contracts; no invented service name here. | Linked/unlinked/wrong Seeker, discovery exclusions, duplicate retry, private dismissal, no peer notification. Old Network send/read paths unreachable. Never ship one half. |
| LOCK 21 stages; queue 26 | Remove `mentor_gate` from `selah_advance_stage()` and the `matches.journey_stage` CHECK. Move authorized stored rows at that value to `phase_1`, preserving pair/Journey/history/permissions. Plan retry/rollback. Retain DOC-SELAH-0069 §1's seven stored values. | Seven-stage real Journey, Compatibility Reveal directly to Faith & Values; no Shepherd gate/optional greetings. Names follow mutual yes, not stage. | Seven valid transitions, invalid stage rejected; zero/one/many converted rows and retries; preserve Family Review, blocked, ended and unpaid checks. |
| LOCK 18 Deal-breakers; queue 22 | `score_candidates()` reads `ch4_hard_requirements` only for DOC-SELAH-0057 §2b's deal-breakers; no removed partner-screen data. Preserve kept-question scoring and the spec's faith/marriage exclusions. | One optional deal-breakers screen, no partner-preference screens; real scoring uses approved questions/consent. | Five choices and exact saved mappings; empty/None clears requirements; old partner data has no effect; skip/withdraw faith; retained-question fixture comparison. |
| Row 10 Replace; queue 8 / LOCK 13 | Connections takeover transaction rechecks owner, old/new Journey/request, capacity and existing gates; ends selected old Journey and admits eligible replacement together, or changes neither. Define binding, concurrent retry and notification/charge deduplication. | Real Connections Replace and locked pause/error flow together; preserve no-Shepherd rule and membership-dependent capacity. | Wrong owner, stale old Journey, blocked/ended peer, failed accept, lost response, duplicate tap, competing replacements. Failure changes neither; one takeover on success. Pre-consent pause has no real peer name. |

## 4. Name rule at the server boundary

Founder, AD-AIOS-129: **"the other Main Shepherd's real name is shown only after both Seekers say yes to a Journey - never sold, never part of an unlock. Before that, `<Name>'s Shepherd`."** Earliest reveal is mutual yes; no extra readiness, Greeting, stage or payment gate. Your own Main Shepherd retains their existing display name.

For every read, the server must establish authenticated Seeker identity, participation in the requested pair/Journey, the correct counterpart's Main link, and both Seekers' authoritative yes to **that same Journey** through request/accept. Another pair/Journey, a Shepherd invitation, link, fixture, `confirmReady`, stage or paid grant proves none of this. Existing block/end/suspension permissions still apply; name eligibility grants no wider permission.

The source exposes `request_new_journey`, `respond_to_journey_request`, match/pair IDs and status; it does not prove an owned-server schema. Held repositories/client flags are not consent records. A later brief must specify auditable, atomic yes persistence and pair/Journey binding. No schema/RPC is defined here. Pending, one-sided, unknown, failed or mismatched agreement fails closed. If the eligible name is unavailable, use the existing generic fallback, never another link's name.

| Boundary | Required enforcement |
|---|---|
| RPCs and entitlement | Replace/retire `shepherds_for_unlocked`'s paid-name contract (`services/selah_shepherd_info_service.dart:110`). Compatibility Unlock entitlement, `selah_unlock_profile`, balances/tiers and client flags cannot authorize or delay an eligible name. |
| Relations/joins/views | Private real-name source and authorized projection. Row policies alone cannot redact a field. Deny bypass via `profiles`, `mentor_links`, future identity stores, joins/views/broad selects and generic RPC objects. Review every §1 path. |
| Serialization | Omit real-name fields entirely before consent; do not send hidden names behind a visibility flag. UI uses `"<Name>'s Shepherd"` from the authorized Seeker name. Apply the rule to rosters, Main-link data and summaries. |
| Realtime/storage/caches | No pre-consent real name in events, paths, metadata, signed links, search or client caches. Scope caches to caller + pair + Journey; recheck permissions and invalidate on relevant changes. No global target-name cache. |
| Errors/notifications/logs | No pre-consent name in errors/debug/validation details, push/email bodies or previews. Workers recheck the bound pair/Journey and audience at send time. Scrub payloads; diagnostics use opaque IDs. |

Future Supabase controls: grants, row policies, private schemas and narrow projections. Secure Storage/Realtime separately; Data API hooks do not protect them. Review privileged functions/views. Nothing configured here. [Data API security](https://supabase.com/docs/guides/api/securing-your-api), [RLS](https://supabase.com/docs/guides/database/postgres/row-level-security).

Later tests must cover two unrelated pairs and multiple Journeys: anonymous/wrong user; no/one yes; failed accept; forged unlock/ready flag; paid without yes; mutual yes without payment; wrong pair/Journey; absent name; Main-link change; revoked session; block/end races. Inspect serialized responses, raw relations/views, RPCs, realtime, caches, notifications and errors. Only an eligible same-pair/Journey reader receives the real name. A new Journey needs its own agreement. Historical display after ending and Main replacement need an explicit permission/retention contract; uncertainty must not leak a name.

## 5. Personal data

Data-handling proposal for legal review, not legal advice. Faith answers reveal religious belief: special-category data. Health, sex-life/orientation and identification biometrics also require review if processed. Portraits are personal data; biometric identification is a separate choice. Do not revive removed ethnicity/nationality/birth-country, medical/disability or income/debt fields through inherited storage/scoring. [ICO special-category guidance](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/lawful-basis/special-category-data/what-is-special-category-data/).

| Minimum LOCK-needed data | Proposed store / readers | Deletion or withdrawal |
|---|---|---|
| ID, email, sessions, eligibility/recovery data | Independent Auth/private account record; member and restricted support. No contact details in Browse. | Authenticated deletion, session revocation and immediate denial; remove identity/sessions subject to reviewed exceptions. |
| Display name, age/DOB if needed, city, languages, approved marriage/profile answers, photos | Separate private source fields from locked projections; authorized profile viewers only. Private photo objects. | Remove originals/derivatives, profile, indexes/links and caches; stop discovery before cleanup. No inherited extras. |
| Faith profile/Values, Family Compatibility and prayer content: special category where faith-revealing | Restricted answers/consent ledger. Faith profile: member/permitted own Shepherd; others: locked projection only. Raw Values private. Family/prayer: locked audiences. Messages/reports may reveal sensitive data; restrict content and audience. | LOCK 6 withdrawal deletes faith answers/derived scores and stops processing; continued use without faith. Legal review must settle Values/Family/prayer/free-text consent scope and retention; do not assume LOCK 6 covers all. |
| Shepherd identity, invitations and Main/Additional links | Private identity/link store; authorized link audiences. Peer Main name strictly §4, no public directory. | Revoke access/invalidate projections; review invitation and minimum-audit deletion. |
| Requests, both yes records, Journeys, suggestions, compatibility results/consent, messages/prayer | Restricted relationship store; participants and explicitly permitted Shepherds. No disclosure of suggestion response; prayer only to locked audience. | Stop access/notifications; remove/de-identify data/attachments per approved participant/safety retention. No invented duration. |
| Reports, blocks, moderation/verification evidence, security events | Restricted safety store and audited staff access; provider result/reference rather than full ID documents where sufficient. | Reviewed safety/legal exceptions only, with reason/review date/access restriction; no blanket account retention. |
| Receipts, transaction references, credits and access/consent audit | Private authority; member's permitted summary and restricted operators. No card data. | Remove unnecessary identifiers; legal review sets accounting/fraud exceptions and member explanation. |

Deletion must cover Auth, DB, objects/derivatives, caches/search, notification queues and processors. Define DB and photo recovery separately: Supabase DB backups omit stored objects. Set backup expiry and an erasure log reapplied after restore; deleted accounts must remain out of use. Do not promise instant erasure from all backups. [Backup scope](https://supabase.com/docs/guides/platform/backups), [ICO erasure guidance](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/individual-rights/individual-rights/right-to-erasure/).

## 6. Provider choice (proposal, not approval)

Primary documents checked 7 November 2026. SELAH needs independent infrastructure, identities and data. Financial estimates stay private.

| Option | Flutter fit / changes | UK/EU location and limits | Founder actions later |
|---|---|---|---|
| Separate managed Supabase organisation/project | Closest fit to current Auth/Postgres/RPC/Storage/Realtime adapters; engineering starting recommendation only. Build independent schema/security/services: Supabase does not supply the inventoried product RPCs. Replace unsafe name/public-photo assumptions and verify supported pinned SDK/contracts. | Specific London `eu-west-2` or EU region such as Frankfurt `eu-central-1`; generic Europe is not necessarily EU. Project region does not settle all processing/support/transfers. [Regions](https://supabase.com/docs/guides/platform/regions). | Choose ownership/region; personally sign up, accept terms/data agreements and billing; approve access and each setup step. |
| Independent Firebase / Google Cloud project | Official Flutter SDKs, but substantial replacement of relational queries/RPCs, transactions, Auth/Storage/Realtime adapters and permission logic. Trusted functions/rules must reproduce SELAH rules; not a drop-in port. [Flutter setup](https://firebase.google.com/docs/flutter/setup). | Firestore London `europe-west2` or specified EU location; Storage/functions selected separately. Firebase Authentication processes exclusively in the US, so not all-UK/EU Auth. [Firestore](https://firebase.google.com/docs/firestore/locations), [functions](https://firebase.google.com/docs/functions/locations), [processing locations](https://firebase.google.com/support/privacy#data_storage_and_processing_locations). | Decide Auth location acceptability after legal review; personally create account/project, accept terms/billing, choose locations and approve broader rewrite. |

November Supabase Flutter/CLI v3 breaking changes require a later compatibility/version check; no upgrade now. [Changelog](https://supabase.com/changelog), [Flutter v3](https://supabase.com/changelog/supabase-flutter-v3), [CLI v3](https://supabase.com/changelog/supabase-cli-v3).

## 7. Build order after 14 December 2026

No date triggers work automatically. Earliest **15 December 2026**, only with each required Founder yes and approved brief/LOCK prerequisites.

| Step | Small future action / exit evidence | Approval gate |
|---|---|---|
| 1 | Empty independent SELAH test project, synthetic data only, after provider/region/ownership/terms decisions; no member import or other-company backend connection. | **Founder yes needed** for account/project/setup, terms and billing. Founder signs up himself. |
| 2 | Approve minimum fields/roles, pair/Journey yes proof, name projection, deletion contract and synthetic fixtures; resolve missing locked states. | Founder-approved service design/scoped brief; this plan is not approval. |
| 3 | Check existing versions; propose exact tools/packages and sizes; separately approve any install, pin dependencies/lockfiles. | **Founder yes needed** for each install/upgrade, tool and size. |
| 4 | Test-only auth/account slice; check spoofed roles/links, revoked/stale sessions, denial and deletion. | **Founder yes needed** for setup/configuration; scoped build brief. No real identities. |
| 5 | Minimum private profiles, consent, links, photos/quarantine, verification and scoring; test permissions, withdrawal, erasure and removed fields. | **Founder yes needed** for providers/setup/spending; product LOCK/brief per slice. |
| 6 | Requests plus §4 name boundary, same-pair/Journey request+accept proof and all denial tests before enabling a real client. | Scoped Founder-approved server brief; no paid-name dependency. |
| 7 | Deliver §3's four paired changes in bounded slices, tested server half before paired real-app release; no half-complete path. | Founder-approved brief per slice; retry/rollback evidence. |
| 8 | Permitted messaging/realtime, safety and receipt/credit validation; synthetic/store-sandbox tests, callbacks/replay protection. | **Founder yes needed** for provider/commerce setup and spending; product/pricing decisions separate. |
| 9 | Test monitoring, restricted operations, DB/object restore, erasure after restore and notification filtering. Evidence is screenshots/JSON/text only. | Founder-approved operators, retention and recovery targets. |
| 10 | Review staging/production, transfers/legal/content/visual acceptance, load/security evidence and paired release/rollback plan before real setup/data. | **Founder yes needed separately** for every production setup, real-data access/import, deployment and release. |

## 8. Open questions and handover

Preparation under OA-SELAH-002/004; these do not block writing the plan.

| Owner | Still needed |
|---|---|
| Founder | Provider, exact region/entity/owner, billing limit; whether all-UK/EU Auth rules out Firebase. Separate later setup approvals. |
| Founder + legal review | Article 6 basis/Article 9 condition; faith/Values/Family/prayer and sensitive free-text consent/withdrawal (LOCK 6 does not settle all); DPIA, age/identity assurance, processors/transfers, retention/deletion exceptions and staff access. LOCK wording is not a legal finding. |
| SELAH designer + Founder | Suggestion limits/Additional Shepherd eligibility; production moderation/verification/safety and sign-in/recovery states; Profile answer/deal-breaker editing. Preserve locked behaviour until decided. |
| Later server brief | Request/accept proof and atomic pair/Journey binding; Main replacement/ended-Journey name permissions; Connections takeover contract; seven-stage conversion/retry/rollback evidence. No assumed schema mapping. |
| Founder | Products/receipt providers/refund-credit policy, operational owners, retention/recovery targets and launch gates. Peer Main names are already decided: never sold/unlocked. |

**PROPOSED; planning only.** "SELAH has none yet" remains the service baseline. No accounts, sign-ins, installs, upgrades, app code, SQL, migrations, configuration, setup, live backend queries or deployment occurred. No other-company backend or keys accessed. Server enforcement and all four waiting server changes remain unimplemented. Existing 04:00 automation untouched.
