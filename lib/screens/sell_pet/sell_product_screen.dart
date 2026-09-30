import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../models/product_model.dart';
import '../../services/notification_service.dart';
import '../../services/store_service.dart';
import '../../utils/constants.dart';
import '../../utils/validators.dart';
import '../../widgets/common.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/section_header.dart';

/// Product listing form. Everything published here is owned by the seller's
/// shop and inherits the shop's verification state.
class SellProductScreen extends StatefulWidget {
  const SellProductScreen({super.key});

  @override
  State<SellProductScreen> createState() => _SellProductScreenState();
}

class _SellProductScreenState extends State<SellProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _priceController = TextEditingController();
  final _mrpController = TextEditingController();
  final _stockController = TextEditingController();
  final _descriptionController = TextEditingController();

  ProductCategory _category = ProductCategory.food;
  String _imagePath = '';
  bool _freeShipping = true;

  @override
  void initState() {
    super.initState();
    _brandController.text = context.read<StoreService>().shopName;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _priceController.dispose();
    _mrpController.dispose();
    _stockController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
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
    if (source == null || !mounted) return;
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    setState(() => _imagePath = picked.path);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final price = double.tryParse(_priceController.text.trim());
    if (price == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Enter a valid selling price')),
        );
      return;
    }

    final mrp = double.tryParse(_mrpController.text.trim());
    if (mrp != null && mrp <= price) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('MRP must be higher than the selling price'),
          ),
        );
      return;
    }

    final stock = int.tryParse(_stockController.text.trim()) ?? 0;
    if (stock < 0) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Stock cannot be negative')),
        );
      return;
    }

    final store = context.read<StoreService>();
    final product = await store.createProductListing(
      name: _nameController.text.trim(),
      brand: _brandController.text.trim(),
      category: _category,
      price: price,
      description: _descriptionController.text.trim(),
      imagePath: _imagePath,
      stock: stock,
    );

    if (!mounted) return;
    context.read<NotificationService>().listingPublished(
      petName: product.name,
      petId: product.id,
    );
    // Land on the shop listing page so the seller sees the new product.
    await Nav.push(context, AppRoutes.myShop);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('${product.name} added to your shop')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isSubmitting = context.watch<StoreService>().isPlacingOrder;
    final store = context.watch<StoreService>();

    return Scaffold(
      appBar: AppBar(title: const Text('List a product')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
          children: [
            AppCard(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderColor: Colors.transparent,
              child: Row(
                children: [
                  Icon(
                    Icons.storefront_rounded,
                    color: scheme.primary,
                    size: 20,
                  ),
                  Gap.w10,
                  Expanded(
                    child: Text(
                      'Listing as ${store.shopName}'
                      '${store.shopVerified ? ' (verified)' : ' (verification pending)'}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Gap.h24,
            const SectionHeader(
              title: 'Product photo',
              subtitle: 'One clear photo works best',
              padding: EdgeInsets.only(),
            ),
            Gap.h12,
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 168,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                  border: Border.all(
                    color: _imagePath.isEmpty
                        ? scheme.outline
                        : Colors.transparent,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: _imagePath.isEmpty
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_a_photo_outlined,
                            color: scheme.onSurface.withValues(alpha: 0.6),
                          ),
                          Gap.h8,
                          Text(
                            'Add a photo',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      )
                    : AppImage(
                        url: _imagePath,
                        width: double.infinity,
                        height: 168,
                        icon: Icons.inventory_2_rounded,
                      ),
              ),
            ),
            Gap.h24,
            const SectionHeader(
              title: 'Product details',
              padding: EdgeInsets.only(),
            ),
            Gap.h12,
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Product name',
                hintText: 'e.g. Chicken Jerky Sticks',
              ),
              validator: Validators.required,
            ),
            Gap.h12,
            TextFormField(
              controller: _brandController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Brand'),
            ),
            Gap.h12,
            DropdownButtonFormField<ProductCategory>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                for (final c in ProductCategory.values)
                  DropdownMenuItem(value: c, child: Text(c.label)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _category = value);
              },
            ),
            Gap.h24,
            const SectionHeader(title: 'Price', padding: EdgeInsets.only()),
            Gap.h12,
            TextFormField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Selling price',
                prefixText: '₹ ',
              ),
              validator: (value) => Validators.positiveNumber(value),
            ),
            Gap.h12,
            TextFormField(
              controller: _mrpController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'MRP (optional)',
                prefixText: '₹ ',
                helperText: 'Shown struck through to show a discount',
              ),
              validator: (value) => Validators.optionalPositiveNumber(value),
            ),
            Gap.h12,
            TextFormField(
              controller: _stockController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Stock quantity',
                hintText: '0',
              ),
              validator: Validators.required,
            ),
            Gap.h12,
            SwitchListTile.adaptive(
              value: _freeShipping,
              onChanged: (value) => setState(() => _freeShipping = value),
              title: const Text('Free delivery'),
              subtitle: const Text('Waive the delivery charge on this item'),
              contentPadding: EdgeInsets.zero,
            ),
            Gap.h16,
            TextFormField(
              controller: _descriptionController,
              minLines: 3,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Ingredients, pack size, who it suits best',
                alignLabelWithHint: true,
              ),
            ),
            Gap.h24,
            CustomButton(
              label: 'Publish product',
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
