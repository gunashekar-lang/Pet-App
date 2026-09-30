import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../models/pet_model.dart';
import '../../models/user_model.dart';
import '../../services/pet_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/common.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/pet_card.dart';
import '../../widgets/section_header.dart';

/// Full listing detail: photo gallery, health records, seller card,
/// description, reviews and the contact / buy actions.
class PetDetailsScreen extends StatefulWidget {
  const PetDetailsScreen({super.key, required this.petId});

  final String petId;

  @override
  State<PetDetailsScreen> createState() => _PetDetailsScreenState();
}

class _PetDetailsScreenState extends State<PetDetailsScreen> {
  late final PageController _galleryController = PageController();
  int _imageIndex = 0;

  @override
  void dispose() {
    _galleryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<PetService>();
    final pet = service.petById(widget.petId);
    final scheme = Theme.of(context).colorScheme;
    final related = service.relatedPets(widget.petId);

    if (pet == null) {
      return Scaffold(
        appBar: AppBar(leading: const _BackButton()),
        body: EmptyState(
          icon: Icons.pets_rounded,
          title: 'Listing unavailable',
          message: 'This listing may have been sold or removed.',
          actionLabel: 'Back to marketplace',
          onAction: () => Nav.pop(context),
        ),
      );
    }

    final isFavorite = service.isFavorite(pet.id);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 340,
            pinned: true,
            stretch: true,
            backgroundColor: scheme.surface,
            surfaceTintColor: Colors.transparent,
            leading: const Padding(
              padding: EdgeInsets.only(left: 8),
              child: _BackButton(),
            ),
            actions: [
              CircleIconButton(
                icon: Icons.ios_share_rounded,
                tooltip: 'Share listing',
                onTap: () => _share(context, pet),
              ),
              Gap.w8,
              CircleIconButton(
                icon: isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                foreground: isFavorite ? AppColors.danger : null,
                tooltip: isFavorite ? 'Remove from favourites' : 'Save',
                onTap: () {
                  HapticFeedback.lightImpact();
                  service.toggleFavorite(pet.id);
                },
              ),
              Gap.w8,
            ],
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: _Gallery(
                pet: pet,
                controller: _galleryController,
                index: _imageIndex,
                onPageChanged: (i) => setState(() => _imageIndex = i),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(pet: pet),
                  Gap.h16,
                  _QuickFacts(pet: pet),
                  Gap.h20,
                  _GroupTitle('About ${pet.name}'),
                  Gap.h8,
                  Text(
                    pet.description,
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.6,
                      color: scheme.onSurface.withValues(alpha: 0.75),
                    ),
                  ),
                  Gap.h20,
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tag in pet.tags)
                        StatusPill(label: tag, icon: Icons.check_rounded),
                    ],
                  ),
                  Gap.h24,
                  _HealthRecords(pet: pet),
                  Gap.h24,
                  const _GroupTitle('Seller'),
                  Gap.h10,
                  _SellerCard(pet: pet),
                  Gap.h24,
                  const _GroupTitle('Reviews from buyers'),
                  Gap.h12,
                  ...service.reviews.map(
                    (r) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ReviewTile(review: r),
                    ),
                  ),
                  Gap.h16,
                  _Engagement(pet: pet),
                  if (related.isNotEmpty) ...[
                    Gap.h24,
                    const _GroupTitle('Similar pets'),
                    Gap.h12,
                    ...related
                        .take(3)
                        .map(
                          (p) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: PetListTile(
                              pet: p,
                              isFavorite: service.isFavorite(p.id),
                              onFavoriteToggle: () =>
                                  service.toggleFavorite(p.id),
                              onTap: () {
                                Nav.pop(context);
                                Nav.push(
                                  context,
                                  AppRoutes.petDetails,
                                  PetDetailsArgs(p.id),
                                );
                              },
                            ),
                          ),
                        ),
                  ],
                  Gap.h120,
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _ActionBar(pet: pet, isFavorite: isFavorite),
    );
  }

  void _share(BuildContext context, PetModel pet) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('Link to ${pet.name} copied to clipboard')),
      );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CircleIconButton(
      icon: Icons.arrow_back_rounded,
      size: 38,
      background: scheme.surface,
      onTap: () => Nav.pop(context),
    );
  }
}

class _Gallery extends StatelessWidget {
  const _Gallery({
    required this.pet,
    required this.controller,
    required this.index,
    required this.onPageChanged,
  });

  final PetModel pet;
  final PageController controller;
  final int index;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final urls = pet.imageUrls.isEmpty ? [''] : pet.imageUrls;

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: controller,
          itemCount: urls.length,
          onPageChanged: onPageChanged,
          itemBuilder: (context, i) => AppImage(
            url: urls[i],
            fit: BoxFit.cover,
            icon: pet.species.icon,
            gradientColors: [
              scheme.primary.withValues(alpha: 0.3),
              scheme.primary.withValues(alpha: 0.1),
            ],
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.3),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.1),
                ],
                stops: const [0, 0.3, 1],
              ),
            ),
          ),
        ),
        if (urls.length > 1)
          Positioned(
            bottom: 18,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < urls.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == index ? 20 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: i == index
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
              ],
            ),
          ),
        Positioned(
          left: 20,
          bottom: 18,
          child: StatusPill(
            label: '${index + 1}/${urls.length}',
            color: Colors.black.withValues(alpha: 0.5),
            solid: true,
            dense: true,
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.pet});

  final PetModel pet;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          pet.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.8,
                          ),
                        ),
                      ),
                      if (pet.isVerified) ...[
                        Gap.w8,
                        Icon(
                          Icons.verified_rounded,
                          size: 20,
                          color: scheme.secondary,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${pet.breed} • ${pet.species.label}',
                    style: TextStyle(
                      fontSize: 14,
                      color: scheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Gap.w12,
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  Helpers.currency(pet.price),
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    color: scheme.primary,
                    letterSpacing: -0.8,
                  ),
                ),
                Text(
                  pet.negotiable ? 'Price negotiable' : 'Firm price',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ],
        ),
        Gap.h12,
        Row(
          children: [
            StatusPill(
              label: pet.status.label,
              icon: Icons.circle,
              color: pet.status == PetStatus.available
                  ? AppColors.success
                  : AppColors.warning,
            ),
            Gap.w8,
            StatusPill(label: pet.condition.label, color: scheme.secondary),
            Gap.w8,
            StatusPill(
              label: pet.location,
              icon: Icons.location_on_rounded,
              color: scheme.onSurface.withValues(alpha: 0.6),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickFacts extends StatelessWidget {
  const _QuickFacts({required this.pet});

  final PetModel pet;

  @override
  Widget build(BuildContext context) {
    final facts = [
      (Icons.cake_rounded, 'Age', pet.ageLabel),
      (Icons.male_rounded, 'Gender', pet.gender),
      (Icons.location_on_rounded, 'Location', pet.location),
      (Icons.visibility_rounded, 'Views', '${pet.views}'),
    ];

    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Row(
        children: [
          for (var i = 0; i < facts.length; i++) ...[
            if (i > 0) const VerticalDivider(width: 1),
            Expanded(
              child: Column(
                children: [
                  Icon(
                    facts[i].$1,
                    size: 19,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  Gap.h6,
                  Text(
                    facts[i].$2,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    facts[i].$3,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HealthRecords extends StatelessWidget {
  const _HealthRecords({required this.pet});

  final PetModel pet;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final checks = <(IconData, String, bool, Color)>[
      (Icons.vaccines_rounded, 'Vaccinated', pet.vaccinated, AppColors.success),
      (Icons.medication_rounded, 'Dewormed', pet.dewormed, AppColors.success),
      (
        Icons.medical_services_rounded,
        'Health checked',
        pet.healthChecked,
        AppColors.success,
      ),
      (
        Icons.qr_code_2_rounded,
        'Microchipped',
        pet.microchipped,
        AppColors.accent,
      ),
      (Icons.healing_rounded, 'Neutered', pet.neutered, AppColors.plum),
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.health_and_safety_rounded,
                  size: 20,
                  color: AppColors.success,
                ),
              ),
              Gap.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Health records',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Health score ${pet.healthScore}/100',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              _ScoreRing(score: pet.healthScore),
            ],
          ),
          Gap.h16,
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: pet.healthScore / 100,
              minHeight: 6,
              backgroundColor: scheme.onSurface.withValues(alpha: 0.07),
              valueColor: const AlwaysStoppedAnimation(AppColors.success),
            ),
          ),
          Gap.h16,
          for (final check in checks)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(
                    check.$3
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    size: 18,
                    color: check.$3
                        ? check.$4
                        : scheme.onSurface.withValues(alpha: 0.3),
                  ),
                  Gap.w10,
                  Text(
                    check.$2,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: check.$3
                          ? scheme.onSurface
                          : scheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          if (pet.vaccineDetails.isNotEmpty) ...[
            const Divider(),
            Gap.h12,
            Text(
              pet.vaccineDetails,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: scheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScoreRing extends StatelessWidget {
  const _ScoreRing({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: score / 100,
            strokeWidth: 4,
            backgroundColor: AppColors.success.withValues(alpha: 0.15),
            valueColor: const AlwaysStoppedAnimation(AppColors.success),
          ),
          Text(
            '$score',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _SellerCard extends StatelessWidget {
  const _SellerCard({required this.pet});

  final PetModel pet;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final seller = pet.seller;

    return AppCard(
      onTap: () => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('${seller.name}\'s profile coming soon')),
        ),
      child: Column(
        children: [
          Row(
            children: [
              AppAvatar(
                url: seller.avatarUrl,
                initials: Helpers.initials(seller.name),
                size: 50,
              ),
              Gap.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            seller.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (seller.verified) ...[
                          Gap.w6,
                          Icon(
                            Icons.verified_rounded,
                            size: 15,
                            color: scheme.secondary,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: AppColors.warning,
                        ),
                        Gap.w2,
                        Text(
                          '${seller.rating.toStringAsFixed(1)} (${seller.reviewCount})',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Gap.w8,
                        Text(
                          '• ${Helpers.plural(seller.reviewCount, 'review').split(' ').last}',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      seller.responseTime,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: scheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
          Gap.h12,
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Member since',
                  value: seller.memberSince == null
                      ? '—'
                      : '${seller.memberSince!.year}',
                ),
              ),
              Gap.w8,
              Expanded(
                child: _MiniStat(
                  label: 'Location',
                  value: seller.location.split(',').first,
                ),
              ),
              Gap.w8,
              const Expanded(
                child: _MiniStat(label: 'Response', value: '< 1 hr'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: scheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final ReviewModel review;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAvatar(
                url: review.avatarUrl,
                initials: Helpers.initials(review.author),
                size: 36,
              ),
              Gap.w10,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.author,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      Helpers.relativeTime(review.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < 5; i++)
                    Icon(
                      i < review.rating.round()
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 14,
                      color: AppColors.warning,
                    ),
                ],
              ),
            ],
          ),
          Gap.h10,
          Text(
            review.comment,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: scheme.onSurface.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}

class _Engagement extends StatelessWidget {
  const _Engagement({required this.pet});

  final PetModel pet;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Row(
        children: [
          _EngagementStat(
            icon: Icons.visibility_rounded,
            value: '${pet.views}',
            label: 'Views',
          ),
          const VerticalDivider(width: 1),
          _EngagementStat(
            icon: Icons.favorite_rounded,
            value: '${pet.favoriteCount}',
            label: 'Saves',
          ),
          const VerticalDivider(width: 1),
          _EngagementStat(
            icon: Icons.calendar_today_rounded,
            value: pet.createdAt == null
                ? '—'
                : Helpers.dayMonth(pet.createdAt!),
            label: 'Listed',
          ),
        ],
      ),
    );
  }
}

class _EngagementStat extends StatelessWidget {
  const _EngagementStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: scheme.onSurface.withValues(alpha: 0.5)),
          Gap.h6,
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              color: scheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
  );
}

/// Sticky bottom bar with the primary purchase actions.
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.pet, required this.isFavorite});

  final PetModel pet;
  final bool isFavorite;

  @override
  Widget build(BuildContext context) {
    final service = context.watch<PetService>();
    final scheme = Theme.of(context).colorScheme;
    final isAvailable = pet.status == PetStatus.available;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  Helpers.currency(pet.price),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: scheme.primary,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  isAvailable ? 'Available now' : pet.status.label,
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
            Gap.w16,
            Expanded(
              child: CustomButton(
                label: isAvailable ? 'Contact seller' : 'Unavailable',
                icon: Icons.chat_rounded,
                expand: false,
                onPressed: !isAvailable
                    ? null
                    : () => Nav.push(
                        context,
                        AppRoutes.contactSeller,
                        ContactSellerArgs(pet.id),
                      ),
              ),
            ),
            Gap.w10,
            IconActionButton(
              icon: isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              isActive: isFavorite,
              activeColor: AppColors.danger,
              foreground: isFavorite ? Colors.white : AppColors.danger,
              size: 52,
              iconSize: 22,
              background: scheme.surface,
              onTap: () => service.toggleFavorite(pet.id),
            ),
          ],
        ),
      ),
    );
  }
}
