import 'package:flutter/material.dart';

import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/cart/cart_screen.dart';
import '../screens/chat/chat_list_screen.dart';
import '../screens/chat/chat_thread_screen.dart';
import '../screens/favorites/favorites_screen.dart';
import '../screens/healthcare/article_detail_screen.dart';
import '../screens/healthcare/healthcare_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/marketplace/marketplace_screen.dart';
import '../screens/marketplace/contact_seller_screen.dart';
import '../screens/my_listings/my_listings_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/orders/order_detail_screen.dart';
import '../screens/orders/orders_screen.dart';
import '../screens/pet_details/pet_details_screen.dart';
import '../screens/product_details/product_details_screen.dart';
import '../screens/profile/edit_profile_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/sell_pet/sell_home_screen.dart';
import '../screens/sell_pet/sell_pet_screen.dart';
import '../screens/sell_pet/sell_product_screen.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/store/my_shop_screen.dart';
import '../screens/store/store_screen.dart';
import '../widgets/app_bottom_navigation.dart';

/// Every named route in the app, so navigation stays type-safe and
/// centrally documented.
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String shell = '/shell';

  /// Tabs rendered inside [AppShell]; each is also routable on its own.
  static const String home = '/home';
  static const String sellHome = '/sell';
  static const String sellPet = '/sell-pet';
  static const String sellProduct = '/sell-product';
  static const String messages = '/messages';
  static const String chatThread = '/messages/thread';

  static const String marketplace = '/marketplace';
  static const String store = '/store';
  static const String myShop = '/my-shop';

  static const String petDetails = '/pet-details';
  static const String contactSeller = '/contact-seller';
  static const String myListings = '/my-listings';
  static const String favorites = '/favorites';

  static const String productDetails = '/product-details';
  static const String cart = '/cart';
  static const String orders = '/orders';
  static const String orderDetails = '/order-details';

  /// Healthcare is guidance-only: tips and written guides.
  static const String healthcare = '/healthcare';
  static const String articleDetails = '/healthcare/article';

  static const String notifications = '/notifications';
  static const String profile = '/profile';
  static const String editProfile = '/profile/edit';

  /// Route table for the top-level app flow.
  static Map<String, WidgetBuilder> get topLevel => {
    splash: (_) => const SplashScreen(),
    onboarding: (_) => const OnboardingScreen(),
    login: (_) => const LoginScreen(),
    register: (_) => const RegisterScreen(),
    forgotPassword: (_) => const ForgotPasswordScreen(),
    shell: (_) => const AppShell(),
    home: (_) => const HomeScreen(),
    marketplace: (_) => const MarketplaceScreen(),
    store: (_) => const StoreScreen(),
    profile: (_) => const ProfileScreen(),
    messages: (_) => const ChatListScreen(),
    notifications: (_) => const NotificationsScreen(),
  };

  /// Full route table including pushed detail screens.
  static Map<String, WidgetBuilder> get all => {
    ...topLevel,
    petDetails: (context) {
      final args = context.routeArguments<PetDetailsArgs>();
      return PetDetailsScreen(petId: args.petId);
    },
    contactSeller: (context) {
      final args = context.routeArguments<ContactSellerArgs>();
      return ContactSellerScreen(petId: args.petId);
    },
    sellPet: (_) => const SellPetScreen(),
    sellHome: (_) => const SellHomeScreen(),
    sellProduct: (_) => const SellProductScreen(),
    myShop: (_) => const MyShopScreen(),
    myListings: (_) => const MyListingsScreen(),
    favorites: (_) => const FavoritesScreen(),
    productDetails: (context) {
      final args = context.routeArguments<ProductDetailsArgs>();
      return ProductDetailsScreen(productId: args.productId);
    },
    cart: (_) => const CartScreen(),
    orders: (_) => const OrdersScreen(),
    orderDetails: (context) {
      final args = context.routeArguments<OrderDetailsArgs>();
      return OrderDetailScreen(orderId: args.orderId);
    },
    healthcare: (_) => const HealthcareScreen(),
    articleDetails: (context) {
      final args = context.routeArguments<ArticleDetailsArgs>();
      return ArticleDetailScreen(articleId: args.articleId);
    },
    editProfile: (_) => const EditProfileScreen(),
    chatThread: (context) {
      final args = context.routeArguments<ChatThreadArgs>();
      return ChatThreadScreen(threadId: args.threadId);
    },
  };
}

/// Helper for extracting typed route arguments.
extension RouteArguments on BuildContext {
  T routeArguments<T>() {
    final args = ModalRoute.of(this)?.settings.arguments;
    if (args is T) return args;
    throw ArgumentError('Expected route arguments of type $T, got $args');
  }
}

class PetDetailsArgs {
  const PetDetailsArgs(this.petId);
  final String petId;
}

class ContactSellerArgs {
  const ContactSellerArgs(this.petId);
  final String petId;
}

class ProductDetailsArgs {
  const ProductDetailsArgs(this.productId);
  final String productId;
}

class OrderDetailsArgs {
  const OrderDetailsArgs(this.orderId);
  final String orderId;
}

class ArticleDetailsArgs {
  const ArticleDetailsArgs(this.articleId);
  final String articleId;
}

class ChatThreadArgs {
  const ChatThreadArgs(this.threadId);
  final String threadId;
}

/// Convenience navigation helpers used across screens.
class Nav {
  Nav._();

  static Future<T?> push<T>(
    BuildContext context,
    String route, [
    Object? args,
  ]) {
    return Navigator.of(context).pushNamed<T>(route, arguments: args);
  }

  static Future<T?> replace<T>(
    BuildContext context,
    String route, [
    Object? args,
  ]) {
    return Navigator.of(
      context,
    ).pushReplacementNamed<T, void>(route, arguments: args);
  }

  static void pop<T>(BuildContext context, [T? result]) {
    Navigator.of(context).pop<T>(result);
  }

  static void popToRoot(BuildContext context) {
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  static void toRoot(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  /// Clears every route in the stack — used for logout and hard resets.
  static Future<T?> resetTo<T>(
    BuildContext context,
    String route, [
    Object? args,
  ]) {
    return Navigator.of(
      context,
      rootNavigator: true,
    ).pushNamedAndRemoveUntil<T>(route, (_) => false, arguments: args);
  }
}
