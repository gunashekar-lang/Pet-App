import 'package:flutter/material.dart';

import '../models/health_model.dart';
import '../utils/constants.dart';

/// Static healthcare guidance: care tips, written guides and FAQs. Clinics,
/// services and bookings are intentionally not part of the healthcare hub.
class HealthData {
  HealthData._();

  static const List<HealthTip> tips = [
    HealthTip(
      id: 't1',
      title: 'Watch their water intake',
      message:
          'A sudden 30% jump in drinking is one of the earliest signs of kidney '
          'or diabetes problems. Keep an eye on the bowl.',
      icon: Icons.water_drop_rounded,
      color: AppColors.periwinkle,
    ),
    HealthTip(
      id: 't2',
      title: 'Brush teeth weekly',
      message:
          'Four out of five pets over three have dental disease. Brushing three '
          'times a week prevents most of it.',
      icon: Icons.cleaning_services_rounded,
      color: AppColors.mint,
    ),
    HealthTip(
      id: 't3',
      title: 'Keep them a healthy weight',
      message:
          'Feel for the ribs with a flat hand. You should feel them easily '
          'without pushing hard. Obesity shortens lifespan by years.',
      icon: Icons.monitor_weight_rounded,
      color: AppColors.amber,
    ),
    HealthTip(
      id: 't4',
      title: 'Exercise for the mind too',
      message:
          '15 minutes of sniff-based play tires a dog out more than an hour of '
          'fetch. Hide treats around the house for a free scavenger hunt.',
      icon: Icons.psychology_rounded,
      color: AppColors.plum,
    ),
  ];

  static const List<HealthArticle> articles = [
    HealthArticle(
      id: 'ha01',
      title: 'The 8 things every new pet owner should do in week one',
      summary:
          'A practical checklist for the first seven days home, from vet booking '
          'to setting up a safe room.',
      category: 'New Owners',
      readMinutes: 6,
      isFeatured: true,
      body:
          '''Bringing a new pet home is exciting, but the first week sets the tone for everything that follows.

**1. Set up a safe room.** Before anything else, prepare a small room away from high-traffic areas. Put their bed, food, water and litter tray or toilet there. A frightened animal needs a small, predictable space where they can hide.

**2. Book a vet visit within 72 hours.** Even healthy-looking pets should get a baseline exam. Bring any paperwork that came with the pet, and a fresh stool sample if you can.

**3. Keep the first three days quiet.** No visitors, no other pets, no outings. Let them explore at their own pace.

**4. Start a routine immediately.** Same times for meals, walks and potty breaks. Animals feel safe when the day is predictable.

**5. Introduce handling gently.** Touch paws, ears and mouth briefly, rewarding each time. Never force it.

**6. Start training early.** Name recognition, "sit" and "come" can be taught with treats in the first week. Keep sessions under three minutes.

**7. Pet-proof before you allow free roam.** Secure cables, move toxic plants, block access to bins and medicines.

**8. Keep a health log.** Note food, toilet habits, energy levels and anything unusual. In a month you will not remember, but your vet will thank you for the notes.''',
    ),
    HealthArticle(
      id: 'ha02',
      title: 'Recognising the early signs of common illnesses',
      summary:
          'Appetite, water, energy and coat changes that deserve a vet call '
          'before they become an emergency.',
      category: 'Prevention',
      readMinutes: 8,
      isFeatured: true,
      body:
          '''Most serious conditions show small, subtle changes days or weeks before a pet becomes visibly unwell. Catching them early almost always means a cheaper, easier fix.

**Appetite change.** Skipping a meal occasionally is normal. Refusing food for more than 24 hours, in any species, is not. Dental pain is the most common and most easily missed cause in adult pets.

**Water intake.** Urinating more than usual, asking to go out more often, or drinking noticeably more all point to kidney disease, diabetes or urinary problems.

**Energy and movement.** A dog who stops wanting walks, or a cat who stops jumping, is telling you something. Limping, stiffness or reluctance to be touched all deserve attention.

**Coat and skin.** A dull, greasy coat, sudden hair loss, itching or a strong odour can all trace back to parasites, allergies or thyroid problems.

**Breathing.** Open-mouth breathing at rest, or resting breathing faster than 30 breaths per minute, needs urgent attention.

**Lumps and swelling.** Any new lump that persists more than two weeks should be checked, especially on older pets.

**Behaviour change.** Sudden aggression, hiding, or loss of interest in things they used to love can be a sign of pain rather than mood.

When in doubt, book the appointment. Vet clinics would much rather see a healthy pet for a check-up than a sick one in a panic.''',
    ),
    HealthArticle(
      id: 'ha03',
      title: 'A complete guide to puppy and kitten vaccination schedules',
      summary:
          'Which shots, at what age, and why the booster matters more than the '
          'first dose.',
      category: 'Vaccination',
      readMinutes: 7,
      body:
          '''Vaccination is one of the simplest ways to protect your pet from diseases that are often fatal and always expensive to treat.

**Puppies and kittens: the first 16 weeks.**
- Weeks 6-8: first dose of the core vaccine, plus a deworming treatment.
- Weeks 10-12: second core dose.
- Weeks 14-16: final core dose. Only after this are puppies fully protected.
- Around 12-16 weeks: leptospirosis and, in high-risk areas, Lyme and kennel cough.
- Rabies: required by law in most regions, typically between 12 and 16 weeks.

**Why the final dose matters.** Maternal antibodies interfere with the early doses, protecting your puppy for a few weeks and then fading. The last dose in the series is the one that reliably builds immunity.

**Adult boosters.** Core vaccines are boosted every one to three years, depending on the disease, the individual and your vet's advice. Rabies is usually every one to three years by law.

**Adults and older pets.** If your pet is overdue, do not panic. Most vets can restart a series. A blood titre test can show whether your pet is already protected and avoid unnecessary shots.

**Reactions to watch for.** Mild tiredness and a small bump at the injection site are common and resolve within a day. Facial swelling, vomiting, breathing difficulty or collapse within 24 hours is an emergency. Stay with your vet for 15 minutes after any vaccination to be safe.''',
    ),
    HealthArticle(
      id: 'ha04',
      title: 'Nutrition basics: what is actually on the label',
      summary:
          'Reading ingredient lists, decoding AAFCO statements and spotting '
          'marketing dressed as science.',
      category: 'Nutrition',
      readMinutes: 9,
      body:
          '''Pet food labels are designed to sell, not to inform. Here is how to read them properly.

**Ingredients are listed by weight, before cooking.** This is the most important thing to understand. A food that lists "chicken" first may contain barely any of it, because the chicken loses water during processing.

**Look for a named, specific protein.** "Chicken" is fine. "Chicken meal" is more concentrated, so it often appears higher. A food with five different animal by-products is a blend, not a premium recipe.

**The AAFCO statement tells you what it is.** "Complete and balanced for adult maintenance" is the baseline. "Growth" or "all life stages" means it suits puppies and kittens too. "Intermittent or supplemental feeding" means it is a topper, not a complete diet.

**Guaranteed analysis is a minimum, not a maximum.** "Crude protein 30%" means at least 30% and possibly much more. It also tells you nothing about digestibility.

**Watch the calorie number.** Kilocalories per cup is what matters for portioning. Many owners overfeed by 20-30% simply because the bowl says nothing.

**Treats should be under 10% of daily calories.** This is the single most common mistake in pet feeding. A few chews can add up to a full meal.

**Water beats everything.** Fresh, clean water available at all times matters more than any ingredient on the list. Run bowls daily and keep at least two in the house.

If you want one change that tends to make the biggest difference, move your pet to a food with a named animal protein as the first ingredient and a short, readable ingredient list.''',
    ),
  ];

  /// FAQ entries shown on the healthcare screen.
  static const List<(String, String)> faqs = [
    (
      'How often should my pet see a vet?',
      'Healthy adult pets need at least one check-up a year. Puppies, kittens, '
          'seniors and pets with ongoing conditions should go every 6 months, and '
          'any time something changes.',
    ),
    (
      'Is it normal for my pet to skip a meal?',
      'Occasionally yes, especially in hot weather. Refusing food for more than '
          '24 hours, or showing any other symptoms, is not normal and should be '
          'discussed with your vet.',
    ),
    (
      'What can I safely give a dog for a upset stomach?',
      'A few hours of fasting followed by small, frequent meals of plain cooked '
          'chicken or rice is usually enough. Avoid human medication and call your '
          'vet first.',
    ),
    (
      'How do I find a trustworthy vet?',
      'Ask neighbours for recommendations, check that the clinic is licensed and '
          'accredited, and confirm they treat your species. A good clinic will '
          'happily discuss treatment options and costs upfront.',
    ),
  ];
}
