import 'package:atproto/atproto.dart';
import 'package:atproto/core.dart' show Session;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:bluesky/bluesky.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:chewie/chewie.dart';
import 'package:xrpc/src/xrpc/xrpc_response.dart';
import 'package:visibility_detector/visibility_detector.dart';


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
  int currentPageIndex = 0;
  String? accessToken; // Para armazenar o token de autenticação

  @override
  void initState() {
    super.initState();
    fetchVideos();
  }

  Future<bool> checkConnectivity() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
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
      bool isConnected = await checkConnectivity();
      if (!isConnected) {
        throw Exception('Sem conexão com a internet. Verifique sua rede e tente novamente.');
      }

      print('Tentando criar instância do Bluesky...');
      if (!loadMore) {
        final session = await createBlueskySession(
          identifier: 'huayan11.bsky.social',
          password: 'Hu4n1m3s', // Substitua por uma senha de aplicativo válida
        );
        bluesky = Bluesky.fromSession(session.data); // Acesse session.data
        accessToken = session.data.accessJwt; // Acesse session.data.accessJwt
        print('Instância criada com sucesso. Access Token: $accessToken');
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
              external: (_) {
                print('Embed externo ignorado.');
                return null;
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
                  'videoUrl': videoUrl, // Usa a URL real do Bluesky
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
        errorMessage = e.toString().contains('Failed host lookup') ||
                e.toString().contains('Sem conexão com a internet')
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

  Future<XRPCResponse<Session>> createBlueskySession({
    required String identifier,
    required String password,
  }) async {
    return await createSession(
      identifier: identifier,
      password: password,
    );
  }

  @override
  Widget build(BuildContext context) {
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
                        onPageChanged: (index) {
                          setState(() {
                            currentPageIndex = index;
                          });
                        },
                        itemBuilder: (context, index) {
                          if (index == videoPosts.length) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          final video = videoPosts[index];
                          return VideoPlayerWidget(
                            video: video,
                            isVisible: index == currentPageIndex,
                            accessToken: accessToken,
                          );
                        },
                      ),
                    ),
    );
  }
}

class VideoPlayerWidget extends StatefulWidget {
  final Map<String, dynamic> video;
  final bool isVisible;
  final String? accessToken;

  const VideoPlayerWidget({
    required this.video,
    required this.isVisible,
    this.accessToken,
    super.key,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;
  ChewieController? _chewieController;
  bool _hasError = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    print('Inicializando VideoPlayerWidget para: ${widget.video['videoUrl']}');
    _initializeVideoPlayer();
  }

  Future<void> _initializeVideoPlayer() async {
    print('Criando VideoPlayerController para: ${widget.video['videoUrl']}');
    _controller = VideoPlayerController.network(
      widget.video['videoUrl'],
      httpHeaders: {
        'Authorization': 'Bearer ${widget.accessToken ?? ''}',
        'Connection': 'keep-alive',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
      },
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: true,
      ),
    );
    try {
      print('Inicializando controlador de vídeo...');
      await _controller.initialize().timeout(const Duration(seconds: 30), onTimeout: () {
        throw Exception('Tempo limite excedido ao inicializar o vídeo.');
      });
      print('Controlador de vídeo inicializado. Aspect ratio: ${_controller.value.aspectRatio}');
      setState(() {
        _isInitialized = true;
        _chewieController = ChewieController(
          videoPlayerController: _controller,
          autoPlay: widget.isVisible,
          looping: true,
          aspectRatio: _controller.value.aspectRatio,
          errorBuilder: (context, errorMessage) {
            print('Erro no Chewie: $errorMessage');
            return const Center(
              child: Icon(Icons.error, color: Colors.red, size: 50),
            );
          },
        );
      });
      print('Vídeo inicializado com sucesso: ${widget.video['videoUrl']}');
    } catch (error) {
      if (mounted) {
        setState(() => _hasError = true);
        print('Erro detalhado ao carregar vídeo: $error');
      }
    }
  }

  @override
  void didUpdateWidget(VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible && !_hasError && _isInitialized && _chewieController != null) {
      _chewieController!.play();
      print('Reproduzindo vídeo: ${widget.video['videoUrl']}');
    } else if (!widget.isVisible && _chewieController != null) {
      _chewieController!.pause();
      print('Pausando vídeo: ${widget.video['videoUrl']}');
    }
  }

  @override
  void dispose() {
    print('Descartando VideoPlayerWidget para: ${widget.video['videoUrl']}');
    _controller.pause();
    _chewieController?.dispose();
    _controller.dispose();
    super.dispose();
    print('VideoPlayerWidget descartado: ${widget.video['videoUrl']}');
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _hasError || !_isInitialized || _chewieController == null
            ? const Center(
                child: Icon(Icons.error, color: Colors.red, size: 50),
              )
            : Chewie(controller: _chewieController!),
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
      ],
    );
  }
}
