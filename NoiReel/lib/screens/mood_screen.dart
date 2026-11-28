import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/mood_row.dart';
import 'mood_text_matcher.dart';
import 'mood_titles_screen.dart';
import 'title_details_screen.dart';

/// The Mood tab: one row of posters per mood, ranked by how well each title
/// fits the mood (GU-01). Pull down to reload
///
/// Mood discovery by feeling and available time (RU-05) will go above the
/// rows later
class MoodScreen extends StatefulWidget {
  /// Creates the Mood tab
  const MoodScreen({super.key, required this.api});

  final ApiClient api; // Used to load moods and titles

  @override
  State<MoodScreen> createState() => _MoodScreenState();
}

class _MoodScreenState extends State<MoodScreen> {
  late Future<List<Mood>> _moods = widget.api.getMoods();

  // SpeechToText manages Android speech-recognition access.
  final SpeechToText _speech = SpeechToText();

  // True when Android reports that speech recognition is available.
  bool _speechReady = false;

  // Tracks whether the microphone is currently listening.
  bool _isListening = false;

  // Stores the words recognized from the user's speech so they can be shown
  // and passed to the mood-matching logic.
  String _recognizedText = '';

  // Changing this rebuilds the mood rows, so they reload their titles.
  int _reloads = 0;

  @override
  void initState() {
    super.initState();

    // Speech recognition only needs to be initialized once when this screen
    // is created. Android will request microphone permission if necessary.
    _initializeSpeech();
  }

  /// Initializes Android's speech-recognition service.
  Future<void> _initializeSpeech() async {
    final available = await _speech.initialize();

    if (!mounted) return;

    setState(() {
      _speechReady = available;
    });
  }

  /// Starts listening when the microphone icon is pressed.
  Future<void> _startListening() async {
    if (!_speechReady) {
      _showMessage(
        'Speech recognition is unavailable or microphone permission was denied.',
      );
      return;
    }

    setState(() {
      _isListening = true;
      _recognizedText = '';
    });

    // The result callback is called as Android recognizes more words.
    await _speech.listen(
      onResult: _onSpeechResult,
    );
  }

  /// Stops the current speech-recognition session.
  Future<void> _stopListening() async {
    await _speech.stop();

    if (!mounted) return;

    setState(() {
      _isListening = false;
    });
  }

  /// Receives partial and final speech-recognition results.
  ///
  /// Partial results update the text shown to the user. The mood is only
  /// selected after Android reports that the user has finished speaking.
  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!mounted) return;

    setState(() {
      _recognizedText = result.recognizedWords;
    });

    if (result.finalResult) {
      _processFinalSpeech(result.recognizedWords);
    }
  }

  /// Converts the final spoken phrase into a mood and opens that mood page.
  Future<void> _processFinalSpeech(String spokenPhrase) async {
    await _speech.stop();

    if (!mounted) return;

    setState(() {
      _isListening = false;
    });

    // MoodTextMatcher checks words such as "down", "happy", and "calm".
    final moodName = MoodTextMatcher.match(spokenPhrase);

    if (moodName == null) {
      _showMessage(
        'No mood detected. Try saying “I feel calm.”',
      );
      return;
    }

    // The app already receives the official Mood objects from the server.
    // We find the matching object so the existing mood-title screen can be
    // reused without changing the backend.
    final moods = await _moods;

    Mood? matchedMood;

    for (final mood in moods) {
      if (mood.name.toLowerCase() == moodName.toLowerCase()) {
        matchedMood = mood;
        break;
      }
    }

    if (!mounted) return;

    if (matchedMood == null) {
      _showMessage('Mood "$moodName" was not found.');
      return;
    }

    _showMessage('Mood detected: ${matchedMood.name}');

    // Reuse the existing navigation method to show titles for the detected
    // mood.
    _openMood(matchedMood);
  }

  /// Shows a short status or error message at the bottom of the screen.
  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  @override
  void dispose() {
    // Stop speech recognition when the screen is removed.
    _speech.cancel();
    super.dispose();
  }

  Future<void> _reload() async {
    final moods = widget.api.getMoods();

    setState(() {
      _moods = moods;
      _reloads++;
    });

    await moods.catchError((_) => <Mood>[]);
  }

  void _open(TitleCard title) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => TitleDetailsScreen(
          api: widget.api,
          title: title,
        ),
      ),
    );
  }

  void _openMood(Mood mood) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => MoodTitlesScreen(
          api: widget.api,
          mood: mood,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      // The existing AppBar title is preserved. The microphone button is
      // added through the actions list on the right side.
      appBar: AppBar(
        title: const Text('NOIREEL'),
        actions: [
          IconButton(
            tooltip: _isListening
                ? 'Stop listening'
                : 'Describe your mood',
            onPressed: _isListening
                ? _stopListening
                : _startListening,
            icon: Icon(
              _isListening ? Icons.mic : Icons.mic_none,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<Mood>>(
          future: _moods,
          builder: (context, snapshot) {
            final loading =
                snapshot.connectionState != ConnectionState.done;
            final moods = snapshot.data ?? const <Mood>[];

            return ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                // Displays the phrase recognized by Android while or after
                // the user speaks.
                if (_recognizedText.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Card(
                      child: ListTile(
                        leading: Icon(
                          _isListening
                              ? Icons.mic
                              : Icons.record_voice_over,
                        ),
                        title: Text(
                          _isListening
                              ? 'Listening...'
                              : 'You said: $_recognizedText',
                        ),
                        subtitle: const Text(
                          'Try saying “I feel down” or “I feel calm.”',
                        ),
                      ),
                    ),
                  ),

                FadeSlideIn(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: Text(
                      'Browse by mood',
                      style: text.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                if (loading)
                  const Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (snapshot.hasError)
                  FadeSlideIn(
                    child: _Notice(
                      text: '${snapshot.error}',
                      onRetry: _reload,
                    ),
                  )
                else if (moods.isEmpty)
                  const FadeSlideIn(
                    child: _Notice(
                      text: 'No moods yet. '
                          'Run db/seed_moods.sql on the server.',
                    ),
                  )
                else
                  for (final (i, mood) in moods.indexed)
                    FadeSlideIn.staggered(
                      key: ValueKey('${mood.id}-$_reloads'),
                      index: i + 1,
                      step: const Duration(milliseconds: 90),
                      child: MoodRow(
                        mood: mood,
                        api: widget.api,
                        onTitleTap: _open,
                        onOpen: () => _openMood(mood),
                      ),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(text, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ],
        ],
      ),
    );
  }
}