import 'package:flutter/material.dart';
import '../widgets/selectors/poll_picker.dart';
import '../screens/polls/create_poll_screen.dart';
import '../models/poll.dart';

/// Example of how to use the PollPicker widget
/// This shows the integration pattern similar to MatchPicker usage
class PollPickerExample extends StatelessWidget {
  final String clubId;

  const PollPickerExample({
    super.key,
    required this.clubId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Poll Picker Example'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () => _showPollPicker(context),
          child: const Text('Show Poll Picker'),
        ),
      ),
    );
  }

  void _showPollPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: PollPicker(
          clubId: clubId,
          onExistingPollSelected: (poll) {
            // Handle existing poll selection
            _handlePollSelected(context, poll);
          },
          onCreateNewPoll: () {
            // Navigate to create poll screen
            _navigateToCreatePoll(context);
          },
        ),
      ),
    );
  }

  void _handlePollSelected(BuildContext context, Poll poll) {
    // Example: Send poll message to chat
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Selected poll: ${poll.question}'),
        backgroundColor: Colors.green,
      ),
    );

    // In real implementation, this would:
    // 1. Create a poll message
    // 2. Send it to the chat
    // 3. Update the UI
  }

  void _navigateToCreatePoll(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CreatePollScreen(
          clubId: clubId,
          onPollCreated: (poll) {
            // Handle new poll creation
            _handlePollSelected(context, poll);
          },
        ),
      ),
    );
  }
}

/// Integration example for message input widget
/// This shows how to integrate PollPicker into the existing message system
class MessageInputPollIntegration {
  static void showPollPicker({
    required BuildContext context,
    required String clubId,
    required Function(Poll) onPollSelected,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: PollPicker(
          clubId: clubId,
          title: 'Send Poll to Chat',
          onExistingPollSelected: (poll) {
            Navigator.of(context).pop();
            onPollSelected(poll);
          },
          onCreateNewPoll: () {
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => CreatePollScreen(
                  clubId: clubId,
                  onPollCreated: onPollSelected,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Example showing how to add poll option to attachment menu
/// This would be integrated into the existing message input widget
class AttachmentMenuPollOption extends StatelessWidget {
  final String clubId;
  final Function(Poll) onPollSelected;

  const AttachmentMenuPollOption({
    super.key,
    required this.clubId,
    required this.onPollSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.poll,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      title: const Text('Poll'),
      subtitle: const Text('Create or share a poll'),
      onTap: () {
        MessageInputPollIntegration.showPollPicker(
          context: context,
          clubId: clubId,
          onPollSelected: onPollSelected,
        );
      },
    );
  }
}