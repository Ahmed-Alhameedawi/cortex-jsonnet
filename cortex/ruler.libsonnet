{
  local container = $.core.v1.container,

  ruler_args::
    $._config.grpcConfig +
    $._config.ringConfig +
    $._config.blocksStorageConfig +
    $._config.queryConfig +
    $._config.queryEngineConfig +
    $._config.distributorConfig +
    $._config.rulerClientConfig +
    $._config.rulerLimitsConfig +
    $._config.queryBlocksStorageConfig +
    $.blocks_metadata_caching_config +
    $.bucket_index_config +
    {
      target: 'ruler',
      // Alertmanager configs
      'ruler.alertmanager-url': 'http://alertmanager.%s.svc.cluster.local/alertmanager' % $._config.namespace,
      'experimental.ruler.enable-api': true,
      'api.response-compression-enabled': true,

      // Ring Configs
      'ruler.enable-sharding': true,
      'ruler.ring.consul.hostname': 'consul.%s.svc.cluster.local:8500' % $._config.namespace,

      // Limits
      'server.grpc-max-send-msg-size-bytes': 10 * 1024 * 1024,
      'server.grpc-max-recv-msg-size-bytes': 10 * 1024 * 1024,

      // Do not extend the replication set on unhealthy (or LEAVING) ingester when "unregister on shutdown"
      // is set to false.
      'distributor.extend-writes': $._config.unregister_ingesters_on_shutdown,
    },

  ruler_container::
    if $._config.ruler_enabled then
      container.new('ruler', $._images.ruler) +
      container.withPorts($.util.defaultPorts) +
      container.withArgsMixin($.util.mapToFlags($.ruler_args)) +
      $.util.resourcesRequests('1', '6Gi') +
      $.util.resourcesLimits('16', '16Gi') +
      $.util.readinessProbe +
      $.jaeger_mixin
    else {},

  local deployment = $.apps.v1.deployment,

  ruler_deployment:
    if $._config.ruler_enabled then
      deployment.new('ruler', 2, [$.ruler_container]) +
      deployment.mixin.spec.strategy.rollingUpdate.withMaxSurge(0) +
      deployment.mixin.spec.strategy.rollingUpdate.withMaxUnavailable(1) +
      deployment.mixin.spec.template.spec.withTerminationGracePeriodSeconds(600) +
      (if $._config.cortex_ruler_allow_multiple_replicas_on_same_node then {} else $.util.antiAffinity) +
      $.util.configVolumeMount($._config.overrides_configmap, '/etc/cortex')
    else {},

  local service = $.core.v1.service,

  ruler_service:
    if $._config.ruler_enabled then
      $.util.serviceFor($.ruler_deployment)
    else {},
}
