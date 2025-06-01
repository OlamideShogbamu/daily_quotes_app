import 'package:flutter/material.dart';
import 'dart:math';
import 'package:hive_flutter/hive_flutter.dart';
import 'quote.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(QuoteAdapter());
  await Hive.openBox('favorites');
  await Hive.openBox('daily');
  runApp(const DailyQuotesApp());
}

class DailyQuotesApp extends StatelessWidget {
  const DailyQuotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Daily Quotes',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MyHomePage(title: 'Daily Motivational Quote'),
    );
  }
}

final List<Quote> allQuotes = [
  Quote(id: '1', text: 'The best way to get started is to quit talking and begin doing.', author: 'Walt Disney'),
  Quote(id: '2', text: 'Don’t let yesterday take up too much of today.', author: 'Will Rogers'),
  Quote(id: '3', text: 'It’s not whether you get knocked down, it’s whether you get up.', author: 'Vince Lombardi'),
  Quote(id: '4', text: 'If you are working on something exciting, it will keep you motivated.'),
  Quote(id: '5', text: 'Success is not in what you have, but who you are.', author: 'Bo Bennett'),
];

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Quote? dailyQuote;
  bool isFavorite = false;

  @override
  void initState() {
    super.initState();
    _loadDailyQuote();
  }

  Future<void> _loadDailyQuote() async {
    final dailyBox = Hive.box('daily');
    final favoritesBox = Hive.box('favorites');
    final now = DateTime.now();
    final lastDate = dailyBox.get('date');
    final lastQuoteId = dailyBox.get('quoteId');
    if (lastDate != null && lastQuoteId != null) {
      final lastShown = DateTime.parse(lastDate);
      if (now.difference(lastShown).inHours < 24) {
        final quote = allQuotes.firstWhere((q) => q.id == lastQuoteId, orElse: () => allQuotes[0]);
        setState(() {
          dailyQuote = quote;
          isFavorite = favoritesBox.get(quote.id, defaultValue: false);
        });
        return;
      }
    }
    // Pick a new random quote
    final random = Random();
    final quote = allQuotes[random.nextInt(allQuotes.length)];
    await dailyBox.put('date', now.toIso8601String());
    await dailyBox.put('quoteId', quote.id);
    setState(() {
      dailyQuote = quote;
      isFavorite = favoritesBox.get(quote.id, defaultValue: false);
    });
  }

  void _toggleFavorite() async {
    if (dailyQuote == null) return;
    final favoritesBox = Hive.box('favorites');
    setState(() {
      isFavorite = !isFavorite;
    });
    await favoritesBox.put(dailyQuote!.id, isFavorite);
  }

  void _goToFavorites() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const FavoritesScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite),
            onPressed: _goToFavorites,
          ),
        ],
      ),
      body: Center(
        child: dailyQuote == null
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '"${dailyQuote!.text}"',
                      style: const TextStyle(fontSize: 24, fontStyle: FontStyle.italic),
                      textAlign: TextAlign.center,
                    ),
                    if (dailyQuote!.author != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Text('- ${dailyQuote!.author!}', style: const TextStyle(fontSize: 18)),
                      ),
                    const SizedBox(height: 32),
                    IconButton(
                      icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: Colors.red, size: 36),
                      onPressed: _toggleFavorite,
                    ),
                    const SizedBox(height: 8),
                    Text(isFavorite ? 'Added to Favorites' : 'Mark as Favorite'),
                  ],
                ),
              ),
      ),
    );
  }
}

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late Box favoritesBox;
  late List<String> favoriteIds;
  late List<Quote> favoriteQuotes;

  @override
  void initState() {
    super.initState();
    favoritesBox = Hive.box('favorites');
    _loadFavorites();
  }

  void _loadFavorites() {
    favoriteIds = favoritesBox.keys.where((k) => favoritesBox.get(k) == true).cast<String>().toList();
    favoriteQuotes = allQuotes.where((q) => favoriteIds.contains(q.id)).toList();
    setState(() {});
  }

  void _toggleFavorite(Quote quote) async {
    await favoritesBox.put(quote.id, false);
    _loadFavorites();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Favorite Quotes')),
      body: favoriteQuotes.isEmpty
          ? const Center(child: Text('No favorites yet.'))
          : ListView.builder(
              itemCount: favoriteQuotes.length,
              itemBuilder: (context, index) {
                final quote = favoriteQuotes[index];
                return ListTile(
                  title: Text('"${quote.text}"'),
                  subtitle: quote.author != null ? Text('- ${quote.author!}') : null,
                  trailing: IconButton(
                    icon: const Icon(Icons.favorite, color: Colors.red),
                    onPressed: () => _toggleFavorite(quote),
                    tooltip: 'Remove from favorites',
                  ),
                );
              },
            ),
    );
  }
}
