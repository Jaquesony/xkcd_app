import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: FutureBuilder<int>(
          future: getLatestComicNumber(),
          initialData: 0,
          builder: (context, snapshot) {
            return HomeScreen(
              title: 'XKCD app',
              latestComic: snapshot.data!,
            );
          }),
      debugShowCheckedModeBanner: false,
    );
  }
}

Future<int> getLatestComicNumber() async {
  final dir = await getTemporaryDirectory();
  var file = File("${dir.path}/latestComicNumber.txt");
  int n = 1;

  try {
    n = json.decode(
      await http.read(
        Uri.parse('https://xkcd.com/info.0.json'),
      ),
    )["num"];
    file.exists().then((exists) {
      if (!exists) file.createSync();
      file.writeAsString('$n');
    });
  } catch (e) {
    if (file.existsSync() && file.readAsStringSync() != "") {
      n = int.parse(file.readAsStringSync());
    }
  }
  return n;
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.title, this.latestComic});
  final int? latestComic;
  final String title;

  Future<Map<String, dynamic>> _fetchComic(int n) async {
    final dir = await getTemporaryDirectory();
    var comicNumber = latestComic! - n;
    print(comicNumber);
    var comicFile = File("${dir.path}/$comicNumber.json");

    if (await comicFile.exists() && comicFile.readAsStringSync() != "") {
      return json.decode(comicFile.readAsStringSync());
    } else {
      comicFile.createSync();
      final comic = json.decode(
        await http.read(
          Uri.parse("https://xkcd.com/$comicNumber/info.0.json"),
        ),
      );
      /*File('${dir.path}/$comicNumber.png')
          .writeAsBytesSync(await http.readBytes(Uri.parse(comic["img"])));
      comic["img"] = '${dir.path}/$comicNumber.png';
      comicFile.writeAsString(json.encode(comic));*/
      return comic;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.looks_one),
            tooltip: "Select Comic By Number",
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (BuildContext context) => const SelectionPage(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.star),
            tooltip: "Browse Starred Comics",
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (BuildContext context) => const StarredPage(),
              ),
            ),
          )
        ],
      ),
      body: ListView.builder(
        itemCount: latestComic,
        itemBuilder: (context, i) => FutureBuilder<Map<String, dynamic>>(
          future: _fetchComic(i),
          builder: (context, comicResult) => comicResult.hasData
              ? ComicTile(comic: comicResult.data)
              : const SizedBox(
                  width: 30,
                  child: Center(child: CircularProgressIndicator()),
                ),
        ),
      ),
    );
  }
}

class ComicTile extends StatelessWidget {
  const ComicTile({super.key, this.comic});
  final Map<String, dynamic>? comic;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Image.network(
        comic!["img"],
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.error),
      ),
      title: Text(comic!["title"]),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (BuildContext context) => ComicPage(comic: comic),
          ),
        );
      },
    );
  }
}

class ComicPage extends StatefulWidget {
  const ComicPage({super.key, this.comic});
  final Map<String, dynamic>? comic;

  @override
  State<ComicPage> createState() => _ComicPageState();
}

class _ComicPageState extends State<ComicPage> {
  void _launchComic(int comicNumber) {
    launchUrl(Uri.parse("https://xkcd.com/$comicNumber/"));
  }

  void _addToStarred(int num) async {
    final dir = await getTemporaryDirectory();
    var docsDir = dir.path;
    var file = File("$docsDir/starred");
    List<int> savedComics = json.decode(file.readAsStringSync()).cast<int>();
    if (isStarred!) {
      savedComics.remove(num);
    } else {
      savedComics.add(num);
    }
    file.writeAsStringSync(json.encode(savedComics));
  }

  bool? isStarred;

  @override
  void initState() {
    super.initState();
    getApplicationDocumentsDirectory().then(
      (dir) {
        var docsDir = dir.path;
        var file = File('$docsDir/starred');
        if (!file.existsSync()) {
          file.createSync();
          file.writeAsStringSync("[]");
          isStarred = false;
        } else {
          setState(() {
            isStarred = _isStarred(widget.comic!["num"]) as bool?;
          });
        }
      },
    );
  }

  Future<bool> _isStarred(int num) async {
    final dir = await getTemporaryDirectory();
    var docsDir = dir.path;
    var file = File('$docsDir/starred');
    List<int> savedComics = json.decode(file.readAsStringSync()).cast<int>();
    if (savedComics.contains(num)) {
      return true;
    } else {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("#${widget.comic!["num"]}"),
        actions: [
          IconButton(
              icon: isStarred == true
                  ? const Icon(Icons.star)
                  : const Icon(Icons.star_border),
              tooltip: "Star Comic",
              onPressed: () {
                _addToStarred(widget.comic!["num"]);
                setState(() {
                  isStarred = !isStarred!;
                });
              }),
        ],
      ),
      body: ListView(
        children: [
          Center(
              child: Text(
            widget.comic!["title"],
            style: Theme.of(context).textTheme.displayMedium,
          )),
          InkWell(
              onTap: () {
                _launchComic(widget.comic!["num"]);
              },
              child: Image.network(widget.comic!["img"])),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(widget.comic!["alt"]),
          )
        ],
      ),
    );
  }
}

class SelectionPage extends StatelessWidget {
  const SelectionPage({super.key});

  Future<Map<String, dynamic>> _fetchComic(String n) async {
    return json
        .decode(await http.read(Uri.parse('https://xkcd.com/$n/info.0.json')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Comic Selection"),
      ),
      body: Center(
        child: TextField(
          decoration: const InputDecoration(label: Text("Insert Comic #")),
          keyboardType: TextInputType.number,
          autofocus: true,
          onSubmitted: (String a) => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FutureBuilder<Map<String, dynamic>>(
                  future: _fetchComic(a),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return const ErrorPage();
                    if (snapshot.hasData) {
                      return ComicPage(comic: snapshot.data);
                    }
                    return const CircularProgressIndicator();
                  }),
            ),
          ),
        ),
      ),
    );
  }
}

class ErrorPage extends StatelessWidget {
  const ErrorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Error Page"),
      ),
      body: Column(
        children: const [
          Icon(Icons.not_interested),
          Text("The comics you have selected doesn't exist"
              "or isn't available"),
        ],
      ),
    );
  }
}

class StarredPage extends StatelessWidget {
  const StarredPage({super.key});

  Future<Map<String, dynamic>> _fetchComic(String n) async {
    final dir = await getTemporaryDirectory();
    var comicFile = File("${dir.path}/$n.json");
    if (await comicFile.exists() && comicFile.readAsStringSync() != "") {
      return json.decode(comicFile.readAsStringSync());
    } else {
      comicFile.createSync();
      final comic = json.decode(
          await http.read(Uri.parse('https://xkcd.com/$n/info.0.json')));
      File('${dir.path}/$n.png')
          .writeAsBytesSync(await http.readBytes(comic["img"]));
      comic["img"] = '${dir.path}/$n.png';
      comicFile.writeAsString(json.encode(comic));
      return comic;
    }
  }

  Future<List<Map<String, dynamic>>> _retrieveSavedComics() async {
    Directory docsDir = await getApplicationDocumentsDirectory();
    File file = File('${docsDir.path}/starred');
    List<Map<String, dynamic>> comics = [];
    if (!file.existsSync()) {
      file.createSync();
      file.writeAsStringSync("[]");
    } else {
      json
          .decode(file.readAsStringSync())
          .forEach((n) async => comics.add(await _fetchComic(n.toString())));
    }
    return comics;
  }

  @override
  Widget build(BuildContext context) {
    var comics = _retrieveSavedComics();
    return Scaffold(
      appBar: AppBar(
        title: const Text("Browse your Favorite Comics"),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: comics,
        builder: (context, snapshot) =>
            snapshot.hasData && snapshot.data!.isNotEmpty
                ? ListView.builder(
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, i) => ComicTile(
                          comic: snapshot.data![i],
                        ))
                : Column(
                    children: const [
                      Icon(Icons.not_interested),
                      Text("""
You haven't starred any comics yet.
Check back after you have found something worthy of being here.
"""),
                    ],
                  ),
      ),
    );
  }
}
