local utils = import 'mixin-utils/utils.libsonnet';

(import 'dashboard-utils.libsonnet') {

  'cortex-queries.json':
    ($.dashboard('Cortex / Queries') + { uid: 'd9931b1054053c8b972d320774bb8f1d' })
    .addClusterSelectorTemplates()
    .addRow(
      $.row('Query Frontend')
      .addPanel(
        $.panel('Queue Duration') +
        $.latencyPanel('cortex_query_frontend_queue_duration_seconds', '{%s}' % $.jobMatcher($._config.job_names.query_frontend)),
      )
      .addPanel(
        $.panel('Retries') +
        $.latencyPanel('cortex_query_frontend_retries', '{%s}' % $.jobMatcher($._config.job_names.query_frontend), multiplier=1) +
        { yaxes: $.yaxes('short') },
      )
      .addPanel(
        $.panel('Queue Length') +
        $.queryPanel('cortex_query_frontend_queue_length{%s}' % $.jobMatcher($._config.job_names.query_frontend), '{{cluster}} / {{namespace}} / {{%s}}' % $._config.per_instance_label),
      )
    )
    .addRow(
      $.row('Query Scheduler')
      .addPanel(
        $.panel('Queue Duration') +
        $.latencyPanel('cortex_query_scheduler_queue_duration_seconds', '{%s}' % $.jobMatcher($._config.job_names.query_scheduler)),
      )
      .addPanel(
        $.panel('Queue Length') +
        $.queryPanel('cortex_query_scheduler_queue_length{%s}' % $.jobMatcher($._config.job_names.query_scheduler), '{{cluster}} / {{namespace}} / {{%s}}' % $._config.per_instance_label),
      )
    )
    .addRow(
      $.row('Query Frontend - Query Splitting and Results Cache')
      .addPanel(
        $.panel('Intervals per Query') +
        $.queryPanel('sum(rate(cortex_frontend_split_queries_total{%s}[1m])) / sum(rate(cortex_frontend_query_range_duration_seconds_count{%s, method="split_by_interval"}[1m]))' % [$.jobMatcher($._config.job_names.query_frontend), $.jobMatcher($._config.job_names.query_frontend)], 'splitting rate') +
        $.panelDescription(
          'Intervals per Query',
          |||
            The average number of splitted queries (partitioned by time) executed a single input query.
          |||
        ),
      )
      .addPanel(
        $.panel('Results Cache Hit %') +
        $.queryPanel(|||
          sum(rate(cortex_cache_hits{name=~"frontend.+", %(q)s}[1m])) / sum(rate(cortex_cache_fetched_keys{name=~"frontend.+", %(q)s}[1m])) or
          sum(rate(cortex_cache_hits_total{name=~"frontend.+", %(q)s}[1m])) / sum(rate(cortex_cache_fetched_keys_total{name=~"frontend.+", %(q)s}[1m]))
        ||| % { q: $.jobMatcher($._config.job_names.query_frontend) }, 'Hit Rate') +
        { yaxes: $.yaxes({ format: 'percentunit', max: 1 }) },
      )
      .addPanel(
        $.panel('Results Cache misses') +
        $.queryPanel(|||
          sum(rate(cortex_cache_fetched_keys{name=~"frontend.+", %(q)s}[1m])) - sum(rate(cortex_cache_hits{name=~"frontend.+", %(q)s}[1m])) or
          sum(rate(cortex_cache_fetched_keys_total{name=~"frontend.+", %(q)s}[1m])) - sum(rate(cortex_cache_hits_total{name=~"frontend.+", %(q)s}[1m]))
        ||| % { q: $.jobMatcher($._config.job_names.query_frontend) }, 'Miss Rate'),
      )
    )
    .addRow(
      $.row('Query Frontend - Query sharding')
      .addPanel(
        $.panel('Sharded Queries Ratio') +
        $.queryPanel(|||
          sum(rate(cortex_frontend_query_sharding_rewrites_succeeded_total{%s}[$__rate_interval])) /
          sum(rate(cortex_frontend_query_sharding_rewrites_attempted_total{%s}[$__rate_interval]))
        ||| % [$.jobMatcher($._config.job_names.query_frontend), $.jobMatcher($._config.job_names.query_frontend)], 'sharded queries ratio') +
        { yaxes: $.yaxes({ format: 'percentunit', max: 1 }) } +
        $.panelDescription(
          'Sharded Queries Ratio',
          |||
            The % of queries that have been successfully rewritten and executed in a shardable way.
            This panel takes in account only type of queries which are supported by query sharding (eg. range queries).
          |||
        ),
      )
      .addPanel(
        $.panel('Number of Sharded Queries per Query') +
        $.latencyPanel('cortex_frontend_sharded_queries_per_query', '{%s}' % $.jobMatcher($._config.job_names.query_frontend), multiplier=1) +
        { yaxes: $.yaxes('short') } +
        $.panelDescription(
          'Number of Sharded Queries per Query',
          |||
            How many sharded queries have been executed for a single input query. It tracks only queries which have
            been successfully rewritten in a shardable way.
          |||
        ),
      )
    )
    .addRow(
      $.row('Querier')
      .addPanel(
        $.panel('Stages') +
        $.queryPanel('max by (slice) (prometheus_engine_query_duration_seconds{quantile="0.9",%s}) * 1e3' % $.jobMatcher($._config.job_names.querier), '{{slice}}') +
        { yaxes: $.yaxes('ms') } +
        $.stack,
      )
      .addPanel(
        $.panel('Chunk cache misses') +
        $.queryPanel(|||
          sum(rate(cortex_cache_fetched_keys{%(q)s,name="chunksmemcache"}[1m])) - sum(rate(cortex_cache_hits{%(q)s,name="chunksmemcache"}[1m])) or
          sum(rate(cortex_cache_fetched_keys_total{%(q)s,name="chunksmemcache"}[1m])) - sum(rate(cortex_cache_hits_total{%(q)s,name="chunksmemcache"}[1m]))
        ||| % { q: $.jobMatcher($._config.job_names.query_frontend) }, 'Hit rate'),
      )
      .addPanel(
        $.panel('Chunk cache corruptions') +
        $.queryPanel('sum(rate(cortex_cache_corrupt_chunks_total{%s}[1m]))' % $.jobMatcher($._config.job_names.querier), 'Corrupt chunks'),
      )
    )
    .addRowIf(
      std.member($._config.storage_engine, 'chunks'),
      $.row('Querier - Chunks storage - Index Cache')
      .addPanel(
        $.panel('Total entries') +
        $.queryPanel('sum(querier_cache_added_new_total{cache="store.index-cache-read.fifocache",%s}) - sum(querier_cache_evicted_total{cache="store.index-cache-read.fifocache",%s})' % [$.jobMatcher($._config.job_names.querier), $.jobMatcher($._config.job_names.querier)], 'Entries'),
      )
      .addPanel(
        $.panel('Cache Hit %') +
        $.queryPanel('(sum(rate(querier_cache_gets_total{cache="store.index-cache-read.fifocache",%s}[1m])) - sum(rate(querier_cache_misses_total{cache="store.index-cache-read.fifocache",%s}[1m]))) / sum(rate(querier_cache_gets_total{cache="store.index-cache-read.fifocache",%s}[1m]))' % [$.jobMatcher($._config.job_names.querier), $.jobMatcher($._config.job_names.querier), $.jobMatcher($._config.job_names.querier)], 'hit rate')
        { yaxes: $.yaxes({ format: 'percentunit', max: 1 }) },
      )
      .addPanel(
        $.panel('Churn Rate') +
        $.queryPanel('sum(rate(querier_cache_evicted_total{cache="store.index-cache-read.fifocache",%s}[1m]))' % $.jobMatcher($._config.job_names.querier), 'churn rate'),
      )
    )
    .addRow(
      $.row('Ingester')
      .addPanel(
        $.panel('Series per Query') +
        utils.latencyRecordingRulePanel('cortex_ingester_queried_series', $.jobSelector($._config.job_names.ingester), multiplier=1) +
        { yaxes: $.yaxes('short') },
      )
      .addPanel(
        $.panel('Chunks per Query') +
        utils.latencyRecordingRulePanel('cortex_ingester_queried_chunks', $.jobSelector($._config.job_names.ingester), multiplier=1) +
        { yaxes: $.yaxes('short') },
      )
      .addPanel(
        $.panel('Samples per Query') +
        utils.latencyRecordingRulePanel('cortex_ingester_queried_samples', $.jobSelector($._config.job_names.ingester), multiplier=1) +
        { yaxes: $.yaxes('short') },
      )
    )
    .addRowIf(
      std.member($._config.storage_engine, 'chunks'),
      $.row('Querier - Chunks storage - Store')
      .addPanel(
        $.panel('Index Lookups per Query') +
        utils.latencyRecordingRulePanel('cortex_chunk_store_index_lookups_per_query', $.jobSelector($._config.job_names.querier), multiplier=1) +
        { yaxes: $.yaxes('short') },
      )
      .addPanel(
        $.panel('Series (pre-intersection) per Query') +
        utils.latencyRecordingRulePanel('cortex_chunk_store_series_pre_intersection_per_query', $.jobSelector($._config.job_names.querier), multiplier=1) +
        { yaxes: $.yaxes('short') },
      )
      .addPanel(
        $.panel('Series (post-intersection) per Query') +
        utils.latencyRecordingRulePanel('cortex_chunk_store_series_post_intersection_per_query', $.jobSelector($._config.job_names.querier), multiplier=1) +
        { yaxes: $.yaxes('short') },
      )
      .addPanel(
        $.panel('Chunks per Query') +
        utils.latencyRecordingRulePanel('cortex_chunk_store_chunks_per_query', $.jobSelector($._config.job_names.querier), multiplier=1) +
        { yaxes: $.yaxes('short') },
      )
    )
    .addRowIf(
      std.member($._config.storage_engine, 'blocks'),
      $.row('Querier - Blocks storage')
      .addPanel(
        $.panel('Number of store-gateways hit per Query') +
        $.latencyPanel('cortex_querier_storegateway_instances_hit_per_query', '{%s}' % $.jobMatcher($._config.job_names.querier), multiplier=1) +
        { yaxes: $.yaxes('short') },
      )
      .addPanel(
        $.panel('Refetches of missing blocks per Query') +
        $.latencyPanel('cortex_querier_storegateway_refetches_per_query', '{%s}' % $.jobMatcher($._config.job_names.querier), multiplier=1) +
        { yaxes: $.yaxes('short') },
      )
      .addPanel(
        $.panel('Consistency checks failed') +
        $.queryPanel('sum(rate(cortex_querier_blocks_consistency_checks_failed_total{%s}[1m])) / sum(rate(cortex_querier_blocks_consistency_checks_total{%s}[1m]))' % [$.jobMatcher($._config.job_names.querier), $.jobMatcher($._config.job_names.querier)], 'Failure Rate') +
        { yaxes: $.yaxes({ format: 'percentunit', max: 1 }) },
      )
    )
    .addRowIf(
      std.member($._config.storage_engine, 'blocks'),
      $.row('')
      .addPanel(
        $.panel('Bucket indexes loaded (per querier)') +
        $.queryPanel([
          'max(cortex_bucket_index_loaded{%s})' % $.jobMatcher($._config.job_names.querier),
          'min(cortex_bucket_index_loaded{%s})' % $.jobMatcher($._config.job_names.querier),
          'avg(cortex_bucket_index_loaded{%s})' % $.jobMatcher($._config.job_names.querier),
        ], ['Max', 'Min', 'Average']) +
        { yaxes: $.yaxes('short') },
      )
      .addPanel(
        $.successFailurePanel(
          'Bucket indexes load / sec',
          'sum(rate(cortex_bucket_index_loads_total{%s}[$__rate_interval])) - sum(rate(cortex_bucket_index_load_failures_total{%s}[$__rate_interval]))' % [$.jobMatcher($._config.job_names.querier), $.jobMatcher($._config.job_names.querier)],
          'sum(rate(cortex_bucket_index_load_failures_total{%s}[$__rate_interval]))' % $.jobMatcher($._config.job_names.querier),
        )
      )
      .addPanel(
        $.panel('Bucket indexes load latency') +
        $.latencyPanel('cortex_bucket_index_load_duration_seconds', '{%s}' % $.jobMatcher($._config.job_names.querier)),
      )
    )
    .addRowIf(
      std.member($._config.storage_engine, 'blocks'),
      $.row('Store-gateway - Blocks storage')
      .addPanel(
        $.panel('Blocks queried / sec') +
        $.queryPanel('sum(rate(cortex_bucket_store_series_blocks_queried_sum{component="store-gateway",%s}[$__rate_interval]))' % $.jobMatcher($._config.job_names.store_gateway), 'blocks') +
        { yaxes: $.yaxes('ops') },
      )
      .addPanel(
        $.panel('Data fetched / sec') +
        $.queryPanel('sum by(data_type) (rate(cortex_bucket_store_series_data_fetched_sum{component="store-gateway",%s}[$__rate_interval]))' % $.jobMatcher($._config.job_names.store_gateway), '{{data_type}}') +
        $.stack +
        { yaxes: $.yaxes('ops') },
      )
      .addPanel(
        $.panel('Data touched / sec') +
        $.queryPanel('sum by(data_type) (rate(cortex_bucket_store_series_data_touched_sum{component="store-gateway",%s}[$__rate_interval]))' % $.jobMatcher($._config.job_names.store_gateway), '{{data_type}}') +
        $.stack +
        { yaxes: $.yaxes('ops') },
      )
    )
    .addRowIf(
      std.member($._config.storage_engine, 'blocks'),
      $.row('')
      .addPanel(
        $.panel('Series fetch duration (per request)') +
        $.latencyPanel('cortex_bucket_store_series_get_all_duration_seconds', '{component="store-gateway",%s}' % $.jobMatcher($._config.job_names.store_gateway)),
      )
      .addPanel(
        $.panel('Series merge duration (per request)') +
        $.latencyPanel('cortex_bucket_store_series_merge_duration_seconds', '{component="store-gateway",%s}' % $.jobMatcher($._config.job_names.store_gateway)),
      )
      .addPanel(
        $.panel('Series returned (per request)') +
        $.queryPanel('sum(rate(cortex_bucket_store_series_result_series_sum{component="store-gateway",%s}[$__rate_interval])) / sum(rate(cortex_bucket_store_series_result_series_count{component="store-gateway",%s}[$__rate_interval]))' % [$.jobMatcher($._config.job_names.store_gateway), $.jobMatcher($._config.job_names.store_gateway)], 'avg series returned'),
      )
    )
    .addRowIf(
      std.member($._config.storage_engine, 'blocks'),
      $.row('')
      .addPanel(
        $.panel('Blocks currently loaded') +
        $.queryPanel('sum(cortex_bucket_store_blocks_loaded{component="store-gateway",%s}) without (user)' % $.jobMatcher($._config.job_names.store_gateway), '{{%s}}' % $._config.per_instance_label)
      )
      .addPanel(
        $.successFailurePanel(
          'Blocks loaded / sec',
          'sum(rate(cortex_bucket_store_block_loads_total{component="store-gateway",%s}[$__rate_interval])) - sum(rate(cortex_bucket_store_block_load_failures_total{component="store-gateway",%s}[$__rate_interval]))' % [$.jobMatcher($._config.job_names.store_gateway), $.jobMatcher($._config.job_names.store_gateway)],
          'sum(rate(cortex_bucket_store_block_load_failures_total{component="store-gateway",%s}[$__rate_interval]))' % $.jobMatcher($._config.job_names.store_gateway),
        )
      )
      .addPanel(
        $.successFailurePanel(
          'Blocks dropped / sec',
          'sum(rate(cortex_bucket_store_block_drops_total{component="store-gateway",%s}[$__rate_interval])) - sum(rate(cortex_bucket_store_block_drop_failures_total{component="store-gateway",%s}[$__rate_interval]))' % [$.jobMatcher($._config.job_names.store_gateway), $.jobMatcher($._config.job_names.store_gateway)],
          'sum(rate(cortex_bucket_store_block_drop_failures_total{component="store-gateway",%s}[$__rate_interval]))' % $.jobMatcher($._config.job_names.store_gateway),
        )
      )
    )
    .addRowIf(
      std.member($._config.storage_engine, 'blocks'),
      $.row('')
      .addPanel(
        $.panel('Lazy loaded index-headers') +
        $.queryPanel('cortex_bucket_store_indexheader_lazy_load_total{%s} - cortex_bucket_store_indexheader_lazy_unload_total{%s}' % [$.jobMatcher($._config.job_names.store_gateway), $.jobMatcher($._config.job_names.store_gateway)], '{{%s}}' % $._config.per_instance_label)
      )
      .addPanel(
        $.panel('Index-header lazy load duration') +
        $.latencyPanel('cortex_bucket_store_indexheader_lazy_load_duration_seconds', '{%s}' % $.jobMatcher($._config.job_names.store_gateway)),
      )
      .addPanel(
        $.panel('Series hash cache hit ratio') +
        $.queryPanel(|||
          sum(rate(cortex_bucket_store_series_hash_cache_hits_total{%s}[$__rate_interval]))
          /
          sum(rate(cortex_bucket_store_series_hash_cache_requests_total{%s}[$__rate_interval]))
        ||| % [$.jobMatcher($._config.job_names.store_gateway), $.jobMatcher($._config.job_names.store_gateway)], 'hit ratio') +
        { yaxes: $.yaxes({ format: 'percentunit', max: 1 }) },
      )
    ),
}
