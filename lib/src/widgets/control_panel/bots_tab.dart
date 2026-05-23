import 'package:flutter/material.dart';

import '../../i18n/app_localizations.dart';
import '../../models/bot_roster.dart';
import '../../models/game_state.dart';
import '../../models/session_config.dart';
import '../../theme/app_theme.dart';
import '../bot_visuals.dart';
import '../typewriter_text.dart';
import 'primitives.dart';

class BotsTab extends StatelessWidget {
  const BotsTab({
    super.key,
    required this.state,
    required this.currentProfile,
    required this.onPersonaChanged,
    required this.onProfileSelected,
  });

  final GameState state;
  final BotProfile currentProfile;
  final ValueChanged<Persona> onPersonaChanged;
  final ValueChanged<BotProfile> onProfileSelected;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(state.config.locale);
    const categories = ['Pirates', 'Beginner', 'Intermediate', 'Advanced'];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeroSpeech(
            profile: currentProfile,
            persona: state.config.persona,
            strings: strings,
            message: state.opponentMessage,
          ),
          const SizedBox(height: 14),
          _PersonaDeck(
            state: state,
            strings: strings,
            onPersonaChanged: onPersonaChanged,
          ),
          const SizedBox(height: 14),
          for (final category in categories) ...[
            _BotCategorySection(
              category: category,
              strings: strings,
              expanded: category == currentProfile.category,
              profiles: [
                for (final profile in botRoster)
                  if (profile.category == category) profile,
              ],
              selectedProfile: currentProfile,
              onProfileSelected: onProfileSelected,
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _HeroSpeech extends StatelessWidget {
  const _HeroSpeech({
    required this.profile,
    required this.persona,
    required this.strings,
    required this.message,
  });

  final BotProfile profile;
  final Persona persona;
  final AppStrings strings;
  final String message;

  @override
  Widget build(BuildContext context) {
    final tone = botProfileTone(profile);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BotAvatarTile(profile: profile, size: 82),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 88),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1EFEA),
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                child: TypewriterText(
                  text: message.isEmpty
                      ? profile.localizedIntroLine(strings)
                      : message,
                  maxLines: 3,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: const Color(0xFF23211D),
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(
              profile.localizedName(strings),
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 10),
            Text(
              '${profile.rating}',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: tone.withValues(alpha: 0.45)),
              ),
              child: Text(
                profile.localizedCategory(strings),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: tone,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ProfileStatPill(
                label: strings.style,
                value: persona.localizedLabel(strings),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ProfileStatPill(
                label: strings.specialty,
                value: profile.localizedSpecialty(strings),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white10),
          ),
          child: Text(
            persona.localizedDescription(strings),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white70,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _PersonaDeck extends StatelessWidget {
  const _PersonaDeck({
    required this.state,
    required this.strings,
    required this.onPersonaChanged,
  });

  final GameState state;
  final AppStrings strings;
  final ValueChanged<Persona> onPersonaChanged;

  @override
  Widget build(BuildContext context) {
    final personas = <Persona>{
      for (final profile in botRoster) profile.persona,
    }.toList(growable: false);

    return CollapsibleControlSectionBand(
      title: strings.personality,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.personalityDescription,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white60,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final persona in personas)
                _PersonaCard(
                  persona: persona,
                  strings: strings,
                  selected: state.config.persona == persona,
                  onTap: () => onPersonaChanged(persona),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PersonaCard extends StatelessWidget {
  const _PersonaCard({
    required this.persona,
    required this.strings,
    required this.selected,
    required this.onTap,
  });

  final Persona persona;
  final AppStrings strings;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = selected
        ? AppColors.primary
        : botProfileTone(bestProfileForPersona(persona));
    return SizedBox(
      key: ValueKey('persona-card-${persona.name}'),
      width: 184,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: tone.withValues(alpha: selected ? 0.18 : 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: tone.withValues(alpha: selected ? 0.72 : 0.34),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                persona.localizedLabel(strings),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 20,
                child: selected
                    ? Row(
                        key: ValueKey('persona-current-${persona.name}'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 15,
                            color: tone,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            strings.current,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: tone,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: 8),
              Text(
                persona.localizedDescription(strings),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileStatPill extends StatelessWidget {
  const _ProfileStatPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: Colors.white54),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _BotCategorySection extends StatelessWidget {
  const _BotCategorySection({
    required this.category,
    required this.strings,
    required this.expanded,
    required this.profiles,
    required this.selectedProfile,
    required this.onProfileSelected,
  });

  final String category;
  final AppStrings strings;
  final bool expanded;
  final List<BotProfile> profiles;
  final BotProfile selectedProfile;
  final ValueChanged<BotProfile> onProfileSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: expanded ? 0.06 : 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(16),
      child: expanded
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      profiles.first.localizedCategory(strings),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    Text(
                      strings.botCount(profiles.length),
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(color: Colors.white54),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    for (final profile in profiles)
                      _BotPortraitCard(
                        profile: profile,
                        strings: strings,
                        selected: profile.name == selectedProfile.name,
                        onTap: () {
                          onProfileSelected(profile);
                        },
                      ),
                  ],
                ),
              ],
            )
          : InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                onProfileSelected(profiles.first);
              },
              child: Row(
                children: [
                  BotAvatarTile(profile: profiles.first, size: 58),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      profiles.first.localizedCategory(strings),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: Colors.white70,
                          ),
                    ),
                  ),
                  Text(
                    strings.botCount(profiles.length),
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: Colors.white54),
                  ),
                ],
              ),
            ),
    );
  }
}

class _BotPortraitCard extends StatelessWidget {
  const _BotPortraitCard({
    required this.profile,
    required this.strings,
    required this.selected,
    required this.onTap,
  });

  final BotProfile profile;
  final AppStrings strings;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = botProfileTone(profile);
    final depthLabel = _depthLabel(profile.difficulty);
    final threadsLabel = _threadsFor(profile.difficulty);
    final hashLabel = _hashFor(profile.difficulty);

    return Tooltip(
      message: [
        profile.localizedTitle(strings),
        '${strings.depth}: $depthLabel',
        '${strings.threads}: $threadsLabel',
        '${strings.hash}: $hashLabel MB',
      ].join('\n'),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: 112,
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
          decoration: BoxDecoration(
            color: const Color(0xFF323837),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.primary : Colors.transparent,
              width: 3,
            ),
          ),
          child: Column(
            children: [
              BotAvatarTile(profile: profile, size: 74),
              const SizedBox(height: 8),
              Text(
                profile.localizedName(strings),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: const Color(0xFFF6F4ED),
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                  letterSpacing: 0,
                  shadows: const [
                    Shadow(
                      blurRadius: 3,
                      color: Color(0xAA000000),
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${profile.rating}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: tone,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _depthLabel(DifficultyLevel difficulty) {
  return switch (difficulty) {
    DifficultyLevel.easy => 'D8',
    DifficultyLevel.normal => 'D10',
    DifficultyLevel.hard => 'D12',
    DifficultyLevel.master => 'D14',
    DifficultyLevel.chaos => 'D16',
  };
}

int _threadsFor(DifficultyLevel difficulty) {
  return switch (difficulty) {
    DifficultyLevel.easy => 1,
    DifficultyLevel.normal => 1,
    DifficultyLevel.hard => 2,
    DifficultyLevel.master => 3,
    DifficultyLevel.chaos => 4,
  };
}

int _hashFor(DifficultyLevel difficulty) {
  return switch (difficulty) {
    DifficultyLevel.easy => 32,
    DifficultyLevel.normal => 64,
    DifficultyLevel.hard => 128,
    DifficultyLevel.master => 192,
    DifficultyLevel.chaos => 256,
  };
}
