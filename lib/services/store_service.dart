import 'package:flutter/foundation.dart';

import '../models/order_model.dart';
import '../models/pet_model.dart';
import '../models/product_model.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';
import 'product_repository.dart';
import 'supabase_config.dart';

/// Order value at or above which delivery is free.
const double freeShippingThreshold = 499;

enum StoreSort { featured, priceLowHigh, priceHighLow, rating, bestSelling }

extension StoreSortX on StoreSort {
  String get label => switch (this) {
    StoreSort.featured => 'Featured',
    StoreSort.priceLowHigh => 'Price: low to high',
    StoreSort.priceHighLow => 'Price: high to low',
    StoreSort.rating => 'Top rated',
    StoreSort.bestSelling => 'Best selling',
  };
}

/// Pet Store state: catalogue, search, cart, wishlist and order history.
class StoreService extends ChangeNotifier {
  StoreService();

  /// Starts empty — products arrive from the API once wired up.
  List<ProductModel> _products = [];
  final List<ReviewModel> _reviews = [];
  final List<CartItem> _cart = [];
  final List<OrderModel> _orders = [];
  final Set<String> _wishlist = {};

  String _query = '';
  ProductCategory? _category;
  final Set<PetSpecies> _speciesTags = {};
  bool _dealsOnly = false;
  bool _inStockOnly = true;
  StoreSort _sort = StoreSort.featured;
  bool _isLoading = false;
  bool _isPlacingOrder = false;

  /// Whether the last server write went through. Goes false when a configured
  /// backend rejects a publish, so the UI can say so instead of lying.
  bool _lastWriteSynced = true;

  String _currentUserId = 'me';

  // ---------------------------------------------------------------- getters

  bool get isLoading => _isLoading;
  bool get isPlacingOrder => _isPlacingOrder;
  bool get lastWriteSynced => _lastWriteSynced;
  String get query => _query;
  ProductCategory? get category => _category;
  Set<PetSpecies> get speciesTags => _speciesTags;
  bool get dealsOnly => _dealsOnly;
  bool get inStockOnly => _inStockOnly;
  StoreSort get sort => _sort;
  List<ReviewModel> get reviews => _reviews;
  List<ProductModel> get allProducts => _products;
  List<OrderModel> get orders => List.unmodifiable(_orders);

  List<CartItem> get cart => List.unmodifiable(_cart);
  int get cartItemCount => _cart.fold(0, (sum, i) => sum + i.quantity);
  Set<String> get wishlist => Set.unmodifiable(_wishlist);

  int get activeFilterCount =>
      (_category != null ? 1 : 0) +
      _speciesTags.length +
      (dealsOnly ? 1 : 0) +
      (inStockOnly ? 1 : 0);

  double get cartSubtotal =>
      _cart.fold(0, (sum, i) => sum + i.product.price * i.quantity);

  double get cartShipping =>
      cartSubtotal == 0 || cartSubtotal >= freeShippingThreshold ? 0 : 49;

  double get freeShippingGap =>
      (freeShippingThreshold - cartSubtotal).clamp(0, freeShippingThreshold);

  double get cartTax => (cartSubtotal * 0.08).roundToDouble();

  double get cartTotal => cartSubtotal + cartShipping + cartTax;

  List<ProductModel> get featuredProducts =>
      _products.where((p) => p.isFeatured || p.isBestSeller).toList();

  List<ProductModel> get dealProducts =>
      _products.where((p) => p.onSale).toList();

  List<ProductModel> get bestSellers =>
      _products.where((p) => p.isBestSeller).toList();

  List<ProductModel> get wishlistProducts =>
      _products.where((p) => _wishlist.contains(p.id)).toList();

  /// Products matching the current store filters.
  List<ProductModel> get results {
    final q = _query.trim().toLowerCase();
    // A seller's own products belong in their shop, not in the buy grid.
    var list = _products.where((p) => p.sellerId != _currentUserId).toList();

    if (_category != null) {
      list = list.where((p) => p.category == _category).toList();
    }
    if (_speciesTags.isNotEmpty) {
      list = list
          .where((p) => p.speciesTags.any((s) => _speciesTags.contains(s)))
          .toList();
    }
    if (_dealsOnly) {
      list = list.where((p) => p.onSale).toList();
    }
    if (_inStockOnly) {
      list = list.where((p) => p.inStock).toList();
    }
    if (q.isNotEmpty) {
      list = list.where((p) {
        return p.name.toLowerCase().contains(q) ||
            p.brand.toLowerCase().contains(q) ||
            p.category.label.toLowerCase().contains(q) ||
            p.description.toLowerCase().contains(q);
      }).toList();
    }

    switch (_sort) {
      case StoreSort.featured:
        list.sort((a, b) {
          final score = (b.isBestSeller ? 1 : 0) - (a.isBestSeller ? 1 : 0);
          return score != 0 ? score : b.soldCount.compareTo(a.soldCount);
        });
      case StoreSort.priceLowHigh:
        list.sort((a, b) => a.price.compareTo(b.price));
      case StoreSort.priceHighLow:
        list.sort((a, b) => b.price.compareTo(a.price));
      case StoreSort.rating:
        list.sort((a, b) => b.rating.compareTo(a.rating));
      case StoreSort.bestSelling:
        list.sort((a, b) => b.soldCount.compareTo(a.soldCount));
    }
    return list;
  }

  int get resultCount => results.length;

  // ------------------------------------------------------------------- shop

  /// Shop that owns the products published through Sell a Product. Created
  /// lazily on first publish. `verified` stays false until the seller
  /// completes the verification flow once a backend exists.
  String _shopName = 'My Pet Shop';
  String _shopTagline = '';
  bool _shopVerified = false;

  String get shopName => _shopName;
  String get shopTagline => _shopTagline;
  bool get shopVerified => _shopVerified;

  /// Live stats shown on the shop card.
  int get shopProductCount =>
      _products.where((p) => p.sellerId == _currentUserId).length;

  /// Points the service at a real user id on sign-in, so "my shop" and the
  /// store grid stay scoped to the signed-in seller. Defaults to `me` offline.
  void setCurrentUser(String userId) {
    if (userId.isEmpty || userId == _currentUserId) return;
    _currentUserId = userId;
    notifyListeners();
  }

  /// Resolves ownership from the live session, mirroring [PetService]. Kept
  /// separate from the auth layer so this service stays independently testable.
  void _resolveCurrentUser() {
    final session = SupabaseConfig.client.auth.currentSession;
    if (session != null && session.user.id != _currentUserId) {
      _currentUserId = session.user.id;
    }
  }

  void updateShop({String? name, String? tagline}) {
    if (name != null && name.trim().isNotEmpty) _shopName = name.trim();
    if (tagline != null) _shopTagline = tagline.trim();
    notifyListeners();
  }

  /// Marks the shop verified. Local stand-in for the backend verification
  /// review; the UI always shows the current state rather than assuming it.
  /// Existing products owned by the shop are updated too, so the badge is
  /// never stale.
  void setShopVerified(bool value) {
    _shopVerified = value;
    _products = _products
        .map(
          (p) => p.sellerId == _currentUserId
              ? p.copyWith(shopVerified: value)
              : p,
        )
        .toList();
    notifyListeners();
  }

  /// Products the signed-in seller owns.
  List<ProductModel> get myShopProducts =>
      _products.where((p) => p.sellerId == _currentUserId).toList();

  /// Publishes a product to the backend when one is configured, otherwise to
  /// in-memory state so the offline demo keeps working.
  ///
  /// A rejected insert still returns the draft so the shop page has something
  /// to show, but [lastWriteSynced] goes false so the screen can say the
  /// product was not saved rather than lying.
  Future<ProductModel> createProductListing({
    required String name,
    required String brand,
    required ProductCategory category,
    required double price,
    String description = '',
    String imagePath = '',
    // The seller no longer sets a quantity, so listings get a healthy default.
    // Zero would mark the product out of stock, and the store's default filter
    // (inStockOnly) would then hide it from the catalogue entirely.
    int stock = 20,
    List<String> highlights = const [],
  }) async {
    _isPlacingOrder = true;
    _lastWriteSynced = true;
    notifyListeners();

    if (ProductRepository.instance.isAvailable) {
      _resolveCurrentUser();
    }

    final draft = ProductModel(
      id: 'prod_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      brand: brand.trim().isEmpty ? _shopName : brand.trim(),
      category: category,
      price: price,
      imageUrl: imagePath,
      description: description,
      highlights: highlights,
      stock: stock,
      // Own listings always carry the seller's shop, so the badge in the
      // store reflects whatever verification state the shop is in.
      sellerId: _currentUserId,
      shopName: _shopName,
      shopVerified: _shopVerified,
    );

    var product = draft;

    if (ProductRepository.instance.isAvailable) {
      final stored = await ProductRepository.instance.create(draft);
      if (stored != null) {
        product = stored;
      } else {
        // Keep the draft visible but flag that the server refused it.
        _lastWriteSynced = false;
      }
    }

    _products = [product, ..._products.where((p) => p.id != product.id)];
    _isPlacingOrder = false;
    notifyListeners();
    return product;
  }

  Future<void> deleteProduct(String productId) async {
    _isLoading = true;
    notifyListeners();
    final saved = await ProductRepository.instance.delete(productId);
    if (ProductRepository.instance.isAvailable && !saved) {
      _lastWriteSynced = false;
    }
    _products = _products.where((p) => p.id != productId).toList();
    _cart.removeWhere((i) => i.product.id == productId);
    _isLoading = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------- actions

  Future<void> bootstrap() async {
    _isLoading = true;
    notifyListeners();
    await refresh();
    _isLoading = false;
    notifyListeners();
  }

  /// Reloads the catalogue from the backend. Ownership is resolved from the
  /// live session first, exactly like [PetService.refresh].
  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();

    if (!ProductRepository.instance.isReadable) {
      // Offline: keep whatever is already in memory.
      _isLoading = false;
      notifyListeners();
      return;
    }

    _resolveCurrentUser();

    final remote = await ProductRepository.instance.fetch(
      excludeSellerId: _currentUserId == 'me' ? null : _currentUserId,
    );

    if (remote.isNotEmpty || _products.isEmpty) {
      _products = remote;
    }

    _isLoading = false;
    notifyListeners();
  }

  void setQuery(String value) {
    if (_query == value) return;
    _query = value;
    notifyListeners();
  }

  void setCategory(ProductCategory? value) {
    _category = value;
    notifyListeners();
  }

  void setDealsOnly(bool value) {
    if (_dealsOnly == value) return;
    _dealsOnly = value;
    notifyListeners();
  }

  void setInStockOnly(bool value) {
    if (_inStockOnly == value) return;
    _inStockOnly = value;
    notifyListeners();
  }

  void toggleSpeciesTag(PetSpecies species) {
    if (_speciesTags.contains(species)) {
      _speciesTags.remove(species);
    } else {
      _speciesTags.add(species);
    }
    notifyListeners();
  }

  void clearFilters() {
    _category = null;
    _speciesTags.clear();
    _dealsOnly = false;
    _inStockOnly = true;
    notifyListeners();
  }

  void setSort(StoreSort value) {
    if (_sort == value) return;
    _sort = value;
    notifyListeners();
  }

  ProductModel? productById(String id) {
    for (final p in _products) {
      if (p.id == id) return p;
    }
    return null;
  }

  List<ProductModel> relatedProducts(String productId, {int limit = 6}) {
    final product = productById(productId);
    if (product == null) return const [];
    return _products
        .where(
          (p) =>
              p.id != productId && p.category == product.category && p.inStock,
        )
        .take(limit)
        .toList();
  }

  bool isInWishlist(String productId) => _wishlist.contains(productId);

  void toggleWishlist(String productId) {
    if (!_wishlist.add(productId)) _wishlist.remove(productId);
    notifyListeners();
  }

  int cartQuantity(String productId) {
    for (final item in _cart) {
      if (item.product.id == productId) return item.quantity;
    }
    return 0;
  }

  bool isInCart(String productId) => cartQuantity(productId) > 0;

  void addToCart(ProductModel product, {int quantity = 1}) {
    final existingIndex = _cart.indexWhere((i) => i.product.id == product.id);
    final stock = product.stock;
    if (existingIndex >= 0) {
      final current = _cart[existingIndex].quantity;
      _cart[existingIndex] = _cart[existingIndex].copyWith(
        quantity: (current + quantity).clamp(1, stock),
      );
    } else {
      _cart.add(CartItem(product: product, quantity: quantity.clamp(1, stock)));
    }
    _decrementStock(product.id, quantity);
    notifyListeners();
  }

  void removeFromCart(String productId) {
    final index = _cart.indexWhere((i) => i.product.id == productId);
    if (index < 0) return;
    _cart.removeAt(index);
    notifyListeners();
  }

  void updateQuantity(String productId, int quantity) {
    final index = _cart.indexWhere((i) => i.product.id == productId);
    if (index < 0) return;
    if (quantity <= 0) {
      _cart.removeAt(index);
    } else {
      _cart[index] = _cart[index].copyWith(quantity: quantity);
    }
    notifyListeners();
  }

  void clearCart() {
    _cart.clear();
    notifyListeners();
  }

  void _decrementStock(String productId, int amount) {
    final product = productById(productId);
    if (product == null) return;
    final newStock = (product.stock - amount).clamp(0, 1 << 30);
    _products = _products
        .map(
          (p) => p.id == productId
              ? p.copyWith(stock: newStock, soldCount: p.soldCount + amount)
              : p,
        )
        .toList();
    // Best-effort persistence so the server stock tracks a sale. A failure
    // here is never worth blocking the order.
    ProductRepository.instance.updateStock(productId, newStock);
  }

  /// Places an order for the current cart and clears it.
  Future<OrderModel> placeOrder({
    required String address,
    String paymentMethod = 'Card •••• 4242',
  }) async {
    if (_cart.isEmpty) {
      throw StateError('Cart is empty');
    }
    _isPlacingOrder = true;
    notifyListeners();
    await Future<void>.delayed(AppConstants.networkDelay);

    final order = OrderModel(
      id: 'PH-${DateTime.now().millisecondsSinceEpoch % 1000000}',
      items: List<CartItem>.from(_cart),
      placedAt: DateTime.now(),
      status: OrderStatus.placed,
      deliveryAddress: address,
      paymentMethod: paymentMethod,
      estimatedDelivery: DateTime.now().add(const Duration(days: 3)),
      trackingNumber: 'TRK${DateTime.now().millisecondsSinceEpoch % 999999}',
    );

    _orders.insert(0, order);
    _cart.clear();
    _isPlacingOrder = false;
    notifyListeners();
    return order;
  }

  void cancelOrder(String orderId) {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index < 0) return;
    _orders[index] = _orders[index].copyWith(status: OrderStatus.cancelled);
    notifyListeners();
  }

  List<OrderModel> get activeOrders =>
      _orders.where((o) => o.isActive).toList();

  List<OrderModel> get pastOrders => _orders.where((o) => !o.isActive).toList();
}
