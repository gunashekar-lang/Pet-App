import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../models/pet_model.dart';
import '../../services/notification_service.dart';
import '../../services/pet_service.dart';
import '../../utils/constants.dart';
import '../../utils/validators.dart';
import '../../widgets/common.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/section_header.dart';

/// Single-page listing form: photos, details, price, vaccination history and
/// health issues all on one scrollable screen.
class SellPetScreen extends StatefulWidget {
  const SellPetScreen({super.key});

  @override
  State<SellPetScreen> createState() => _SellPetScreenState();
}

class _SellPetScreenState extends State<SellPetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _breedController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _priceController = TextEditingController();
  final _healthIssuesController = TextEditingController();
  final _imagePaths = <String>[];
  final _vaccinations = <VaccinationRecord>[];

  PetSpecies _species = PetSpecies.dog;
  PetAge _age = PetAge.young;
  String _gender = 'Male';
  bool _negotiable = false;

  @override
  void initState() {
    super.initState();
    _locationController.text = 'Your area';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _priceController.dispose();
    _healthIssuesController.dispose();
    super.dispose();
  }

  Future<void> _addPhoto(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    setState(() => _imagePaths.add(picked.path));
  }

  Future<void> _choosePhotoSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    await _addPhoto(source);
  }

  void _removePhoto(int index) {
    setState(() => _imagePaths.removeAt(index));
  }

  Future<void> _addVaccination() async {
    final record = await showModalBottomSheet<VaccinationRecord>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _VaccinationSheet(),
    );
    if (record == null) return;
    setState(() => _vaccinations.add(record));
  }

  void _removeVaccination(int index) {
    setState(() => _vaccinations.removeAt(index));
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final price = double.tryParse(_priceController.text.trim());
    if (price == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Enter a valid asking price')),
        );
      return;
    }

    final service = context.read<PetService>();
    final pet = await service.createListing(
      name: _nameController.text.trim(),
      species: _species,
      breed: _breedController.text.trim().isEmpty
          ? 'Mixed'
          : _breedController.text.trim(),
      ageInMonths: _age.monthsApprox,
      gender: _gender,
      price: price,
      description: _descriptionController.text.trim(),
      location: _locationController.text.trim(),
      healthIssues: _healthIssuesController.text.trim().isEmpty
          ? 'None known'
          : _healthIssuesController.text.trim(),
      negotiable: _negotiable,
      imagePaths: _imagePaths,
      vaccinations: _vaccinations,
      tags: [_species.label, _age.label],
    );

    if (!mounted) return;
    context.read<NotificationService>().listingPublished(
      petName: pet.name,
      petId: pet.id,
    );
    // Land on My Listings so the seller immediately sees what they published.
    await Nav.push(context, AppRoutes.myListings);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('${pet.name} is now listed')));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isSubmitting = context.watch<PetService>().isSubmitting;

    return Scaffold(
      appBar: AppBar(title: const Text('List a pet')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
          children: [
            const SectionHeader(
              title: 'Photos',
              subtitle: 'Add real photos of your pet',
              padding: EdgeInsets.only(),
            ),
            Gap.h12,
            SizedBox(
              height: 104,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _AddPhotoTile(onTap: _choosePhotoSource),
                  for (final path in _imagePaths)
                    Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: Stack(
                        children: [
                          AppImage(
                            url: path,
                            width: 104,
                            height: 104,
                            borderRadius: BorderRadius.circular(14),
                            icon: Icons.pets_rounded,
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () =>
                                  _removePhoto(_imagePaths.indexOf(path)),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Gap.h24,
            const SectionHeader(
              title: 'About your pet',
              padding: EdgeInsets.only(),
            ),
            Gap.h12,
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Biscuit',
              ),
              validator: Validators.required,
            ),
            Gap.h12,
            DropdownButtonFormField<PetSpecies>(
              initialValue: _species,
              decoration: const InputDecoration(labelText: 'Species'),
              items: [
                for (final species in PetSpecies.values)
                  DropdownMenuItem(value: species, child: Text(species.label)),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _species = value);
              },
            ),
            Gap.h12,
            TextFormField(
              controller: _breedController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Breed',
                hintText: 'e.g. Labrador mix',
              ),
            ),
            Gap.h12,
            DropdownButtonFormField<PetAge>(
              initialValue: _age,
              decoration: const InputDecoration(labelText: 'Age'),
              items: [
                for (final age in PetAge.values)
                  DropdownMenuItem(value: age, child: Text(age.label)),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _age = value);
              },
            ),
            Gap.h12,
            DropdownButtonFormField<String>(
              initialValue: _gender,
              decoration: const InputDecoration(labelText: 'Gender'),
              items: const [
                DropdownMenuItem(value: 'Male', child: Text('Male')),
                DropdownMenuItem(value: 'Female', child: Text('Female')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _gender = value);
              },
            ),
            Gap.h12,
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(labelText: 'Location'),
            ),
            Gap.h12,
            TextFormField(
              controller: _descriptionController,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Temperament, habits, why you are rehoming',
                alignLabelWithHint: true,
              ),
              validator: Validators.required,
            ),
            Gap.h24,
            const SectionHeader(title: 'Price', padding: EdgeInsets.only()),
            Gap.h12,
            TextFormField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Asking price',
                prefixText: '₹ ',
              ),
              validator: Validators.price,
            ),
            SwitchListTile.adaptive(
              value: _negotiable,
              onChanged: (value) => setState(() => _negotiable = value),
              title: const Text('Price is negotiable'),
              contentPadding: EdgeInsets.zero,
            ),
            Gap.h16,
            const SectionHeader(
              title: 'Vaccination',
              subtitle: 'Add the dates so buyers know what is up to date',
              padding: EdgeInsets.only(),
            ),
            Gap.h8,
            OutlinedButton.icon(
              onPressed: _addVaccination,
              icon: const Icon(Icons.vaccines_rounded, size: 18),
              label: Text(
                _vaccinations.isEmpty
                    ? 'Add vaccination history'
                    : 'Add another vaccination',
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            if (_vaccinations.isNotEmpty) ...[
              Gap.h12,
              for (var i = 0; i < _vaccinations.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _VaccinationTile(
                    record: _vaccinations[i],
                    onRemove: () => _removeVaccination(i),
                  ),
                ),
            ],
            Gap.h16,
            TextFormField(
              controller: _healthIssuesController,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Health issues',
                hintText: 'None known',
                alignLabelWithHint: true,
                helperText:
                    'List any known conditions, allergies or medication',
              ),
            ),
            Gap.h12,
            AppCard(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderColor: Colors.transparent,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: scheme.onSurface.withValues(alpha: 0.6),
                  ),
                  Gap.w10,
                  Expanded(
                    child: Text(
                      'Listings with photos and an honest health summary get '
                      'more enquiries. Only share details you can show buyers.',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: scheme.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Gap.h24,
            CustomButton(
              label: 'Publish listing',
              icon: Icons.check_rounded,
              isLoading: isSubmitting,
              onPressed: isSubmitting ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.primary.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 104,
          height: 104,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: scheme.primary.withValues(alpha: 0.35),
              style: BorderStyle.solid,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_a_photo_rounded, color: scheme.primary, size: 24),
              Gap.h8,
              Text(
                'Add photo',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VaccinationTile extends StatelessWidget {
  const _VaccinationTile({required this.record, required this.onRemove});

  final VaccinationRecord record;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      child: Row(
        children: [
          Icon(Icons.vaccines_rounded, size: 20, color: scheme.primary),
          Gap.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  record.name,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Given ${record.formattedDate}',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: scheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                if (record.formattedNextDue != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Next due ${record.formattedNextDue}',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: scheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet for capturing one vaccination record.
class _VaccinationSheet extends StatefulWidget {
  const _VaccinationSheet();

  @override
  State<_VaccinationSheet> createState() => _VaccinationSheetState();
}

class _VaccinationSheetState extends State<_VaccinationSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  DateTime? _given;
  DateTime? _nextDue;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isGiven}) async {
    final now = DateTime.now();
    final initial = isGiven ? (_given ?? now) : (_nextDue ?? now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 12),
      lastDate: DateTime(now.year + 12),
    );
    if (picked == null) return;
    setState(() {
      if (isGiven) {
        _given = picked;
      } else {
        _nextDue = picked;
      }
    });
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      VaccinationRecord(
        name: _nameController.text.trim(),
        dateGiven: _given ?? DateTime.now(),
        nextDue: _nextDue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vaccination record',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            Gap.h16,
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Vaccine name',
                hintText: 'e.g. Rabies',
              ),
              validator: Validators.required,
            ),
            Gap.h12,
            AppCard(
              onTap: () => _pickDate(isGiven: true),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.event_rounded, size: 20),
                  Gap.w12,
                  Expanded(
                    child: Text(
                      _given == null
                          ? 'Date given (optional)'
                          : 'Given ${_given!.toIso8601String().split('T').first}',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Gap.h12,
            AppCard(
              onTap: () => _pickDate(isGiven: false),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.event_repeat_rounded, size: 20),
                  Gap.w12,
                  Expanded(
                    child: Text(
                      _nextDue == null
                          ? 'Next due (optional)'
                          : 'Next due ${_nextDue!.toIso8601String().split('T').first}',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Gap.h20,
            CustomButton(label: 'Save record', onPressed: _save),
          ],
        ),
      ),
    );
  }
}
