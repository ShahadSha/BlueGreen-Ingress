
provider "kubernetes" {
    config_path    = "~/.kube/config"
    config_context = "minikube"
}

locals {
    user_data = jsondecode(file("applications.json"))
    size = length(local.user_data.applications[*])
}


resource "kubernetes_deployment" "deployments" {
  count = local.size
  metadata {
    name = local.user_data.applications[count.index].name
    labels = {
      app = local.user_data.applications[count.index].name
    }
  }

  spec {
    replicas = local.user_data.applications[count.index].replicas
    selector {
      match_labels = {
        app = local.user_data.applications[count.index].name
      }
    }

    template {
      metadata {
        labels = {
          app = local.user_data.applications[count.index].name
        }
      }

      spec {
        container {
          image = local.user_data.applications[count.index].image
          name  = local.user_data.applications[count.index].name
          args = ["-listen=:${local.user_data.applications[count.index].port}","-text=\"I am ${local.user_data.applications[count.index].name}\""]
          port {
            container_port = local.user_data.applications[count.index].port
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "services" {
  count = local.size
  metadata {
    name = local.user_data.applications[count.index].name
  }
  spec {
    selector = {
      app = local.user_data.applications[count.index].name
    }
    session_affinity = "ClientIP"
    port {
      port        = local.user_data.applications[count.index].port
      target_port = local.user_data.applications[count.index].port
    }

    type = "ClusterIP"
  }
}


resource "kubernetes_ingress_v1" "ingress_rule_foo" {
  metadata {
    name = local.user_data.applications[0].name
    annotations = {
      "kubernetes.io/ingress.class" = "nginx"
    }
  }
  spec {
    rule {
      http {
        path {
          backend {
            service {
              name = local.user_data.applications[0].name
              port {
                number = local.user_data.applications[0].port
              }
            }
          }
          path = "/"
          path_type = "Prefix"
        }
      }
    }
  }
}

resource "kubernetes_ingress_v1" "ingress" {
  count = local.size - 1
  metadata {
    name = local.user_data.applications[count.index + 1].name
    annotations = {
      "kubernetes.io/ingress.class" = "nginx"
      "nginx.ingress.kubernetes.io/canary" = "true"
      "nginx.ingress.kubernetes.io/canary-weight" = local.user_data.applications[count.index + 1].traffic_weight 
    }
  }
  spec {
    rule {
      http {
        path {
          backend {
            service {
              name = local.user_data.applications[count.index + 1].name
              port {
                number = local.user_data.applications[count.index + 1].port
              }
            }
          }
          path = "/"
          path_type = "Prefix"
        }
        }
      }
    }  
}
