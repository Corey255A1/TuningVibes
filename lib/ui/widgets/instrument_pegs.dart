import 'package:flutter/material.dart';
import '../../domain/tuner_models.dart';

/// Renders an interactive headstock diagram for the selected instrument.
/// Pegs light up in real-time when active, and tapping them locks the target string.
class InstrumentPegs extends StatelessWidget {
  final Tuning tuning;
  final InstrumentString? activeString;
  final InstrumentString? selectedString;
  final Function(InstrumentString?) onSelectString;
  final bool hasSignal;
  final bool isLocked;

  const InstrumentPegs({
    super.key,
    required this.tuning,
    required this.activeString,
    required this.selectedString,
    required this.onSelectString,
    required this.hasSignal,
    required this.isLocked,
  });

  @override
  Widget build(BuildContext context) {
    final strings = tuning.strings;
    final int count = strings.length;

    // Split pegs into left and right sides
    // E.g., for 6 strings: 3 on left (pegs 4, 5, 6), 3 on right (pegs 1, 2, 3)
    // For 4 strings: 2 on left (pegs 3, 4), 2 on right (pegs 1, 2)
    // Note: strings are typically ordered high-to-low (index 1 is highest pitch, count is lowest)
    // Left side (low strings): index > count/2
    // Right side (high strings): index <= count/2
    final List<InstrumentString> rightPegs = [];
    final List<InstrumentString> leftPegs = [];

    final int mid = (count / 2).ceil();
    for (int i = 0; i < count; i++) {
      final s = strings[i];
      if (i < mid) {
        rightPegs.add(s);
      } else {
        // To make physical layout intuitive:
        // Left side lowest string at the top left, right side highest string at top right.
        leftPegs.add(s);
      }
    }

    // Reverse left pegs so the lowest string is at the top left
    final leftPegsOrdered = leftPegs.reversed.toList();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "STRING SELECTOR",
                style: TextStyle(
                  color: Colors.grey.withOpacity(0.5),
                  fontSize: 9.0,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              GestureDetector(
                onTap: () => onSelectString(null),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                  decoration: BoxDecoration(
                    color: selectedString == null
                        ? Colors.cyan.withOpacity(0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(
                      color: selectedString == null
                          ? Colors.cyan.withOpacity(0.3)
                          : Colors.grey.withOpacity(0.2),
                    ),
                  ),
                  child: Text(
                    "AUTO-DETECT",
                    style: TextStyle(
                      color: selectedString == null ? Colors.cyanAccent : Colors.grey,
                      fontSize: 8.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0),
          Row(
            children: [
              // Left pegs column
              Expanded(
                child: Column(
                  children: leftPegsOrdered.map((s) => _buildPeg(s, isLeft: true)).toList(),
                ),
              ),
              
              // Center stylized wooden headstock bridge
              Container(
                width: 45,
                height: count == 6 ? 160 : 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.grey[900]!,
                      Colors.grey[850]!,
                      Colors.grey[900]!,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 2,
                    height: double.infinity,
                    color: Colors.white.withOpacity(0.04),
                  ),
                ),
              ),
              
              // Right pegs column
              Expanded(
                child: Column(
                  children: rightPegs.map((s) => _buildPeg(s, isLeft: false)).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPeg(InstrumentString s, {required bool isLeft}) {
    final bool isUserSelected = selectedString == s;
    final bool isCurrentlyActive = activeString == s;
    final bool isActiveWithSignal = isCurrentlyActive && hasSignal;
    
    Color glowColor = Colors.cyanAccent;
    if (isActiveWithSignal) {
      glowColor = isLocked ? Colors.greenAccent : Colors.cyanAccent;
    } else if (isUserSelected) {
      glowColor = Colors.grey[400]!;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: GestureDetector(
        onTap: () {
          // If already selected, tap again to release lock (return to auto-detect)
          if (isUserSelected) {
            onSelectString(null);
          } else {
            onSelectString(s);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: isActiveWithSignal
                ? glowColor.withOpacity(0.08)
                : (isUserSelected ? Colors.white.withOpacity(0.03) : Colors.transparent),
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(
              color: isActiveWithSignal
                  ? glowColor.withOpacity(0.4)
                  : (isUserSelected ? Colors.white.withOpacity(0.2) : Colors.transparent),
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: isLeft ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (isLeft) ...[
                _buildPegKnob(s, isLeft, isActiveWithSignal, isUserSelected, glowColor),
                const SizedBox(width: 8.0),
              ],
              Column(
                crossAxisAlignment: isLeft ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(
                    s.note.label,
                    style: TextStyle(
                      color: isActiveWithSignal
                          ? glowColor
                          : (isUserSelected ? Colors.white : Colors.grey[400]),
                      fontSize: 14.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "String ${s.index}",
                    style: TextStyle(
                      color: Colors.grey.withOpacity(0.5),
                      fontSize: 9.0,
                    ),
                  ),
                ],
              ),
              if (!isLeft) ...[
                const SizedBox(width: 8.0),
                _buildPegKnob(s, isLeft, isActiveWithSignal, isUserSelected, glowColor),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPegKnob(
    InstrumentString s,
    bool isLeft,
    bool isActiveWithSignal,
    bool isUserSelected,
    Color glowColor,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 20,
      height: 12,
      decoration: BoxDecoration(
        color: isActiveWithSignal ? glowColor : Colors.grey[800],
        borderRadius: BorderRadius.circular(3.0),
        boxShadow: isActiveWithSignal
            ? [
                BoxShadow(
                  color: glowColor.withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : (isUserSelected
                ? [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.2),
                      blurRadius: 4,
                    )
                  ]
                : []),
      ),
    );
  }
}
