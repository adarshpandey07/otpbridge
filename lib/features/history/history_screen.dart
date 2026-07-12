import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:otpbridge/app/providers.dart';
import 'package:otpbridge/core/theme/app_colors.dart';
import 'package:otpbridge/core/theme/app_spacing.dart';
import 'package:otpbridge/core/widgets/widgets.dart';
import 'package:otpbridge/domain/models/models.dart';
import 'package:otpbridge/features/dashboard/widgets/activity_row.dart';
import 'package:otpbridge/features/history/widgets/history_detail_sheet.dart';
import 'package:otpbridge/features/shared/relative_time.dart';

/// Searchable, filterable timeline of everything the pipeline has handled.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

enum _OutcomeFilter {
  all('All', null),
  forwarded('Forwarded', {OtpOutcome.forwarded, OtpOutcome.approved}),
  blocked('Blocked', {OtpOutcome.blocked, OtpOutcome.rejected}),
  pending('Pending', {OtpOutcome.pendingApproval, OtpOutcome.queued}),
  failed('Failed', {OtpOutcome.failed, OtpOutcome.expired});

  const _OutcomeFilter(this.label, this.outcomes);

  final String label;
  final Set<OtpOutcome>? outcomes;
}

sealed class _HistoryItem {
  const _HistoryItem();
}

class _DayHeader extends _HistoryItem {
  const _DayHeader(this.label);
  final String label;
}

class _EntryItem extends _HistoryItem {
  const _EntryItem(this.entry);
  final HistoryEntry entry;
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  _OutcomeFilter _filter = _OutcomeFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesQuery(HistoryEntry entry, String q) {
    final c = entry.classification;
    final haystack = [
      c.brand,
      c.category.label,
      c.otp,
      c.merchant,
      c.sms.sender,
      entry.ruleName,
      ...entry.recipientNames,
    ];
    return haystack
        .any((s) => s != null && s.toLowerCase().contains(q));
  }

  List<HistoryEntry> _filtered(List<HistoryEntry> all) {
    final q = _query.trim().toLowerCase();
    var list = [...all]..sort((a, b) => b.at.compareTo(a.at));
    final outcomes = _filter.outcomes;
    if (outcomes != null) {
      list = list.where((e) => outcomes.contains(e.outcome)).toList();
    }
    if (q.isNotEmpty) {
      list = list.where((e) => _matchesQuery(e, q)).toList();
    }
    return list;
  }

  List<_HistoryItem> _grouped(List<HistoryEntry> entries) {
    final items = <_HistoryItem>[];
    DateTime? currentDay;
    for (final entry in entries) {
      final day = DateTime(entry.at.year, entry.at.month, entry.at.day);
      if (day != currentDay) {
        currentDay = day;
        items.add(_DayHeader(dayLabel(day)));
      }
      items.add(_EntryItem(entry));
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(historyProvider);

    return Scaffold(
      body: SafeArea(
        child: historyAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => EmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Something went wrong',
            message: 'History could not be loaded.\n$error',
          ),
          data: (entries) {
            if (entries.isEmpty) {
              return const EmptyState(
                icon: Icons.history_rounded,
                title: 'No history yet',
                message:
                    'Once OTPBridge starts screening messages, every '
                    'decision will show up here.',
              );
            }
            final filtered = _filtered(entries);
            final items = _grouped(filtered);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH,
                    AppSpacing.lg,
                    AppSpacing.screenH,
                    AppSpacing.md,
                  ),
                  child: Text(
                    'History',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenH,
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _query = value),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search brand, code, recipient…',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              tooltip: 'Clear search',
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenH,
                    ),
                    scrollDirection: Axis.horizontal,
                    itemCount: _OutcomeFilter.values.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: AppSpacing.xs),
                    itemBuilder: (context, index) {
                      final filter = _OutcomeFilter.values[index];
                      return ChoiceChip(
                        label: Text(filter.label),
                        selected: _filter == filter,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _filter = filter),
                      );
                    },
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? const EmptyState(
                          icon: Icons.search_off_rounded,
                          title: 'No matches',
                          message:
                              'Try a different search or clear the filters.',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.screenH,
                            AppSpacing.xs,
                            AppSpacing.screenH,
                            AppSpacing.xl,
                          ),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return switch (item) {
                              _DayHeader(:final label) => Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    AppSpacing.xxs,
                                    AppSpacing.md,
                                    AppSpacing.xxs,
                                    AppSpacing.xs,
                                  ),
                                  child: Text(
                                    label.toUpperCase(),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: context.tokens.textTertiary,
                                          letterSpacing: 0.8,
                                        ),
                                  ),
                                ),
                              _EntryItem(:final entry) => Padding(
                                  key: ValueKey(entry.id),
                                  padding: const EdgeInsets.only(
                                    bottom: AppSpacing.xs,
                                  ),
                                  child: GlassCard(
                                    padding:
                                        const EdgeInsets.all(AppSpacing.xxs),
                                    child: ActivityRow(
                                      entry: entry,
                                      onTap: () =>
                                          showHistoryDetail(context, entry),
                                    ),
                                  ),
                                ),
                            };
                          },
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
