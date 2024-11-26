data "kubernetes_service" "nginx_ingress_controller" {
  metadata {
    name      = "nginx-ingress-nginx-controller"
    namespace = "mke"
  }
}

locals {
  nginx_lb_ip = (
    length(data.kubernetes_service.nginx_ingress_controller.status) > 0 &&
    length(data.kubernetes_service.nginx_ingress_controller.status[0].load_balancer) > 0 &&
    length(data.kubernetes_service.nginx_ingress_controller.status[0].load_balancer[0].ingress) > 0
  ) ? data.kubernetes_service.nginx_ingress_controller.status[0].load_balancer[0].ingress[0].ip : null
}

resource "kubectl_manifest" "temp_ingress" {
  count     = var.delete_ingress ? 0 : 1
  yaml_body = <<-YAML
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: temp-mke4-ingress
  namespace: mke
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx-default
  rules:
    - host: mke4.konitzer.dev
      http:
        paths:
          - path: /bob
            pathType: Prefix
            backend:
              service:
                name: proxy-service
                port:
                  number: 80
  tls:
    - hosts:
        - mke4.konitzer.dev
      secretName: user-provided-ingress-cert
  YAML
}

resource "null_resource" "wait_for_certificate" {
  provisioner "local-exec" {
    command = <<EOT
    kubectl --kubeconfig ${path.root}/kubeconfig wait --for=condition=Ready --timeout=200s certificate/user-provided-ingress-cert -n mke
    EOT
  }

  depends_on = [kubectl_manifest.temp_ingress]
}

resource "kubectl_manifest" "nginx_ingress_annotation" {
  yaml_body = <<-YAML
apiVersion: v1
kind: Service
metadata:
  name: nginx-ingress-nginx-controller
  namespace: mke
  annotations:
    metallb.universe.tf/allow-shared-ip: "key-to-share-1.2.3.4"
  YAML
}

resource "kubectl_manifest" "proxy_cluster_role" {
  yaml_body = <<-YAML
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: configmap-editor
rules:
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["list", "get"]
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "update", "patch"] 
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "update", "patch"]  
  YAML
}

resource "kubectl_manifest" "proxy_service_account" {
  yaml_body = <<-YAML
apiVersion: v1
kind: ServiceAccount
metadata:
  name: nginx-lb-serviceaccount
  namespace: mke
  YAML
}

resource "kubectl_manifest" "proxy_cluster_role_binding" {
  yaml_body = <<-YAML
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: update-configmap
subjects:
- kind: ServiceAccount
  name: nginx-lb-serviceaccount
  namespace: mke
roleRef:
  kind: ClusterRole
  name: configmap-editor
  apiGroup: rbac.authorization.k8s.io
  YAML
}

resource "kubectl_manifest" "proxy_configmap" {
  yaml_body = <<-YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
  namespace: mke
data:
  nginx.conf: |
    user  nginx;
    worker_processes  1;
    error_log  /var/log/nginx/error.log warn;
    pid        /var/run/nginx.pid;
    events {
      worker_connections  1024;
    }
    stream {
      upstream ucp_8132 {
         server {server_ip}:8132 max_fails=2 fail_timeout=30s;
      }
      server {
         listen 8132;
         proxy_pass ucp_8132;
      }

      upstream ucp_6443 {
         server {server_ip}:6443 max_fails=2 fail_timeout=30s;
      }
      server {
         listen 6443;
         proxy_pass ucp_6443;
      }
      
      upstream ucp_9443 {
         server {server_ip}:9443 max_fails=2 fail_timeout=30s;
      }
      server {
         listen 9443;
         proxy_pass ucp_9443;
      }
    }
  YAML
}

resource "kubectl_manifest" "proxy_configmap_script" {
  yaml_body = <<-YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: updater-script
  namespace: mke
data:
  update-config.sh: |
    #!/bin/bash

    NAMESPACE=$${MY_POD_NAMESPACE:-default}
    trap "rm -f /tmp/nginx-configmap.yaml; exit" INT TERM EXIT
    previous_ips=""

    echo "$(date): Starting config-updater script in namespace $NAMESPACE."

    # Check if the ConfigMap already has an annotation indicating the configuration was applied
    echo "Checking if configmap has already been updated"
    ANNOTATION_CHECK=$(kubectl get configmap nginx-config -n "$NAMESPACE" -o=jsonpath='{.metadata.annotations.config-applied}' 2>/dev/null)

    if [ "$ANNOTATION_CHECK" = "true" ]; then

        echo "Configmap annotation found"
        # Fetch initial node IPs and set as previous_ips
        echo "Fetching initial master node IPs..."
        NODE_IPS=$(kubectl get nodes -l node-role.kubernetes.io/control-plane -o=jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}' | tr ' ' '\n')

        # Check if the kubectl command was successful
        if [ $? -ne 0 ]; then
            echo "Error fetching initial master node IPs. Exiting."
            exit 1
        fi

        # Check if the fetched IPs are empty
        if [ -z "$NODE_IPS" ]; then
            echo "No master node IPs found. Exiting."
            exit 1
        fi

        previous_ips="$NODE_IPS"
        echo "Initial IPs: $previous_ips"
    else
        echo "No annotation found"        
    fi    

    while true; do
        echo "Fetching master node IPs..."
        NODE_IPS=$(kubectl get nodes -l node-role.kubernetes.io/control-plane -o=jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}' | tr ' ' '\n')
        
        # Check if the kubectl command was successful
        if [ $? -ne 0 ]; then
            echo "Error fetching master node IPs."
            sleep 60
            continue
        fi

        # Check if the fetched IPs are empty
        if [ -z "$NODE_IPS" ]; then
            echo "No master node IPs found."
            sleep 60
            continue
        fi

        echo "Fetched IPs: $NODE_IPS"

        if [ "$NODE_IPS" != "$previous_ips" ]; then
            echo "Detected change in node IPs. Updating nginx.conf..."

            # Construct the NGINX upstream config for both ports
            NGINX_CONFIG="user  nginx;
    worker_processes  1;
    error_log  /var/log/nginx/error.log warn;
    pid        /var/run/nginx.pid;
    events {
      worker_connections  1024;
    }
    stream {
      upstream ucp_8132 {\n"
            for IP in $NODE_IPS; do
                NGINX_CONFIG="$NGINX_CONFIG    server $IP:8132 max_fails=2 fail_timeout=30s;\n"
            done
            NGINX_CONFIG="$NGINX_CONFIG  }
      server {
         listen 8132;
         proxy_pass ucp_8132;
      }

      upstream ucp_6443 {\n"
            for IP in $NODE_IPS; do
                NGINX_CONFIG="$NGINX_CONFIG    server $IP:6443 max_fails=2 fail_timeout=30s;\n"
            done
            NGINX_CONFIG="$NGINX_CONFIG  }
      server {
         listen 6443;
         proxy_pass ucp_6443;
      }      

      upstream ucp_9443 {\n"
            for IP in $NODE_IPS; do
                NGINX_CONFIG="$NGINX_CONFIG    server $IP:9443 max_fails=2 fail_timeout=30s;\n"
            done
            NGINX_CONFIG="$NGINX_CONFIG  }
      server {
         listen 9443;
         proxy_pass ucp_9443;
      }
    }"

            # Write to a temporary file
            echo "apiVersion: v1\nkind: ConfigMap\nmetadata:\n  name: nginx-config\n  namespace: $NAMESPACE\n  annotations:\n    config-applied: \"true\"\ndata:\n  nginx.conf: |" > /tmp/nginx-configmap.yaml
            echo "$NGINX_CONFIG" | sed 's/^/    /' >> /tmp/nginx-configmap.yaml

            # Apply the updated config
            if ! OUTPUT=$(kubectl apply -f /tmp/nginx-configmap.yaml -n "$NAMESPACE" 2>&1); then
                echo "Error applying nginx.conf: $$OUTPUT"
            else
                echo "nginx.conf updated successfully."
            fi

            # Restarting the deployment
            if ! OUTPUT=$(kubectl rollout restart deployment/nginx-lb -n "$NAMESPACE" 2>&1); then
                echo "Error restarting deployment: $OUTPUT"
            else
                echo "Nginx restarted successfully."
            fi            

            # Update previous_ips with the current state
            previous_ips="$NODE_IPS"
        else
            echo "No change in master node IPs detected."
        fi    

        echo "Sleeping for 60 seconds before next check..."
        sleep 60
    done
  YAML
}

resource "kubectl_manifest" "proxy_deployment" {
  yaml_body = <<-YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-lb
  namespace: mke
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-lb
  template:
    metadata:
      labels:
        app: nginx-lb
    spec:
      serviceAccountName: nginx-lb-serviceaccount 
      containers: 
      - name: nginx
        image: nginx:stable
        ports:
        - containerPort: 8132
        - containerPort: 6443
        - containerPort: 9443
        volumeMounts:
        - name: nginx-config-volume
          mountPath: /etc/nginx/nginx.conf
          subPath: nginx.conf
          readOnly: true
        - name: scripts
          mountPath: /scripts  
      - name: config-updater
        env:
        - name: MY_POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace      
        image: bitnami/kubectl:latest
        command: ["/bin/sh", "/scripts/update-config.sh"]
        volumeMounts:
        - name: scripts
          mountPath: /scripts                   
      volumes:
      - name: nginx-config-volume
        configMap:
          name: nginx-config
      - name: scripts
        configMap:
          name: updater-script                        
  YAML
}

resource "kubectl_manifest" "proxy_service" {
  yaml_body = <<-YAML
apiVersion: v1
kind: Service
metadata:
  name: nginx-lb-service
  namespace: mke
  annotations:
    metallb.universe.tf/allow-shared-ip: "key-to-share-1.2.3.4"
spec:
  %{ if local.nginx_lb_ip != null }
  loadBalancerIP: ${local.nginx_lb_ip}
  %{ endif }
  selector:
    app: nginx-lb
  ports:
    - name: konnectivity
      protocol: TCP
      port: 8132
      targetPort: 8132
    - name: mke-api  
      protocol: TCP
      port: 6443
      targetPort: 6443
    - name: controller-api
      protocol: TCP
      port: 9443
      targetPort: 9443    
  type: LoadBalancer     
  YAML
}
