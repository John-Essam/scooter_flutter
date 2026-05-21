import 'package:flutter/material.dart';

class ScooterHomeScreen extends StatelessWidget {
  const ScooterHomeScreen({
    super.key,
    required this.deviceId,
    required this.batteryPercent,
    required this.isLocked,
    required this.currentGear,
    required this.onToggleLock,
    required this.onSetGear,
    required this.onDisconnect,
    this.isUpdatingLock = false,
    this.isUpdatingGear = false,
  });

  final String deviceId;
  final int batteryPercent;
  final bool isLocked;
  final int currentGear;
  final Future<void> Function(bool locked) onToggleLock;
  final Future<void> Function(int gear) onSetGear;
  final Future<void> Function() onDisconnect;
  final bool isUpdatingLock;
  final bool isUpdatingGear;

  @override
  Widget build(BuildContext context) {
    final batteryStatus = batteryPercent > 40
        ? 'Normal'
        : batteryPercent > 20
        ? 'Low'
        : 'Critical';
    final statusColor = batteryPercent > 40
        ? const Color(0xFF0A9F6D)
        : batteryPercent > 20
        ? const Color(0xFFF5A524)
        : const Color(0xFFE54B4B);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F0EB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F0EB),
        elevation: 0,
        title: const Text(
          'cardoO Scooter X3',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF003E75),
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () => onDisconnect(),
            child: const Text('Disconnect'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 8),
              SizedBox(
                height: 360,
                child: Stack(
                  children: [
                    const Positioned.fill(
                      child: Image(
                        image: AssetImage('assets/images/scooter-x3.png'),
                        fit: BoxFit.contain,
                      ),
                    ),
                    Positioned(
                      right: 22,
                      bottom: 95,
                      child: _StatusCard(
                        batteryPercent: batteryPercent,
                        batteryStatus: batteryStatus,
                        statusColor: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: LockSlider(
                      locked: isLocked,
                      busy: isUpdatingLock,
                      onTargetChanged: onToggleLock,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _PowerGearCard(
                  currentGear: currentGear,
                  busy: isUpdatingGear,
                  onSetGear: onSetGear,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                child: Text(
                  'Connected device: $deviceId',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF4E5D70),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PowerGearCard extends StatelessWidget {
  const _PowerGearCard({
    required this.currentGear,
    required this.busy,
    required this.onSetGear,
  });

  final int currentGear;
  final bool busy;
  final Future<void> Function(int gear) onSetGear;

  @override
  Widget build(BuildContext context) {
    final selected = currentGear.clamp(0, 3);
    final labels = <int, String>{0: 'Eco', 1: '1', 2: '2', 3: '3'};

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4FA3).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.speed,
                    color: Color(0xFFFF4FA3),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Power Gear',
                    style: TextStyle(
                      color: Color(0xFF003E75),
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (busy)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF2F5FA),
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [0, 1, 2, 3].map((gear) {
                  final isActive = selected == gear;
                  return Expanded(
                    child: GestureDetector(
                      onTap: busy ? null : () => onSetGear(gear),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        height: 44,
                        decoration: BoxDecoration(
                          color: isActive
                              ? const Color(0xFF003E75)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          labels[gear]!,
                          style: TextStyle(
                            color: isActive
                                ? Colors.white
                                : const Color(0xFF6B7A90),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.batteryPercent,
    required this.batteryStatus,
    required this.statusColor,
  });

  final int batteryPercent;
  final String batteryStatus;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 162,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22093A66),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Status',
              style: TextStyle(
                color: Color(0xFF003E75),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                _BatteryIcon(level: batteryPercent, color: statusColor),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    batteryStatus,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '$batteryPercent%',
              style: const TextStyle(
                color: Color(0xFF003E75),
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  'Connected',
                  style: TextStyle(
                    color: Color(0xFF0A9F6D),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Icon(Icons.bluetooth, size: 16, color: Color(0xFF0A9F6D)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BatteryIcon extends StatelessWidget {
  const _BatteryIcon({required this.level, required this.color});

  final int level;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final clamped = level.clamp(0, 100);
    return Row(
      children: [
        Container(
          width: 28,
          height: 13,
          padding: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF003E75), width: 1.4),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: (25 * clamped / 100).clamp(4, 25).toDouble(),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          ),
        ),
        Container(
          width: 2.2,
          height: 6,
          margin: const EdgeInsets.only(left: 1),
          decoration: BoxDecoration(
            color: const Color(0xFF003E75),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ],
    );
  }
}

class LockSlider extends StatefulWidget {
  const LockSlider({
    super.key,
    required this.locked,
    required this.onTargetChanged,
    this.busy = false,
  });

  final bool locked;
  final Future<void> Function(bool locked) onTargetChanged;
  final bool busy;

  @override
  State<LockSlider> createState() => _LockSliderState();
}

class _LockSliderState extends State<LockSlider> {
  double? _dragPosition;
  double? _dragStartX;

  @override
  void didUpdateWidget(covariant LockSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.busy && oldWidget.locked != widget.locked) {
      _dragPosition = null;
      _dragStartX = null;
    } else if (!widget.busy &&
        oldWidget.busy &&
        oldWidget.locked == widget.locked) {
      _dragPosition = null;
      _dragStartX = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const knobSize = 52.0;
        final maxX = (constraints.maxWidth - knobSize)
            .clamp(0.0, double.infinity)
            .toDouble();
        final origin = widget.locked ? 0.0 : maxX;
        final currentX = (_dragPosition ?? origin).clamp(0.0, maxX).toDouble();

        return Container(
          height: 62,
          decoration: BoxDecoration(
            color: const Color(0xFF0A345A),
            borderRadius: BorderRadius.circular(34),
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  widget.busy
                      ? 'Updating lock...'
                      : (widget.locked ? 'Slide to Unlock' : 'Slide to Lock'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              Positioned(
                left: currentX,
                top: 5,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: widget.busy
                      ? null
                      : (_) {
                          setState(() {
                            _dragStartX = currentX;
                            _dragPosition = currentX;
                          });
                        },
                  onHorizontalDragUpdate: widget.busy
                      ? null
                      : (details) {
                          setState(() {
                            final base = _dragPosition ?? _dragStartX ?? origin;
                            _dragPosition = (base + details.delta.dx)
                                .clamp(0.0, maxX)
                                .toDouble();
                          });
                        },
                  onHorizontalDragCancel: widget.busy
                      ? null
                      : () {
                          setState(() {
                            _dragStartX = null;
                            _dragPosition = null;
                          });
                        },
                  onHorizontalDragEnd: widget.busy
                      ? null
                      : (_) async {
                          final x = (_dragPosition ?? origin)
                              .clamp(0.0, maxX)
                              .toDouble();
                          final shouldUnlock =
                              widget.locked && x > (maxX * 0.65);
                          final shouldLock =
                              !widget.locked && x < (maxX * 0.35);
                          final shouldToggle = shouldUnlock || shouldLock;
                          final targetX = widget.locked ? maxX : 0.0;

                          setState(() {
                            _dragStartX = null;
                            _dragPosition = shouldToggle ? targetX : null;
                          });

                          if (shouldToggle) {
                            await widget.onTargetChanged(!widget.locked);
                          }
                        },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: knobSize,
                    height: knobSize,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x44000000),
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.locked ? Icons.lock : Icons.lock_open,
                      color: const Color(0xFF0A345A),
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
