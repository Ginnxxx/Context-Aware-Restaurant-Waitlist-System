import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../domain/venue_context.dart';
import '../../shared/brand_widgets.dart';
import '../widgets/page_intro.dart';

typedef SaveVenueSettings =
    Future<void> Function({
      required String name,
      required String address,
      required double latitude,
      required double longitude,
      required int averageTurnoverMinutes,
      required int outerGeofenceMeters,
      required int arrivalGeofenceMeters,
      required int seatCapacity,
    });

typedef CreateBranchCallback =
    Future<void> Function({
      required String name,
      required String address,
      required double latitude,
      required double longitude,
      required int averageTurnoverMinutes,
      required int outerGeofenceMeters,
      required int arrivalGeofenceMeters,
      required int seatCapacity,
    });

class StaffSettingsPage extends StatefulWidget {
  const StaffSettingsPage({
    super.key,
    required this.venue,
    required this.queueOpen,
    required this.onQueueChanged,
    required this.onSave,
    this.onCreateBranch,
  });

  final VenueContext? venue;
  final bool queueOpen;
  final ValueChanged<bool> onQueueChanged;
  final SaveVenueSettings onSave;
  final CreateBranchCallback? onCreateBranch;

  @override
  State<StaffSettingsPage> createState() => _StaffSettingsPageState();
}

class _StaffSettingsPageState extends State<StaffSettingsPage> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final addressController = TextEditingController();
  final latController = TextEditingController();
  final lngController = TextEditingController();
  final turnoverController = TextEditingController();
  final outerController = TextEditingController();
  final arrivalController = TextEditingController();
  final capacityController = TextEditingController();
  String? error;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    _load(widget.venue);
  }

  @override
  void didUpdateWidget(covariant StaffSettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only reload form fields if the user switched to a different venue/branch,
    // NOT on periodic background stream polls of the same venue.
    if (oldWidget.venue?.id != widget.venue?.id && !saving) {
      _load(widget.venue);
    }
  }

  void _load(VenueContext? venue) {
    if (venue == null) return;
    nameController.text = venue.name;
    addressController.text = venue.address;
    latController.text = venue.latitude.toStringAsFixed(5);
    lngController.text = venue.longitude.toStringAsFixed(5);
    turnoverController.text = '${venue.averageTurnoverMinutes}';
    outerController.text = '${venue.outerGeofenceMeters}';
    arrivalController.text = '${venue.arrivalGeofenceMeters}';
    capacityController.text = '${venue.seatCapacity}';
  }

  @override
  void dispose() {
    nameController.dispose();
    addressController.dispose();
    latController.dispose();
    lngController.dispose();
    turnoverController.dispose();
    outerController.dispose();
    arrivalController.dispose();
    capacityController.dispose();
    super.dispose();
  }

  String? _requiredText(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required' : null;

  String? _numberBetween(String? value, int minimum, int maximum) {
    final parsed = int.tryParse(value ?? '');
    if (parsed == null) return 'Enter a whole number';
    if (parsed < minimum || parsed > maximum) {
      return 'Use a value from $minimum to $maximum';
    }
    return null;
  }

  String? _coordinateValidator(String? value, double min, double max) {
    final parsed = double.tryParse(value ?? '');
    if (parsed == null) return 'Enter valid decimal';
    if (parsed < min || parsed > max) return 'Between $min and $max';
    return null;
  }

  Future<void> save() async {
    if (formKey.currentState?.validate() != true) return;
    final outer = int.parse(outerController.text);
    final arrival = int.parse(arrivalController.text);
    final lat = double.parse(latController.text);
    final lng = double.parse(lngController.text);

    if (arrival >= outer) {
      setState(
        () => error = 'Arrival radius must be smaller than approach radius.',
      );
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.onSave(
        name: nameController.text,
        address: addressController.text,
        latitude: lat,
        longitude: lng,
        averageTurnoverMinutes: int.parse(turnoverController.text),
        outerGeofenceMeters: outer,
        arrivalGeofenceMeters: arrival,
        seatCapacity: int.parse(capacityController.text),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Venue & coordinate settings saved.'),
          backgroundColor: AppColors.forest,
        ),
      );
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _showAddBranchDialog() {
    final branchFormKey = GlobalKey<FormState>();
    final bName = TextEditingController();
    final bAddress = TextEditingController();
    final bLat = TextEditingController(text: '16.82860');
    final bLng = TextEditingController(text: '96.12870');
    final bTurnover = TextEditingController(text: '5');
    final bOuter = TextEditingController(text: '800');
    final bArrival = TextEditingController(text: '100');
    final bCapacity = TextEditingController(text: '40');
    bool bBusy = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add New Restaurant Branch'),
          content: SingleChildScrollView(
            child: Form(
              key: branchFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: bName,
                    validator: _requiredText,
                    decoration: const InputDecoration(
                      labelText: 'Branch Name',
                      hintText: 'e.g. UIT Downtown Branch',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: bAddress,
                    validator: _requiredText,
                    decoration: const InputDecoration(
                      labelText: 'Address',
                      hintText: 'e.g. Sule Pagoda Road, Yangon',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: bLat,
                          validator: (v) => _coordinateValidator(v, -90, 90),
                          decoration: const InputDecoration(labelText: 'Latitude'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: bLng,
                          validator: (v) => _coordinateValidator(v, -180, 180),
                          decoration: const InputDecoration(labelText: 'Longitude'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: bOuter,
                          validator: (v) => _numberBetween(v, 100, 5000),
                          decoration: const InputDecoration(labelText: 'Outer (m)'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: bArrival,
                          validator: (v) => _numberBetween(v, 25, 500),
                          decoration: const InputDecoration(labelText: 'Arrival (m)'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: bBusy
                  ? null
                  : () async {
                      if (branchFormKey.currentState?.validate() != true) return;
                      setDialogState(() => bBusy = true);
                      try {
                        await widget.onCreateBranch?.call(
                          name: bName.text,
                          address: bAddress.text,
                          latitude: double.parse(bLat.text),
                          longitude: double.parse(bLng.text),
                          averageTurnoverMinutes: int.parse(bTurnover.text),
                          outerGeofenceMeters: int.parse(bOuter.text),
                          arrivalGeofenceMeters: int.parse(bArrival.text),
                          seatCapacity: int.parse(bCapacity.text),
                        );
                        if (!mounted) return;
                        if (ctx.mounted) Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('New branch created successfully!'),
                            backgroundColor: AppColors.forest,
                          ),
                        );
                      } catch (err) {
                        setDialogState(() => bBusy = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $err')),
                          );
                        }
                      }
                    },
              child: Text(bBusy ? 'Creating…' : 'Create Branch'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final venue = widget.venue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: PageIntro(
                eyebrow: 'VENUE CONTROL',
                title: 'Settings',
                subtitle:
                    'Manage availability, wait-time assumptions and location coordinates.',
              ),
            ),
            if (widget.onCreateBranch != null)
              FilledButton.tonalIcon(
                onPressed: _showAddBranchDialog,
                icon: const Icon(Icons.add_location_alt_rounded, size: 18),
                label: const Text('Add Branch'),
              ),
          ],
        ),
        const SizedBox(height: 22),
        if (venue == null)
          const Center(child: CircularProgressIndicator())
        else ...[
          Card(
            child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 22,
                vertical: 10,
              ),
              secondary: SoftIcon(
                widget.queueOpen
                    ? Icons.door_front_door_outlined
                    : Icons.pause_circle_outline_rounded,
                color: widget.queueOpen ? AppColors.forest : AppColors.coral,
                background: widget.queueOpen
                    ? AppColors.mint
                    : const Color(0xFFFFECE8),
              ),
              title: Text(
                widget.queueOpen ? 'Queue is open' : 'Queue is paused',
              ),
              subtitle: Text(
                widget.queueOpen
                    ? 'Customers can currently join the waitlist.'
                    : 'New queue entries are temporarily disabled.',
              ),
              value: widget.queueOpen,
              onChanged: widget.onQueueChanged,
            ),
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Venue profile & coordinates',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: nameController,
                      validator: _requiredText,
                      decoration: const InputDecoration(
                        labelText: 'Venue name',
                        prefixIcon: Icon(Icons.storefront_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: addressController,
                      validator: _requiredText,
                      decoration: const InputDecoration(
                        labelText: 'Address',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: latController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            validator: (v) => _coordinateValidator(v, -90, 90),
                            decoration: const InputDecoration(
                              labelText: 'Latitude',
                              prefixIcon: Icon(Icons.gps_fixed_rounded),
                              helperText: 'e.g. 16.85585 (UIT)',
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: TextFormField(
                            controller: lngController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            validator: (v) => _coordinateValidator(v, -180, 180),
                            decoration: const InputDecoration(
                              labelText: 'Longitude',
                              prefixIcon: Icon(Icons.explore_outlined),
                              helperText: 'e.g. 96.13527',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Queue timing',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: turnoverController,
                      keyboardType: TextInputType.number,
                      validator: (value) => _numberBetween(value, 1, 120),
                      decoration: const InputDecoration(
                        labelText: 'Average turnover per party (minutes)',
                        prefixIcon: Icon(Icons.timer_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: capacityController,
                      keyboardType: TextInputType.number,
                      validator: (value) => _numberBetween(value, 1, 1000),
                      decoration: const InputDecoration(
                        labelText: 'Total guest seat capacity',
                        prefixIcon: Icon(Icons.chair_alt_outlined),
                        helperText:
                            'Counts individual guest seats, not tables.',
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Geofence boundaries',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Changes apply immediately to live customer distance calculations and map rings.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final narrow = constraints.maxWidth < 620;
                        final fields = <Widget>[
                          TextFormField(
                            controller: outerController,
                            keyboardType: TextInputType.number,
                            validator: (value) =>
                                _numberBetween(value, 100, 5000),
                            decoration: const InputDecoration(
                              labelText: 'Approach radius (metres)',
                              prefixIcon: Icon(Icons.radar_rounded),
                            ),
                          ),
                          TextFormField(
                            controller: arrivalController,
                            keyboardType: TextInputType.number,
                            validator: (value) =>
                                _numberBetween(value, 25, 500),
                            decoration: const InputDecoration(
                              labelText: 'Arrival radius (metres)',
                              prefixIcon: Icon(Icons.my_location_rounded),
                            ),
                          ),
                        ];
                        if (narrow) {
                          return Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: fields[0],
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: fields[1],
                              ),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: fields[0]),
                            const SizedBox(width: 14),
                            Expanded(child: fields[1]),
                          ],
                        );
                      },
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        error!,
                        style: const TextStyle(
                          color: AppColors.coral,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: saving ? null : save,
                        icon: saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(saving ? 'Saving…' : 'Save settings'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
