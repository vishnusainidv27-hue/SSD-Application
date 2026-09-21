import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Lets Admin drop a pin on the customer's exact building/landmark (tap the map
/// to place it, drag to fine-tune). Pops with the chosen [LatLng], or null if
/// cancelled. The coordinates are stored on the customer for the Delivery Boy
/// app's navigation (Requirements §4.2.3).
class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key, this.initialPosition});

  /// The customer's currently saved pin, if any.
  final LatLng? initialPosition;

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  // Roughly the centre of India, zoomed out, until Admin places a pin.
  static const LatLng _fallbackCenter = LatLng(20.5937, 78.9629);
  static const double _fallbackZoom = 4.5;
  static const double _pinnedZoom = 17;

  LatLng? _pin;

  @override
  void initState() {
    super.initState();
    _pin = widget.initialPosition;
  }

  @override
  Widget build(BuildContext context) {
    final pin = _pin;
    return Scaffold(
      appBar: AppBar(title: const Text('Pick location')),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: pin ?? _fallbackCenter,
              zoom: pin == null ? _fallbackZoom : _pinnedZoom,
            ),
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
            mapToolbarEnabled: false,
            onTap: (position) => setState(() => _pin = position),
            markers: {
              if (pin != null)
                Marker(
                  markerId: const MarkerId('customer'),
                  position: pin,
                  draggable: true,
                  onDragEnd: (position) => setState(() => _pin = position),
                ),
            },
          ),
          if (pin == null)
            const Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Zoom in to the building and tap the map to drop a pin. '
                    'Drag the pin to adjust it.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: pin == null ? null : () => Navigator.of(context).pop(pin),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('Use this location'),
            ),
          ),
        ),
      ),
    );
  }
}
