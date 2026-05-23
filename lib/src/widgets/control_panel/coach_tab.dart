import 'package:flutter/material.dart';

import '../../i18n/app_localizations.dart';
import '../../models/game_state.dart';
import '../../models/session_config.dart';
import 'primitives.dart';

class CoachTab extends StatelessWidget {
  const CoachTab({
    super.key,
    required this.state,
    required this.onPersonaChanged,
    required this.onCoachPersonaChanged,
    required this.onTauntLevelChanged,
  });

  final GameState state;
  final ValueChanged<Persona> onPersonaChanged;
  final ValueChanged<CoachPersona> onCoachPersonaChanged;
  final ValueChanged<TauntLevel> onTauntLevelChanged;

  @override
  Widget build(BuildContext context) {
    final hint = state.hint;
    final strings = AppStrings.of(state.config.locale);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ControlSectionBand(
            title: strings.coachFeed,
            child: hint == null
                ? Text(
                    state.coachMessage,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white70,
                      height: 1.35,
                    ),
                  )
                : Column(
                    children: [
                      ControlDataLine(
                        label: strings.bestMove,
                        value: hint.bestMoveUci,
                      ),
                      ControlDataLine(
                        label: strings.evaluation,
                        value: hint.evaluationLabel,
                      ),
                      ControlDataLine(
                        label: strings.depth,
                        value: '${hint.depth}',
                      ),
                      ControlDataLine(
                        label: strings.time,
                        value: '${hint.elapsedMs} ms',
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 14),
          CollapsibleControlSectionBand(
            title: strings.personality,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ControlDataLine(
                  label: strings.opponentAttitude,
                  value: state.config.persona.localizedLabel(strings),
                ),
                Text(
                  state.config.persona.localizedDescription(strings),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white60,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 14),
                LabeledDropdown<CoachPersona>(
                  label: strings.teacherVoice,
                  value: state.config.coachPersona,
                  items: CoachPersona.values,
                  itemLabel: (item) => item.localizedLabel(strings),
                  onChanged: onCoachPersonaChanged,
                ),
                const SizedBox(height: 14),
                SegmentedPicker<TauntLevel>(
                  label: strings.tauntLevel,
                  value: state.config.tauntLevel,
                  options: TauntLevel.values,
                  itemLabel: (item) => item.localizedLabel(strings),
                  onChanged: onTauntLevelChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
