import 'package:app/commonWidgets/raise_it_ticket_card.dart';
import 'package:app/screens/raise_ticket/create_raise_it_ticket.dart';
import 'package:app/constants/app_colors.dart';
import 'package:app/constants/app_images.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/constants/constants_strings.dart';
import 'package:app/models/raise_it_ticket_model.dart';
import 'package:app/models/screen_permission.dart';
import 'package:app/commonWidgets/safe_svg_picture.dart';
import 'package:app/services/service_locator.dart';
import 'package:app/utils/toastbar.dart';
import 'package:flutter/material.dart';

class RaiseTicketsScreen extends StatefulWidget {
  final ScreenPermission? permission;

  const RaiseTicketsScreen({super.key, this.permission});

  @override
  State<RaiseTicketsScreen> createState() => _RaiseTicketsScreenState();
}

class _RaiseTicketsScreenState extends State<RaiseTicketsScreen> {
  List<RaiseItTicket> _tickets = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets({bool showFullScreenLoader = true}) async {
    if (showFullScreenLoader) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final tickets =
          await ServiceLocator().raiseItTicketRepository.getAllRaiseTickets();
      if (!mounted) return;
      setState(() {
        _tickets = tickets;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = _formatError(e);
      });
    }
  }

  String _formatError(Object error) {
    final message = error.toString();
    if (message.startsWith('Exception: ')) {
      return message.substring('Exception: '.length);
    }
    return message;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      floatingActionButton: _buildFab(),
      body: Stack(
        children: [
          Positioned.fill(
            child: SafeSvgPicture.asset(
              AppImages.home,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          SafeArea(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primaryGreen,
        ),
      );
    }

    if (_errorMessage != null) {
      return _buildMessage(_errorMessage!, showRetry: true);
    }

    if (_tickets.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _loadTickets(showFullScreenLoader: false),
        color: AppColors.primaryGreen,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.35),
            _buildMessage('No tickets found'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadTickets(showFullScreenLoader: false),
      color: AppColors.primaryGreen,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 8, bottom: 88),
        itemCount: _tickets.length,
        itemBuilder: (context, index) {
          final ticket = _tickets[index];
          return RaiseItTicketCard(
            ticket: ticket,
            onTap: () {
              Toastbar.showInfoToastbar(
                'Ticket details coming soon',
                context,
              );
            },
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      shadowColor: Colors.transparent,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 10, top: 12, right: 16),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_sharp,
                  color: AppColors.white,
                  size: 25,
                ),
                onPressed: () => Navigator.of(context).pop(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Raise IT Ticket',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    fontFamily: poppins,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _buildFab() {
    if (!(widget.permission?.canAdd ?? true)) {
      return null;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 4),
      child: Material(
        color: AppColors.primaryGreen,
        borderRadius: BorderRadius.circular(12),
        elevation: 4,
        child: InkWell(
          onTap: () async {
            final created = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (context) => const CreateRaiseItTicketScreen(),
              ),
            );
            if (created == true && mounted) {
              _loadTickets();
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: const SizedBox(
            width: 56,
            height: 56,
            child: Icon(Icons.add, color: Colors.white, size: 32),
          ),
        ),
      ),
    );
  }

  Widget _buildMessage(String message, {bool showRetry = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (showRetry) ...[
              getHeight(16),
              TextButton(
                onPressed: () => _loadTickets(),
                child: const Text(
                  'Retry',
                  style: TextStyle(color: AppColors.white),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
