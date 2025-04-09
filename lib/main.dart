import 'package:atproto/atproto.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:bluesky/bluesky.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bluesky Feed',
      home: const VideoFeedPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class VideoFeedPage extends StatefulWidget {
  const VideoFeedPage({super.key});

  @override
  State<VideoFeedPage> createState() => _VideoFeedPageState();
}

class _VideoFeedPageState extends State<VideoFeedPage> {
  List<Map<String, dynamic>> videoPosts = [];
  bool isLoading = true;
  bool isLoadingMore = false;
  bool hasError = false;
  String? errorMessage;
  String? cursor;
  late Bluesky bluesky;

  @override
  void initState() {
    super.initState();
    fetchVideos();
  }

  Future<void> fetchVideos({bool loadMore = false}) async {
    if (loadMore && cursor == null) return;

    setState(() {
      if (loadMore) {
        isLoadingMore = true;
      } else {
        isLoading = true;
        hasError = false;
        errorMessage = null;
      }
    });

    try {
      print('Tentando criar instância do Bluesky...');
      if (!loadMore) {
        bluesky = await createBlueskyInstance(
          identifier: 'huayan11.bsky.social',
          password: 'Hu4n1m3s', // Substitua por uma senha de aplicativo válida
        );
        print('Instância criada com sucesso.');
      }

      print('Buscando timeline...');
      final timeline = await bluesky.feed.getTimeline(cursor: loadMore ? cursor : null);
      cursor = timeline.data.cursor;
      print('Timeline recebida: ${timeline.data.feed.length} itens');

      final newPosts = timeline.data.feed
          .where((item) => item.post.embed != null)
          .map((item) {
            final embed = item.post.embed!;
            print('Embed encontrado: ${embed.runtimeType}');
            return embed.when(
              external: (external) {
                final videoUrl = external.external.uri.toString();
                print('Embed externo: $videoUrl');
                return {
                  'videoUrl': videoUrl,
                  'authorName': item.post.author.displayName ?? 'Desconhecido',
                  'authorHandle': item.post.author.handle,
                  'avatar': item.post.author.avatar,
                };
              },
              images: (_) {
                print('Embed de imagem ignorado.');
                return null;
              },
              record: (_) {
                print('Embed de registro ignorado.');
                return null;
              },
              recordWithMedia: (_) {
                print('Embed de registro com mídia ignorado.');
                return null;
              },
              video: (video) {
                final videoUrl = video.playlist.toString();
                print('Embed de vídeo: $videoUrl');
                return {
                  'videoUrl': videoUrl,
                  'authorName': item.post.author.displayName ?? 'Desconhecido',
                  'authorHandle': item.post.author.handle,
                  'avatar': item.post.author.avatar,
                };
              },
              unknown: (_) {
                print('Embed desconhecido ignorado.');
                return null;
              },
            );
          })
          .whereType<Map<String, dynamic>>()
          .toList();

      setState(() {
        if (loadMore) {
          videoPosts.addAll(newPosts);
        } else {
          videoPosts = newPosts;
        }
        print('Vídeos encontrados: ${videoPosts.length}');
        if (videoPosts.isEmpty && !loadMore) {
          errorMessage = 'Nenhum vídeo encontrado na sua timeline.';
        }
      });
    } catch (e) {
      print('Erro ao buscar vídeos: $e');
      setState(() {
        hasError = true;
        errorMessage = e.toString().contains('Failed host lookup')
            ? 'Sem conexão com a internet. Verifique sua rede e tente novamente.'
            : e.toString().contains('Invalid identifier or password')
                ? 'Falha na autenticação. Verifique suas credenciais e tente novamente.'
                : 'Erro ao carregar vídeos: $e';
      });
    }

    setState(() {
      isLoading = false;
      isLoadingMore = false;
    });
  }

  Future<Bluesky> createBlueskyInstance({
    required String identifier,
    required String password,
  }) async {
    final session = await createSession(
      identifier: identifier,
      password: password,
    );
    return Bluesky.fromSession(session.data);
  }

  @override
  Widget build(BuildContext context) {
    // Verifica se está rodando na web
    const bool isWeb = identical(0, 0.0); // kIsWeb não está disponível diretamente
    if (isWeb) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'Este aplicativo não suporta a web. Por favor, execute em um dispositivo Android ou iOS.',
            style: TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : hasError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        errorMessage ?? 'Erro ao carregar vídeos',
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => fetchVideos(),
                        child: const Text('Tentar Novamente'),
                      ),
                    ],
                  ),
                )
              : videoPosts.isEmpty
                  ? Center(
                      child: Text(
                        errorMessage ?? 'Nenhum vídeo encontrado',
                        style: const TextStyle(color: Colors.white),
                      ),
                    )
                  : NotificationListener<ScrollNotification>(
                      onNotification: (ScrollNotification scrollInfo) {
                        if (scrollInfo.metrics.pixels >=
                                scrollInfo.metrics.maxScrollExtent * 0.8 &&
                            !isLoadingMore) {
                          fetchVideos(loadMore: true);
                        }
                        return false;
                      },
                      child: PageView.builder(
                        scrollDirection: Axis.vertical,
                        itemCount: videoPosts.length + (isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == videoPosts.length) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          final video = videoPosts[index];
                          return VideoPlayerWidget(video: video);
                        },
                      ),
                    ),
    );
  }
}

class VideoPlayerWidget extends StatefulWidget {
  final Map<String, dynamic> video;

  const VideoPlayerWidget({required this.video, super.key});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }

  void _initializeVideoPlayer() {
    _controller = VideoPlayerController.network(widget.video['videoUrl'])
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _controller.setLooping(true);
            _controller.play();
          });
        }
      }).catchError((error) {
        if (mounted) {
          setState(() => _hasError = true);
          print('Erro ao carregar vídeo: $error');
        }
      });
  }

  @override
  void dispose() {
    _controller.pause();
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (mounted) {
      setState(() {
        _controller.value.isPlaying ? _controller.pause() : _controller.play();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _togglePlayPause,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _controller.value.isInitialized
              ? FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller.value.size.width,
                    height: _controller.value.size.height,
                    child: VideoPlayer(_controller),
                  ),
                )
              : _hasError
                  ? const Center(
                      child: Icon(Icons.error, color: Colors.red, size: 50),
                    )
                  : const Center(child: CircularProgressIndicator()),
          Positioned(
            bottom: 16,
            left: 16,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey,
                  child: ClipOval(
                    child: widget.video['avatar'] != null
                        ? CachedNetworkImage(
                            imageUrl: widget.video['avatar'],
                            fit: BoxFit.cover,
                            width: 40,
                            height: 40,
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.person, color: Colors.white),
                          )
                        : const Icon(Icons.person, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.video['authorName'] ?? 'Desconhecido',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            offset: Offset(1, 1),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '@${widget.video['authorHandle'] ?? 'desconhecido'}',
                      style: const TextStyle(
                        color: Colors.white70,
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            offset: Offset(1, 1),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!_controller.value.isPlaying && _controller.value.isInitialized)
            const Center(
              child: Icon(
                Icons.play_arrow,
                size: 60,
                color: Colors.white54,
              ),
            ),
        ],
      ),
    );
  }
}