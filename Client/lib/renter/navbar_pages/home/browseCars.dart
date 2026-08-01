import 'package:flutter/material.dart';

import '../search/search.dart';

const _primary = Color(0xFF1D4ED8);
const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _border = Color(0xFFE2E8F0);

class BrowseCars extends StatelessWidget {
  final String renterId;

  const BrowseCars({super.key, required this.renterId});

  static const List<_CarCategory> _categories = [
    _CarCategory(
      title: 'Sedan',
      image: 'assets/images/sedan.png',
      tint: Color(0xFFEFF6FF),
    ),
    _CarCategory(
      title: 'SUV',
      image: 'assets/images/suv.png',
      tint: Color(0xFFECFDF5),
    ),
    _CarCategory(
      title: 'Luxury',
      image: 'assets/images/luxury.png',
      tint: Color(0xFFF5F3FF),
    ),
    _CarCategory(
      title: 'Compact',
      image: 'assets/images/compact.png',
      tint: Color(0xFFFFF7ED),
    ),
    _CarCategory(
      title: 'Electric',
      image: 'assets/images/electric.png',
      tint: Color(0xFFF0FDFA),
    ),
    _CarCategory(
      title: 'Convertible',
      image: 'assets/images/convertible.png',
      tint: Color(0xFFFDF2F8),
    ),
    _CarCategory(
      title: 'Sports',
      image: 'assets/images/sports.png',
      tint: Color(0xFFFEF2F2),
    ),
  ];

  void _openSearch(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RenterSearch(id: renterId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 620 ? 3 : 2;

        return GridView.builder(
          itemCount: _categories.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: columns == 3 ? 1.12 : 1.02,
          ),
          itemBuilder: (context, index) {
            return _CategoryCard(
              category: _categories[index],
              onTap: () => _openSearch(context),
            );
          },
        );
      },
    );
  }
}

class _CarCategory {
  final String title;
  final String image;
  final Color tint;

  const _CarCategory({
    required this.title,
    required this.image,
    required this.tint,
  });
}

class _CategoryCard extends StatelessWidget {
  final _CarCategory category;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.category,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: category.tint,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Image.asset(
                    category.image,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.directions_car_filled_outlined,
                      size: 48,
                      color: _muted,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(13, 2, 10, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        category.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: _primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
