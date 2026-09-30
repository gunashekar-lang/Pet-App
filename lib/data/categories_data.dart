import 'package:flutter/material.dart';

import '../models/pet_model.dart';
import '../utils/constants.dart';

/// Category chips used on Home and in the Marketplace filter sheet. These are
/// UI taxonomy, not seeded content.
class CategoriesData {
  CategoriesData._();

  static const List<CategoryModel> all = [
    CategoryModel(
      id: 'dogs',
      name: 'Dogs',
      icon: Icons.pets_rounded,
      color: AppColors.brand,
      subtitle: 'Puppies to adults',
    ),
    CategoryModel(
      id: 'cats',
      name: 'Cats',
      icon: Icons.pets_rounded,
      color: AppColors.plum,
      subtitle: 'Kitten to grown',
    ),
    CategoryModel(
      id: 'birds',
      name: 'Birds',
      icon: Icons.flutter_dash_rounded,
      color: AppColors.periwinkle,
      subtitle: 'Talkers & singers',
    ),
    CategoryModel(
      id: 'rabbits',
      name: 'Rabbits',
      icon: Icons.cruelty_free_rounded,
      color: AppColors.rose,
      subtitle: 'Soft & silent',
    ),
    CategoryModel(
      id: 'fish',
      name: 'Fish',
      icon: Icons.water_rounded,
      color: AppColors.mint,
      subtitle: 'Aquatic companions',
    ),
    CategoryModel(
      id: 'reptiles',
      name: 'Reptiles',
      icon: Icons.eco_rounded,
      color: AppColors.amber,
      subtitle: 'Low maintenance',
    ),
    CategoryModel(
      id: 'small',
      name: 'Small Pets',
      icon: Icons.radar_rounded,
      color: AppColors.periwinkle,
      subtitle: 'Hamsters & more',
    ),
  ];

  static CategoryModel? byId(String id) {
    for (final c in all) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Maps a marketplace category id to a [PetSpecies].
  static PetSpecies speciesFor(String categoryId) => switch (categoryId) {
    'dogs' => PetSpecies.dog,
    'cats' => PetSpecies.cat,
    'birds' => PetSpecies.bird,
    'rabbits' => PetSpecies.rabbit,
    'fish' => PetSpecies.fish,
    'reptiles' => PetSpecies.reptile,
    _ => PetSpecies.smallPet,
  };
}
