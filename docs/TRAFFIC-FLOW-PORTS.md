# Traffic Flow & Port Mapping - Infrastructure Overview

> **Last Updated**: January 5, 2026  
> **Purpose**: Tài liệu tổng hợp flow từ bên ngoài (Internet) vào application qua các thành phần infrastructure và ports tương ứng

---

## 📊 Executive Summary

Khi một user truy cập application từ Internet, request đi qua **8 layers** với **node groups** là infrastructure layer quan trọng:

```
Internet → DNS → [WAF] → ALB → [SG] → [Node Group] → Ingress → Service → Pod
(443)    (53)   (443)   (443)  (checks) (t3.large×2) (80/3000) (80/3000) (80/3000)
```

**Infrastructure Components:**
- **Node Group**: 2× t3.large EC2 instances (2 vCPU, 8GB RAM each)
- **Auto-Scaling**: Min 2, Desired 2, Max 4 nodes
- **Networking**: AWS VPC CNI for pod-to-pod communication
- **Max Pods per Node**: 17 pods (ENI limitation for t3.large)

**Total latency estimation:**
- DNS: ~10-50ms
- WAF: ~5-10ms  
- ALB: ~10-20ms
- Node Network: ~1-2ms (iptables + CNI)
- K8s Ingress: ~1-5ms
- Service routing: ~1ms
- Pod processing: varies by app

**Quick Navigation:**
- [📈 Sequence Diagrams](#-sequence-diagrams) - Visual flow với Mermaid diagrams (11 diagrams)
- [🌐 ASCII Diagram](#-complete-traffic-flow-diagram-ascii) - Text-based architecture
- [📋 Port Summary](#-port-summary-table) - Port mapping table
- [🔐 Security Groups](#-security-group-rules-detail) - Firewall rules
- [🚨 Troubleshooting](#-common-issues--troubleshooting) - Debug guide

---

## 📈 Sequence Diagrams

### Diagram 1: Successful Homepage Request

```mermaid
sequenceDiagram
    autonumber
    participant User as 👤 User Browser
    participant DNS as Route53 DNS
    participant WAF as AWS WAF
    participant ALB as Application Load Balancer
    participant SG as Security Groups
    participant Ingress as K8s Ingress Controller
    participant SvcUI as Service: flowise-ui
    participant PodUI as Pod: flowise-ui

    User->>DNS: DNS Query: flowise-dev.do2506.click
    Note over DNS: Port 53 (UDP/TCP)
    DNS-->>User: A Record: 52.77.xxx.xxx (ALB IP)
    
    User->>WAF: HTTPS Request: GET / (Port 443)
    Note over WAF: Inspect traffic<br/>- SQL Injection: ✅ Pass<br/>- XSS: ✅ Pass<br/>- Rate Limit: ✅ OK (50/2000)
    
    WAF->>ALB: Forward to ALB (Port 443)
    Note over ALB: TLS Termination<br/>Certificate: *.do2506.click
    
    ALB->>SG: Check Security Group Rules
    Note over SG: ALB SG → Node SG<br/>Port 443 → Port 80 ✅
    
    SG->>Ingress: HTTP Request (Port 80)
    Note over Ingress: Match Rule:<br/>Host: flowise-dev.do2506.click<br/>Path: / → flowise-ui:80
    
    Ingress->>SvcUI: Route to Service (Port 80)
    Note over SvcUI: ClusterIP: 10.100.x.x<br/>Load Balance: Round-robin
    
    SvcUI->>PodUI: Forward to Pod (Port 80)
    Note over PodUI: Container Port: 80<br/>IP: 10.0.1.45<br/>Nginx serves React app
    
    PodUI-->>SvcUI: 200 OK + HTML
    SvcUI-->>Ingress: Response
    Ingress-->>ALB: Response
    ALB-->>WAF: Response
    WAF-->>User: 200 OK (HTTPS)
    
    Note over User,PodUI: Total Time: ~50-100ms<br/>Ports: 53→443→443→80→80→80
```

---

### Diagram 2: Successful API Request

```mermaid
sequenceDiagram
    autonumber
    participant User as 👤 User Browser
    participant DNS as Route53 DNS
    participant WAF as AWS WAF
    participant ALB as Application Load Balancer
    participant SG as Security Groups
    participant Ingress as K8s Ingress Controller
    participant SvcAPI as Service: flowise-server
    participant PodAPI as Pod: flowise-server
    participant DB as Database (SQLite)

    User->>DNS: DNS Query: flowise-dev.do2506.click
    DNS-->>User: A Record: 52.77.xxx.xxx
    
    User->>WAF: POST /api/v1/chatflows (Port 443)
    Note over WAF: Inspect Request Body<br/>- SQL Injection: ✅ Clean<br/>- Rate Limit: ✅ OK<br/>- Payload Size: ✅ Valid
    
    WAF->>ALB: Forward to ALB (Port 443)
    Note over ALB: TLS Termination<br/>Route to Target Group
    
    ALB->>SG: Check Security Rules
    Note over SG: ALB SG → Node SG<br/>Port 443 → Port 3000 ✅
    
    SG->>Ingress: HTTP Request (Port 3000)
    Note over Ingress: Match Rule:<br/>Path: /api → flowise-server:3000
    
    Ingress->>SvcAPI: Route to Service (Port 3000)
    Note over SvcAPI: ClusterIP: 10.100.x.x<br/>Select Pod by Label
    
    SvcAPI->>PodAPI: Forward to Pod (Port 3000)
    Note over PodAPI: Container Port: 3000<br/>IP: 10.0.1.78<br/>Node.js Express API
    
    PodAPI->>PodAPI: Authenticate User
    PodAPI->>DB: Query Chatflows
    DB-->>PodAPI: Return Data
    PodAPI->>PodAPI: Format JSON Response
    
    PodAPI-->>SvcAPI: 200 OK + JSON
    SvcAPI-->>Ingress: Response
    Ingress-->>ALB: Response
    ALB-->>WAF: Response
    WAF-->>User: 200 OK (HTTPS)
    
    Note over User,DB: Total Time: ~100-200ms<br/>Ports: 53→443→443→3000→3000→3000
```

---

### Diagram 3: WAF Blocks Malicious Request

```mermaid
sequenceDiagram
    autonumber
    participant Attacker as 🔴 Attacker
    participant DNS as Route53 DNS
    participant WAF as AWS WAF
    participant ALB as Application Load Balancer (Not Reached)
    participant CloudWatch as CloudWatch Logs

    Attacker->>DNS: DNS Query: flowise-dev.do2506.click
    DNS-->>Attacker: A Record: 52.77.xxx.xxx
    
    Attacker->>WAF: GET /?id=1' OR '1'='1 (Port 443)
    Note over WAF: 🔍 Inspect Request<br/>DETECTED: SQL Injection Pattern
    
    WAF->>WAF: Match Rule: AWSManagedRulesSQLiRuleSet
    Note over WAF: Priority 3: SQL Injection<br/>Action: BLOCK
    
    WAF->>CloudWatch: Log Blocked Request
    Note over CloudWatch: Log Entry:<br/>- Source IP: xxx.xxx.xxx.xxx<br/>- Pattern: SQL Injection<br/>- Action: BLOCKED<br/>- Rule: SQLi_QUERYARGUMENTS
    
    WAF-->>Attacker: ❌ 403 Forbidden
    Note over Attacker: Request NEVER reaches ALB<br/>Blocked at Layer 2 (WAF)
    
    CloudWatch->>CloudWatch: Increment Metric: BlockedRequests
    
    alt Block Count > 100 in 5 min
        CloudWatch->>CloudWatch: Trigger Alarm
        Note over CloudWatch: SNS → Email/Slack Alert<br/>"High number of blocked requests"
    end
```

---

### Diagram 4: Health Check Flow

```mermaid
sequenceDiagram
    autonumber
    participant ALB as Application Load Balancer
    participant TG as Target Group
    participant PodAPI as Pod: flowise-server
    participant App as Express Application

    loop Every 30 seconds
        ALB->>TG: Initiate Health Check
        TG->>PodAPI: HTTP GET /api/v1/ping
        Note over PodAPI: Container Port: 3000
        
        PodAPI->>App: Route to Health Endpoint
        
        alt Pod is Healthy
            App-->>PodAPI: 200 OK {"status":"ok"}
            PodAPI-->>TG: 200 OK
            TG-->>ALB: Mark Target HEALTHY
            Note over ALB: Healthy Threshold: 2/2<br/>Status: ✅ IN_SERVICE
        else Pod is Unhealthy
            App-->>PodAPI: 500 Error or Timeout
            PodAPI-->>TG: 500 Error / Timeout
            TG-->>ALB: Mark Target UNHEALTHY
            Note over ALB: Unhealthy Threshold: 3/3<br/>Status: ❌ OUT_OF_SERVICE
            ALB->>ALB: Remove from Load Balancing
        end
    end
```

---

### Diagram 5: Complete Request Flow with Node Groups

```mermaid
sequenceDiagram
    autonumber
    participant User as 👤 User
    participant DNS as Route53<br/>(Port 53)
    participant WAF as WAF<br/>(Port 443)
    participant ALB as ALB<br/>(Port 443)
    participant SG as Security Groups
    participant Node as EC2 Node<br/>(t3.large)
    participant Kubelet as Kubelet<br/>(Node Agent)
    participant Ingress as Ingress<br/>(Port 80/3000)
    participant Svc as K8s Service<br/>(ClusterIP)
    participant Pod as Pod<br/>(Port 80/3000)

    rect rgb(240, 248, 255)
        Note over User,DNS: Layer 1: DNS Resolution (10-50ms)
        User->>+DNS: Query: flowise-dev.do2506.click
        DNS-->>-User: Response: ALB IP
    end

    rect rgb(255, 250, 240)
        Note over User,WAF: Layer 2: WAF Inspection (5-10ms)
        User->>+WAF: HTTPS Request
        WAF->>WAF: Run 9 Rule Groups
        WAF-->>-ALB: Forward (if allowed)
    end

    rect rgb(240, 255, 240)
        Note over ALB,Node: Layer 3: Load Balancing (10-20ms)
        ALB->>+SG: Check Firewall Rules
        Note over SG: ALB SG → Node SG<br/>Port 443 → 80/3000 ✅
        SG-->>-ALB: Allow
        ALB->>ALB: TLS Termination
        ALB->>+Node: Route to Node IP<br/>IP: 10.0.1.45 (Pod CIDR)
        Note over Node: EC2 Instance: t3.large<br/>2 vCPU, 8GB RAM<br/>AZ: ap-southeast-1a
    end

    rect rgb(245, 255, 245)
        Note over Node,Kubelet: Layer 4: Node Network (1-2ms)
        Node->>+Kubelet: Packet arrives at Node
        Note over Kubelet: Kubelet manages:<br/>- CNI networking<br/>- iptables rules<br/>- Pod lifecycle
        Kubelet->>Kubelet: Check iptables
        Note over Kubelet: iptables NAT:<br/>NodeIP:Port → PodIP:Port
    end

    rect rgb(255, 240, 245)
        Note over Kubelet,Pod: Layer 5-7: Kubernetes Routing (1-5ms)
        Kubelet->>+Ingress: Forward to Ingress Pod
        Ingress->>+Svc: Route by Path
        Note over Svc: Service Type: ClusterIP<br/>Endpoints: 2 pods<br/>LB: Round-robin
        Svc->>+Pod: Forward to Pod
        Note over Pod: Container on this Node<br/>IP: 10.0.1.78<br/>Port: 3000
        Pod->>Pod: Process Request
        Pod-->>-Svc: Response
        Svc-->>-Ingress: Response
        Ingress-->>-Kubelet: Response
    end

    rect rgb(245, 245, 255)
        Note over Kubelet,User: Response Path (reverse flow)
        Kubelet-->>-Node: Response
        Node-->>ALB: Response
        ALB-->>WAF: HTTPS Response
        WAF-->>User: Final Response
    end

    Note over User,Pod: Total Round Trip: 50-200ms<br/>Path: Internet → ALB → Node → Pod
```

---

### Diagram 6: Node Group Auto-Scaling & Health

```mermaid
sequenceDiagram
    autonumber
    participant CloudWatch as CloudWatch<br/>Metrics
    participant ASG as Auto Scaling Group
    participant EKS as EKS Control Plane
    participant Node1 as Node 1<br/>(Running)
    participant Node2 as Node 2<br/>(Running)
    participant Node3 as Node 3<br/>(New)
    participant Kubelet as Kubelet
    participant Pods as Pods

    Note over CloudWatch,Pods: Scenario: High CPU Usage Triggers Scale-Up

    Node1->>CloudWatch: Report CPU: 85%
    Node2->>CloudWatch: Report CPU: 90%
    
    CloudWatch->>CloudWatch: Evaluate Metric
    Note over CloudWatch: Average CPU > 80%<br/>Duration: 5 minutes
    
    CloudWatch->>ASG: Trigger Scale-Up
    Note over ASG: Current: 2 nodes<br/>Desired: 3 nodes<br/>Max: 4 nodes
    
    ASG->>ASG: Launch EC2 Instance
    Note over ASG: Instance Type: t3.large<br/>AMI: EKS Optimized<br/>Subnet: Private (AZ-c)
    
    ASG->>Node3: EC2 Instance Created
    Note over Node3: IP: 10.0.3.23<br/>State: Initializing
    
    Node3->>Node3: Install Kubelet
    Node3->>Node3: Install CNI Plugin
    Node3->>Node3: Configure iptables
    
    Node3->>EKS: Register with Cluster
    Note over EKS: Node: ip-10-0-3-23<br/>Status: Ready
    
    EKS->>Kubelet: Schedule Pending Pods
    Kubelet->>Pods: Create Pods on Node3
    
    Note over Node1,Pods: Load Distributed Across 3 Nodes
    
    alt Health Check Failure
        Node2->>Node2: Health Check Failed
        Node2->>EKS: Report: NotReady
        EKS->>Kubelet: Evict Pods from Node2
        Kubelet->>Node1: Reschedule Pods
        Kubelet->>Node3: Reschedule Pods
        EKS->>ASG: Mark Node2 Unhealthy
        ASG->>Node2: Terminate Instance
        ASG->>ASG: Launch Replacement
    end
```

---

### Diagram 7: Node-to-Node Communication (Cross-Node Pods)

```mermaid
sequenceDiagram
    autonumber
    participant PodUI as UI Pod<br/>Node 1<br/>10.0.1.45:80
    participant CNI1 as AWS VPC CNI<br/>(Node 1)
    participant VPC as VPC Network<br/>(ENI)
    participant CNI2 as AWS VPC CNI<br/>(Node 2)
    participant PodAPI as API Pod<br/>Node 2<br/>10.0.2.78:3000

    Note over PodUI,PodAPI: Pods on Different Nodes

    PodUI->>CNI1: HTTP Request to 10.0.2.78:3000
    Note over CNI1: Check routing table<br/>Destination: Different Node
    
    CNI1->>VPC: Route via ENI
    Note over VPC: AWS VPC Native Routing<br/>No overlay network<br/>Direct pod-to-pod IP
    
    VPC->>CNI2: Packet arrives at Node 2
    Note over CNI2: iptables rules<br/>Forward to Pod IP
    
    CNI2->>PodAPI: Deliver to Pod
    Note over PodAPI: Container receives packet<br/>No NAT, direct routing
    
    PodAPI-->>CNI2: Response
    CNI2-->>VPC: Route back
    VPC-->>CNI1: Return packet
    CNI1-->>PodUI: Deliver response
    
    Note over PodUI,PodAPI: Benefits:<br/>- Native VPC routing<br/>- No overlay latency<br/>- Security Groups apply<br/>- AWS CloudWatch visibility
```

---

### Diagram 8: Multi-Path Request Decision Flow

```mermaid
sequenceDiagram
    autonumber
    participant User as 👤 User
    participant ALB as ALB
    participant Ingress as Ingress
    participant SvcUI as flowise-ui:80
    participant SvcAPI as flowise-server:3000
    participant PodUI as UI Pod (Nginx)
    participant PodAPI as API Pod (Node.js)

    User->>ALB: HTTPS Request
    ALB->>Ingress: Forward (after TLS)
    
    alt Path: / (root)
        Ingress->>SvcUI: Route to UI Service
        SvcUI->>PodUI: Port 80
        PodUI-->>SvcUI: index.html
        SvcUI-->>Ingress: Response
    else Path: /dashboard
        Ingress->>SvcUI: Route to UI Service
        SvcUI->>PodUI: Port 80
        PodUI-->>SvcUI: SPA (client-side routing)
        SvcUI-->>Ingress: Response
    else Path: /api/*
        Ingress->>SvcAPI: Route to API Service
        SvcAPI->>PodAPI: Port 3000
        PodAPI-->>SvcAPI: JSON Response
        SvcAPI-->>Ingress: Response
    else Path: /metrics
        Ingress->>SvcAPI: Route to API Service
        SvcAPI->>PodAPI: Port 3000
        PodAPI-->>SvcAPI: Prometheus Metrics
        SvcAPI-->>Ingress: Response
    else No Match
        Ingress-->>ALB: 404 Not Found
    end
    
    Ingress-->>ALB: Final Response
    ALB-->>User: HTTPS Response
```

---

### Diagram 9: Error Scenarios

```mermaid
sequenceDiagram
    autonumber
    participant User as 👤 User
    participant WAF as WAF
    participant ALB as ALB
    participant Pod as Pod
    participant CloudWatch as CloudWatch

    Note over User,CloudWatch: Scenario 1: WAF Blocks Request
    User->>WAF: Malicious Request
    WAF->>CloudWatch: Log: Blocked
    WAF-->>User: 403 Forbidden
    Note over User: Request blocked at Layer 2

    Note over User,CloudWatch: Scenario 2: Pod Not Ready
    User->>WAF: Normal Request
    WAF->>ALB: Forward
    ALB->>Pod: HTTP Request
    Pod-->>ALB: No Response (timeout)
    ALB->>CloudWatch: Log: 504 Timeout
    ALB-->>WAF: 504 Gateway Timeout
    WAF-->>User: 504 Gateway Timeout

    Note over User,CloudWatch: Scenario 3: Application Error
    User->>WAF: Normal Request
    WAF->>ALB: Forward
    ALB->>Pod: HTTP Request
    Pod->>Pod: Application Error
    Pod-->>ALB: 500 Internal Server Error
    ALB->>CloudWatch: Log: 5xx Error
    ALB-->>WAF: 500 Internal Server Error
    WAF-->>User: 500 Internal Server Error

    Note over User,CloudWatch: Scenario 4: Rate Limit Exceeded
    User->>WAF: Request #2001 in 5 min
    WAF->>WAF: Check Rate Limit
    Note over WAF: Limit: 2000 req/5min<br/>Current: 2001<br/>Action: BLOCK
    WAF->>CloudWatch: Log: Rate Limited
    WAF-->>User: 429 Too Many Requests
```

---

### Diagram 10: Pod to Pod Communication (Same Node)

```mermaid
sequenceDiagram
    autonumber
    participant PodUI as UI Pod<br/>(10.0.1.45:80)
    participant DNS as CoreDNS<br/>(K8s DNS)
    participant SvcAPI as flowise-server<br/>(ClusterIP)
    participant PodAPI as API Pod<br/>(10.0.1.78:3000)

    Note over PodUI,PodAPI: Internal Communication (no ALB)
    
    PodUI->>DNS: Resolve: flowise-server.flowise-dev.svc.cluster.local
    DNS-->>PodUI: ClusterIP: 10.100.50.20
    
    PodUI->>SvcAPI: HTTP GET http://flowise-server:3000/api/v1/config
    Note over SvcAPI: Service Routes to Available Pod
    
    SvcAPI->>PodAPI: Forward to Pod IP:Port
    Note over PodAPI: Direct pod-to-pod<br/>No external network
    
    PodAPI->>PodAPI: Process Request
    PodAPI-->>SvcAPI: 200 OK + JSON
    SvcAPI-->>PodUI: Response
    
    Note over PodUI,PodAPI: Fast & Secure<br/>~1-2ms latency<br/>No encryption needed (trusted network)
```

---

### Diagram 11: ArgoCD Deployment Flow (GitOps)

```mermaid
sequenceDiagram
    autonumber
    participant Dev as 👨‍💻 Developer
    participant Git as GitHub Repo
    participant ArgoCD as ArgoCD Server
    participant K8s as K8s API Server
    participant Pod as New Pod

    Dev->>Git: git push (update manifest)
    Note over Git: Change: replicas: 2 → 3
    
    ArgoCD->>Git: Poll every 3 minutes
    Git-->>ArgoCD: Detect changes
    
    ArgoCD->>ArgoCD: Compare Desired vs Current State
    Note over ArgoCD: Desired: 3 replicas<br/>Current: 2 replicas<br/>Status: OutOfSync
    
    ArgoCD->>K8s: kubectl apply -f manifest.yaml
    Note over K8s: Update Deployment<br/>Set replicas: 3
    
    K8s->>K8s: Schedule new Pod
    K8s->>Pod: Create Pod on Node
    
    Pod->>Pod: Pull Image from ECR
    Pod->>Pod: Start Container
    Pod->>Pod: Health Check: Liveness
    Pod->>Pod: Health Check: Readiness
    
    Pod-->>K8s: Ready
    K8s-->>ArgoCD: Sync Successful
    
    ArgoCD->>ArgoCD: Update Status
    Note over ArgoCD: Status: Synced ✅<br/>Health: Healthy ✅
```

---

## 🌐 Complete Traffic Flow Diagram (ASCII)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         INTERNET (Public)                               │
│                                                                         │
│  User Browser: https://flowise-dev.do2506.click                        │
│                                                                         │
│  Port: 443 (HTTPS)                                                      │
└───────────────────────────────┬─────────────────────────────────────────┘
                                │
                                │ TLS 1.2/1.3
                                │ (Encrypted)
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  LAYER 1: DNS RESOLUTION                                                │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                                                         │
│  Component: Amazon Route53                                              │
│  Port: 53 (DNS)                                                         │
│  Protocol: DNS over UDP/TCP                                             │
│                                                                         │
│  Records:                                                               │
│  - flowise-dev.do2506.click → A record → ALB Public IP                  │
│  - flowise-staging.do2506.click → A record → ALB Public IP              │
│  - flowise-prod.do2506.click → A record → ALB Public IP                 │
│  - argocd.do2506.click → A record → ALB Public IP                       │
│  - prometheus.do2506.click → A record → ALB Public IP                   │
│  - grafana.do2506.click → A record → ALB Public IP                      │
│                                                                         │
│  TTL: 300 seconds (5 minutes)                                           │
└───────────────────────────────┬─────────────────────────────────────────┘
                                │
                                │ Returns: ALB DNS/IP
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  LAYER 2: WEB APPLICATION FIREWALL (WAF)                                │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                                                         │
│  Component: AWS WAF v2 (Regional)                                       │
│  Port: 443 (Inspects HTTPS traffic)                                     │
│  Scope: REGIONAL (attached to ALB)                                      │
│                                                                         │
│  ┌───────────────────────────────────────────────────────────┐         │
│  │  INSPECTION RULES (executed in priority order)            │         │
│  ├───────────────────────────────────────────────────────────┤         │
│  │  Priority 1: AWS Managed Rules - Core Rule Set           │         │
│  │              └─ SQL Injection                             │         │
│  │              └─ XSS (Cross-Site Scripting)                │         │
│  │              └─ LFI (Local File Inclusion)                │         │
│  │              └─ RFI (Remote File Inclusion)               │         │
│  │                                                           │         │
│  │  Priority 2: Known Bad Inputs                             │         │
│  │              └─ Known malicious patterns                  │         │
│  │              └─ Exploits database                         │         │
│  │                                                           │         │
│  │  Priority 3: SQL Database Protection (conditional)        │         │
│  │              └─ Advanced SQL injection patterns           │         │
│  │                                                           │         │
│  │  Priority 4: Linux OS Protection (conditional)            │         │
│  │              └─ Linux command injection                   │         │
│  │              └─ Shellshock attacks                        │         │
│  │                                                           │         │
│  │  Priority 5: Rate Limiting                                │         │
│  │              └─ Limit: 2000 requests per 5 minutes        │         │
│  │              └─ Per IP address tracking                   │         │
│  │              └─ Action: BLOCK excess requests             │         │
│  │                                                           │         │
│  │  Priority 6: Geo Blocking (conditional)                   │         │
│  │              └─ Block specific countries                  │         │
│  │              └─ Allow list: VN, US, SG, etc.              │         │
│  │                                                           │         │
│  │  Priority 7: IP Blacklist (conditional)                   │         │
│  │              └─ Manually blocked IPs                      │         │
│  │              └─ Known attack sources                      │         │
│  │                                                           │         │
│  │  Priority 8: IP Whitelist (conditional)                   │         │
│  │              └─ Only allow specific IPs                   │         │
│  │              └─ Corporate networks, VPN, etc.             │         │
│  │                                                           │         │
│  │  Priority 9: Custom Regex Pattern (conditional)           │         │
│  │              └─ Custom attack patterns                    │         │
│  │              └─ Business-specific validation              │         │
│  └───────────────────────────────────────────────────────────┘         │
│                                                                         │
│  Logging: CloudWatch Logs                                               │
│  Log Group: /aws/waf/my-eks-dev-dev-waf                                 │
│  Retention: 30 days                                                     │
│                                                                         │
│  Metrics:                                                               │
│  - BlockedRequests                                                      │
│  - AllowedRequests                                                      │
│  - CountedRequests                                                      │
│                                                                         │
│  Alarms:                                                                │
│  - Blocked requests > 100 in 5 min → Alert                              │
│  - Rate limit hits > 50 in 5 min → Alert                                │
└───────────────────────────────┬─────────────────────────────────────────┘
                                │
                                │ ✅ ALLOWED (clean traffic)
                                │ ❌ BLOCKED (malicious/rate-limited)
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  LAYER 3: APPLICATION LOAD BALANCER (ALB)                               │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                                                         │
│  Component: AWS ALB (flowise-dev-alb)                                   │
│  Type: internet-facing                                                  │
│  Scheme: Internet-facing                                                │
│  VPC: Public subnets (2 AZs)                                            │
│                                                                         │
│  ┌───────────────────────────────────────────────────────────┐         │
│  │  LISTENERS                                                 │         │
│  ├───────────────────────────────────────────────────────────┤         │
│  │                                                           │         │
│  │  Listener 1: HTTP → Port 80                               │         │
│  │  ─────────────────────────                                │         │
│  │  Protocol: HTTP                                           │         │
│  │  Action: REDIRECT to HTTPS (443)                          │         │
│  │  Status: 301 Moved Permanently                            │         │
│  │                                                           │         │
│  │  Listener 2: HTTPS → Port 443                             │         │
│  │  ──────────────────────────                               │         │
│  │  Protocol: HTTPS                                          │         │
│  │  Certificate: ACM (*.do2506.click)                        │         │
│  │  SSL Policy: ELBSecurityPolicy-TLS-1-2-2017-01           │         │
│  │                                                           │         │
│  │  Rules:                                                   │         │
│  │  ┌─────────────────────────────────────────┐             │         │
│  │  │ Host: flowise-dev.do2506.click          │             │         │
│  │  ├─────────────────────────────────────────┤             │         │
│  │  │ Path: /api/*                            │             │         │
│  │  │ → Target Group: flowise-server          │             │         │
│  │  │ → Port: 3000                            │             │         │
│  │  │ → Health: /api/v1/ping                  │             │         │
│  │  │                                         │             │         │
│  │  │ Path: /*                                │             │         │
│  │  │ → Target Group: flowise-ui              │             │         │
│  │  │ → Port: 80                              │             │         │
│  │  │ → Health: /                             │             │         │
│  │  └─────────────────────────────────────────┘             │         │
│  └───────────────────────────────────────────────────────────┘         │
│                                                                         │
│  Target Type: IP (direct to pod IPs)                                    │
│  Health Checks:                                                         │
│  - Interval: 30 seconds                                                 │
│  - Timeout: 5 seconds                                                   │
│  - Healthy threshold: 2 consecutive successes                           │
│  - Unhealthy threshold: 3 consecutive failures                          │
│                                                                         │
│  Cross-Zone Load Balancing: Enabled                                     │
│  Deletion Protection: Disabled (dev), Enabled (prod)                    │
│                                                                         │
│  Tags:                                                                  │
│  - Environment: dev                                                     │
│  - Application: flowise                                                 │
│  - ManagedBy: kubernetes-alb-controller                                 │
└───────────────────────────────┬─────────────────────────────────────────┘
                                │
                                │ Routes to Target Groups
                                │ Port: 80 (UI) or 3000 (API)
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  LAYER 4: SECURITY GROUPS                                               │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────┐           │
│  │  ALB SECURITY GROUP (sg-alb-xxx)                        │           │
│  ├─────────────────────────────────────────────────────────┤           │
│  │  Inbound Rules:                                         │           │
│  │  - Port 80 (HTTP) from 0.0.0.0/0                        │           │
│  │  - Port 443 (HTTPS) from 0.0.0.0/0                      │           │
│  │                                                         │           │
│  │  Outbound Rules:                                        │           │
│  │  - Port 80 to Node SG (for UI pods)                     │           │
│  │  - Port 3000 to Node SG (for Server pods)               │           │
│  └─────────────────────────────────────────────────────────┘           │
│                     │                                                   │
│                     │ Allows traffic                                    │
│                     ▼                                                   │
│  ┌─────────────────────────────────────────────────────────┐           │
│  │  EKS NODE SECURITY GROUP (sg-node-xxx)                  │           │
│  ├─────────────────────────────────────────────────────────┤           │
│  │  Inbound Rules:                                         │           │
│  │  - Port 80 from ALB SG (UI traffic)                     │           │
│  │  - Port 3000 from ALB SG (API traffic)                  │           │
│  │  - Port 443 from Cluster SG (K8s API)                   │           │
│  │  - Port 1025-65535 from Cluster SG (kubelet)            │           │
│  │  - All traffic from Node SG (inter-node)                │           │
│  │  - Port 22 from Bastion (optional SSH)                  │           │
│  │                                                         │           │
│  │  Outbound Rules:                                        │           │
│  │  - All traffic to 0.0.0.0/0 (egress)                    │           │
│  └─────────────────────────────────────────────────────────┘           │
│                     │                                                   │
│                     │                                                   │
│                     ▼                                                   │
│  ┌─────────────────────────────────────────────────────────┐           │
│  │  EKS CLUSTER SECURITY GROUP (sg-cluster-xxx)            │           │
│  ├─────────────────────────────────────────────────────────┤           │
│  │  Inbound Rules:                                         │           │
│  │  - Port 443 from Node SG (pods → API server)            │           │
│  │                                                         │           │
│  │  Outbound Rules:                                        │           │
│  │  - Port 443 to Node SG (API server → webhooks)          │           │
│  │  - Port 1025-65535 to Node SG (API server → kubelet)    │           │
│  │  - All traffic to 0.0.0.0/0 (egress)                    │           │
│  └─────────────────────────────────────────────────────────┘           │
└───────────────────────────────┬─────────────────────────────────────────┘
                                │
                                │ Packet filter passed
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  LAYER 5: KUBERNETES INGRESS                                            │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                                                         │
│  Component: Ingress Resource (flowise-ingress)                          │
│  Namespace: flowise-dev                                                 │
│  IngressClass: alb                                                      │
│  Managed By: AWS Load Balancer Controller                               │
│                                                                         │
│  ┌───────────────────────────────────────────────────────────┐         │
│  │  ROUTING RULES                                             │         │
│  ├───────────────────────────────────────────────────────────┤         │
│  │                                                           │         │
│  │  Host: flowise-dev.do2506.click                           │         │
│  │  ─────────────────────────────                            │         │
│  │                                                           │         │
│  │  Path: / (Prefix)                                         │         │
│  │  ─────────────────                                        │         │
│  │  Backend:                                                 │         │
│  │    Service: flowise-ui                                    │         │
│  │    Port: 80                                               │         │
│  │    Protocol: HTTP                                         │         │
│  │                                                           │         │
│  │  Examples:                                                │         │
│  │    https://flowise-dev.do2506.click/                      │         │
│  │    https://flowise-dev.do2506.click/login                 │         │
│  │    https://flowise-dev.do2506.click/dashboard             │         │
│  │                                                           │         │
│  │  ─────────────────────────────────────────────            │         │
│  │                                                           │         │
│  │  Path: /api (Prefix)                                      │         │
│  │  ────────────────────                                     │         │
│  │  Backend:                                                 │         │
│  │    Service: flowise-server                                │         │
│  │    Port: 3000                                             │         │
│  │    Protocol: HTTP                                         │         │
│  │                                                           │         │
│  │  Examples:                                                │         │
│  │    https://flowise-dev.do2506.click/api/v1/ping           │         │
│  │    https://flowise-dev.do2506.click/api/v1/chatflows      │         │
│  │    https://flowise-dev.do2506.click/api/v1/nodes          │         │
│  └───────────────────────────────────────────────────────────┘         │
│                                                                         │
│  Annotations:                                                           │
│  - alb.ingress.kubernetes.io/scheme: internet-facing                    │
│  - alb.ingress.kubernetes.io/target-type: ip                            │
│  - alb.ingress.kubernetes.io/listen-ports: [{"HTTP":80},{"HTTPS":443}] │
│  - alb.ingress.kubernetes.io/ssl-redirect: "443"                        │
│  - alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:...           │
│  - alb.ingress.kubernetes.io/wafv2-acl-arn: arn:aws:wafv2:...           │
│  - alb.ingress.kubernetes.io/healthcheck-path: /                        │
│  - alb.ingress.kubernetes.io/healthcheck-interval-seconds: "30"         │
└───────────────────────────────┬─────────────────────────────────────────┘
                                │
                                │ Route to Service
                                │ via iptables on Node
                                │
                    ┌───────────┴────────────┐
                    │                        │
                    ▼                        ▼
┌─────────────────────────────┐   ┌─────────────────────────────┐
│  LAYER 6: KUBERNETES SERVICE│   │  LAYER 6: KUBERNETES SERVICE│
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━│   │  ━━━━━━━━━━━━━━━━━━━━━━━━━━│
│                             │   │                             │
│  Name: flowise-ui           │   │  Name: flowise-server       │
│  Type: ClusterIP            │   │  Type: ClusterIP            │
│  Namespace: flowise-dev     │   │  Namespace: flowise-dev     │
│                             │   │                             │
│  Port Mapping:              │   │  Port Mapping:              │
│  - Port: 80                 │   │  - Port: 3000               │
│  - TargetPort: http (80)    │   │  - TargetPort: http (3000)  │
│  - Protocol: TCP            │   │  - Protocol: TCP            │
│                             │   │                             │
│  Selector:                  │   │  Selector:                  │
│  - app: flowise             │   │  - app: flowise             │
│  - component: ui            │   │  - component: server        │
│                             │   │                             │
│  ClusterIP: 10.100.x.x      │   │  ClusterIP: 10.100.x.x      │
│  (Internal only)            │   │  (Internal only)            │
│                             │   │                             │
│  Endpoints: 2 pods          │   │  Endpoints: 2 pods          │
│  - 10.0.1.45:80             │   │  - 10.0.1.78:3000           │
│  - 10.0.2.67:80             │   │  - 10.0.2.89:3000           │
└──────────────┬──────────────┘   └──────────────┬──────────────┘
               │                                 │
               │ Load balance                    │ Load balance
               │ (round-robin)                   │ (round-robin)
               │                                 │
               ▼                                 ▼
        ┌──────────────┐                  ┌──────────────┐
        │   Pod 1      │                  │   Pod 1      │
        └──────────────┘                  └──────────────┘
        ┌──────────────┐                  ┌──────────────┐
        │   Pod 2      │                  │   Pod 2      │
        └──────────────┘                  └──────────────┘
               │                                 │
               └─────────────┬───────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  LAYER 7: KUBERNETES PODS                                               │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                                                         │
│  ┌───────────────────────────────────────────────────────────┐         │
│  │  POD: flowise-ui-xxx                                      │         │
│  ├───────────────────────────────────────────────────────────┤         │
│  │  Namespace: flowise-dev                                   │         │
│  │  Node: ip-10-0-1-xxx.ec2.internal                         │         │
│  │  IP: 10.0.1.45 (Pod CIDR)                                 │         │
│  │                                                           │         │
│  │  Container: ui                                            │         │
│  │  Image: flowise-ui:latest                                 │         │
│  │  Port: 80/TCP (containerPort)                             │         │
│  │  Protocol: HTTP                                           │         │
│  │                                                           │         │
│  │  Application: Nginx serving React SPA                     │         │
│  │  - Static assets (HTML, CSS, JS)                          │         │
│  │  - Client-side routing                                    │         │
│  │  - Proxy /api requests to backend                         │         │
│  │                                                           │         │
│  │  Resources:                                               │         │
│  │  - CPU Request: 50m, Limit: 250m                          │         │
│  │  - Memory Request: 128Mi, Limit: 256Mi                    │         │
│  │                                                           │         │
│  │  Health Checks:                                           │         │
│  │  - Liveness: HTTP GET :80/                                │         │
│  │  - Readiness: HTTP GET :80/                               │         │
│  │  - Initial Delay: 10s                                     │         │
│  │  - Period: 30s                                            │         │
│  └───────────────────────────────────────────────────────────┘         │
│                                                                         │
│  ┌───────────────────────────────────────────────────────────┐         │
│  │  POD: flowise-server-xxx                                  │         │
│  ├───────────────────────────────────────────────────────────┤         │
│  │  Namespace: flowise-dev                                   │         │
│  │  Node: ip-10-0-2-xxx.ec2.internal                         │         │
│  │  IP: 10.0.1.78 (Pod CIDR)                                 │         │
│  │                                                           │         │
│  │  Container: server                                        │         │
│  │  Image: flowise-server:latest                             │         │
│  │  Port: 3000/TCP (containerPort)                           │         │
│  │  Protocol: HTTP                                           │         │
│  │                                                           │         │
│  │  Application: Node.js Express API                         │         │
│  │  - REST API endpoints                                     │         │
│  │  - Database connections                                   │         │
│  │  - Business logic                                         │         │
│  │  - Authentication                                         │         │
│  │                                                           │         │
│  │  API Endpoints:                                           │         │
│  │  - GET /api/v1/ping (health check)                        │         │
│  │  - POST /api/v1/auth/login                                │         │
│  │  - GET /api/v1/chatflows                                  │         │
│  │  - POST /api/v1/prediction/:id                            │         │
│  │  - ... (many more endpoints)                              │         │
│  │                                                           │         │
│  │  Resources:                                               │         │
│  │  - CPU Request: 200m, Limit: 2000m                        │         │
│  │  - Memory Request: 1Gi, Limit: 2Gi                        │         │
│  │                                                           │         │
│  │  Health Checks:                                           │         │
│  │  - Liveness: HTTP GET :3000/api/v1/ping                   │         │
│  │  - Readiness: HTTP GET :3000/api/v1/ping                  │         │
│  │  - Initial Delay: 30s                                     │         │
│  │  - Period: 30s                                            │         │
│  │                                                           │         │
│  │  Environment Variables:                                   │         │
│  │  - PORT: 3000                                             │         │
│  │  - DATABASE_TYPE: sqlite                                  │         │
│  │  - FLOWISE_USERNAME: admin                                │         │
│  │  - FLOWISE_PASSWORD: *** (from ConfigMap)                 │         │
│  │  - LOG_LEVEL: debug                                       │         │
│  │  - CORS_ORIGINS: *                                        │         │
│  │  - ENABLE_METRICS: true                                   │         │
│  └───────────────────────────────────────────────────────────┘         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 📋 Port Summary Table

| Layer | Component | Inbound Port | Outbound Port | Protocol | Notes |
|-------|-----------|--------------|---------------|----------|-------|
| 1 | Route53 DNS | 53 | 53 | UDP/TCP | DNS resolution |
| 2 | WAF | 443 | 443 | HTTPS | Inspects, filters traffic |
| 3 | ALB Listener 1 | 80 | 443 | HTTP→HTTPS | Redirects to HTTPS |
| 3 | ALB Listener 2 | 443 | 80/3000 | HTTPS→HTTP | TLS termination here |
| 4 | ALB Security Group | 80, 443 | 80, 3000 | TCP | Internet to ALB |
| 4 | Node Security Group | 80, 3000 | any | TCP | ALB to Pods |
| 4 | Cluster Security Group | 443 | 443, 1025-65535 | TCP | API server ↔ Nodes |
| 5 | Ingress Controller | 80, 3000 | 80, 3000 | HTTP | Routes by path |
| 6 | Service: flowise-ui | 80 | 80 | TCP | ClusterIP, internal |
| 6 | Service: flowise-server | 3000 | 3000 | TCP | ClusterIP, internal |
| 7 | Pod: flowise-ui | 80 | - | TCP | Container port 80 |
| 7 | Pod: flowise-server | 3000 | - | TCP | Container port 3000 |

---

## 🔐 Security Group Rules Detail

### ALB Security Group
```hcl
# Inbound
- Port 80 from 0.0.0.0/0 (HTTP from Internet)
- Port 443 from 0.0.0.0/0 (HTTPS from Internet)

# Outbound
- Port 80 to Node SG (UI pods)
- Port 3000 to Node SG (Server pods)
- Port 443 to 0.0.0.0/0 (for AWS API calls)
```

### EKS Node Security Group
```hcl
# Inbound
- Port 80 from ALB SG (UI traffic)
- Port 3000 from ALB SG (Server traffic)
- Port 443 from Cluster SG (K8s API server)
- Port 1025-65535 from Cluster SG (kubelet communication)
- All traffic from Node SG (inter-node communication)
- Port 22 from Bastion SG (optional SSH access)

# Outbound
- All traffic to 0.0.0.0/0 (Internet access for pulling images, etc.)
```

### EKS Cluster Security Group
```hcl
# Inbound
- Port 443 from Node SG (Pods calling K8s API)

# Outbound
- Port 443 to Node SG (Webhooks)
- Port 1025-65535 to Node SG (kubelet, pods)
- All traffic to 0.0.0.0/0 (Internet access)
```

---

## 🎯 Request Examples

### Example 1: User accesses Homepage

```
1. User enters: https://flowise-dev.do2506.click/
2. DNS Query: flowise-dev.do2506.click → 52.77.xxx.xxx (ALB IP)
3. Browser connects to: 52.77.xxx.xxx:443
4. WAF inspects: ✅ ALLOWED (no malicious pattern)
5. ALB receives HTTPS on port 443
6. ALB terminates TLS, sends HTTP to port 80
7. Security Group: ALB SG → Node SG (port 80)
8. Ingress Controller: Path "/" → flowise-ui:80
9. Service: flowise-ui routes to pod IP 10.0.1.45:80
10. Pod: nginx serves index.html
11. Response: 200 OK with HTML content
```

**Ports traversed:** 53 → 443 → 443 → 443 → 80 → 80 → 80 → 80

**Total hops:** 8 layers, 7 port changes

---

### Example 2: User makes API call

```
1. Browser sends: POST https://flowise-dev.do2506.click/api/v1/chatflows
2. DNS Query: flowise-dev.do2506.click → 52.77.xxx.xxx (ALB IP)
3. Browser connects to: 52.77.xxx.xxx:443
4. WAF inspects: ✅ ALLOWED (rate limit OK, no SQL injection)
5. ALB receives HTTPS on port 443
6. ALB terminates TLS, sends HTTP to port 3000
7. Security Group: ALB SG → Node SG (port 3000)
8. Ingress Controller: Path "/api" → flowise-server:3000
9. Service: flowise-server routes to pod IP 10.0.1.78:3000
10. Pod: Node.js Express processes request
11. Response: 200 OK with JSON data
```

**Ports traversed:** 53 → 443 → 443 → 443 → 3000 → 3000 → 3000 → 3000

**Total hops:** 8 layers, 7 port changes

---

### Example 3: WAF blocks malicious request

```
1. Attacker sends: https://flowise-dev.do2506.click/?id=1' OR '1'='1
2. DNS Query: flowise-dev.do2506.click → 52.77.xxx.xxx
3. Browser connects to: 52.77.xxx.xxx:443
4. WAF inspects: ❌ BLOCKED (SQL injection pattern detected)
5. WAF returns: 403 Forbidden
6. Request NEVER reaches ALB
```

**Ports traversed:** 53 → 443 → 443 (stopped at WAF)

**Blocked at:** Layer 2 (WAF)

---

## 📊 Multi-Environment Port Differences

| Environment | Domain | ALB Name | WAF Rules | Ports | Replicas |
|-------------|--------|----------|-----------|-------|----------|
| **Dev** | flowise-dev.do2506.click | flowise-dev-alb | Relaxed (testing friendly) | 80, 443, 3000 | 1 UI, 1 Server |
| **Staging** | flowise-staging.do2506.click | flowise-staging-alb | Moderate (prod-like) | 80, 443, 3000 | 2 UI, 2 Server |
| **Production** | flowise.do2506.click | flowise-prod-alb | Strict (full protection) | 80, 443, 3000 | 3 UI, 3 Server |

**Key differences:**
- Port configuration: SAME across all environments
- Security rules: DIFFERENT (WAF strictness)
- Resource scaling: DIFFERENT (replica counts)
- Health check thresholds: DIFFERENT (prod more strict)

---

## 🔍 Monitoring & Observability

### CloudWatch Metrics (by Layer)

**Layer 2: WAF Metrics**
```
Namespace: AWS/WAFV2
- BlockedRequests (Count)
- AllowedRequests (Count)
- CountedRequests (Count)
- SampledRequests (List of blocked IPs)
```

**Layer 3: ALB Metrics**
```
Namespace: AWS/ApplicationELB
- TargetResponseTime (Milliseconds)
- RequestCount (Count)
- HTTPCode_Target_2XX_Count (Success)
- HTTPCode_Target_4XX_Count (Client errors)
- HTTPCode_Target_5XX_Count (Server errors)
- UnHealthyHostCount (Count)
- HealthyHostCount (Count)
- ActiveConnectionCount (Count)
```

**Layer 7: Pod Metrics (Prometheus)**
```
# Container metrics
container_cpu_usage_seconds_total
container_memory_usage_bytes
container_network_receive_bytes_total
container_network_transmit_bytes_total

# Application metrics (if enabled)
http_requests_total{path="/api", status="200"}
http_request_duration_seconds
flowise_chatflow_executions_total
```

---

## 🚨 Common Issues & Troubleshooting

### Issue 1: 502 Bad Gateway

**Symptoms:** ALB returns 502 error

**Possible causes:**
- Pod not ready (failing health check)
- Service selector mismatch
- Security group blocking traffic
- Pod crashed/restarting

**Debug steps:**
```bash
# Check pod status
kubectl get pods -n flowise-dev

# Check pod logs
kubectl logs -n flowise-dev flowise-server-xxx

# Check service endpoints
kubectl get endpoints -n flowise-dev flowise-server

# Check security group rules
aws ec2 describe-security-groups --group-ids sg-xxx
```

---

### Issue 2: 403 Forbidden from WAF

**Symptoms:** Request blocked before reaching ALB

**Possible causes:**
- SQL injection pattern in URL/body
- Rate limit exceeded
- IP in blacklist
- Geo-blocking active

**Debug steps:**
```bash
# Check WAF logs
aws logs tail /aws/waf/my-eks-dev-dev-waf --follow

# Check blocked requests
aws wafv2 get-sampled-requests \
  --web-acl-arn arn:aws:wafv2:... \
  --rule-metric-name BlockedRequests \
  --scope REGIONAL \
  --time-window StartTime=xxx,EndTime=xxx

# Temporarily disable rule for testing
# (Edit terraform.tfvars, set enable_sql_injection_rule = false)
```

---

### Issue 3: Timeout (504 Gateway Timeout)

**Symptoms:** Request times out after 60 seconds

**Possible causes:**
- ALB idle timeout too short
- Target health check failing
- Application processing too slow
- Database query hanging

**Debug steps:**
```bash
# Check ALB target health
aws elbv2 describe-target-health \
  --target-group-arn arn:aws:elasticloadbalancing:...

# Check pod resource usage
kubectl top pods -n flowise-dev

# Check application logs
kubectl logs -n flowise-dev flowise-server-xxx --tail=100

# Increase ALB timeout (if needed)
# Add annotation: alb.ingress.kubernetes.io/load-balancer-attributes: idle_timeout.timeout_seconds=300
```

---

## 📖 Related Documentation

- [WAF Architecture Position](./WAF-ARCHITECTURE-POSITION.md)
- [CloudFront Deployment Guide](./CLOUDFRONT-DEPLOYMENT.md)
- [Namespace Architecture](./NAMESPACE-ARCHITECTURE.md)
- [ArgoCD Deployment Guide](./ARGOCD-DEPLOYMENT.md)
- [Resource Limits Final](./RESOURCE-LIMITS-FINAL.md)

---

## 🔄 Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-01-05 | Initial documentation with complete traffic flow and port mapping |

---

**👨‍💻 Maintained by:** DevOps Team  
**📧 Questions?** Check [troubleshooting-guide.md](../docs/terraform-learning/troubleshooting-guide.md)
