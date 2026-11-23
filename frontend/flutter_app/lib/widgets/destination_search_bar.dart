import 'package:flutter/material.dart';
import '../models/destination_place.dart';

class DestinationSearchBar extends StatelessWidget {
  final TextEditingController searchController;
  final bool isSearching;
  final String? searchError;
  final List<DestinationPlace> searchResults;
  final VoidCallback onSearch;
  final ValueChanged<DestinationPlace> onSelectDestination;

  const DestinationSearchBar({
    super.key,
    required this.searchController,
    required this.isSearching,
    required this.searchError,
    required this.searchResults,
    required this.onSearch,
    required this.onSelectDestination,
  });

  Widget _buildSearchResults() {
    if (isSearching) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (searchError != null) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          searchError!,
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    if (searchResults.isEmpty) return const SizedBox.shrink();

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 260),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: searchResults.length,
        separatorBuilder: (_, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final place = searchResults[index];
          return ListTile(
            dense: true,
            leading: const Icon(Icons.location_on_outlined),
            title: Text(place.name),
            subtitle: Text(
              place.address,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => onSelectDestination(place),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
            child: Row(
              children: [
                const Icon(Icons.search),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => onSearch(),
                    decoration: const InputDecoration(
                      hintText: '목적지를 검색하세요',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onSearch,
                  icon: const Icon(Icons.arrow_forward),
                ),
              ],
            ),
          ),
          if (isSearching || searchError != null || searchResults.isNotEmpty)
            const Divider(height: 1),
          _buildSearchResults(),
        ],
      ),
    );
  }
}
