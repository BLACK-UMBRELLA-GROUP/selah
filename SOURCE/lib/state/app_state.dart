// Shared in-memory app state — the founder's own profile fields
// (collected across Chapter 1/2 onboarding) plus Browse decisions
// (Declined/Saved/Outgoing Likes per PROFILE DECISION SYSTEM/Summary.md)
// and the resulting Potential/Active Journeys (MATCH_UX_SPEC_CURRENT_
// VERSION_V1.md). No backend yet, so this is a single in-memory
// ChangeNotifier singleton — good enough for today's testable build,
// and the natural seam to swap for real persistence (Supabase) later.

import 'package:flutter/foundation.dart';
import '../models/journey_match.dart';
import '../models/journey_bio.dart';
import '../models/seeker_profile.dart';
import '../services/selah_local_prefs.dart';
import '../services/selah_internal_preview_client.dart';
import '../services/selah_mentor_link_service.dart';

enum SelahPlan { basic, one }

class AppState extends ChangeNotifier {
  AppState._();
  static final AppState instance = AppState._();

  // Own profile — filled in as onboarding chapters complete, AND
  // rehydrated from the database on every cold start (see
  // SelahSessionRouter.hydrate). Before 2026-08-01 only the first of those
  // existed, so every field here was null on relaunch — see hydrate()'s
  // doc comment for what that broke.
  String? name;

  /// Middle name and surname together, as one line — "Fatima Ahmed" beside
  /// a `name` of "Maryam". The same shape SeekerProfile.surnameLine uses
  /// for everybody else, so the Founder's own profile and a Browse card
  /// render from the same idea rather than two.
  ///
  /// ADDED 2026-08-07. It was the last of the three fields carrying a "not
  /// faked" note on screen — `profiles.surname_line` has existed and been
  /// selectable since July, and three screens said so in comments while
  /// showing a first name where a full name was asked for. `bio` and
  /// `created_at` are still outstanding.
  String? surnameLine;

  /// "Maryam Fatima Ahmed", or just "Maryam" when there is no surname —
  /// never a trailing space, and never the word "null".
  String? get fullName {
    final n = name?.trim();
    if (n == null || n.isEmpty) return null;
    final s = surnameLine?.trim();
    return (s == null || s.isEmpty) ? n : '$n $s';
  }

  String? gender;
  DateTime? dob;
  List<String> photos = [];
  double avatarAlignmentX = 0;
  double avatarAlignmentY = 0;
  String? location;
  String? christianTradition;
  SelahPlan plan = SelahPlan.basic;

  /// Optional, Journey-only biography assembled during Seeker onboarding.
  /// It is intentionally separate from the scored Chapter 3/4 answers.
  JourneyBio journeyBio = const JourneyBio();

  /// Server-computed age, from ages_for(). Separate from [dob] because
  /// `profiles.date_of_birth` is no longer selectable by the client
  /// (audit finding C2 — the column-level SELECT was revoked on
  /// 2026-08-01), so a rehydrated session can know the age without ever
  /// receiving the birthdate. [dob] stays populated during the onboarding
  /// session that captured it, and is null on every subsequent launch —
  /// prefer this field for display.
  int? age;

  /// True once hydrate() has run for this launch. Screens don't currently
  /// need it, but without a flag there is no way to tell "not loaded yet"
  /// from "loaded, and genuinely empty" — which is exactly the ambiguity
  /// that made the null-gender bug hard to spot.
  bool hydrated = false;

  /// A principal change is a new member session, including when the next
  /// principal opens the Founder landing without choosing a sample persona.
  /// This is deliberately independent of developer mode and never persists.
  void resetForAccountChange() {
    name = null;
    surnameLine = null;
    gender = null;
    dob = null;
    photos = [];
    avatarAlignmentX = 0;
    avatarAlignmentY = 0;
    location = null;
    christianTradition = null;
    plan = SelahPlan.basic;
    journeyBio = const JourneyBio();
    age = null;
    hydrated = false;
    notifyNewMatches = true;
    notifyNewMessages = true;
    notifyMentorRequests = true;
    mentorName = null;
    mentorRelationship = null;
    mentorHasMentorOne = false;
    mentorLinkedSeekers.clear();
    mentorRealLinkedSeekers = [];
    declined.clear();
    saved.clear();
    outgoingLikes.clear();
    potentialJourneys = [];
    activeJourneys = [];
    pendingBrowseProfile = null;
    shepherdSuggestedBy = const {};
    deckVersion++;
    suggestionsVersion++;
    notifyListeners();
  }

  /// Populates this singleton from the signed-in user's real rows.
  /// Called once per cold start by SelahSessionRouter.
  void hydrateFrom({
    String? name,
    String? surnameLine,
    String? gender,
    String? location,
    int? age,
    SelahPlan? plan,
  }) {
    this.name = name;
    // Replace missing fields too: a missing row value never means that a
    // preceding member's value remains valid. Preview identity stays local.
    if (!SelahInternalPreviewClient.isActive) {
      SelahLocalPrefs.setCachedFirstName(name);
    }
    this.surnameLine = surnameLine;
    this.gender = gender;
    if (!SelahInternalPreviewClient.isActive) {
      SelahLocalPrefs.setCachedGender(gender);
    }
    this.location = location;
    this.age = age;
    this.plan = plan ?? SelahPlan.basic;
    avatarAlignmentX = SelahLocalPrefs.cachedAvatarAlignmentX;
    avatarAlignmentY = SelahLocalPrefs.cachedAvatarAlignmentY;
    hydrated = true;
    notifyListeners();
  }

  // Notification preferences (2026-07-26, Settings build-out). No push
  // notification system exists in this build yet (no Bell icon, no
  // delivery mechanism, no backend table) — these are preference
  // toggles only, captured now so they're ready to wire up the moment
  // real notifications are built, per NotificationSettingsScreen's own
  // on-screen disclosure. In-memory only, like the rest of AppState.
  bool notifyNewMatches = true;
  bool notifyNewMessages = true;
  bool notifyMentorRequests = true;

  void setNotificationPreference({
    bool? newMatches,
    bool? newMessages,
    bool? mentorRequests,
  }) {
    if (newMatches != null) notifyNewMatches = newMatches;
    if (newMessages != null) notifyNewMessages = newMessages;
    if (mentorRequests != null) notifyMentorRequests = mentorRequests;
    notifyListeners();
  }

  // Shepherd identity — separate from the Seeker profile fields above per
  // MENTOR_ARCHITECTURE_CURRENT_VERSION_V5.md: "Shepherd accounts carry
  // identity only" and are entirely separate from a Seeker account (a
  // person cannot be both on the same account). Kept minimal since the
  // onboarding content itself is a v1 draft — see inherited decision 081.
  String? mentorName;

  /// DEMOTED 2026-08-06 — **not authoritative**. A display LABEL captured at
  /// Shepherd onboarding, held in memory, never persisted.
  ///
  /// The database is the source of truth: `mentor_links.relationship`, stored
  /// as a code, one per link. This field survives for exactly one purpose —
  /// pre-filling the relationship the Shepherd already stated when they go
  /// on to accept an invite (`accept_mentor_invite_screen`). It must never
  /// again be read as an answer to "how is this Shepherd related", because
  /// it cannot be: a Shepherd linked to two Seekers has two relationships
  /// and this holds one value.
  ///
  /// Founder, 2026-08-06: *"Remove every authoritative read… it should never
  /// override database data once a link has been created."*
  ///
  /// If you are about to read this field to render something, you want
  /// `MentorLinkedPerson.relationshipLabel` instead.
  String? mentorRelationship; // Label, e.g. 'Father'. Prefill only.
  bool mentorHasMentorOne =
      false; // Legacy local seam for SELAH One — Shepherd (£19.99/month).

  // Superseded by mentorRealLinkedSeekers below (2026-07-18, real Shepherd
  // linking) — kept to avoid touching any other reference, but no
  // longer written to.
  final List<SeekerProfile> mentorLinkedSeekers = [];

  // Real linked Seekers, fetched via SelahMentorLinkService.fetchLinkedPeople
  // (asMentor: true) from the live mentor_links table. Deliberately just
  // id/firstName — Journey/Timeline visibility for a Shepherd isn't built
  // yet, so this only supports "who is linked", not "what's happening
  // in their Journey".
  List<MentorLinkedPerson> mentorRealLinkedSeekers = [];

  void setMentorRealLinkedSeekers(List<MentorLinkedPerson> people) {
    mentorRealLinkedSeekers = people;
    notifyListeners();
  }

  void saveMentorOnboarding({
    required String name,
    required String relationship,
    required String gender,
    String? surnameLine,
  }) {
    mentorName = name;
    this.name = name;
    this.surnameLine = surnameLine;
    mentorRelationship = relationship;
    this.gender = gender;
    if (!SelahInternalPreviewClient.isActive) {
      SelahLocalPrefs.setCachedGender(gender);
    }
    notifyListeners();
  }

  void setMentorOne(bool value) {
    mentorHasMentorOne = value;
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // ONE STATE PER PROFILE — Founder decision 2026-08-03.
  //
  // Saved, Considering and Declined are MUTUALLY EXCLUSIVE. A profile sits
  // in exactly one of them, or none. The most recent action wins.
  //
  // THIS REVERSES THE 2026-08-01 DECISION, deliberately and on the record,
  // because the comment that used to sit here argued the opposite case at
  // length and someone will otherwise reintroduce it:
  //
  //   1 Aug   Saved was a BOOKMARK on its own axis. Saved + Considering
  //           was valid and intended. Rationale: "don't let me lose this
  //           profile" is not a decision.
  //   3 Aug   Founder, seeing Sami appear under both CONSIDERED and SAVED:
  //           "a user can't be both saved and considered, so there's an
  //           error there."
  //
  // The two-axis model was defensible and the data was never wrong. It
  // lost on the only ground that matters: shown a person in two places,
  // the Founder read it as a bug every single time. A model that has to be
  // explained before a screen makes sense is the wrong model.
  //
  // Enforced in three places, so a client that forgets cannot break it:
  //   here                     the three methods below
  //   database                 saves/likes/passes exclusivity triggers
  //   test/decision_model_test the invariant, asserted
  // ---------------------------------------------------------------------
  final List<SeekerProfile> declined = [];
  final List<SeekerProfile> saved = [];
  final List<SeekerProfile> outgoingLikes = [];

  /// Every profile the Seeker has acted on, in any way. Browse excludes
  /// these from the deck.
  ///
  /// Now INCLUDES `saved`. Under the two-axis model a bookmark was not a
  /// decision, so a saved profile stayed browsable and wore a badge. With
  /// one state per profile, saving IS acting on someone — so they leave
  /// the deck like anything else, and the Browse "Saved" badge that
  /// existed to explain their reappearance is gone with it.
  Set<String> get decidedProfileIds => {
    for (final p in declined) p.id,
    for (final p in outgoingLikes) p.id,
    for (final p in saved) p.id,
  };

  bool isSaved(String profileId) => saved.any((p) => p.id == profileId);

  /// Drops a profile from all three lists. Every state change goes through
  /// this first, which is what makes the states exclusive rather than
  /// merely usually-exclusive.
  void _clearState(String id) {
    declined.removeWhere((x) => x.id == id);
    saved.removeWhere((x) => x.id == id);
    outgoingLikes.removeWhere((x) => x.id == id);
  }

  // Journeys — per MATCH_UX_SPEC: Match event (mutual Like) creates a
  // Potential Journey; the Pre-Journey Ritual (SelahJourneyService.
  // promoteToActive, a real RPC) promotes it to an Active Journey.
  // Real matches.status/journey_stage now back this directly (2026-07-25
  // migration) — these lists are populated wholesale via
  // setJourneyMatches() after a SelahJourneyService.fetchJourneyMatches()
  // call, not mutated locally.
  List<JourneyMatch> potentialJourneys = [];
  List<JourneyMatch> activeJourneys = [];

  /// Replaces both Journey lists wholesale from a fresh
  /// SelahJourneyService.fetchJourneyMatches() read — the way screens
  /// refresh Journey state after any promote/suspend/resume/end call,
  /// now that Journey lifecycle is real backend state rather than a
  /// local synchronous mutation.
  void setJourneyMatches({
    required List<JourneyMatch> potential,
    required List<JourneyMatch> active,
  }) {
    potentialJourneys = potential;
    activeJourneys = active;
    notifyListeners();
  }

  void saveChapter1({
    required String name,
    required String gender,
    required DateTime dob,
    String? surnameLine,
  }) {
    this.name = name;
    this.surnameLine = surnameLine;
    // First moment a new Seeker's name exists — cached for the same
    // launch-after-onboarding reason as the gender line below
    // (inherited decision 169 Phase 2).
    if (!SelahInternalPreviewClient.isActive) {
      SelahLocalPrefs.setCachedFirstName(name);
    }
    this.gender = gender;
    // First moment a new Seeker's gender exists. Without this the launch
    // straight after onboarding would still flash.
    if (!SelahInternalPreviewClient.isActive) {
      SelahLocalPrefs.setCachedGender(gender);
    }
    this.dob = dob;
    notifyListeners();
  }

  void saveChapter2({
    required List<String> photos,
    String? location,
    String? christianTradition,
  }) {
    this.photos = photos;
    this.location = location;
    this.christianTradition = christianTradition;
    notifyListeners();
  }

  /// Updates only the ordered profile-photo projection after Edit Photos.
  /// The first entry is the main photo; persistence remains owned by
  /// SelahPhotoService rather than this in-memory state object.
  void setProfilePhotos(List<String> value) {
    photos = List<String>.of(value);
    notifyListeners();
  }

  void setAvatarAlignmentY(double value) {
    avatarAlignmentY = value.clamp(-1.0, 1.0).toDouble();
    if (!SelahInternalPreviewClient.isActive) {
      SelahLocalPrefs.setAvatarAlignmentY(avatarAlignmentY);
    }
    notifyListeners();
  }

  void setAvatarAlignment({required double x, required double y}) {
    avatarAlignmentX = x.clamp(-1.0, 1.0).toDouble();
    avatarAlignmentY = y.clamp(-1.0, 1.0).toDouble();
    if (!SelahInternalPreviewClient.isActive) {
      SelahLocalPrefs.setAvatarAlignmentX(avatarAlignmentX);
      SelahLocalPrefs.setAvatarAlignmentY(avatarAlignmentY);
    }
    notifyListeners();
  }

  void saveJourneyBio(JourneyBio value) {
    journeyBio = value;
    notifyListeners();
  }

  /// Decline. Clears any other state first — see the note above.
  void decline(SeekerProfile p) {
    // recordPass is an idempotent insert: re-passing an existing Pass does
    // not change its server timestamp. Keep that same recency locally.
    if (declined.any((existing) => existing.id == p.id)) return;
    _clearState(p.id);
    // Match fetchDecisions' created_at DESC order. A new Pass goes first;
    // membership display windows never trim this list.
    declined.insert(0, p);
    notifyListeners();
  }

  /// Save. Now a STATE, not a bookmark: saving someone you were
  /// Considering removes the Consider.
  void save(SeekerProfile p) {
    _clearState(p.id);
    saved.add(p);
    notifyListeners();
  }

  /// Removes a Save, leaving the profile in no state at all. It becomes
  /// browsable again — which is correct: un-saving is undoing the only
  /// thing you had done.
  void unsave(SeekerProfile p) {
    saved.removeWhere((x) => x.id == p.id);
    notifyListeners();
  }

  /// Replaces all three lists from the database on sign-in.
  ///
  /// LOST AND RESTORED 2026-08-03. It sat inside the DECISIONS block that
  /// was rewritten for the one-state model and went out with it —
  /// `flutter analyze` caught the orphaned call in SelahSessionRouter.
  /// Brace-balance checks cannot see this class of mistake: deleting a
  /// method leaves perfectly valid syntax.
  ///
  /// Replaces rather than merges. The database is the source of truth at
  /// sign-in, and merging would resurrect anything removed on another
  /// device.
  ///
  /// The lists arrive already exclusive — the saves/likes/passes triggers
  /// guarantee it server-side — so no reconciliation is needed here. If a
  /// profile ever did appear in two, the later list would silently win,
  /// which is why the invariant is enforced in the database and not left
  /// to this method.
  void hydrateDecisions({
    required List<SeekerProfile> saved,
    required List<SeekerProfile> considered,
    required List<SeekerProfile> passed,
  }) {
    this.saved
      ..clear()
      ..addAll(saved);
    outgoingLikes
      ..clear()
      ..addAll(considered);
    declined
      ..clear()
      ..addAll(passed);
    notifyListeners();
  }

  /// Reset Search — Founder decision 2026-08-01: clears Declined ONLY.
  ///
  /// Not Considering, not Saved. This exists to give people another chance
  /// at profiles they passed on.
  void resetDeclined() {
    declined.clear();
    notifyListeners();
  }

  /// Consider. Clears any other state first.
  bool like(SeekerProfile p) {
    _clearState(p.id);
    outgoingLikes.add(p);
    final isMatch = p.alreadyLikedYou;
    notifyListeners();
    return isMatch;
  }

  /// Developer Mode preset support (2026-07-19, Founder request) —
  /// resets all session-scoped state and applies a scenario in one
  /// step, so switching test accounts never leaks the previous
  /// scenario's Browse decisions, journeys, or profile fields into the
  /// next one. Only called from DeveloperAccessScreen.
  void applyDevPreset({
    String? name,
    String? gender,
    DateTime? dob,
    SelahPlan plan = SelahPlan.basic,
    String? location,
    String? mentorName,
    String? mentorRelationship,
    bool mentorHasMentorOne = false,
  }) {
    if (SelahInternalPreviewClient.isActive) {
      // A main-account preview must not inherit real identity/context, and
      // the same reset runs before leaving the latched preview at sign-out.
      surnameLine = null;
      age = null;
      hydrated = false;
      journeyBio = const JourneyBio();
      pendingBrowseProfile = null;
      shepherdSuggestedBy = const {};
      mentorLinkedSeekers.clear();
      notifyNewMatches = true;
      notifyNewMessages = true;
      notifyMentorRequests = true;
      deckVersion++;
      suggestionsVersion++;
    }
    this.name = name;
    // Same inherited decision 165 lesson applied to the name on day one
    // (inherited decision 169 Phase 2): every writer caches, or the cache lies
    // after a Developer Access switch. A null name clears the key.
    if (!SelahInternalPreviewClient.isActive) {
      SelahLocalPrefs.setCachedFirstName(name);
    }
    this.gender = gender;
    // CACHES IT TOO — 2026-08-13 (inherited decision 165). This was the only gender
    // writer in the class that did not, so a Developer Access switch
    // changed the live gender and left the disk cache holding whoever
    // was signed in before. main() reads that cache on the next launch
    // to pick the first colour painted, so the next cold start opened in
    // the previous account's gradient. Compare hydrateFrom and
    // saveChapter1, which have always written both.
    if (!SelahInternalPreviewClient.isActive) {
      SelahLocalPrefs.setCachedGender(gender);
    }
    this.dob = dob;
    this.plan = plan;
    this.location = location;
    photos = [];
    avatarAlignmentX = 0;
    avatarAlignmentY = 0;
    christianTradition = null;
    this.mentorName = mentorName;
    this.mentorRelationship = mentorRelationship;
    this.mentorHasMentorOne = mentorHasMentorOne;
    mentorRealLinkedSeekers = [];
    declined.clear();
    saved.clear();
    outgoingLikes.clear();
    potentialJourneys.clear();
    activeJourneys.clear();
    notifyListeners();
  }

  /// Clears every decision, leaving identity and profile data alone.
  ///
  /// ADDED 2026-08-04 for the dev panel's "Reset account state" button
  /// (Founder: "I need a profile reset button in toggle since I can't reset
  /// all things"). The panel deletes the matching database rows; this drops
  /// the in-memory mirror so the UI does not keep showing decisions that no
  /// longer exist on the server.
  ///
  /// Deliberately narrower than the full reset above: photos, Christian
  /// tradition, name
  /// and Shepherd details survive, because they cost real effort to set up
  /// and a reset that destroyed them would be too dangerous to use.
  /// Bumped whenever the deck must be re-fetched from scratch rather than
  /// merely re-filtered. Browse watches this and reloads.
  ///
  /// ADDED 2026-08-05 (Fable). Resetting from the dev panel cleared the
  /// decision lists and the server rows, so profiles vanished from
  /// Connections — but Browse fetches once in initState and holds the deck
  /// in its own State, so the profiles never came back until the app was
  /// restarted. "Reset" that needs a restart to finish isn't a reset.
  int deckVersion = 0;

  /// Bumped when Shepherd Suggestions change on the server, so Connections
  /// refetches instead of showing a stale list. Same pattern as
  /// [deckVersion] and for the same reason — a screen that loads once in
  /// initState cannot know the world moved underneath it.
  int suggestionsVersion = 0;

  void bumpSuggestions() {
    suggestionsVersion++;
    notifyListeners();
  }

  /// A profile Browse should jump to next time it opens, set by "View
  /// profile" on a Shepherd Suggestion (Founder, 2026-08-05: "a user has a
  /// button to view profile which then takes them back on the Browse page").
  ///
  /// Carried as state rather than a route argument because Browse is a TAB,
  /// not a pushed screen — HomeShell keeps all four alive in an IndexedStack
  /// — so there is no navigation call to hang an argument off. Browse clears
  /// it once consumed, so returning to the tab later doesn't re-jump.
  SeekerProfile? pendingBrowseProfile;

  /// Who suggested each profile, by profile id — e.g. `{'abc…': 'Ibrahim'}`.
  ///
  /// Held app-wide, not inside Connections, because the fact travels with
  /// the person (Founder, 2026-08-05: "a shepherd suggested a person but a
  /// person was browsing anyway and saw a person shepherd suggested… if
  /// they decline, consider etc it moves to decline/consider/save but still
  /// with the word shepherd suggested somewhere"). Browse marks them
  /// whether you arrived from the suggestion or simply met them in the
  /// deck, and the mark survives into whichever list they end up in.
  Map<String, String> shepherdSuggestedBy = const {};

  void setShepherdSuggestedBy(Map<String, String> byId) {
    shepherdSuggestedBy = byId;
    notifyListeners();
  }

  /// The Shepherd who suggested [profileId], or null if nobody did.
  String? suggestedBy(String profileId) => shepherdSuggestedBy[profileId];

  void requestBrowseProfile(SeekerProfile p) {
    pendingBrowseProfile = p;
    notifyListeners();
  }

  SeekerProfile? takePendingBrowseProfile() {
    final p = pendingBrowseProfile;
    pendingBrowseProfile = null;
    return p;
  }

  void clearDecisionsForReset() {
    declined.clear();
    saved.clear();
    outgoingLikes.clear();
    potentialJourneys.clear();
    activeJourneys.clear();
    deckVersion++;
    notifyListeners();
  }

  /// Requests a clean Browse fetch without changing any decision state.
  /// Used when a profile is unhidden: the server may return that person
  /// again, while developer-preview hides are resolved from local storage.
  void refreshBrowseDeck() {
    deckVersion++;
    notifyListeners();
  }

  /// Removes a newly hidden person from every account-local surface now.
  /// The server/RLS owns the durable boundary for real accounts; this avoids
  /// leaving a stale card visible until each kept-alive tab happens to fetch.
  void removeHiddenProfileFromSession(String profileId) {
    _clearState(profileId);
    potentialJourneys.removeWhere((journey) => journey.profile.id == profileId);
    activeJourneys.removeWhere((journey) => journey.profile.id == profileId);
    if (pendingBrowseProfile?.id == profileId) pendingBrowseProfile = null;
    if (shepherdSuggestedBy.containsKey(profileId)) {
      shepherdSuggestedBy = Map<String, String>.from(shepherdSuggestedBy)
        ..remove(profileId);
    }
    notifyListeners();
  }

  /// Mock plan change — real purchase flow (App Store/Play Store IAP,
  /// or Stripe for web) is not built yet; this just flips the local
  /// entitlement so tier-gated UI (Incoming Potentials, daily limits,
  /// Pause Journey, etc. per SELAH_PRODUCT_SPEC_CURRENT_VERSION_V4.md §6-7)
  /// is testable today.
  void setPlan(SelahPlan newPlan) {
    plan = newPlan;
    notifyListeners();
  }
}
