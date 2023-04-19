module "aws_vpc" {
  source           = "../../modules/virtual-network"
  pjname           = var.pjname
  envname          = var.envname
  vpc_name         = var.vpc_name
  vpc_cidr         = var.vpc_cidr
  database_subnets = var.database_subnets
  private_subnets  = var.private_subnets
  public_subnets   = var.public_subnets
  aws_s3_bucket_bucket_arn = module.aws_logging.aws_s3_bucket_bucket_arn
}

module "aws_alb" {
  source                             = "../../modules/ingress"
  depends_on                         = [ module.aws_rds ]
  pjname                             = var.pjname
  envname                            = var.envname
  alb_ingress_domain_name            = var.alb_ingress_domain_name
  alb_ingress_argocd_subdomain_name  = var.alb_ingress_argocd_subdomain_name
  alb_ingress_chatops_subdomain_name = var.alb_ingress_chatops_subdomain_name
  alb_ingress_allow_ips              = var.alb_ingress_allow_ips
  alb_ingress_argocd_allow_ips       = var.alb_ingress_argocd_allow_ips
  alb_ingress_chatops_allow_ips      = var.alb_ingress_chatops_allow_ips
  vpc_id                             = module.aws_vpc.vpc_id
  public_subnets                     = module.aws_vpc.public_subnets
  nat_public_ips                     = module.aws_vpc.nat_public_ips
  eks_worker_security_group_id       = module.aws_eks.worker_security_group_id
}

module "aws_eks" {
  source                        = "../../modules/k8s"
  pjname                        = var.pjname
  envname                       = var.envname
  eks_version                   = var.eks_version
  eks_node_type                 = var.eks_node_type
  generic_asg_min_size          = var.generic_asg_min_size
  generic_asg_max_size          = var.generic_asg_max_size
  generic_asg_desired_capacity  = var.generic_asg_desired_capacity
  platform_asg_min_size         = var.platform_asg_min_size
  platform_asg_max_size         = var.platform_asg_max_size
  platform_asg_desired_capacity = var.platform_asg_desired_capacity
  service_asg_min_size          = var.service_asg_min_size
  service_asg_max_size          = var.service_asg_max_size
  service_asg_desired_capacity  = var.service_asg_desired_capacity
  private_subnets               = module.aws_vpc.private_subnets
  vpc_id                        = module.aws_vpc.vpc_id
  aws_lb_tg_alb_ingress_arn     = module.aws_alb.aws_lb_tg_alb_ingress_arn
  aws_lb_tg_alb_ingress_argocd_arn   = module.aws_alb.aws_lb_tg_alb_ingress_argocd_arn
  aws_lb_tg_alb_ingress_chatops_arn  = module.aws_alb.aws_lb_tg_alb_ingress_chatops_arn
}

module "aws_cicd" {
  source            = "../../modules/cicd"
  pjname            = var.pjname
  envname           = var.envname
  oidc_provider_arn = module.aws_eks.oidc_provider_arn
}

module "aws_cluster-autoscaler" {
  source                  = "../../modules/cluster-autoscaler"
  pjname                  = var.pjname
  envname                 = var.envname
  cluster_oidc_issuer_url = module.aws_eks.cluster_oidc_issuer_url
  oidc_provider_arn       = module.aws_eks.oidc_provider_arn
}

module "aws_rds" {
  source                  = "../../modules/rdb"
  pjname                  = var.pjname
  envname                 = var.envname
  vpc_cidr                = var.vpc_cidr
  mysql_version           = var.mysql_version
  mysql_node_type         = var.mysql_node_type
  storage_size            = var.storage_size
  master_user_name        = var.master_user_name
  random_password         = module.aws_rds.random_password
  vpc_id                  = module.aws_vpc.vpc_id
  database_subnets        = module.aws_vpc.database_subnets
  alb_ingress_domain_name = var.alb_ingress_domain_name
}

module "aws_msk_cluster" {
  source                        = "../../modules/event-stream"
  pjname                        = var.pjname
  envname                       = var.envname
  private_subnets               = module.aws_vpc.private_subnets
  vpc_id                        = module.aws_vpc.vpc_id
  ingress_security_groups       = [module.aws_eks.worker_security_group_id]
  aws_s3_bucket_bucket-short_id = module.aws_logging.aws_s3_bucket_bucket-short_id
}

module "aws_security" {
  source                  = "../../modules/security"
  pjname                  = var.pjname
  envname                 = var.envname
  aws_account_id          = var.aws_account_id
  role_namespace          = var.role_namespace
  cluster_oidc_issuer_url = module.aws_eks.cluster_oidc_issuer_url
  master_user_name        = var.master_user_name
  random_password         = module.aws_rds.random_password
  datadog_api_key         = var.monitoring_dd_api_key
}

module "aws_security_monitoring" {
  source                   = "../../modules/security-monitoring"
  pjname                   = var.pjname
  envname                  = var.envname
  aws_account_id           = var.aws_account_id
  email                    = var.email
  aws_s3_bucket_bucket_id  = module.aws_logging.aws_s3_bucket_bucket_id
  aws_s3_bucket_bucket_arn = module.aws_logging.aws_s3_bucket_bucket_arn
  guardduty_flag           = var.guardduty_flag
}

module "aws_backup" {
  source      = "../../modules/backup"
  pjname      = var.pjname
  envname     = var.envname
  backup_cron = var.backup_cron
}

module "aws_waf" {
  source                     = "../../modules/waf"
  pjname                     = var.pjname
  envname                    = var.envname
  cloudwatch_metrics_enabled = var.waf_cloudwatch_metrics_enabled
  sampled_requests_enabled   = var.waf_sampled_requests_enabled
  aws_lb_ingress_arn         = module.aws_alb.aws_lb_ingress_arn
  aws_lb_ingress_argocd_arn  = module.aws_alb.aws_lb_ingress_argocd_arn
  aws_lb_ingress_chatops_arn = module.aws_alb.aws_lb_ingress_chatops_arn
}

module "aws_logging" {
  source = "../../modules/logging"
  depends_on                            = [ module.aws_rds ]
  pjname                                = var.pjname
  envname                               = var.envname
  aws_account_id                        = var.aws_account_id
  aws_wafv2_web_acl_alb_waf_web_acl_arn = module.aws_waf.aws_wafv2_web_acl_alb_waf_web_acl_arn
}

# Monitoring (Datadog)
/*
module "monitoring" {
  source = "../../modules/monitoring"
  
  pjname  = var.pjname
  envname = var.envname
  api_key = var.monitoring_dd_api_key
  app_key = var.monitoring_dd_app_key
  env     = var.monitoring_dd_env

  dashboard = [{
    json = <<EOF
{"title":"Custom Kubernetes - Overview","description":"Our Kubernetes dashboard gives you broad visibility into the scale, status, and resource usage of your cluster and its containers. Further reading for Kubernetes monitoring:\n\n- [Autoscale Kubernetes workloads with any Datadog metric](https://www.datadoghq.com/blog/autoscale-kubernetes-datadog/)\n\n- [How to monitor Kubernetes + Docker with Datadog](https://www.datadoghq.com/blog/monitor-kubernetes-docker/)\n\n- [Monitoring in the Kubernetes era](https://www.datadoghq.com/blog/monitoring-kubernetes-era/)\n\n- [Monitoring Kubernetes performance metrics](https://www.datadoghq.com/blog/monitoring-kubernetes-performance-metrics/)\n\n- [Collecting metrics with built-in Kubernetes monitorinng tools](https://www.datadoghq.com/blog/how-to-collect-and-graph-kubernetes-metrics/)\n\n- [Monitoring Kubernetes with Datadog](https://www.datadoghq.com/blog/monitoring-kubernetes-with-datadog/)\n\n- [Datadog's Kubernetes integration docs](https://docs.datadoghq.com/integrations/kubernetes/)\n\nClone this template dashboard to make changes and add your own graph widgets.","widgets":[{"id":0,"layout":{"x":151,"y":57,"width":43,"height":24},"definition":{"title":"Most memory-intensive pods","title_size":"16","title_align":"left","time":{"live_span":"4h"},"type":"toplist","requests":[{"q":"top(sum:kubernetes.memory.usage{$scope,$deployment,$daemonset,$cluster,$namespace,!pod_name:no_pod,$label,$service,$node} by {pod_name}, 10, 'mean', 'desc')","style":{"palette":"cool"}}],"custom_links":[]}},{"id":1,"layout":{"x":107,"y":57,"width":43,"height":24},"definition":{"title":"Most CPU-intensive pods","title_size":"16","title_align":"left","time":{"live_span":"4h"},"type":"toplist","requests":[{"q":"top(sum:kubernetes.cpu.usage.total{$scope,$deployment,$daemonset,$cluster,$namespace,!pod_name:no_pod,$label,$service,$node} by {pod_name}, 10, 'mean', 'desc')","style":{"palette":"warm"}}],"custom_links":[]}},{"id":2,"layout":{"x":0,"y":0,"width":23,"height":15},"definition":{"type":"image","url":"/static/images/screenboard/integrations/kubernetes.jpg","sizing":"zoom"}},{"id":3,"layout":{"x":80,"y":0,"width":13,"height":7},"definition":{"title":"Kubelets up","title_size":"16","title_align":"center","time":{"live_span":"10m"},"type":"check_status","check":"kubernetes.kubelet.check","grouping":"cluster","group_by":[],"tags":["$scope","$node","$label"]}},{"id":4,"layout":{"x":50,"y":91,"width":16,"height":14},"definition":{"title":"Pods Available","title_size":"16","title_align":"left","time":{"live_span":"5m"},"type":"query_value","requests":[{"q":"sum:kubernetes_state.deployment.replicas_available{$scope,$deployment,$daemonset,$cluster,$label,$namespace,$service,$node}","aggregator":"avg","conditional_formats":[{"comparator":">","palette":"green_on_white","value":0}]}],"autoscale":true,"custom_links":[],"precision":0}},{"id":5,"layout":{"x":67,"y":91,"width":37,"height":14},"definition":{"title":"Pods available","title_size":"16","title_align":"left","show_legend":false,"legend_size":"0","time":{"live_span":"4h"},"type":"timeseries","requests":[{"q":"sum:kubernetes_state.deployment.replicas_available{$scope,$deployment,$daemonset,$service,$label,$cluster,$namespace,$node} by {deployment}","style":{"palette":"green","line_type":"solid","line_width":"normal"},"display_type":"area"}],"custom_links":[]}},{"id":6,"layout":{"x":50,"y":76,"width":16,"height":14},"definition":{"title":"Pods desired","title_size":"16","title_align":"left","time":{"live_span":"5m"},"type":"query_value","requests":[{"q":"sum:kubernetes_state.deployment.replicas_desired{$scope,$deployment,$daemonset,$cluster,$label,$namespace,$service,$node}","aggregator":"avg","conditional_formats":[{"custom_fg_color":"#6a53a1","comparator":">","palette":"custom_text","value":0}]}],"autoscale":true,"custom_links":[],"precision":0}},{"id":7,"layout":{"x":67,"y":76,"width":37,"height":14},"definition":{"title":"Pods desired","title_size":"16","title_align":"left","show_legend":false,"legend_size":"0","time":{"live_span":"4h"},"type":"timeseries","requests":[{"q":"sum:kubernetes_state.deployment.replicas_desired{$scope,$deployment,$daemonset,$cluster,$label,$namespace,$service,$node} by {deployment}","style":{"palette":"purple","line_type":"solid","line_width":"normal"},"display_type":"area"}],"custom_links":[]}},{"id":8,"layout":{"x":50,"y":106,"width":16,"height":14},"definition":{"title":"Pods unavailable","title_size":"16","title_align":"left","time":{"live_span":"5m"},"type":"query_value","requests":[{"q":"sum:kubernetes_state.deployment.replicas_unavailable{$scope,$deployment,$daemonset,$cluster,$label,$namespace,$service,$node}","aggregator":"avg","conditional_formats":[{"comparator":">","palette":"yellow_on_white","value":0},{"comparator":"<=","palette":"green_on_white","value":0}]}],"autoscale":true,"custom_links":[],"precision":0}},{"id":9,"layout":{"x":67,"y":106,"width":37,"height":14},"definition":{"title":"Pods unavailable","title_size":"16","title_align":"left","show_legend":false,"legend_size":"0","time":{"live_span":"4h"},"type":"timeseries","requests":[{"q":"sum:kubernetes_state.deployment.replicas_unavailable{$scope,$deployment,$daemonset,$service,$label,$cluster,$namespace,$node} by {deployment}","style":{"palette":"orange","line_type":"solid","line_width":"normal"},"display_type":"area"}],"custom_links":[]}},{"id":10,"layout":{"x":37,"y":16,"width":67,"height":5},"definition":{"type":"note","content":"Pods","background_color":"gray","font_size":"18","text_align":"center","show_tick":false,"tick_pos":"50%","tick_edge":"bottom"}},{"id":11,"layout":{"x":107,"y":16,"width":87,"height":5},"definition":{"type":"note","content":"[Resource utilization](https://www.datadoghq.com/blog/monitoring-kubernetes-performance-metrics/#toc-resource-utilization6)","background_color":"gray","font_size":"18","text_align":"center","show_tick":false,"tick_pos":"50%","tick_edge":"bottom"}},{"id":12,"layout":{"x":0,"y":34,"width":36,"height":37},"definition":{"time":{"live_span":"1w"},"type":"event_stream","query":"sources:kubernetes $node","tags_execution":"and","event_size":"s"}},{"id":13,"layout":{"x":37,"y":38,"width":33,"height":15},"definition":{"title":"Running pods per node","title_size":"16","title_align":"left","show_legend":false,"type":"timeseries","requests":[{"q":"sum:kubernetes.pods.running{$scope,$deployment,$daemonset,$label,$cluster,$namespace,$service,$node} by {host}","style":{"palette":"dog_classic","line_type":"solid","line_width":"normal"},"display_type":"area"}],"yaxis":{"include_zero":true,"scale":"linear","label":"","min":"auto","max":"auto"},"custom_links":[]}},{"id":14,"layout":{"x":151,"y":22,"width":43,"height":18},"definition":{"title":"Memory usage per node","title_size":"16","title_align":"left","type":"hostmap","requests":{"fill":{"q":"sum:kubernetes.memory.usage{$scope,$deployment,$daemonset,$namespace,$cluster,$label,$service,$node} by {host}"}},"no_metric_hosts":false,"no_group_hosts":true,"scope":["$scope","$node","$label","$kube_deployment","$kube_namespace"],"custom_links":[],"style":{"palette":"hostmap_blues","palette_flip":false}}},{"id":15,"layout":{"x":107,"y":121,"width":43,"height":16},"definition":{"title":"Network errors per node","title_size":"16","title_align":"left","show_legend":false,"legend_size":"0","time":{"live_span":"4h"},"type":"timeseries","requests":[{"q":"sum:kubernetes.network.rx_errors{$scope,$deployment,$daemonset,$namespace,$cluster,$label,$service,$node} by {host}","style":{"palette":"warm"},"display_type":"bars"},{"q":"sum:kubernetes.network.tx_errors{$scope,$deployment,$daemonset,$namespace,$cluster,$label,$service,$node} by {host}","style":{"palette":"warm"},"display_type":"bars"},{"q":"sum:kubernetes.network_errors{$scope,$deployment,$daemonset,$namespace,$cluster,$label,$service,$node} by {host}","style":{"palette":"warm","line_type":"solid","line_width":"normal"},"display_type":"bars"}],"custom_links":[]}},{"id":16,"layout":{"x":107,"y":41,"width":43,"height":15},"definition":{"title":"Sum Kubernetes CPU requests per node","title_size":"16","title_align":"left","show_legend":false,"legend_size":"0","time":{"live_span":"4h"},"type":"timeseries","requests":[{"q":"sum:kubernetes.cpu.requests{$scope,$deployment,$daemonset,$cluster,$namespace,$label,$service,$node} by {host}","style":{"palette":"warm"},"display_type":"line"}],"custom_links":[]}},{"id":17,"layout":{"x":151,"y":41,"width":43,"height":15},"definition":{"title":"Sum Kubernetes memory requests per node","title_size":"16","title_align":"left","show_legend":false,"legend_size":"0","time":{"live_span":"4h"},"type":"timeseries","requests":[{"q":"sum:kubernetes.memory.requests{$scope,$deployment,$daemonset,$cluster,$namespace,$label,$service,$node} by {host}","style":{"palette":"cool"},"display_type":"line"}],"custom_links":[]}},{"id":18,"layout":{"x":107,"y":82,"width":87,"height":5},"definition":{"type":"note","content":"Disk I/O & Network","background_color":"gray","font_size":"18","text_align":"center","show_tick":false,"tick_pos":"50%","tick_edge":"bottom"}},{"id":19,"layout":{"x":107,"y":88,"width":43,"height":16},"definition":{"title":"Network in per node","title_size":"16","title_align":"left","show_legend":false,"legend_size":"0","time":{"live_span":"4h"},"type":"timeseries","requests":[{"q":"sum:kubernetes.network.rx_bytes{$scope,$deployment,$daemonset,$cluster,$namespace,$label,$service,$node} by {host}","style":{"palette":"purple"},"display_type":"line"}],"custom_links":[]}},{"id":20,"layout":{"x":107,"y":105,"width":43,"height":15},"definition":{"title":"Network out per node","title_size":"16","title_align":"left","show_legend":false,"legend_size":"0","time":{"live_span":"4h"},"type":"timeseries","requests":[{"q":"sum:kubernetes.network.tx_bytes{$scope,$deployment,$daemonset,$namespace,$cluster,$label,$service,$node} by {host}","style":{"palette":"green"},"display_type":"line"}],"custom_links":[]}},{"id":21,"layout":{"x":0,"y":16,"width":36,"height":5},"definition":{"type":"note","content":"[Events](https://www.datadoghq.com/blog/monitoring-kubernetes-performance-metrics/#toc-correlate-with-events10)","background_color":"gray","font_size":"18","text_align":"center","show_tick":false,"tick_pos":"50%","tick_edge":"bottom"}},{"id":22,"layout":{"x":0,"y":22,"width":36,"height":9},"definition":{"title":"Number of Kubernetes events per node","title_size":"16","title_align":"left","time":{"live_span":"1d"},"type":"event_timeline","query":"sources:kubernetes $node","tags_execution":"and"}},{"id":23,"layout":{"x":107,"y":22,"width":43,"height":18},"definition":{"title":"CPU utilization per node","title_size":"16","title_align":"left","type":"hostmap","requests":{"fill":{"q":"sum:kubernetes.cpu.usage.total{$scope,$deployment,$daemonset,$namespace,$cluster,$label,$service,$node} by {host}"}},"no_metric_hosts":false,"no_group_hosts":true,"scope":["$scope","$node","$label","$kube_deployment","$kube_namespace"],"custom_links":[],"style":{"palette":"YlOrRd","palette_flip":false}}},{"id":24,"layout":{"x":95,"y":0,"width":16,"height":15},"definition":{"type":"note","content":"Read our\n[Monitoring guide for Kubernetes](https://www.datadoghq.com/blog/monitoring-kubernetes-era/).\n \nCheck [the agent documentation](https://docs.datadoghq.com/agent/kubernetes/) if some of the graphs are empty.","background_color":"yellow","font_size":"14","text_align":"center","show_tick":false,"tick_pos":"50%","tick_edge":"left"}},{"id":25,"layout":{"x":0,"y":76,"width":16,"height":14},"definition":{"title":"Desired","title_size":"16","title_align":"left","time":{"live_span":"5m"},"type":"query_value","requests":[{"q":"sum:kubernetes_state.daemonset.desired{$scope,$deployment,$daemonset,$cluster,$label,$namespace,$service,$node}","aggregator":"last","conditional_formats":[{"custom_fg_color":"#6a53a1","comparator":">","palette":"custom_text","value":0}]}],"autoscale":true,"custom_links":[],"precision":0}},{"id":26,"layout":{"x":17,"y":76,"width":32,"height":14},"definition":{"title":"Pods desired","title_size":"16","title_align":"left","show_legend":false,"legend_size":"0","time":{"live_span":"4h"},"type":"timeseries","requests":[{"q":"sum:kubernetes_state.daemonset.desired{$scope,$deployment,$daemonset,$service,$namespace,$label,$cluster,$node} by {daemonset}","style":{"palette":"purple","line_type":"solid","line_width":"normal"},"display_type":"area"}],"custom_links":[]}},{"id":27,"layout":{"x":0,"y":91,"width":16,"height":14},"definition":{"title":"Ready","title_size":"16","title_align":"left","time":{"live_span":"5m"},"type":"query_value","requests":[{"q":"sum:kubernetes_state.daemonset.ready{$scope,$deployment,$daemonset,$cluster,$label,$namespace,$service,$node}","aggregator":"last","conditional_formats":[{"comparator":">","palette":"green_on_white","value":0},{"comparator":"<=","palette":"red_on_white","value":0}]}],"autoscale":true,"custom_links":[],"precision":0}},{"id":28,"layout":{"x":80,"y":8,"width":13,"height":7},"definition":{"title":"Kubelet Ping","title_size":"16","title_align":"center","time":{"live_span":"10m"},"type":"check_status","check":"kubernetes.kubelet.check.ping","grouping":"cluster","group_by":[],"tags":["*","$node","$label","$scope"]}},{"id":29,"layout":{"x":50,"y":127,"width":54,"height":14},"definition":{"title":"Container states","title_size":"16","title_align":"left","show_legend":false,"legend_size":"0","time":{"live_span":"4h"},"type":"timeseries","requests":[{"q":"sum:kubernetes_state.container.running{$scope,$deployment,$daemonset,$service,$namespace,$label,$cluster,$node}","style":{"palette":"dog_classic","line_type":"solid","line_width":"normal"},"display_type":"line"},{"q":"sum:kubernetes_state.container.waiting{$scope,$deployment,$daemonset,$service,$namespace,$label,$cluster,$node}","style":{"palette":"warm","line_type":"solid","line_width":"normal"},"display_type":"line"},{"q":"sum:kubernetes_state.container.terminated{$scope,$deployment,$daemonset,$service,$namespace,$label,$cluster,$node}","style":{"palette":"grey","line_type":"solid","line_width":"normal"},"display_type":"line"},{"q":"sum:kubernetes_state.container.ready{$scope,$deployment,$daemonset,$service,$namespace,$label,$cluster,$node}","style":{"palette":"grey","line_type":"solid","line_width":"normal"},"display_type":"line"}],"yaxis":{"include_zero":true,"scale":"linear","label":"","min":"auto","max":"auto"},"custom_links":[]}},{"id":30,"layout":{"x":17,"y":112,"width":32,"height":14},"definition":{"title":"Ready","title_size":"16","title_align":"left","show_legend":false,"legend_size":"0","time":{"live_span":"1h"},"type":"timeseries","requests":[{"q":"sum:kubernetes_state.replicaset.replicas_ready{$scope,$daemonset,$service,$namespace,$deployment,$label,$cluster,$node} by {replicaset}","style":{"palette":"purple","line_type":"solid","line_width":"normal"},"display_type":"area"}],"custom_links":[]}},{"id":31,"layout":{"x":17,"y":127,"width":32,"height":14},"definition":{"title":"Not ready","title_size":"16","title_align":"left","show_legend":false,"legend_size":"0","time":{"live_span":"1h"},"type":"timeseries","requests":[{"q":"sum:kubernetes_state.replicaset.replicas_desired{$scope,$daemonset,$service,$namespace,$deployment,$label,$cluster,$node} by {replicaset}-sum:kubernetes_state.replicaset.replicas_ready{$scope,$daemonset,$service,$namespace,$deployment,$label,$cluster,$node} by {replicaset}","style":{"palette":"orange","line_type":"solid","line_width":"normal"},"display_type":"area"}],"custom_links":[]}},{"id":32,"layout":{"x":151,"y":105,"width":43,"height":15},"definition":{"title":"Disk reads per node","title_size":"16","title_align":"left","show_legend":false,"legend_size":"0","time":{"live_span":"4h"},"type":"timeseries","requests":[{"q":"sum:kubernetes.io.read_bytes{$scope,$daemonset,$service,$namespace,$label,$cluster,$deployment,$node} by {replicaset,host}-avg:kubernetes_state.replicaset.replicas_ready{$scope,$daemonset,$service,$namespace,$label,$cluster,$deployment,$node} by {host}","style":{"palette":"grey","line_type":"solid","line_width":"normal"},"display_type":"line"}],"custom_links":[]}},{"id":33,"layout":{"x":151,"y":88,"width":43,"height":16},"definition":{"title":"Disk writes per node","title_size":"16","title_align":"left","show_legend":false,"legend_size":"0","time":{"live_span":"4h"},"type":"timeseries","requests":[{"q":"sum:kubernetes.io.write_bytes{$scope,$daemonset,$service,$namespace,$label,$cluster,$deployment,$node} by {replicaset,host}-avg:kubernetes_state.replicaset.replicas_ready{$scope,$daemonset,$service,$namespace,$label,$cluster,$deployment,$node} by {host}","style":{"palette":"grey","line_type":"solid","line_width":"normal"},"display_type":"line"}],"custom_links":[]}},{"id":34,"layout":{"x":0,"y":70,"width":49,"height":5},"definition":{"type":"note","content":"DaemonSets","background_color":"gray","font_size":"18","text_align":"center","show_tick":false,"tick_pos":"50%","tick_edge":"bottom"}},{"id":35,"layout":{"x":50,"y":70,"width":54,"height":5},"definition":{"type":"note","content":"Deployments","background_color":"gray","font_size":"18","text_align":"center","show_tick":false,"tick_pos":"50%","tick_edge":"bottom"}},{"id":36,"layout":{"x":0,"y":106,"width":49,"height":5},"definition":{"type":"note","content":"ReplicaSets","background_color":"gray","font_size":"18","text_align":"center","show_tick":false,"tick_pos":"50%","tick_edge":"bottom"}},{"id":37,"layout":{"x":50,"y":121,"width":54,"height":5},"definition":{"type":"note","content":"Containers","background_color":"gray","font_size":"18","text_align":"center","show_tick":false,"tick_pos":"50%","tick_edge":"bottom"}},{"id":38,"layout":{"x":0,"y":112,"width":16,"height":14},"definition":{"title":"Ready","title_size":"16","title_align":"left","time":{"live_span":"5m"},"type":"query_value","requests":[{"q":"sum:kubernetes_state.replicaset.replicas_ready{$scope,$deployment,$daemonset,$cluster,$label,$namespace,$service,$node}","aggregator":"last","conditional_formats":[{"custom_fg_color":"#6a53a1","comparator":">","palette":"custom_text","value":0}]}],"autoscale":true,"custom_links":[],"precision":0}},{"id":39,"layout":{"x":0,"y":127,"width":16,"height":14},"definition":{"title":"Not ready","title_size":"16","title_align":"left","time":{"live_span":"5m"},"type":"query_value","requests":[{"q":"sum:kubernetes_state.replicaset.replicas_desired{$scope,$daemonset,$service,$namespace,$deployment,$label,$cluster,$node}-sum:kubernetes_state.replicaset.replicas_ready{$scope,$daemonset,$service,$namespace,$deployment,$label,$cluster,$node}","aggregator":"last","conditional_formats":[{"custom_fg_color":"#6a53a1","comparator":">","palette":"yellow_on_white","value":0}]}],"autoscale":true,"custom_links":[],"precision":0}},{"id":40,"layout":{"x":17,"y":91,"width":32,"height":14},"definition":{"title":"Pods ready","title_size":"16","title_align":"left","show_legend":false,"legend_size":"0","time":{"live_span":"4h"},"type":"timeseries","requests":[{"q":"sum:kubernetes_state.daemonset.ready{$scope,$deployment,$daemonset,$service,$namespace,$label,$cluster,$node} by {daemonset}","style":{"palette":"green","line_type":"solid","line_width":"normal"},"display_type":"area"}],"custom_links":[]}},{"id":41,"layout":{"x":37,"y":22,"width":33,"height":15},"definition":{"title":"Running pods per namespace","title_size":"16","title_align":"left","show_legend":false,"legend_size":"0","type":"timeseries","requests":[{"q":"sum:kubernetes.pods.running{$scope,$cluster,$namespace,$deployment,$daemonset,$label,$node,$service} by {cluster_name,kube_namespace}","style":{"palette":"dog_classic","line_type":"solid","line_width":"normal"},"display_type":"area"}],"yaxis":{"include_zero":true,"scale":"linear","label":"","min":"auto","max":"auto"},"custom_links":[{"link":"https://www.google.com?search={{kube_namespace.value}}","label":"Search Namespace on Google"}]}},{"id":42,"layout":{"x":37,"y":54,"width":33,"height":15},"definition":{"title":"Pods in bad phase by namespaces","title_size":"16","title_align":"left","type":"toplist","requests":[{"q":"top(sum:kubernetes_state.pod.status_phase{$scope,$cluster,$namespace,$deployment,$daemonset,!phase:running,!phase:succeeded,$label,$node,$service} by {cluster_name,kube_namespace,phase}, 100, 'last', 'desc')","conditional_formats":[{"comparator":">","palette":"white_on_red","value":0},{"comparator":"<=","palette":"white_on_green","value":0}]}],"custom_links":[]}},{"id":43,"layout":{"x":71,"y":54,"width":33,"height":15},"definition":{"title":"CrashloopBackOff by Pod","title_size":"16","title_align":"left","show_legend":false,"legend_size":"0","type":"timeseries","requests":[{"q":"sum:kubernetes_state.container.waiting{$cluster,$namespace,$deployment,reason:crashloopbackoff,$scope,$daemonset,$label,$node,$service} by {pod_name}","style":{"palette":"dog_classic","line_type":"solid","line_width":"normal"},"display_type":"bars"}],"yaxis":{"include_zero":true,"scale":"linear","label":"","min":"auto","max":"auto"},"markers":[{"label":"y = 0","value":"y = 0","display_type":"ok dashed"}],"custom_links":[]}},{"id":44,"layout":{"x":71,"y":22,"width":33,"height":15},"definition":{"title":"Pods running by namespace","title_size":"16","title_align":"left","type":"toplist","requests":[{"q":"top(sum:kubernetes.pods.running{$scope,$namespace,$deployment,$cluster,$daemonset,$label,$node,$service} by {cluster_name,kube_namespace}, 100, 'max', 'desc')","conditional_formats":[{"comparator":">","palette":"white_on_red","value":2000},{"comparator":">","palette":"white_on_yellow","value":1500},{"comparator":"<=","palette":"white_on_green","value":3000}]}],"custom_links":[]}},{"id":45,"layout":{"x":71,"y":38,"width":33,"height":15},"definition":{"title":"Pods in ready state by node","title_size":"16","title_align":"left","type":"toplist","requests":[{"q":"top(sum:kubernetes_state.pod.ready{$scope,$cluster,$namespace,$deployment,condition:true,$daemonset,$label,$node,$service} by {kubernetes_cluster,host,nodepool}, 10, 'last', 'desc')","conditional_formats":[{"comparator":"<=","palette":"white_on_green","value":24},{"comparator":">","palette":"white_on_red","value":32},{"comparator":">","palette":"white_on_yellow","value":24}]}],"custom_links":[]}},{"id":46,"layout":{"x":24,"y":0,"width":13,"height":7},"definition":{"title":"Clusters","title_size":"16","title_align":"left","type":"query_value","requests":[{"q":"count_nonzero(avg:kubernetes.pods.running{$scope,$label,$node,$service,$daemonset,$deployment,$namespace,$cluster} by {cluster_name})","aggregator":"avg"}],"custom_links":[],"precision":0}},{"id":47,"layout":{"x":38,"y":0,"width":13,"height":7},"definition":{"title":"Namespaces","title_size":"16","title_align":"left","type":"query_value","requests":[{"q":"count_nonzero(avg:kubernetes.pods.running{$scope,$label,$node,$service,$daemonset,$deployment,$namespace,$cluster} by {cluster_name,kube_namespace})","aggregator":"avg"}],"custom_links":[],"precision":0}},{"id":48,"layout":{"x":52,"y":8,"width":13,"height":7},"definition":{"title":"Deployments","title_size":"16","title_align":"left","type":"query_value","requests":[{"q":"count_nonzero(avg:kubernetes_state.deployment.replicas{$scope,$label,$node,$service,$daemonset,$deployment,$namespace,$cluster} by {cluster_name,kube_namespace,kube_deployment})","aggregator":"avg"}],"custom_links":[],"precision":0}},{"id":49,"layout":{"x":52,"y":0,"width":13,"height":7},"definition":{"title":"Services","title_size":"16","title_align":"left","type":"query_value","requests":[{"q":"sum:kubernetes_state.service.count{$scope,$label,$node,$service,$daemonset,$deployment,$namespace,$cluster}","aggregator":"avg"}],"custom_links":[],"precision":0}},{"id":50,"layout":{"x":38,"y":8,"width":13,"height":7},"definition":{"title":"DaemonSets","title_size":"16","title_align":"left","type":"query_value","requests":[{"q":"count_nonzero(avg:kubernetes_state.daemonset.desired{$scope,$label,$node,$service,$daemonset,$deployment,$namespace,$cluster} by {cluster_name,kube_namespace,kube_daemon_set})","aggregator":"avg"}],"custom_links":[],"precision":0}},{"id":51,"layout":{"x":24,"y":8,"width":13,"height":7},"definition":{"title":"Nodes","title_size":"16","title_align":"left","type":"query_value","requests":[{"q":"sum:kubernetes_state.node.count{$scope,$label,$node,$service,$daemonset,$deployment,$namespace,$cluster}","aggregator":"avg"}],"custom_links":[],"precision":0}},{"id":52,"layout":{"x":66,"y":0,"width":13,"height":7},"definition":{"title":"Pods","title_size":"16","title_align":"left","type":"query_value","requests":[{"q":"sum:kubernetes.pods.running{$scope,$label,$node,$service,$daemonset,$deployment,$namespace,$cluster}","aggregator":"avg"}],"custom_links":[{"link":"https://app.datadoghq.com/screen/integration/30322/kubernetes-pods-overview","label":"View Pods overview"}],"precision":0}},{"id":53,"layout":{"x":66,"y":8,"width":13,"height":7},"definition":{"title":"Containers","title_size":"16","title_align":"left","type":"query_value","requests":[{"q":"sum:kubernetes.containers.running{$scope,$label,$node,$service,$daemonset,$deployment,$namespace,$cluster}","aggregator":"avg"}],"custom_links":[],"precision":0}},{"id":54,"layout":{"x":151,"y":121,"width":43,"height":16},"definition":{"title":"Network errors per pod","title_size":"16","title_align":"left","show_legend":false,"legend_size":"0","time":{"live_span":"4h"},"type":"timeseries","requests":[{"q":"sum:kubernetes.network.rx_errors{$scope,$deployment,$daemonset,$namespace,$cluster,$label,$service,$node} by {pod_name}","style":{"palette":"warm","line_type":"solid","line_width":"normal"},"display_type":"bars"},{"q":"sum:kubernetes.network.tx_errors{$scope,$deployment,$daemonset,$namespace,$cluster,$label,$service,$node} by {pod_name}","style":{"palette":"warm","line_type":"solid","line_width":"normal"},"display_type":"bars"}],"yaxis":{"include_zero":true,"scale":"linear","label":"","min":"auto","max":"auto"},"custom_links":[]}}],"template_variables":[{"name":"scope","default":"*"},{"name":"cluster","default":"*","prefix":"cluster_name"},{"name":"namespace","default":"*","prefix":"kube_namespace"},{"name":"deployment","default":"*","prefix":"kube_deployment"},{"name":"daemonset","default":"*","prefix":"kube_daemon_set"},{"name":"service","default":"*","prefix":"kube_service"},{"name":"node","default":"*","prefix":"node"},{"name":"label","default":"*","prefix":"label"}],"layout_type":"free","is_read_only":true,"notify_list":[],"id":"kubernetes_overview_dashboard_json"}
EOF
  }]

  monitor = concat(
    # generate error rate monitor definition
    [for service in local.services : {
      name = replace(
        local.monitor.template.error_rate_name,
        local.monitor.placeholder.service_name,
        service.name
      )
      type = "query alert"
      query = replace(
        replace(
          local.monitor.template.error_rate_query,
          local.monitor.placeholder.service_tag,
          service.tag
        ),
        local.monitor.placeholder.env_tag,
        local.env_tag
      )
      message = replace(
        local.monitor.template.error_rate_message,
        local.monitor.placeholder.service_name,
        service.name
      )
      tags = [local.env_tag, service.tag]
      monitor_thresholds = {
        warning  = 0.01
        critical = 0.05
      }
    }],
    # generate avg latency monitor definition
    [for service in local.services : {
      name = replace(
        local.monitor.template.avg_latency_name,
        local.monitor.placeholder.service_name,
        service.name
      )
      type = "metric alert"
      query = replace(
        replace(
          local.monitor.template.avg_latency_query,
          local.monitor.placeholder.service_tag,
          service.tag
        ),
        local.monitor.placeholder.env_tag,
        local.env_tag
      )
      message = replace(
        local.monitor.template.avg_latency_message,
        local.monitor.placeholder.service_name,
        service.name
      )
      tags = [local.env_tag, service.tag]
      monitor_thresholds = {
        warning  = 0.3
        critical = 0.5
      }
    }]
  )

  synthetics = [
    {
      name = "microservices scenario test"

      locations = ["aws:ap-northeast-1"]
      status    = "paused"
      message   = "@pagerduty-${local.pagerduty.services[0].name} the frontend is down or in trouble"

      options_list = {
        follow_redirects = true
        tick_every       = 900
        retry = {
          count    = 1
          interval = 2000
        }
      }

      api_steps = [
        {
          name          = "access top page"
          allow_failure = false

          request_definition = {
            method = "GET"
            url    = "${local.sampleapps_base_url}/"
            body   = null
          }

          request_headers = null

          assertion = {
            status_code_is             = "307"
            response_time_is_less_than = 2000
          }

          extracted_values = []
        },
        {
          name          = "login"
          allow_failure = false

          request_definition = {
            method = "POST"
            url    = "${local.sampleapps_base_url}/login"
            body   = "userId=test&password=test"
          }

          request_headers = {
            Content-Type = "application/x-www-form-urlencoded"
          }

          assertion = {
            status_code_is             = "302"
            response_time_is_less_than = 2000
          }

          extracted_values = [{
            name  = "SHOP_SESSION_ID"
            type  = "http_header"
            field = "set-cookie"
            parser = {
              type  = "regex"
              value = "(?<=shop_session-id=)[^;]+;"
            }
          }]
        },
        {
          name          = "access product"
          allow_failure = false

          request_definition = {
            method = "GET"
            url    = "${local.sampleapps_base_url}/product/OLJCESPC7Z"
            body   = null
          }

          request_headers = {
            Cookie = "shop_session-id={{ SHOP_SESSION_ID }}; shop_user-id=test"
          }

          assertion = {
            status_code_is             = "200"
            response_time_is_less_than = 2000
          }

          extracted_values = []
        },
        {
          name          = "add product to cart"
          allow_failure = false

          request_definition = {
            method = "POST"
            url    = "${local.sampleapps_base_url}/cart"
            body   = "product_id=OLJCESPC7Z&quantity=1"
          }

          request_headers = {
            Content-Type = "application/x-www-form-urlencoded"
            Cookie       = "shop_session-id={{ SHOP_SESSION_ID }}; shop_user-id=test"
          }

          assertion = {
            status_code_is             = "302"
            response_time_is_less_than = 2000
          }

          extracted_values = []
        },
        {
          name          = "checkout"
          allow_failure = false

          request_definition = {
            method = "POST"
            url    = "${local.sampleapps_base_url}/cart/checkout"
            body   = "email=someone%40example.com&street_address=1600+Amphitheatre+Parkway&zip_code=94043&city=Mountain+View&state=CA&country=United+States&credit_card_number=4432-8015-6152-0454&credit_card_expiration_month=1&credit_card_expiration_year=2022&credit_card_cvv=672"
          }

          request_headers = {
            Content-Type = "application/x-www-form-urlencoded"
            Cookie       = "shop_session-id={{ SHOP_SESSION_ID }}; shop_user-id=test"
          }

          assertion = {
            status_code_is             = "200"
            response_time_is_less_than = 2000
          }

          extracted_values = []
        },
        {
          name          = "access coupon page"
          allow_failure = false

          request_definition = {
            method = "GET"
            url    = "${local.sampleapps_base_url}/coupon"
            body   = null
          }

          request_headers = {
            Cookie = "shop_session-id={{ SHOP_SESSION_ID }}; shop_user-id=test"
          }

          assertion = {
            status_code_is             = "200"
            response_time_is_less_than = 2000
          }

          extracted_values = []
        }
      ]
    }
  ]

  aws_integration = {
    account_id = var.aws_account_id
  }

  logs_archive = {
    bucket = "${var.pjname}-${var.envname}-datadog-log-archive-bucket"
  }

  pagerduty = {
    subdomain = var.monitoring_pd_subdomain
    api_token = var.pagerduty_token

    services = [for service in local.pagerduty.services : {
      service_name = service.name
      service_key  = service.key
    }]
  }
}

module "pagerduty" {
  source                             = "../../modules/pagerduty"
  pjname                             = var.pjname
  envname                            = var.envname
  pagerduty_token                    = var.pagerduty_token
  pagerduty_schedule_layer_user      = var.pagerduty_schedule_layer_user
  pagerduty_escalation_target_leader = var.pagerduty_escalation_target_leader
  pagerduty_escalation_target_admin  = var.pagerduty_escalation_target_admin
  pagerduty_slack_app_id             = var.pagerduty_slack_app_id
  pagerduty_slack_bot_user_id        = var.pagerduty_slack_bot_user_id
  pagerduty_slack_channel            = var.pagerduty_slack_channel
  pagerduty_slack_channel_id         = var.pagerduty_slack_channel_id
  pagerduty_slack_authed_user_id     = var.pagerduty_slack_authed_user_id
  pagerduty_slack_team_id            = var.pagerduty_slack_team_id
  pagerduty_slack_name               = var.pagerduty_slack_name
}
*/
module "aws_iam" {
  source              = "../../modules/iam"
  pjname              = var.pjname
  envname             = var.envname
  iam_allow_trust_ips = var.iam_allow_trust_ips
}
