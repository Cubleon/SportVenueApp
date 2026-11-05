import 'package:flutter/material.dart';
import 'package:maplibre/maplibre.dart' as maplibre;

import '../theme/app_theme.dart';
import 'shared_widgets.dart';

class LocationPicker extends StatefulWidget {
  const LocationPicker({super.key, this.initialPoint, this.readOnly = false});
  final maplibre.Geographic? initialPoint;
  final bool readOnly;

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  late maplibre.Geographic? _point = widget.initialPoint;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Расположение площадки')),
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            widget.readOnly
                ? 'Расположение площадки из заявки.'
                : 'Приблизьте карту и нажмите на место, где находится площадка.',
          ),
        ),
        Expanded(
          child: maplibre.MapLibreMap(
            key: const ValueKey('public-venue-location-map'),
            options: maplibre.MapOptions(
              initStyle: 'https://tiles.openfreemap.org/styles/liberty',
              initCenter:
                  _point ??
                  const maplibre.Geographic(lon: 37.6173, lat: 55.7558),
              initZoom: _point == null ? 10.6 : 15,
              minZoom: 1,
              maxZoom: 19,
            ),
            onEvent: (event) {
              if (!widget.readOnly && event is maplibre.MapEventClick) {
                setState(() => _point = event.point);
              }
            },
            children: [
              maplibre.WidgetLayer(
                markers: [
                  if (_point != null)
                    maplibre.Marker(
                      point: _point!,
                      size: const Size.square(44),
                      child: Icon(
                        Icons.location_on,
                        size: 44,
                        color: context.colors.accent,
                        semanticLabel: 'Расположение площадки',
                      ),
                    ),
                ],
              ),
              const maplibre.MapCompass(
                alignment: Alignment.topRight,
                padding: EdgeInsets.all(12),
              ),
              const maplibre.SourceAttribution(
                alignment: Alignment.bottomLeft,
                showMapLibre: false,
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: PrimaryButton(
              label: widget.readOnly
                  ? 'Закрыть карту'
                  : 'Подтвердить расположение',
              onPressed: _point == null
                  ? null
                  : () => widget.readOnly
                        ? Navigator.pop(context)
                        : Navigator.pop(context, _point),
            ),
          ),
        ),
      ],
    ),
  );
}
