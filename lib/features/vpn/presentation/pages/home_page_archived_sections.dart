/*
  Archived UI sections from HomePage (hidden per request).
  Date: 2026-04-19

  1) Xray Runtime Preview block

  if (state.runtimeConfigPreview != null) ...[
    const SizedBox(height: 16),
    Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Xray Runtime Preview',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            SelectableText(
              state.runtimeConfigPreview!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    ),
  ],

  2) Live Logs card block (filters, log file actions, log list)

  const SizedBox(height: 16),
  Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Live Logs',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton(
                onPressed: state.logs.isEmpty ? null : controller.clearLogs,
                child: const Text('Clear Logs'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: VpnLogFilter.values
                .map(
                  (filter) => ChoiceChip(
                    label: Text(_labelForFilter(filter)),
                    selected: state.logFilter == filter,
                    onSelected: (_) => controller.setLogFilter(filter),
                  ),
                )
                .toList(),
          ),
          if (state.logFilePath != null) ...[
            const SizedBox(height: 12),
            // Open / Share / Copy Path actions...
          ],
          const SizedBox(height: 12),
          if (state.visibleLogs.isEmpty)
            const Text('No logs for the current filter yet.')
          else
            ...state.visibleLogs.map(
              (log) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          log.title,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _SeverityBadge(severity: log.severity),
                            const SizedBox(width: 8),
                            Text(
                              _formatTimestamp(log.timestamp),
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          log.message,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  ),

  3) Removed helpers:
     - _labelForFilter(VpnLogFilter filter)
     - _SeverityBadge widget
*/
