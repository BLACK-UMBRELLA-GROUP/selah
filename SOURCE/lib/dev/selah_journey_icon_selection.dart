// Paint-only historical shapes. The Founder selected Couple on 2026-10-13;
// there is no runtime chooser, account store or comparison setter anymore.
enum SelahJourneyIconDesign {
  current('Current'),
  footsteps('Footsteps'),
  sharedPath('Shared path'),
  together('Together'),
  linked('Linked'),
  lasting('Lasting'),
  growing('Growing'),
  milestone('Milestone'),
  twoPaths('Two paths'),
  withIntention('With intention'),
  couple('Couple');

  const SelahJourneyIconDesign(this.label);
  final String label;
}
